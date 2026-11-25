#pragma once

#include <QByteArray>
#include <QColor>
#include <QFutureWatcher>
#include <QImage>
#include <QMutex>
#include <QPainter>
#include <QPainterPath>
#include <QQuickPaintedItem>
#include <QString>
#include <QTimer>
#include <QVector>
#include <atomic>
#include <memory>

// Etapa 8: off-thread Qt raster of the original EHUDMAP1 / EHUDCTY1 records.
// Never access QQuickItem or GUI state in QtConcurrent worker. UI only blits
// a completed frame; stale work is cancelled/coalesced on pan / zoom / accent.
class WorldMapRenderer : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(double centerX READ centerX WRITE setCenterX NOTIFY cameraChanged)
    Q_PROPERTY(double centerY READ centerY WRITE setCenterY NOTIFY cameraChanged)
    Q_PROPERTY(double zoom READ zoom WRITE setZoom NOTIFY cameraChanged)
    Q_PROPERTY(QColor accent READ accent WRITE setAccent NOTIFY accentChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
public:
    explicit WorldMapRenderer(QQuickItem *parent = nullptr);
    ~WorldMapRenderer() override;
    void paint(QPainter *painter) override;
    double centerX() const { return m_centerX; }
    double centerY() const { return m_centerY; }
    double zoom() const { return m_zoom; }
    QColor accent() const { return m_accent; }
    QString error() const { return m_error; }
    void setCenterX(double value);
    void setCenterY(double value);
    void setZoom(double value);
    void setAccent(QColor value);

signals:
    void cameraChanged();
    void accentChanged();
    void errorChanged();

protected:
    void componentComplete() override;

private:
    struct Component { QPainterPath path; QRectF bounds; };
    struct Country { QString id; QString name; QVector<Component> components; };
    struct Contour { QPainterPath path; QRectF bounds; };
    struct Band { int elevation = 0; QVector<Contour> lines; QVector<Contour> fills; };
    struct MapData { QVector<Country> countries; QVector<Band> bands; };
    struct RenderRequest {
        double centerX = 0;
        double centerY = 0;
        double zoom = 1;
        QColor accent;
        quint64 revision = 0;
        int pixels = 1024;
    };
    struct RenderResult { QImage image; RenderRequest request; };

    void loadAssets();
    bool loadTerrain(const QByteArray &data);
    bool loadCountries(const QByteArray &data);
    void setError(QString value);
    void invalidate();
    void startRender();
    void finishRender();
    static RenderResult rasterize(const MapData &data,
                                  const RenderRequest &request,
                                  const std::atomic<quint64> &revision);
    static bool drawMap(QPainter *painter, const MapData &data,
                        const RenderRequest &request,
                        const std::atomic<quint64> &revision);
    static bool drawWrappedWorld(QPainter *painter, int wrap,
                                 const QString &highlight, const MapData &data,
                                 const RenderRequest &request,
                                 const std::atomic<quint64> &revision);

    std::shared_ptr<MapData> m_data = std::make_shared<MapData>();
    std::shared_ptr<std::atomic<quint64>> m_revision =
        std::make_shared<std::atomic<quint64>>(0);
    QFutureWatcher<RenderResult> m_watcher;
    QTimer m_timer;
    mutable QMutex m_frameMutex;
    QImage m_frame;
    RenderRequest m_frameRequest;
    bool m_busy = false;
    bool m_dirty = true;
    double m_centerX = (114.0579 + 180.0) / 360.0;
    double m_centerY = (90.0 - 22.5431) / 180.0;
    double m_zoom = 3.0;
    QColor m_accent = QColor("#FAD41F");
    QString m_error;
};
