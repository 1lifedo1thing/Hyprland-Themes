#include "worldmaprenderer.hpp"

#include <QBrush>
#include <QMutexLocker>
#include <QPen>
#include <QtConcurrent/QtConcurrentRun>
#include <QImage>
#include <QFile>
#include <QPainter>
#include <QRadialGradient>
#include <QtGlobal>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>

namespace {
constexpr double kUnit = 1.14 * 1920.0 * 1.15 / 1470.0;
constexpr double kDiscSize = 860.0;
constexpr double kCenter = 430.0;
constexpr double kWorldWidth = 1024.0;
constexpr double kWorldHeight = 512.0;

struct Reader {
    const QByteArray &bytes;
    qsizetype pos = 0;
    bool ok = true;
    bool take(quint8 &v) {
        if (!ok || pos >= bytes.size()) { ok = false; return false; }
        v = quint8(bytes.at(pos++)); return true;
    }
    bool u16(quint16 &v) {
        quint8 lo,hi;
        if (!take(lo) || !take(hi)) return false;
        v = quint16(lo) | (quint16(hi) << 8); return true;
    }
    bool u32(quint32 &v) {
        quint16 lo,hi;
        if (!u16(lo) || !u16(hi)) return false;
        v = quint32(lo) | (quint32(hi) << 16); return true;
    }
    bool text(QString &s, quint32 n, quint32 max) {
        if (!ok || n == 0 || n > max || n > quint64(bytes.size() - pos)) {
            ok = false; return false;
        }
        s = QString::fromUtf8(bytes.constData()+pos, qsizetype(n));
        pos += qsizetype(n);
        if (s.isEmpty() || s.contains(QChar::ReplacementCharacter)) {ok=false; return false;}
        return true;
    }
    bool point16(QPointF &p) {
        quint16 x,y;
        if (!u16(x) || !u16(y)) return false;
        p = QPointF(double(x)/65535.0*kWorldWidth, double(y)/65535.0*kWorldHeight);
        return true;
    }
    bool point24(QPointF &p) {
        quint32 x,y;
        if (!u32(x) || !u32(y) || x > 16777215u || y > 16777215u) {ok=false; return false;}
        p = QPointF(double(x)/16777215.0*kWorldWidth, double(y)/16777215.0*kWorldHeight);
        return true;
    }
};

QColor rgba(int red, int green, int blue, int alpha) {
    return QColor(red,green,blue,alpha);
}
}

WorldMapRenderer::WorldMapRenderer(QQuickItem *parent) : QQuickPaintedItem(parent) {
    setAntialiasing(true);
    setOpaquePainting(false);
    setRenderTarget(QQuickPaintedItem::Image);
    m_timer.setSingleShot(true);
    m_timer.setInterval(32); // coalesce QML's separate x/y/zoom assignments
    connect(&m_timer, &QTimer::timeout, this, &WorldMapRenderer::startRender);
    connect(&m_watcher, &QFutureWatcher<RenderResult>::finished,
            this, &WorldMapRenderer::finishRender);
    connect(this, &QQuickItem::visibleChanged, this, [this]() {
        if (isVisible() && m_dirty) m_timer.start();
    });
    loadAssets();
}

WorldMapRenderer::~WorldMapRenderer() {
    m_revision->fetch_add(1, std::memory_order_relaxed);
    m_timer.stop();
    // Worker has no access to the QQuickItem, only to immutable shared geometry.
    // Cancellation checks prevent leaving a runaway worker after the item dies.
    m_watcher.waitForFinished();
}

void WorldMapRenderer::componentComplete() {
    QQuickPaintedItem::componentComplete();
    invalidate();
}

void WorldMapRenderer::invalidate() {
    m_revision->fetch_add(1, std::memory_order_relaxed);
    m_dirty = true;
    if (isComponentComplete() && isVisible()) m_timer.start();
    update(); // cheap repaint of last available frame, never a geographic paint
}

void WorldMapRenderer::setError(QString value) {
    if (value == m_error) return;
    m_error = std::move(value);
    emit errorChanged();
}
void WorldMapRenderer::setCenterX(double value) {
    if (!std::isfinite(value)) return;
    value -= std::floor(value);
    if (std::abs(m_centerX-value)<1e-11) return;
    { QMutexLocker lock(&m_frameMutex); m_centerX=value; }
    emit cameraChanged(); invalidate();
}
void WorldMapRenderer::setCenterY(double value) {
    if (!std::isfinite(value)) return;
    value = std::clamp(value,0.0,1.0);
    if (std::abs(m_centerY-value)<1e-11) return;
    { QMutexLocker lock(&m_frameMutex); m_centerY=value; }
    emit cameraChanged(); invalidate();
}
void WorldMapRenderer::setZoom(double value) {
    if (!std::isfinite(value)) return;
    value = std::clamp(value,1.0,128.0);
    if (std::abs(m_zoom-value)<1e-11) return;
    { QMutexLocker lock(&m_frameMutex); m_zoom=value; }
    emit cameraChanged(); invalidate();
}
void WorldMapRenderer::setAccent(QColor value) {
    if (!value.isValid() || value == m_accent) return;
    { QMutexLocker lock(&m_frameMutex); m_accent=value; }
    emit accentChanged(); invalidate();
}

void WorldMapRenderer::loadAssets() {
    QFile terrain(QStringLiteral(":/assets/world-map/Terrain.bin"));
    QFile countries(QStringLiteral(":/assets/world-map/Countries.bin"));
    if (!terrain.open(QIODevice::ReadOnly) || !countries.open(QIODevice::ReadOnly)) {
        setError(QStringLiteral("Não foi possível abrir os dados offline Terrain.bin/Countries.bin"));
        return;
    }
    const QByteArray t = terrain.readAll(), c = countries.readAll();
    if (!loadTerrain(t) || !loadCountries(c)) {
        m_data->bands.clear(); m_data->countries.clear();
        setError(QStringLiteral("Arquivos geográficos inválidos; origem preservada"));
        return;
    }
    setError({});
}

// Byte-for-byte format: EndfieldHUD/Sources/WorldMapTerrain.swift.
bool WorldMapRenderer::loadTerrain(const QByteArray &data) {
    if (data.size() < 12 || data.size() > 3*1024*1024 || data.left(8) != "EHUDMAP1") return false;
    Reader r{data,8}; quint32 bandCount;
    if (!r.u32(bandCount) || bandCount<1 || bandCount>32) return false;
    QVector<Band> decoded; decoded.reserve(int(bandCount));
    quint64 totalPoints=0,totalPaths=0;
    for (quint32 b=0;b<bandCount;++b) {
        quint32 rawElevation,lines,fills;
        if (!r.u32(rawElevation)||!r.u32(lines)||!r.u32(fills)) return false;
        const int elevation = int(qint32(rawElevation));
        totalPaths += quint64(lines)+fills;
        if (elevation < -12000 || elevation > 12000 || lines>20000 || fills>20000 || totalPaths>40000) return false;
        Band band; band.elevation=elevation;
        band.lines.reserve(int(lines));
        band.fills.reserve(int(fills));
        for (quint32 index=0;index<lines+fills;++index) {
            quint8 closed; quint32 count;
            if (!r.take(closed) || !r.u32(count)) return false;
            totalPoints += count;
            if (closed>1 || count<2 || count>150000 || totalPoints>150000) return false;
            Contour contour;
            if (index>=lines) contour.path.setFillRule(Qt::OddEvenFill);
            for (quint32 v=0;v<count;++v) {
                QPointF point;
                if (!r.point16(point)) return false;
                if (v==0) contour.path.moveTo(point); else contour.path.lineTo(point);
            }
            if (closed) contour.path.closeSubpath();
            contour.bounds = contour.path.boundingRect();
            if (index<lines) band.lines.append(std::move(contour));
            else band.fills.append(std::move(contour));
        }
        decoded.append(std::move(band));
    }
    if (!r.ok || r.pos!=data.size()) return false;
    m_data->bands=std::move(decoded); return true;
}

// Byte-for-byte format: EndfieldHUD/Sources/WorldMapCountries.swift.
bool WorldMapRenderer::loadCountries(const QByteArray &data) {
    if (data.size()<12 || data.size()>1024*1024 || data.left(8)!="EHUDCTY1") return false;
    Reader r{data,8}; quint32 n;
    if(!r.u32(n) || n<1 || n>512) return false;
    QVector<Country> decoded; decoded.reserve(int(n));
    quint64 totalPoints=0,totalComponents=0,totalRings=0;
    for(quint32 i=0;i<n;++i) {
        quint8 idLength; quint16 nameLength; quint32 components;
        Country country;
        if (!r.take(idLength)||!r.text(country.id,idLength,12)||!r.u16(nameLength)
            ||!r.text(country.name,nameLength,128)||!r.u32(components)) return false;
        totalComponents += components;
        if (components<1 || components>8192 || totalComponents>10000) return false;
        country.components.reserve(int(components));
        for (quint32 j=0;j<components;++j) {
            quint32 rings;
            if (!r.u32(rings)) return false;
            totalRings+=rings;
            if (rings<1||rings>1024||totalRings>20000) return false;
            Component component;
            component.path.setFillRule(Qt::OddEvenFill);
            for (quint32 ring=0;ring<rings;++ring) {
                quint32 points;
                if(!r.u32(points)) return false;
                totalPoints+=points;
                if(points<3||points>120000||totalPoints>120000) return false;
                for(quint32 v=0;v<points;++v) {
                    QPointF point;
                    if(!r.point24(point)) return false;
                    if(!v) component.path.moveTo(point); else component.path.lineTo(point);
                }
                component.path.closeSubpath();
            }
            component.bounds=component.path.boundingRect();
            if(component.bounds.isEmpty()) return false;
            country.components.append(std::move(component));
        }
        decoded.append(std::move(country));
    }
    if(!r.ok||r.pos!=data.size())return false;
    m_data->countries=std::move(decoded);return true;
}


// QML / QQuickPaintedItem lifecycle stays on the GUI/render threads.
// Only the immutable geographic snapshot and a QImage are used by QtConcurrent.
void WorldMapRenderer::startRender() {
    if (!isComponentComplete() || !isVisible() || !m_dirty || m_busy ||
        m_data->bands.isEmpty() || m_data->countries.isEmpty()) return;
    RenderRequest request;
    {
        QMutexLocker lock(&m_frameMutex);
        request.centerX = m_centerX;
        request.centerY = m_centerY;
        request.zoom = m_zoom;
        request.accent = m_accent;
    }
    request.revision = m_revision->load(std::memory_order_relaxed);
    // Bounding raster budget independent from zoom. Does not allocate enormous textures at 128x.
    request.pixels = std::clamp(int(std::ceil(std::max(width(), height()) * 1.25)), 860, 1536);
    m_dirty = false;
    m_busy = true;
    const std::shared_ptr<const MapData> data = m_data;
    const auto token = m_revision;
    m_watcher.setFuture(QtConcurrent::run([data, request, token]() {
        return rasterize(*data, request, *token);
    }));
}

void WorldMapRenderer::finishRender() {
    const RenderResult result = m_watcher.result();
    m_busy = false;
    if (!result.image.isNull() &&
        m_revision->load(std::memory_order_relaxed) == result.request.revision) {
        {
            QMutexLocker lock(&m_frameMutex);
            m_frame = result.image;
            m_frameRequest = result.request;
        }
        update();
    }
    if (m_dirty && isVisible()) m_timer.start();
}

WorldMapRenderer::RenderResult WorldMapRenderer::rasterize(
    const MapData &data, const RenderRequest &request,
    const std::atomic<quint64> &revision)
{
    RenderResult result;
    result.request = request;
    if (revision.load(std::memory_order_relaxed) != request.revision) return result;
    QImage raster(request.pixels, request.pixels, QImage::Format_ARGB32_Premultiplied);
    if (raster.isNull()) return result;
    raster.fill(Qt::transparent);
    {
        QPainter painter(&raster);
        painter.setRenderHint(QPainter::Antialiasing, true);
        painter.scale(double(request.pixels) / kDiscSize,
                      double(request.pixels) / kDiscSize);
        painter.fillRect(QRectF(0,0,kDiscSize,kDiscSize),rgba(31,31,31,228));
        if (!drawMap(&painter, data, request, revision)) return result;
    }
    if (revision.load(std::memory_order_relaxed) == request.revision)
        result.image = std::move(raster);
    return result;
}

bool WorldMapRenderer::drawMap(QPainter *painter, const MapData &data,
                               const RenderRequest &request,
                               const std::atomic<quint64> &revision)
{
    QString highlight;
    const QPointF focus(request.centerX*kWorldWidth,request.centerY*kWorldHeight);
    for (const Country &country : data.countries) {
        if (revision.load(std::memory_order_relaxed) != request.revision) return false;
        for (const Component &part : country.components) {
            if (part.bounds.contains(focus) && part.path.contains(focus)) {
                highlight=country.id; break;
            }
        }
        if(!highlight.isEmpty())break;
    }
    for(int wrap=-1;wrap<=1;++wrap) {
        if (revision.load(std::memory_order_relaxed) != request.revision ||
            !drawWrappedWorld(painter,wrap,highlight,data,request,revision)) return false;
    }
    return true;
}

void WorldMapRenderer::paint(QPainter *painter) {
    QImage cached;
    RenderRequest prior;
    RenderRequest current;
    {
        QMutexLocker lock(&m_frameMutex);
        cached = m_frame;  // cheap implicitly shared copy; the worker never mutates it
        prior = m_frameRequest;
        current.centerX = m_centerX;
        current.centerY = m_centerY;
        current.zoom = m_zoom;
        current.accent = m_accent;
    }
    if (width() <= 0 || height() <= 0) return;
    painter->setRenderHint(QPainter::Antialiasing, true);
    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->save();
    painter->scale(width() / kDiscSize, height() / kDiscSize);
    painter->fillRect(QRectF(0,0,kDiscSize,kDiscSize),rgba(31,31,31,228));
    if (!cached.isNull()) {
        // Transform the last finished frame while the asynchronous painter catches up.
        // The transform uses the same 440x220 world-to-screen mapping as Stage 7.
        // The shortest wrapped X difference prevents discontinuities at the dateline.
        double dx = prior.centerX - current.centerX;
        dx -= std::round(dx);
        const double scale = current.zoom / prior.zoom;
        const double newWorldW = 440.0 * current.zoom * kUnit;
        const double newWorldH = 220.0 * current.zoom * kUnit;
        const double left = kCenter + dx * newWorldW - kCenter * scale;
        const double top  = kCenter + (prior.centerY-current.centerY) * newWorldH - kCenter * scale;
        painter->save();
        painter->setClipRect(QRectF(0,0,kDiscSize,kDiscSize));
        // Source overwrites fallback pixels rather than double-compositing its translucent base.
        painter->setCompositionMode(QPainter::CompositionMode_Source);
        painter->drawImage(QRectF(left,top,kDiscSize*scale,kDiscSize*scale),cached);
        painter->restore();
    }
    // Source centre-backdrop alpha ramp remains screen fixed, not warped with old imagery.
    QRadialGradient mask(QPointF(kCenter,kCenter),kCenter);
    mask.setColorAt(0.00,Qt::white);
    mask.setColorAt(0.52,Qt::white);
    mask.setColorAt(0.74,QColor(255,255,255,140));
    mask.setColorAt(1.00,QColor(255,255,255,0));
    painter->setCompositionMode(QPainter::CompositionMode_DestinationIn);
    painter->fillRect(QRectF(0,0,kDiscSize,kDiscSize),QBrush(mask));
    painter->restore();
}

// Reconstruct the original dark relief painter (WorldMapRasterPainter.swift).
// QPainter replaces CoreGraphics; the source EHUDMAP1 / EHUDCTY1 remains intact.
bool WorldMapRenderer::drawWrappedWorld(QPainter *painter, int wrap, const QString &highlight,
                                        const MapData &data, const RenderRequest &request,
                                        const std::atomic<quint64> &revision) {
    const double imageW = 440.0 * request.zoom * kUnit;
    const double imageH = 220.0 * request.zoom * kUnit;
    const double sx = imageW / kWorldWidth;
    const double sy = imageH / kWorldHeight;
    const double offsetX = kCenter - request.centerX * imageW + wrap * imageW;
    const double offsetY = kCenter - request.centerY * imageH;
    const QRectF visible(-offsetX/sx, -offsetY/sy, kDiscSize/sx, kDiscSize/sy);
    if (!visible.intersects(QRectF(0, 0, kWorldWidth, kWorldHeight))) return true;
    const QRectF padded = visible.adjusted(-12/sx, -12/sy, 12/sx, 12/sy);

    painter->save();
    painter->translate(offsetX, offsetY);
    painter->scale(sx, sy);
    painter->setClipRect(QRectF(0, 0, kWorldWidth, kWorldHeight), Qt::IntersectClip);

    // The original renderer layers each country in four subdued raised plates,
    // then draws an accent-tinted face for the country at the camera centre.
    QPainterPath land;
    land.setFillRule(Qt::OddEvenFill);
    for (const Country &country : data.countries) {
        if (revision.load(std::memory_order_relaxed) != request.revision) { painter->restore(); return false; }
        const bool selected = country.id == highlight;
        for (const Component &comp : country.components) {
            if (revision.load(std::memory_order_relaxed) != request.revision) { painter->restore(); return false; }
            if (!padded.intersects(comp.bounds)) continue;
            const QPainterPath &path = comp.path;
            land.addPath(path);

            painter->save();
            painter->translate(3.0/sx, 9.0/sy);
            painter->fillPath(path, rgba(0, 0, 0, 107)); // 0.42 alpha
            painter->restore();

            for (int i=0;i<4;++i) {
                const double amount = double(i)/3.0;
                const double depth = double(4-i)*1.6;
                painter->save();
                painter->translate(depth*0.35/sx, depth/sy);
                QColor fill;
                if (selected) {
                    const double mix = 0.48 - amount*0.12;
                    fill.setRgbF(request.accent.redF()*(1-mix),
                                 request.accent.greenF()*(1-mix),
                                 request.accent.blueF()*(1-mix), 0.95);
                } else {
                    const double gray = 0.19 + amount*0.12;
                    fill.setRgbF(gray,gray,gray,0.98);
                }
                painter->fillPath(path,fill);
                painter->restore();
            }
            const QColor face = selected
                ? QColor::fromRgbF(request.accent.redF(),request.accent.greenF(),request.accent.blueF(),0.51)
                : QColor::fromRgbF(0.60,0.60,0.60,0.43);
            painter->fillPath(path,face);
            QColor edge;
            if (selected) {
                const double mix = 0.38;
                edge.setRgbF(request.accent.redF()*(1-mix)+mix,
                             request.accent.greenF()*(1-mix)+mix,
                             request.accent.blueF()*(1-mix)+mix,0.95);
            } else edge.setRgbF(0.92,0.92,0.92,0.82);
            painter->setPen(QPen(edge, (selected ? 1.50 : 1.05)/sx,
                                 Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
            painter->setBrush(Qt::NoBrush);
            painter->drawPath(path);
        }
    }

    // Fine diagonal hatching, clipped to the land itself, as in the original.
    // Lines are 4.5 final pixels apart; keep the spacing constant at any zoom.
    if (!land.isEmpty()) {
        painter->save();
        painter->setClipPath(land,Qt::IntersectClip);
        const double spacing=4.5/sx;
        const double phase=std::fmod(request.centerX*440*request.zoom-request.centerY*220*request.zoom,4.5)/sx;
        painter->setPen(QPen(QColor::fromRgbF(1,1,1,0.17),1.3/sx));
        const double lo=std::floor((visible.left()-visible.height())/spacing)*spacing;
        for(double x=lo; x<=visible.right()+visible.height(); x+=spacing) {
            painter->drawLine(QPointF(x-phase,visible.top()),
                              QPointF(x-phase+visible.height(),visible.bottom()));
        }
        painter->restore();
    }

    // 12 × 6 source graticule, lighter than the relief and country borders.
    painter->setPen(QPen(QColor::fromRgbF(.80,.80,.80,.09),.35/sx));
    for (int i=0;i<=12;++i) {
        const double x=i*kWorldWidth/12.0;
        if (x>=padded.left() && x<=padded.right())
            painter->drawLine(QPointF(x,0),QPointF(x,kWorldHeight));
    }
    for (int i=0;i<=6;++i) {
        const double y=i*kWorldHeight/6.0;
        if (y>=padded.top() && y<=padded.bottom())
            painter->drawLine(QPointF(0,y),QPointF(kWorldWidth,y));
    }

    // Crucial performance improvement: no entire global contour is repainted
    // when a small country is in view.  This matches the source painter's
    // geometry culling without introducing unsafe UI-thread QQuick access.
    painter->setBrush(Qt::NoBrush);
    painter->setPen(QPen(QColor::fromRgbF(.72,.78,.80,.29),.38/sx,
                         Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
    for (const Band &band : data.bands) {
        if (revision.load(std::memory_order_relaxed) != request.revision) { painter->restore(); return false; }
        if (band.elevation==0) continue; // country files supply coastlines
        for (const Contour &contour : band.lines) {
            if (revision.load(std::memory_order_relaxed) != request.revision) { painter->restore(); return false; }
            if (!contour.bounds.intersects(padded)) continue;
            painter->drawPath(contour.path);
        }
    }
    painter->restore();
    return revision.load(std::memory_order_relaxed) == request.revision;
}
