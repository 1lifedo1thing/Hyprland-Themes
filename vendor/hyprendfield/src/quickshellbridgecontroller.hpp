#pragma once
// HYPR_ENDFIELD_BRIDGE_STAGE18A
#include <QObject>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QVariantMap>
#include <QStringList>

// Apenas lê o config do end4-pC. Todas as escritas passam pelo IPC do próprio Quickshell.
class QuickshellBridgeController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap configState READ configState NOTIFY configStateChanged) // HYPR_ENDFIELD_SETTINGS_HUB_20A
public:
    explicit QuickshellBridgeController(QObject *parent = nullptr);
    QVariantMap state() const { return m_state; }
    QVariantMap configState() const { return m_configState; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setScheme(const QString &id);
    Q_INVOKABLE void configRefresh();
    Q_INVOKABLE void configSetOption(const QString &key, const QVariant &value);
    Q_INVOKABLE void setAccent(const QString &slot, const QString &accent);
    Q_INVOKABLE void importScheme();
    Q_INVOKABLE void openSchemeFolder();
    Q_INVOKABLE void reloadSchemes();
    Q_INVOKABLE bool createScheme(const QString &id, const QString &primary, const QString &secondary);
signals:
    void stateChanged();
    void configStateChanged();
private:
    QString m_config;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QVariantMap m_state;
    QVariantMap m_configState;
    bool m_configBusy = false;
    QString m_configNotice;
    bool m_busy = false;
    QString m_notice;
    void publish();
    void configPublish();
    void runConfigAction(const QStringList &args, bool refreshCatalog);
};
