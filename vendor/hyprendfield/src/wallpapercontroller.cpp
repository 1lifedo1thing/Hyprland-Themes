// HYPR_ENDFIELD_WALLPAPER_STAGE16 — uses the installed end4-pC switchwall.sh.
#include "wallpapercontroller.hpp"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSet>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>
#include <QtConcurrentRun>
#include <algorithm>

namespace {
QString configFile() {
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/illogical-impulse/config.json";
}
QString switchwallFile() {
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + "/quickshell/end4-pC/scripts/colors/switchwall.sh";
}
QString currentWallpaper() {
    QFile file(configFile());
    if (!file.open(QIODevice::ReadOnly)) return {};
    const auto document = QJsonDocument::fromJson(file.read(2 * 1024 * 1024));
    return document.object().value("background").toObject().value("wallpaperPath").toString();
}
QString thumbnailsDir() {
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/wallpaper-thumbnails-v16";
}
bool isVideo(const QString &suffix) {
    return QStringList{"mp4", "webm", "mkv", "mov", "avi"}.contains(suffix);
}
bool isImage(const QString &suffix) {
    return QStringList{"png", "jpg", "jpeg", "webp", "bmp", "tif", "tiff", "gif"}.contains(suffix);
}
QString thumbnail(const QFileInfo &info, const QString &cacheDir, bool video) {
    const auto seed = info.absoluteFilePath() + '|' + QString::number(info.size()) + '|'
        + QString::number(info.lastModified().toMSecsSinceEpoch());
    const QString key = QString::fromLatin1(QCryptographicHash::hash(seed.toUtf8(), QCryptographicHash::Sha256).toHex());
    const QString target = cacheDir + '/' + key + ".jpg";
    if (QFileInfo(target).isFile() && QFileInfo(target).size() > 0) return QUrl::fromLocalFile(target).toString();
    const QString temporary = cacheDir + "/." + key + ".jpg.tmp";
    if (video) {
        const QString program = QStandardPaths::findExecutable("ffmpeg");
        if (program.isEmpty()) return {};
        QProcess ffmpeg;
        ffmpeg.start(program, {"-hide_banner", "-loglevel", "error", "-nostdin", "-y",
            "-ss", "0.3", "-i", info.absoluteFilePath(), "-frames:v", "1", "-vf", "scale=640:-2",
            "-q:v", "4", "-f", "image2", "-update", "1", temporary});
        if (!ffmpeg.waitForStarted(2500)) return {};
        if (!ffmpeg.waitForFinished(7000)) { ffmpeg.kill(); ffmpeg.waitForFinished(500); QFile::remove(temporary); return {}; }
        if (ffmpeg.exitCode() != 0 || !QFileInfo(temporary).isFile()) { QFile::remove(temporary); return {}; }
    } else {
        QImageReader reader(info.absoluteFilePath());
        reader.setAutoTransform(true);
        const QSize size = reader.size();
        if (!size.isValid() || size.width() > 32768 || size.height() > 32768) return {};
        reader.setScaledSize(size.scaled(640, 360, Qt::KeepAspectRatio));
        auto image = reader.read();
        if (image.isNull() || !QImageWriter(temporary, "jpeg").write(image.convertToFormat(QImage::Format_RGB888))) {
            QFile::remove(temporary); return {};
        }
    }
    if (!QFile::rename(temporary, target)) { QFile::remove(temporary); return {}; }
    return QUrl::fromLocalFile(target).toString();
}
QVariantList scanWallpapers() {
    const QString root = QDir::homePath() + "/Pictures/Wallpapers";
    QSet<QString> seen;
    QStringList paths;
    // Do not follow symlinks or scan unrelated directories / mounted network volumes.
    if (QDir(root).exists()) {
        QDirIterator it(root, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        unsigned examined = 0;
        while (it.hasNext() && examined++ < 20000 && paths.size() < 180) {
            const QString path = it.next();
            const QFileInfo info = it.fileInfo();
            if (!info.isFile() || info.isSymLink()) continue;
            const auto suffix = info.suffix().toLower();
            if (!isImage(suffix) && !isVideo(suffix)) continue;
            if (seen.contains(path)) continue;
            paths.append(path); seen.insert(path);
        }
    }
    // Current wallpaper can be outside Pictures/Wallpapers; show it if accessible.
    const QString active = currentWallpaper();
    const QFileInfo activeInfo(active);
    if (!active.isEmpty() && activeInfo.isFile() && !seen.contains(active)
            && (isImage(activeInfo.suffix().toLower()) || isVideo(activeInfo.suffix().toLower()))) paths.prepend(active);
    std::sort(paths.begin(), paths.end(), [](const QString &a, const QString &b) {
        return QString::compare(QFileInfo(a).fileName(), QFileInfo(b).fileName(), Qt::CaseInsensitive) < 0;
    });
    const QString cacheDir = thumbnailsDir();
    QDir().mkpath(cacheDir);
    QVariantList result;
    for (const auto &path : paths) {
        QFileInfo info(path);
        const bool video = isVideo(info.suffix().toLower());
        const QString preview = thumbnail(info, cacheDir, video);
        result.append(QVariantMap{{"name", info.completeBaseName()}, {"path", info.absoluteFilePath()},
            {"preview", preview}, {"video", video}});
    }
    return result;
}
QVariantMap applyWallpaper(const QString &path) {
    const QFileInfo info(path);
    if (!info.isFile()) return {{"error", QStringLiteral("Arquivo não encontrado.")}};
    const QString suffix = info.suffix().toLower();
    if (!isVideo(suffix) && !isImage(suffix)) return {{"error", QStringLiteral("Formato não suportado.")}};
    const QString script = switchwallFile();
    if (!QFileInfo(script).isFile()) return {{"error", QStringLiteral("switchwall.sh do end4-pC não encontrado.")}};
    const QString bash = QStandardPaths::findExecutable("bash");
    if (bash.isEmpty()) return {{"error", QStringLiteral("bash não encontrado.")}};
    QProcess process;
    // HYPR_ENDFIELD_WALLPAPER_FDS_16B: switchwall.sh starts mpvpaper in the
    // background. Redirect inherited descriptors before the short-lived
    // QProcess is created, otherwise mpvpaper can lose stdout/stderr and exit.
    process.setStandardInputFile(QProcess::nullDevice());
    process.setStandardOutputFile(QProcess::nullDevice());
    process.setStandardErrorFile(QProcess::nullDevice());
#ifdef Q_OS_UNIX
    // HYPR_ENDFIELD_WALLPAPER_SESSION_16C: the Bash script launches mpvpaper in
    // the background. Put Bash (and its children) in a different session so
    // Ctrl+C/terminal HUP on Endfield cannot kill the wallpaper player.
    // Qt 6.7+ (the supported Arch Qt6 version).
    process.setUnixProcessParameters(QProcess::UnixProcessFlag::CreateNewSession
        | QProcess::UnixProcessFlag::DisconnectControllingTerminal);
#endif
    process.start(bash, {script, "--image", info.absoluteFilePath()});
    if (!process.waitForStarted(3000)) return {{"error", QStringLiteral("Não foi possível iniciar switchwall.sh.")}};
    if (!process.waitForFinished(120000)) {
        process.kill(); process.waitForFinished(1000);
        return {{"error", QStringLiteral("A aplicação ultrapassou 120 segundos. Confira o wallpaper atual.")}};
    }
    const QString updated = currentWallpaper();
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0
        || QFileInfo(updated).absoluteFilePath() != info.absoluteFilePath()) {
        return {{"error", QStringLiteral("O switchwall.sh não confirmou a aplicação. Verifique FFmpeg/mpvpaper e o log.")}};
    }
    return {{"path", info.absoluteFilePath()}};
}
}

WallpaperController::WallpaperController(QObject *parent) : QObject(parent), m_activePath(currentWallpaper()) {
    connect(&m_scan, &QFutureWatcherBase::finished, this, [this] {
        const QString selected = m_items.value(m_index).toMap().value("path").toString();
        m_items = m_scan.result();
        m_index = 0;
        for (int i = 0; i < m_items.size(); ++i) {
            const QString path = m_items[i].toMap().value("path").toString();
            if (path == selected) { m_index = i; break; }
            if (path == m_activePath) m_index = i;
        }
        if (m_recheck) { m_recheck = false; refresh(); }
        emit changed();
    });
    connect(&m_apply, &QFutureWatcherBase::finished, this, [this] {
        const auto result = m_apply.result();
        m_error = result.value("error").toString();
        m_message = m_error.isEmpty() ? QStringLiteral("Wallpaper aplicado ao Quickshell.") : QString();
        if (m_error.isEmpty()) setCurrent(result.value("path").toString());
        emit changed();
    });
}
WallpaperController::~WallpaperController() { m_scan.waitForFinished(); m_apply.waitForFinished(); }
QVariantMap WallpaperController::state() const {
    return {{"items", m_items}, {"index", m_index}, {"activePath", m_activePath},
            {"loading", m_scan.isRunning()}, {"busy", m_apply.isRunning()},
            {"error", m_error}, {"message", m_message}};
}
void WallpaperController::setCurrent(const QString &path) {
    if (m_activePath == path) return;
    m_activePath = path; emit changed();
}
void WallpaperController::refresh() {
    if (m_scan.isRunning()) { m_recheck = true; return; }
    m_error.clear(); m_message.clear();
    m_activePath = currentWallpaper();
    m_scan.setFuture(QtConcurrent::run(scanWallpapers));
    emit changed();
}
void WallpaperController::syncActive() {
    if (m_apply.isRunning()) return;
    const QString path = currentWallpaper();
    if (path == m_activePath) return;
    setCurrent(path);
    int index = -1;
    for (int i = 0; i < m_items.size(); ++i)
        if (m_items[i].toMap().value("path").toString() == path) { index = i; break; }
    if (index >= 0) select(index);
    else refresh();
}
void WallpaperController::select(int index) {
    if (m_items.isEmpty()) return;
    const int nextIndex = std::clamp(index, 0, int(m_items.size()) - 1);
    if (nextIndex == m_index) return;
    m_index = nextIndex; m_error.clear(); m_message.clear(); emit changed();
}
void WallpaperController::next() { if (!m_items.isEmpty()) select((m_index + 1) % m_items.size()); }
void WallpaperController::previous() { if (!m_items.isEmpty()) select((m_index + m_items.size() - 1) % m_items.size()); }
void WallpaperController::applySelected() {
    if (m_scan.isRunning() || m_apply.isRunning() || m_items.isEmpty()) return;
    const QString path = m_items.value(m_index).toMap().value("path").toString();
    if (path.isEmpty()) return;
    m_error.clear(); m_message.clear();
    m_apply.setFuture(QtConcurrent::run([path] { return applyWallpaper(path); }));
    emit changed();
}
