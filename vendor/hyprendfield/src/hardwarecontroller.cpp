#include "hardwarecontroller.hpp"
// HYPR_ENDFIELD_HARDWARE_STAGE15

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QSysInfo>
#include <QThread>
#include <QTimer>
#include <QtConcurrentRun>

#include <algorithm>
#include <limits>

namespace {
QString readText(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    return QString::fromUtf8(file.read(4096)).trimmed();
}
QString clean(QString text) {
    text = text.simplified();
    if (text.isEmpty() || text.compare("To Be Filled By O.E.M.", Qt::CaseInsensitive) == 0
        || text.compare("Default string", Qt::CaseInsensitive) == 0
        || text.compare("Not Specified", Qt::CaseInsensitive) == 0) return {};
    return text;
}
QString orUnavailable(const QString &text) { return text.isEmpty() ? QStringLiteral("Não disponível") : text; }
QString capacity(quint64 bytes) {
    const double gib = double(bytes) / (1024.0 * 1024.0 * 1024.0);
    if (gib >= 1024.0) return QString::number(gib / 1024.0, 'f', 2) + QStringLiteral(" TiB");
    return QString::number(gib, 'f', gib >= 100 ? 0 : 1) + QStringLiteral(" GiB");
}
QString desktopCpu() {
    const QString text = readText(QStringLiteral("/proc/cpuinfo"));
    for (const auto &line : text.split('\n')) {
        const int colon = line.indexOf(':');
        if (colon < 0) continue;
        const auto field = line.left(colon).trimmed();
        if (field == QStringLiteral("model name") || field == QStringLiteral("Hardware"))
            return clean(line.mid(colon + 1));
    }
    return {};
}
QString gpuFromPci() {
    const QString program = QStandardPaths::findExecutable(QStringLiteral("lspci"));
    if (program.isEmpty()) return {};
    QProcess process;
    process.start(program, {QStringLiteral("-mm")}, QIODevice::ReadOnly);
    if (!process.waitForStarted(500)) return {};
    if (!process.waitForFinished(1200)) {
        process.kill(); process.waitForFinished(200); return {};
    }
    if (process.exitCode() != 0) return {};
    const QString lines = QString::fromUtf8(process.readAllStandardOutput());
    const QRegularExpression quoted(QStringLiteral(R"rx("([^"]+)")rx"));
    QString candidate;
    for (const auto &line : lines.split('\n')) {
        if (!line.contains(QStringLiteral("VGA compatible controller"))
            && !line.contains(QStringLiteral("3D controller"))
            && !line.contains(QStringLiteral("Display controller"))) continue;
        auto it = quoted.globalMatch(line);
        QStringList columns;
        while (it.hasNext()) columns << it.next().captured(1);
        if (columns.size() < 3) continue;
        const QString vendor = clean(columns[1]), device = clean(columns[2]);
        if (device.isEmpty()) continue;
        const QString label = device + (vendor.isEmpty() ? QString() : QStringLiteral(" · ") + vendor);
        if (candidate.isEmpty()) candidate = label;
        if (vendor.contains(QStringLiteral("AMD"), Qt::CaseInsensitive)
            || vendor.contains(QStringLiteral("NVIDIA"), Qt::CaseInsensitive)) return label;
    }
    return candidate;
}
QString gpuFallback() {
    QDir cards(QStringLiteral("/sys/class/drm"));
    for (const auto &name : cards.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!QRegularExpression(QStringLiteral("^card[0-9]+$")).match(name).hasMatch()) continue;
        const QString base = cards.filePath(name + QStringLiteral("/device/"));
        const QString vendor = readText(base + QStringLiteral("vendor"));
        const QString device = readText(base + QStringLiteral("device"));
        if (vendor.isEmpty() || device.isEmpty()) continue;
        const QString brand = vendor == QLatin1String("0x1002") ? QStringLiteral("AMD Radeon")
            : vendor == QLatin1String("0x10de") ? QStringLiteral("NVIDIA")
            : vendor == QLatin1String("0x8086") ? QStringLiteral("Intel") : QStringLiteral("PCI GPU");
        return brand + QStringLiteral(" · ") + vendor + QStringLiteral(":") + device;
    }
    return {};
}
QString operatingSystem() {
    QFile file(QStringLiteral("/etc/os-release"));
    if (!file.open(QIODevice::ReadOnly)) return {};
    QString name;
    for (QString line : QString::fromUtf8(file.read(16 * 1024)).split('\n')) {
        if (!line.startsWith(QStringLiteral("PRETTY_NAME="))) continue;
        name = line.mid(12).trimmed();
        if (name.size() >= 2 && name.front() == QLatin1Char('"') && name.back() == QLatin1Char('"'))
            name = name.mid(1, name.size() - 2);
        break;
    }
    return clean(name);
}
QString disksText(QString *shortLabel) {
    QDir blocks(QStringLiteral("/sys/block"));
    QStringList disks;
    const QRegularExpression physical(QStringLiteral("^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|mmcblk[0-9]+)$"));
    for (const auto &name : blocks.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!physical.match(name).hasMatch()) continue;
        bool valid = false;
        const quint64 sectors = readText(blocks.filePath(name + QStringLiteral("/size"))).toULongLong(&valid);
        if (!valid || sectors == 0 || sectors > std::numeric_limits<quint64>::max() / 512) continue;
        QString model = clean(readText(blocks.filePath(name + QStringLiteral("/device/model"))));
        if (model.isEmpty()) model = name;
        disks << (model + QStringLiteral(" · ") + capacity(sectors * 512));
    }
    if (!disks.isEmpty()) {
        *shortLabel = QStringLiteral("%1 unidade(s)").arg(disks.size());
        return disks.mid(0, 3).join(QStringLiteral("  /  "))
            + (disks.size() > 3 ? QStringLiteral("  (+%1)").arg(disks.size() - 3) : QString());
    }
    const QStorageInfo root = QStorageInfo::root();
    if (root.isValid() && root.bytesTotal() > 0) {
        *shortLabel = capacity(quint64(root.bytesTotal()));
        return QStringLiteral("Sistema de arquivos raiz");
    }
    return {};
}
} // namespace

HardwareController::HardwareController(QObject *parent) : QObject(parent) {
    connect(&m_reader, &QFutureWatcherBase::finished, this, [this] {
        m_data = m_reader.result();
        m_loading = false;
        emit changed();
    });
    QTimer::singleShot(0, this, &HardwareController::refresh);
}
HardwareController::~HardwareController() { m_reader.waitForFinished(); }
QVariantMap HardwareController::state() const {
    auto state = m_data;
    state[QStringLiteral("loading")] = m_loading;
    return state;
}
void HardwareController::refresh() {
    if (m_reader.isRunning()) return;
    m_loading = true;
    emit changed();
    m_reader.setFuture(QtConcurrent::run(&HardwareController::collect));
}
QVariantMap HardwareController::collect() {
    const QString vendor = clean(readText(QStringLiteral("/sys/devices/virtual/dmi/id/board_vendor")));
    const QString motherboard = clean(readText(QStringLiteral("/sys/devices/virtual/dmi/id/board_name")));
    const QString boardVersion = clean(readText(QStringLiteral("/sys/devices/virtual/dmi/id/board_version")));
    const QString cpu = desktopCpu();
    const int threads = QThread::idealThreadCount();
    const QString gpu = [&] { const QString pci = gpuFromPci(); return pci.isEmpty() ? gpuFallback() : pci; }();
    QString memory;
    QFile meminfo(QStringLiteral("/proc/meminfo"));
    if (meminfo.open(QIODevice::ReadOnly)) {
        for (const auto &line : meminfo.readAll().split('\n')) {
            if (!line.startsWith("MemTotal:")) continue;
            const auto match = QRegularExpression(QStringLiteral("MemTotal:\\s*(\\d+)"))
                .match(QString::fromLatin1(line));
            if (match.hasMatch()) {
                bool ok = false;
                const quint64 kb = match.captured(1).toULongLong(&ok);
                if (ok && kb < std::numeric_limits<quint64>::max() / 1024) memory = capacity(kb * 1024);
            }
            break;
        }
    }
    QString diskCount;
    const QString disks = disksText(&diskCount);
    const QString os = operatingSystem();
    const QString kernel = QSysInfo::kernelVersion();
    return {
        {QStringLiteral("cpu"), orUnavailable(cpu)},
        {QStringLiteral("cpuDetails"), threads > 0 ? QStringLiteral("%1 threads lógicas").arg(threads) : QStringLiteral("CPU detectada pelo Linux")},
        {QStringLiteral("gpu"), orUnavailable(gpu)},
        {QStringLiteral("gpuDetails"), gpu.isEmpty() ? QStringLiteral("Instale pciutils para identificar a GPU") : QStringLiteral("Dispositivo gráfico PCI")},
        {QStringLiteral("board"), orUnavailable(motherboard)},
        {QStringLiteral("boardDetails"), (vendor + (boardVersion.isEmpty() ? QString() : QStringLiteral(" · ") + boardVersion)).trimmed()},
        {QStringLiteral("memory"), orUnavailable(memory)},
        {QStringLiteral("memoryDetails"), QStringLiteral("Memória total informada pelo kernel")},
        {QStringLiteral("storage"), orUnavailable(diskCount)},
        {QStringLiteral("storageDetails"), orUnavailable(disks)},
        {QStringLiteral("system"), orUnavailable(os)},
        {QStringLiteral("systemDetails"), QStringLiteral("Kernel %1 · %2").arg(kernel, QSysInfo::currentCpuArchitecture())}
    };
}
