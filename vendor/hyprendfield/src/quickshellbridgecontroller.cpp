// HYPR_ENDFIELD_BRIDGE_STAGE18A
#include "quickshellbridgecontroller.hpp"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QJsonArray>
#include <QJsonValue>
#include <QSaveFile>
#include <QColor>
#include <QPointer>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <algorithm>

QuickshellBridgeController::QuickshellBridgeController(QObject *parent)
    : QObject(parent)
    , m_config(QDir::homePath() + QStringLiteral("/.config/illogical-impulse/config.json"))
{
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(200);
    connect(&m_debounce, &QTimer::timeout, this, &QuickshellBridgeController::refresh);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this,
            [this](const QString &) { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this,
            [this](const QString &) { m_debounce.start(); });
    refresh();
}

void QuickshellBridgeController::publish()
{
    QVariantMap next;
    const QByteArray bytes = [&] {
        QFile file(m_config);
        return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
    }();
    QJsonParseError error{};
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &error);
    const bool valid = error.error == QJsonParseError::NoError && doc.isObject();
    const QJsonObject config = valid ? doc.object() : QJsonObject{};
    const auto appearance = config.value(QStringLiteral("appearance")).toObject();
    const auto palette = appearance.value(QStringLiteral("palette")).toObject();
    next[QStringLiteral("available")] = valid;
    next[QStringLiteral("scheme")] = palette.value(QStringLiteral("namedScheme")).toString();
    next[QStringLiteral("wallpaper")] = config.value(QStringLiteral("background"))
                                        .toObject().value(QStringLiteral("wallpaperPath")).toString();
    next[QStringLiteral("busy")] = m_busy;
    next[QStringLiteral("notice")] = m_notice;

    // O mesmo conjunto de diretórios que o end4-pC usa para os temas nomeados.
    QSet<QString> seen;
    QList<QPair<QString, QString>> schemes;
    for (const auto &dirName : {
             QDir::homePath() + QStringLiteral("/.config/illogical-impulse/schemes"),
             QDir::homePath() + QStringLiteral("/.config/quickshell/end4-pC/scripts/colors/schemes")}) {
        QDir dir(dirName);
        const auto files = dir.entryInfoList({QStringLiteral("*.json")}, QDir::Files | QDir::Readable);
        int visited = 0;
        for (const auto &entry : files) {
            if (++visited > 200) break;
            const QString id = entry.completeBaseName();
            if (id.startsWith(QLatin1Char('_')) || seen.contains(id)) continue;
            if (!QRegularExpression(QStringLiteral("^[A-Za-z0-9._-]{1,80}$")).match(id).hasMatch()) continue;
            QFile f(entry.absoluteFilePath());
            if (!f.open(QIODevice::ReadOnly)) continue;
            const auto content = QJsonDocument::fromJson(f.read(128 * 1024));
            if (!content.isObject() || !content.object().contains(QStringLiteral("dark"))) continue;
            const QString label = content.object().value(QStringLiteral("name")).toString(id);
            schemes.append({id, label});
            seen.insert(id);
        }
    }
    std::sort(schemes.begin(), schemes.end(), [](const auto &a, const auto &b) {
        return QString::localeAwareCompare(a.second, b.second) < 0;
    });
    QVariantList options;
    options.append(QVariantMap{{QStringLiteral("id"), QString()},
                               {QStringLiteral("name"), QStringLiteral("Material (automático)")}});
    for (const auto &scheme : schemes)
        options.append(QVariantMap{{QStringLiteral("id"), scheme.first},
                                   {QStringLiteral("name"), scheme.second}});
    next[QStringLiteral("schemes")] = options;
    next[QStringLiteral("primaryAccent")] = palette.value(QStringLiteral("namedSchemePrimary")).toString();
    next[QStringLiteral("secondaryAccent")] = palette.value(QStringLiteral("namedSchemeSecondary")).toString();
    QVariantList accentEntries;
    for (const auto &dirName : {
             QDir::homePath() + QStringLiteral("/.config/illogical-impulse/schemes"),
             QDir::homePath() + QStringLiteral("/.config/quickshell/end4-pC/scripts/colors/schemes")}) {
        QFile f(dirName + QLatin1Char('/') + palette.value(QStringLiteral("namedScheme")).toString() + QStringLiteral(".json"));
        if (!f.open(QIODevice::ReadOnly)) continue;
        const auto scheme = QJsonDocument::fromJson(f.read(128*1024));
        if (!scheme.isObject()) continue;
        const QJsonObject colors = scheme.object().value(QStringLiteral("dark")).toObject().value(QStringLiteral("accents")).toObject();
        for (auto it=colors.begin(); it!=colors.end(); ++it)
            if (it.value().isString()) accentEntries.append(QVariantMap{{QStringLiteral("id"),it.key()},{QStringLiteral("color"),it.value().toString()}});
        if (!accentEntries.isEmpty()) break;
    }
    next[QStringLiteral("accents")] = accentEntries;

    if (next != m_state) {
        m_state = std::move(next);
        emit stateChanged();
    }
}

void QuickshellBridgeController::refresh()
{
    const QString directory = QFileInfo(m_config).absolutePath();
    if (QFileInfo::exists(directory) && !m_watcher.directories().contains(directory))
        m_watcher.addPath(directory);
    if (QFileInfo::exists(m_config) && !m_watcher.files().contains(m_config))
        m_watcher.addPath(m_config);
    publish();
}

void QuickshellBridgeController::setScheme(const QString &id)
{
    if (m_busy || !m_state.value(QStringLiteral("available")).toBool()) return;
    bool found = id.isEmpty();
    for (const QVariant &item : m_state.value(QStringLiteral("schemes")).toList()) {
        if (item.toMap().value(QStringLiteral("id")).toString() == id) { found = true; break; }
    }
    if (!found) { m_notice = tr("Tema não encontrado; nenhuma alteração feita"); publish(); return; }
    const QString qs = QStandardPaths::findExecutable(QStringLiteral("qs"));
    if (qs.isEmpty()) { m_notice = tr("Quickshell (qs) não encontrado"); publish(); return; }
    m_busy = true;
    m_notice = tr("Enviando ao Quickshell…");
    publish();
    auto *proc = new QProcess(this);
    proc->setProgram(qs);
    proc->setArguments({QStringLiteral("-c"), QStringLiteral("end4-pC"),
                        QStringLiteral("ipc"), QStringLiteral("call"),
                        QStringLiteral("hyprendfieldBridge"), QStringLiteral("setScheme"),
                        id.isEmpty() ? QStringLiteral("__material__") : id});
    connect(proc, &QProcess::finished, this,
            [this, proc](int code, QProcess::ExitStatus status) {
        m_busy = false;
        m_notice = status == QProcess::NormalExit && code == 0
            ? tr("Solicitação enviada. Aguardando sincronização…")
            : tr("Erro na comunicação com o Quickshell; tema preservado");
        proc->deleteLater();
        refresh();
        QTimer::singleShot(1600, this, &QuickshellBridgeController::refresh);
    });
    connect(proc, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            m_busy = false;
            m_notice = tr("Não foi possível iniciar o controle do Quickshell");
            publish();
        }
    });
    proc->start();
    QTimer::singleShot(4000, proc, [proc] {
        if (proc->state() != QProcess::NotRunning) proc->kill();
    });
}


// HYPR_ENDFIELD_SETTINGS_HUB_20A — complemento, sem alterar setScheme (18A).
void QuickshellBridgeController::configPublish()
{
    m_configState[QStringLiteral("busy")] = m_configBusy;
    m_configState[QStringLiteral("notice")] = m_configNotice;
    emit configStateChanged();
}

void QuickshellBridgeController::configRefresh()
{
    if (m_configBusy) return;
    const QString qs = QStandardPaths::findExecutable(QStringLiteral("qs"));
    if (qs.isEmpty()) { m_configNotice = tr("Comando qs não encontrado"); configPublish(); return; }
    m_configBusy=true;
    m_configNotice=tr("Sincronizando com o Quickshell...");
    configPublish();
    auto *proc = new QProcess(this);
    proc->setProgram(qs);
    proc->setArguments({QStringLiteral("-c"),QStringLiteral("end4-pC"),QStringLiteral("ipc"),QStringLiteral("call"),QStringLiteral("hyprendfieldConfig"),QStringLiteral("snapshot")});
    connect(proc,&QProcess::finished,this,[this,proc](int code,QProcess::ExitStatus status){
        m_configBusy=false;
        const auto bytes=proc->readAllStandardOutput().trimmed();
        const auto data=QJsonDocument::fromJson(bytes);
        if(status==QProcess::NormalExit&&code==0&&data.isObject()&&data.object().value(QStringLiteral("sections")).isArray()) {
            m_configState[QStringLiteral("sections")]=data.object().value(QStringLiteral("sections")).toArray().toVariantList();
            m_configState[QStringLiteral("available")]=true;
            m_configNotice.clear();
        } else {
            m_configNotice=tr("IPC de configurações indisponível; preservadas as opções anteriores");
        }
        proc->deleteLater();configPublish();
    });
    connect(proc,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){
        if(e==QProcess::FailedToStart){m_configBusy=false;m_configNotice=tr("Falha ao consultar Quickshell");configPublish();}
    });
    proc->start();
    QTimer::singleShot(5000,proc,[proc]{if(proc->state()!=QProcess::NotRunning)proc->kill();});
}

void QuickshellBridgeController::runConfigAction(const QStringList &args, bool refreshCatalog)
{
    if(m_configBusy)return;
    const QString qs = QStandardPaths::findExecutable(QStringLiteral("qs"));
    if(qs.isEmpty()){m_configNotice=tr("Comando qs não encontrado");configPublish();return;}
    m_configBusy=true;
    configPublish();
    auto *proc = new QProcess(this);
    proc->setProgram(qs);
    proc->setArguments(QStringList{QStringLiteral("-c"),QStringLiteral("end4-pC"),QStringLiteral("ipc"),QStringLiteral("call"),QStringLiteral("hyprendfieldConfig")}+args);
    connect(proc,&QProcess::finished,this,[this,proc,refreshCatalog](int code,QProcess::ExitStatus status){
        const QByteArray output=proc->readAllStandardOutput().trimmed();
        const bool accepted=status==QProcess::NormalExit && code==0 && (!refreshCatalog || output=="OK");
        m_configBusy=false;
        m_configNotice=accepted?tr("Comando aceito pelo Quickshell"):tr("O Quickshell rejeitou ou não executou a alteração");
        proc->deleteLater(); configPublish();
        if(refreshCatalog) QTimer::singleShot(250,this,&QuickshellBridgeController::configRefresh);
        else QTimer::singleShot(900,this,&QuickshellBridgeController::refresh);
    });
    connect(proc,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){
        if(e==QProcess::FailedToStart){m_configBusy=false;m_configNotice=tr("Falha ao enviar controle ao Quickshell");configPublish();}
    });
    proc->start();
    QTimer::singleShot(5000,proc,[proc]{if(proc->state()!=QProcess::NotRunning)proc->kill();});
}

void QuickshellBridgeController::configSetOption(const QString &key,const QVariant &value)
{
    if(m_configBusy||key.size()>180||key.isEmpty())return;
    const QJsonObject object{{QStringLiteral("value"),QJsonValue::fromVariant(value)}};
    const QString wire=QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact));
    runConfigAction({QStringLiteral("write"),key,wire},true);
}
void QuickshellBridgeController::setAccent(const QString &slot,const QString &accent)
{
    if(slot!=QStringLiteral("primary")&&slot!=QStringLiteral("secondary"))return;
    bool present=false;
    for(const auto &item:m_state.value(QStringLiteral("accents")).toList())
        if(item.toMap().value(QStringLiteral("id")).toString()==accent){present=true;break;}
    if(!present||m_state.value(QStringLiteral("scheme")).toString().isEmpty())return;
    runConfigAction({QStringLiteral("setAccent"),slot,accent},false);
}
void QuickshellBridgeController::importScheme() {runConfigAction({QStringLiteral("addScheme")},false);}
void QuickshellBridgeController::openSchemeFolder(){runConfigAction({QStringLiteral("openSchemes")},false);}
void QuickshellBridgeController::reloadSchemes(){runConfigAction({QStringLiteral("reloadSchemes")},false);}

bool QuickshellBridgeController::createScheme(const QString &id,const QString &primary,const QString &secondary)
{
    const QRegularExpression name(QStringLiteral("^[A-Za-z0-9_-]{3,40}$"));
    const QRegularExpression hex(QStringLiteral("^#[0-9a-fA-F]{6}$"));
    if(!name.match(id).hasMatch()||!hex.match(primary).hasMatch()||!hex.match(secondary).hasMatch()) {
        m_notice=tr("Use nome de 3 a 40 caracteres e cores #RRGGBB");publish();return false;
    }
    const QString templatePath=QDir::homePath()+QStringLiteral("/.config/quickshell/end4-pC/scripts/colors/schemes/_template.json");
    QFile file(templatePath);
    if(!file.open(QIODevice::ReadOnly)){m_notice=tr("Template oficial de paletas não encontrado");publish();return false;}
    const auto parsed=QJsonDocument::fromJson(file.read(128*1024));
    if(!parsed.isObject()){m_notice=tr("Template de paleta inválido");publish();return false;}
    QJsonObject obj=parsed.object();obj.insert(QStringLiteral("name"),id);
    QJsonObject defaults=obj.value(QStringLiteral("defaults")).toObject();
    defaults.insert(QStringLiteral("primary"),QStringLiteral("cyan"));
    defaults.insert(QStringLiteral("secondary"),QStringLiteral("blue"));
    obj.insert(QStringLiteral("defaults"),defaults);
    for(const QString &mode:{QStringLiteral("dark"),QStringLiteral("light")}) {
        QJsonObject block=obj.value(mode).toObject();
        if(!block.value(QStringLiteral("accents")).isObject()){
            m_notice=tr("Template sem mapa de cores");publish();return false;
        }
        QJsonObject accents=block.value(QStringLiteral("accents")).toObject();
        accents.insert(QStringLiteral("cyan"),primary.toUpper());
        accents.insert(QStringLiteral("blue"),secondary.toUpper());
        block.insert(QStringLiteral("accents"),accents);obj.insert(mode,block);
    }
    const QString destination=QDir::homePath()+QStringLiteral("/.config/illogical-impulse/schemes");
    const QString path=destination+QLatin1Char('/')+id+QStringLiteral(".json");
    if(QFileInfo::exists(path)){m_notice=tr("Paleta já existe; nada foi sobrescrito");publish();return false;}
    if(!QDir().mkpath(destination)){m_notice=tr("Sem permissão para criar pasta de paletas");publish();return false;}
    QSaveFile output(path);
    const QByteArray bytes=QJsonDocument(obj).toJson(QJsonDocument::Indented);
    if(!output.open(QIODevice::WriteOnly)){
        m_notice=tr("Não foi possível abrir novo arquivo de paleta");publish();return false;
    }
    output.setPermissions(QFile::ReadOwner|QFile::WriteOwner);
    if(output.write(bytes)!=bytes.size()||!output.commit()){
        m_notice=tr("Falha ao criar paleta");publish();return false;
    }
    m_notice=tr("Paleta criada; abra a lista para aplicá-la");
    refresh();reloadSchemes();
    return true;
}
