#include "storagecontroller.hpp"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <array>
#include <vector>
#include <QProcess>
#include <QSettings>
#include <QStorageInfo>
#include <QSet>
#include <QtConcurrentRun>
#include <algorithm>

namespace {
// Bounded, read-only walk. No automatic scan and no traversal of other disks.
QVariantMap scanLocalStorage(QString root, const QString &volumeId) {
    constexpr int maxFiles = 15000, maxEntries = 30000, maxDirectories = 10000, maxDepth = 10;
    constexpr qint64 maxTimeMs = 12000;
    QVariantMap result{{"volumeId", volumeId}, {"root", root}, {"error", QString()},
                       {"truncated", false}, {"files", 0}, {"directories", 0},
                       {"bytes", qint64(0)}};
    const QFileInfo source(root);
    const QStorageInfo sourceDisk(root);
    if (!source.exists() || !source.isDir() || source.isSymLink() ||
        !sourceDisk.isValid() || !sourceDisk.isReady()) {
        result["error"] = QStringLiteral("A pasta selecionada nao esta acessivel.");
        return result;
    }
    struct Bucket { QString title; qint64 bytes{}; int count{}; };
    std::array<Bucket, 7> buckets{{
        {QStringLiteral("Imagens")}, {QStringLiteral("Videos")},
        {QStringLiteral("Audio")}, {QStringLiteral("Documentos")},
        {QStringLiteral("Compactados")}, {QStringLiteral("Codigo")},
        {QStringLiteral("Outros")}
    }};
    const auto category = [](const QString &ext) -> int {
        static const QSet<QString> images{"png","jpg","jpeg","webp","gif","bmp","tif","tiff","heic","svg","avif"};
        static const QSet<QString> videos{"mp4","mkv","mov","webm","avi","m4v","wmv","flv","ts"};
        static const QSet<QString> audio{"mp3","flac","wav","ogg","m4a","opus","aac","wma"};
        static const QSet<QString> docs{"pdf","doc","docx","odt","txt","md","csv","xls","xlsx","ppt","pptx","epub"};
        static const QSet<QString> archives{"zip","tar","gz","xz","zst","7z","rar","bz2","iso","appimage"};
        static const QSet<QString> code{"c","cpp","h","hpp","rs","go","py","js","jsx","ts","tsx","java","kt","html","css","sh","qml","json","toml","yaml","yml"};
        if (images.contains(ext)) return 0;
        if (videos.contains(ext)) return 1;
        if (audio.contains(ext)) return 2;
        if (docs.contains(ext)) return 3;
        if (archives.contains(ext)) return 4;
        if (code.contains(ext)) return 5;
        return 6;
    };
    struct Large { QString path; QString name; qint64 bytes{}; };
    std::vector<Large> largest;
    std::vector<QPair<QString,int>> pending{{root, 0}};
    int files = 0, directories = 0, entries = 0;
    qint64 total = 0;
    bool truncated = false;
    QElapsedTimer watch; watch.start();
    while (!pending.empty()) {
        if (files >= maxFiles || entries >= maxEntries || directories >= maxDirectories || watch.elapsed() >= maxTimeMs) {
            truncated = true; break;
        }
        const auto [folder, depth] = pending.back(); pending.pop_back();
        // Do not cross mounted filesystems or follow symlinks.
        const QStorageInfo disk(folder);
        if (!disk.isValid() || disk.device() != sourceDisk.device()) continue;
        ++directories;
        QDirIterator iterator(folder, QDir::AllEntries | QDir::NoDotAndDotDot |
                            QDir::NoSymLinks | QDir::Hidden | QDir::System);
        while (iterator.hasNext()) {
            if (files >= maxFiles || entries >= maxEntries || watch.elapsed() >= maxTimeMs) {
                truncated = true; break;
            }
            iterator.next(); ++entries;
            const QFileInfo info = iterator.fileInfo();
            if (info.isSymLink()) continue;
            if (info.isDir()) {
                if (depth < maxDepth) pending.push_back({info.absoluteFilePath(), depth + 1});
                else truncated = true;
            } else if (info.isFile()) {
                const qint64 size = std::max<qint64>(0, info.size());
                auto &bucket = buckets[category(info.suffix().toLower())];
                bucket.bytes += size; ++bucket.count; ++files; total += size;
                if (size > 0 && (largest.size() < 8 || size > largest.back().bytes)) {
                    largest.push_back({info.absoluteFilePath(), info.fileName(), size});
                    std::sort(largest.begin(), largest.end(), [](const Large &a, const Large &b) {
                        return a.bytes == b.bytes ? a.path < b.path : a.bytes > b.bytes;
                    });
                    if (largest.size() > 8) largest.pop_back();
                }
            }
        }
        if (truncated && (files >= maxFiles || entries >= maxEntries || watch.elapsed() >= maxTimeMs)) break;
    }
    if (!pending.empty()) truncated = true;
    QVariantList categories, biggest;
    for (const auto &b : buckets)
        categories.append(QVariantMap{{"name", b.title}, {"bytes", b.bytes}, {"files", b.count},
            {"fraction", total > 0 ? double(b.bytes) / double(total) : 0.0}});
    for (const auto &b : largest)
        biggest.append(QVariantMap{{"name", b.name}, {"path", b.path}, {"bytes", b.bytes}});
    result["categories"] = categories;
    result["largest"] = biggest;
    result["files"] = files;
    result["directories"] = directories;
    result["bytes"] = total;
    result["truncated"] = truncated;
    result["elapsedMs"] = watch.elapsed();
    return result;
}
} // namespace

StorageController::StorageController(QObject *parent) : QObject(parent) {
    m_selection = QSettings().value("storage/volume").toString();
    m_timer.setInterval(60'000);
    connect(&m_timer, &QTimer::timeout, this, &StorageController::refresh);
    connect(&m_reader, &QFutureWatcherBase::finished, this, [this] { m_volumes = m_reader.result(); emit changed(); });
    connect(&m_scanWatcher, &QFutureWatcherBase::finished, this, [this] {
        const auto snapshot = m_scanWatcher.result();
        const QString activeId = state().value("volume").toMap().value("id").toString();
        if (activeId != snapshot.value("volumeId").toString()) return;
        m_analysis = snapshot;
        emit analysisChanged();
    });
}
StorageController::~StorageController() { m_reader.waitForFinished(); m_scanWatcher.waitForFinished(); }
QVariantList StorageController::readVolumes() {
    // Select local block-backed mounts before statfs; a stalled network share
    // must not prevent a reading. Btrfs subvolumes share the same capacity.
    QFile mounts("/proc/self/mountinfo"); if (!mounts.open(QIODevice::ReadOnly)) return {};
    QList<QPair<QString, QString>> paths{{"/", ""}};
    for (const auto &line : mounts.readAll().split('\n')) {
        const auto halves = line.split(' '); const int separator = halves.indexOf("-");
        if (separator < 6 || separator + 2 >= halves.size()) continue;
        const QByteArray device = halves[separator + 2], type = halves[separator + 1];
        if (!device.startsWith("/dev/") || type == "squashfs" || type == "iso9660") continue;
        QByteArray path = halves[4]; path.replace("\\040", " ").replace("\\011", "\t").replace("\\134", "\\");
        if (path != "/") paths.append({QString::fromUtf8(path), QString::fromUtf8(device)});
    }
    QVariantList result; QSet<QByteArray> seen;
    for (const auto &[path, ignored] : paths) {
        Q_UNUSED(ignored)
        QStorageInfo disk(path);
        if (!disk.isValid() || !disk.isReady() || disk.bytesTotal() <= 0 || disk.bytesAvailable() < 0) continue;
        const QByteArray identity = disk.device().isEmpty() ? path.toUtf8() : disk.device();
        if (seen.contains(identity)) continue;
        seen.insert(identity);
        const qint64 total = disk.bytesTotal(), available = std::clamp(disk.bytesAvailable(), qint64(0), total);
        const QString name = disk.name().isEmpty() ? path : disk.name();
        result.append(QVariantMap{{"id", QString::fromUtf8(identity)}, {"path", path}, {"name", name},
            {"total", total}, {"available", available}, {"used", total - available}, {"fraction", double(total - available) / total}});
    }
    return result;
}
QVariantMap StorageController::state() const {
    QVariantMap selected;
    for (const auto &value : m_volumes) if (value.toMap().value("id").toString() == m_selection) { selected = value.toMap(); break; }
    if (selected.isEmpty() && !m_volumes.isEmpty()) selected = m_volumes.first().toMap();
    return {{"volumes", m_volumes}, {"volume", selected}, {"loading", m_reader.isRunning()}};
}
QVariantMap StorageController::analysis() const {
    QVariantMap output = m_analysis;
    output["loading"] = m_scanWatcher.isRunning();
    return output;
}
void StorageController::setActive(bool active) {
    if (m_active == active) return;
    m_active = active;
    if (active) { refresh(); m_timer.start(); } else m_timer.stop();
    emit activeChanged();
}
void StorageController::refresh() {
    if (m_reader.isRunning()) return;
    m_reader.setFuture(QtConcurrent::run(readVolumes)); emit changed();
}
void StorageController::selectVolume(const QString &id) {
    for (const auto &value : m_volumes) if (value.toMap().value("id").toString() == id) {
        m_selection = id; QSettings().setValue("storage/volume", id); m_analysis.clear(); emit analysisChanged(); emit changed(); return;
    }
}
bool StorageController::openDolphin() {
    return QProcess::startDetached("dolphin", {state().value("volume").toMap().value("path", "/").toString()});
}

void StorageController::analyze() {
    if (m_scanWatcher.isRunning()) return;
    const QVariantMap volume = state().value("volume").toMap();
    const QString id = volume.value("id").toString();
    QString root = volume.value("path").toString();
    if (id.isEmpty() || root.isEmpty()) {
        m_analysis = {{"error", QStringLiteral("Nenhum volume disponivel para analise.")}};
        emit analysisChanged(); return;
    }
    // On root, inspect personal files only, not /proc, /sys, /dev or the whole OS.
    if (root == QStringLiteral("/")) {
        const QString home = QDir::homePath();
        if (QStorageInfo(home).device() != QStorageInfo(root).device()) {
            m_analysis = {{"error", QStringLiteral("A pasta pessoal pertence a outro volume. Selecione esse disco.")}};
            emit analysisChanged(); return;
        }
        root = home;
    }
    m_analysis = {{"root", root}, {"volumeId", id}, {"files", 0}, {"bytes", qint64(0)}};
    emit analysisChanged();
    m_scanWatcher.setFuture(QtConcurrent::run([root, id] { return scanLocalStorage(root, id); }));
    emit analysisChanged();
}
bool StorageController::revealAnalyzedFile(const QString &path) {
    // Only one of the files returned by the latest completed local scan.
    if (m_scanWatcher.isRunning() || path.isEmpty()) return false;
    const QString id = state().value("volume").toMap().value("id").toString();
    if (m_analysis.value("volumeId").toString() != id) return false;
    for (const auto &value : m_analysis.value("largest").toList()) {
        if (value.toMap().value("path").toString() == path && QFileInfo(path).isFile())
            return QProcess::startDetached(QStringLiteral("dolphin"), {QFileInfo(path).absolutePath()});
    }
    return false;
}
