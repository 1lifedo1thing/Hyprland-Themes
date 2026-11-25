#include "focusmodecontroller.hpp"

#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QLocale>

#include <algorithm>
#include <cmath>
#include <limits>
#include <time.h>
#include <utility>

namespace
{
constexpr auto trackedWorkKey = "focusMode/trackedWorkSeconds";
constexpr auto sessionKey = "focusMode/sessionV1"; // HYPR_ENDFIELD_FOCUS_STAGE13

double finiteTotal(double first, double second)
{
    const double total = first + second;
    return std::isfinite(total) ? total : std::numeric_limits<double>::max();
}
}

FocusModeController::FocusModeController(QObject *parent, Clock clock, QString settingsPath, Clock wallClock)
    : QObject(parent)
    , m_clock(clock ? std::move(clock) : Clock(&FocusModeController::continuousTime))
    , m_wallClock(wallClock ? std::move(wallClock) : Clock([] {
          return QDateTime::currentMSecsSinceEpoch() / 1000.0;
      }))
    , m_settings(settingsPath.isEmpty()
          ? std::make_unique<QSettings>()
          : std::make_unique<QSettings>(settingsPath, QSettings::IniFormat))
{
    bool valid = false;
    const double restored = m_settings->value(QString::fromLatin1(trackedWorkKey), 0).toDouble(&valid);
    if (valid && std::isfinite(restored) && restored >= 0) {
        m_trackedTotal = restored;
    }

    m_displayTimer.setTimerType(Qt::PreciseTimer);
    m_displayTimer.setInterval(1000);
    connect(&m_displayTimer, &QTimer::timeout, this, [this] { refreshAt(now()); });

    m_completionTimer.setTimerType(Qt::PreciseTimer);
    m_completionTimer.setSingleShot(true);
    connect(&m_completionTimer, &QTimer::timeout, this, [this] { refreshAt(now()); });

    // Autosave periodico: uma queda abrupta perde no maximo ~30 segundos de
    // trabalho. O contador fica ativo mesmo quando a interface esta oculta.
    m_autosaveTimer.setInterval(30'000);
    connect(&m_autosaveTimer, &QTimer::timeout, this, [this] {
        const double time = now();
        refreshAt(time);
        if (m_phase == Phase::Running) {
            checkpoint(time);
            persistSession(time, true);
        }
    });
    restoreSession(now());
    reconcileTimers(now());
}

FocusModeController::~FocusModeController()
{
    shutdown();
}

double FocusModeController::continuousTime()
{
    timespec value{};
#ifdef CLOCK_BOOTTIME
    constexpr clockid_t clockId = CLOCK_BOOTTIME;
#else
    constexpr clockid_t clockId = CLOCK_MONOTONIC;
#endif
    if (clock_gettime(clockId, &value) == 0) {
        return double(value.tv_sec) + double(value.tv_nsec) / 1'000'000'000.0;
    }
    return QDateTime::currentMSecsSinceEpoch() / 1000.0;
}

double FocusModeController::now() const
{
    return m_clock();
}

FocusModeController::Snapshot FocusModeController::snapshotAt(double time) const
{
    const double interval = m_startedAt ? std::max(0.0, time - *m_startedAt) : 0;
    double elapsed = std::max(0.0, m_accumulated + (std::isfinite(interval) ? interval : 0));
    if (m_kind == Kind::Countdown) {
        elapsed = std::min(m_duration, elapsed);
    }
    const double remaining = m_kind == Kind::Countdown ? std::max(0.0, m_duration - elapsed) : 0;
    const double shown = m_kind == Kind::Countdown
        ? std::ceil(remaining - 0.000001)
        : std::floor(elapsed + 0.000001);
    const int displayed = int(std::clamp(shown, 0.0, double(std::numeric_limits<int>::max() / 2)));
    return {elapsed, remaining, displayed};
}

double FocusModeController::trackedWorkSecondsAt(double time) const
{
    const double delta = std::max(0.0, snapshotAt(time).elapsed - m_trackedSessionElapsed);
    return finiteTotal(m_trackedTotal, delta);
}

QString FocusModeController::formatTime(qint64 seconds)
{
    seconds = std::max<qint64>(0, seconds);
    if (seconds >= 3600) {
        return QStringLiteral("%1:%2:%3")
            .arg(seconds / 3600)
            .arg(seconds / 60 % 60, 2, 10, QLatin1Char('0'))
            .arg(seconds % 60, 2, 10, QLatin1Char('0'));
    }
    return QStringLiteral("%1:%2")
        .arg(seconds / 60, 2, 10, QLatin1Char('0'))
        .arg(seconds % 60, 2, 10, QLatin1Char('0'));
}

QString FocusModeController::timeTextAt(double time) const
{
    return formatTime(snapshotAt(time).displayedSeconds);
}

QString FocusModeController::kindName(Kind value)
{
    return value == Kind::Countdown ? QStringLiteral("countdown") : QStringLiteral("stopwatch");
}

QString FocusModeController::phaseName(Phase value)
{
    switch (value) {
    case Phase::Idle: return QStringLiteral("idle");
    case Phase::Running: return QStringLiteral("running");
    case Phase::Paused: return QStringLiteral("paused");
    case Phase::Stopped: return QStringLiteral("stopped");
    case Phase::Completed: return QStringLiteral("completed");
    }
    return {};
}

QVariantMap FocusModeController::state() const
{
    const double time = now();
    const Snapshot value = snapshotAt(time);
    const bool sessionActive = m_phase == Phase::Running || m_phase == Phase::Paused;
    const double elapsedFraction = m_kind == Kind::Countdown && m_duration > 0
        ? std::clamp(value.elapsed / m_duration, 0.0, 1.0)
        : std::fmod(value.elapsed, 60.0) / 60.0;
    const double dialFraction = m_kind == Kind::Countdown && m_duration > 0
        ? std::clamp(double(value.displayedSeconds) / m_duration, 0.0, 1.0)
        : double(value.displayedSeconds % 60) / 60.0;

    return {
        {QStringLiteral("kind"), kindName(m_kind)},
        {QStringLiteral("phase"), phaseName(m_phase)},
        {QStringLiteral("duration"), int(std::lround(m_duration))},
        {QStringLiteral("elapsed"), value.elapsed},
        {QStringLiteral("remaining"), value.remaining},
        {QStringLiteral("displayedSeconds"), value.displayedSeconds},
        {QStringLiteral("timeText"), formatTime(value.displayedSeconds)},
        {QStringLiteral("progress"), elapsedFraction},
        {QStringLiteral("dialFraction"), dialFraction},
        {QStringLiteral("sessionActive"), sessionActive},
        {QStringLiteral("running"), m_phase == Phase::Running},
        {QStringLiteral("trackedWorkSeconds"), trackedWorkSecondsAt(time)},
        {QStringLiteral("trackedWorkText"), formatTime(qint64(std::floor(trackedWorkSecondsAt(time))))}
    };
}

void FocusModeController::setActive(bool value)
{
    if (m_active == value) return;
    m_active = value;
    emit activeChanged();
    const double time = now();
    refreshAt(time);
    if (!value) {
        checkpoint(time);
        persistSession(time);
    }
    reconcileTimers(time);
    if (value) publish(time, true);
}

bool FocusModeController::chooseCountdown(int seconds)
{
    if (seconds < 1 || seconds > 86'400) return false;
    const double time = now();
    checkpoint(time);
    m_kind = Kind::Countdown;
    m_duration = seconds;
    m_accumulated = 0;
    m_startedAt.reset();
    m_phase = Phase::Idle;
    m_trackedSessionElapsed = 0;
    changed(time);
    return true;
}

std::optional<int> FocusModeController::parseDuration(const QString &input)
{
    QString text = input.trimmed();
    const QStringList parts = text.split(QLatin1Char(':'), Qt::KeepEmptyParts);
    double seconds = 0;
    if (parts.size() == 2) {
        bool minutesValid = false;
        bool secondsValid = false;
        const qlonglong minutes = parts.at(0).toLongLong(&minutesValid);
        const qlonglong remainder = parts.at(1).toLongLong(&secondsValid);
        if (!minutesValid || !secondsValid || minutes < 0 || remainder < 0 || remainder >= 60) return {};
        seconds = double(minutes) * 60 + double(remainder);
    } else if (parts.size() == 1) {
        text.replace(QLatin1Char(','), QLatin1Char('.'));
        bool valid = false;
        const double minutes = QLocale::c().toDouble(text, &valid);
        if (!valid || !std::isfinite(minutes)) return {};
        seconds = minutes * 60;
    } else {
        return {};
    }
    if (!std::isfinite(seconds) || seconds < 1 || seconds > 86'400) return {};
    return int(std::lround(seconds));
}

bool FocusModeController::chooseCustomDuration(const QString &text)
{
    const auto duration = parseDuration(text);
    return duration && chooseCountdown(*duration);
}

QString FocusModeController::durationEditText() const
{
    const int seconds = std::clamp(int(std::lround(m_duration)), 1, 86'400);
    return QStringLiteral("%1:%2")
        .arg(seconds / 60)
        .arg(seconds % 60, 2, 10, QLatin1Char('0'));
}

void FocusModeController::chooseStopwatch()
{
    const double time = now();
    checkpoint(time);
    m_kind = Kind::Stopwatch;
    m_accumulated = 0;
    m_startedAt.reset();
    m_phase = Phase::Idle;
    m_trackedSessionElapsed = 0;
    changed(time);
}

void FocusModeController::start()
{
    if (m_phase == Phase::Running) return;
    if (m_phase == Phase::Paused) { resume(); return; }
    const double time = now();
    checkpoint(time);
    m_accumulated = 0;
    m_startedAt = time;
    m_phase = Phase::Running;
    m_trackedSessionElapsed = 0;
    changed(time);
}

void FocusModeController::pause()
{
    if (m_phase != Phase::Running) return;
    const double time = now();
    refreshAt(time);
    if (m_phase != Phase::Running) return;
    checkpoint(time);
    m_accumulated = snapshotAt(time).elapsed;
    m_startedAt.reset();
    m_phase = Phase::Paused;
    changed(time);
}

void FocusModeController::resume()
{
    if (m_phase != Phase::Paused) return;
    const double time = now();
    m_startedAt = time;
    m_phase = Phase::Running;
    changed(time);
}

void FocusModeController::stop()
{
    if (m_phase != Phase::Running && m_phase != Phase::Paused) return;
    const double time = now();
    checkpoint(time);
    m_accumulated = snapshotAt(time).elapsed;
    m_startedAt.reset();
    m_phase = Phase::Stopped;
    changed(time);
}

void FocusModeController::reset()
{
    const double time = now();
    checkpoint(time);
    m_accumulated = 0;
    m_startedAt.reset();
    m_phase = Phase::Idle;
    m_trackedSessionElapsed = 0;
    changed(time);
}

void FocusModeController::refresh()
{
    refreshAt(now());
}

void FocusModeController::refreshAt(double time)
{
    if (m_phase == Phase::Running && m_kind == Kind::Countdown
        && snapshotAt(time).remaining <= 0.000001) {
        checkpoint(time);
        m_accumulated = m_duration;
        m_startedAt.reset();
        m_phase = Phase::Completed;
        changed(time);
        emit completed();
        return;
    }
    reconcileTimers(time);
    if (m_active) publish(time, false);
}

void FocusModeController::checkpoint(double time)
{
    const double elapsed = snapshotAt(time).elapsed;
    const double delta = std::max(0.0, elapsed - m_trackedSessionElapsed);
    m_trackedTotal = finiteTotal(m_trackedTotal, delta);
    m_trackedSessionElapsed = elapsed;
    persistTrackedWorkSeconds();
}

void FocusModeController::changed(double time)
{
    m_displayTimer.stop();
    m_completionTimer.stop();
    reconcileTimers(time);
    persistSession(time);
    publish(time, true);
}

void FocusModeController::publish(double time, bool force)
{
    const int second = snapshotAt(time).displayedSeconds;
    if (!force && m_publishedSecond && *m_publishedSecond == second) return;
    m_publishedSecond = second;
    emit stateChanged();
}

void FocusModeController::reconcileTimers(double time)
{
    if (m_phase != Phase::Running) {
        m_displayTimer.stop();
        m_completionTimer.stop();
        m_autosaveTimer.stop();
        return;
    }

    if (!m_autosaveTimer.isActive()) m_autosaveTimer.start();
    if (m_active) {
        if (!m_displayTimer.isActive()) m_displayTimer.start();
    } else {
        m_displayTimer.stop();
    }

    if (m_kind == Kind::Countdown) {
        if (!m_completionTimer.isActive()) {
            const double remaining = std::max(0.001, snapshotAt(time).remaining);
            const qint64 milliseconds = qint64(std::ceil(remaining * 1000.0));
            m_completionTimer.start(int(std::clamp<qint64>(milliseconds, 1, std::numeric_limits<int>::max())));
        }
    } else {
        m_completionTimer.stop();
    }
}

// Persistencia da sessao completa: um registro JSON para evitar estados
// parcialmente gravados. O valor antigo trackedWorkSeconds e mantido intacto.
QString FocusModeController::bootIdentity()
{
    QFile file(QStringLiteral("/proc/sys/kernel/random/boot_id"));
    if (!file.open(QIODevice::ReadOnly)) return {};
    return QString::fromUtf8(file.readAll().trimmed());
}

void FocusModeController::persistSession(double time, bool synchronize)
{
    const double wall = m_wallClock();
    if (!std::isfinite(time) || !std::isfinite(wall)) return;
    const QJsonObject data{
        {QStringLiteral("version"), 1},
        {QStringLiteral("kind"), kindName(m_kind)},
        {QStringLiteral("phase"), phaseName(m_phase)},
        {QStringLiteral("duration"), m_duration},
        {QStringLiteral("elapsed"), snapshotAt(time).elapsed},
        {QStringLiteral("mono"), time},
        {QStringLiteral("wall"), wall},
        {QStringLiteral("boot"), bootIdentity()}
    };
    m_settings->setValue(QString::fromLatin1(sessionKey),
                         QString::fromUtf8(QJsonDocument(data).toJson(QJsonDocument::Compact)));
    if (synchronize) m_settings->sync();
}

void FocusModeController::restoreSession(double time)
{
    QJsonParseError parseError;
    const auto json = m_settings->value(QString::fromLatin1(sessionKey)).toString().toUtf8();
    const auto document = QJsonDocument::fromJson(json, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) return;
    const auto data = document.object();
    if (data.value(QStringLiteral("version")).toInt() != 1) return;
    const QString kind = data.value(QStringLiteral("kind")).toString();
    const QString phase = data.value(QStringLiteral("phase")).toString();
    const double duration = data.value(QStringLiteral("duration")).toDouble(-1);
    const double elapsed = data.value(QStringLiteral("elapsed")).toDouble(-1);
    if ((kind != QLatin1String("countdown") && kind != QLatin1String("stopwatch"))
        || (phase != QLatin1String("idle") && phase != QLatin1String("running")
            && phase != QLatin1String("paused") && phase != QLatin1String("stopped")
            && phase != QLatin1String("completed"))
        || !std::isfinite(duration) || duration < 1 || duration > 86'400
        || !std::isfinite(elapsed) || elapsed < 0 || elapsed > 10.0 * 365 * 86'400
        || !std::isfinite(time)) return;

    double downtime = 0;
    if (phase == QLatin1String("running")) {
        const double savedMono = data.value(QStringLiteral("mono")).toDouble(-1);
        const double savedWall = data.value(QStringLiteral("wall")).toDouble(-1);
        const double currentWall = m_wallClock();
        const QString previousBoot = data.value(QStringLiteral("boot")).toString();
        const QString currentBoot = bootIdentity();
        if (!previousBoot.isEmpty() && previousBoot == currentBoot
            && std::isfinite(savedMono) && savedMono >= 0 && time >= savedMono) {
            downtime = time - savedMono;
        } else if (std::isfinite(savedWall) && std::isfinite(currentWall)
                   && savedWall >= 0 && currentWall >= savedWall) {
            // Reinicio do computador: uptime deixa de ser comparavel.
            downtime = currentWall - savedWall;
        }
        downtime = std::clamp(downtime, 0.0, 10.0 * 365 * 86'400);
    }

    m_kind = kind == QLatin1String("countdown") ? Kind::Countdown : Kind::Stopwatch;
    m_phase = phase == QLatin1String("running") ? Phase::Running
        : phase == QLatin1String("paused") ? Phase::Paused
        : phase == QLatin1String("stopped") ? Phase::Stopped
        : phase == QLatin1String("completed") ? Phase::Completed : Phase::Idle;
    m_duration = duration;
    m_accumulated = std::min(elapsed + downtime, 10.0 * 365 * 86'400);
    if (m_kind == Kind::Countdown) {
        m_accumulated = std::min(m_accumulated, m_duration);
        if (m_phase == Phase::Running && m_accumulated >= m_duration - 0.000001)
            m_phase = Phase::Completed;
    }
    m_startedAt = m_phase == Phase::Running ? std::optional<double>(time) : std::nullopt;
    // A parte ja acumulada foi salva no contador total pelo checkpoint do
    // encerramento/autosave. Tempo fora do app conta somente se estava rodando.
    m_trackedSessionElapsed = elapsed;
    if (m_phase == Phase::Completed && phase == QLatin1String("running")) {
        checkpoint(time);
        persistSession(time, true);
    }
}

void FocusModeController::persistTrackedWorkSeconds(bool synchronize)
{
    m_settings->setValue(QString::fromLatin1(trackedWorkKey), m_trackedTotal);
    if (synchronize) m_settings->sync();
}

// Grava antes de encerrar o processo, sem converter uma sessao rodando
// em "parada" no armazenamento. Quando reabrir, o tempo continua correto.
void FocusModeController::shutdown()
{
    if (m_shutdown) return;
    m_shutdown = true;
    const double time = now();
    refreshAt(time);
    checkpoint(time);
    persistSession(time, true);
    m_active = false;
    m_displayTimer.stop();
    m_completionTimer.stop();
    m_autosaveTimer.stop();
}
