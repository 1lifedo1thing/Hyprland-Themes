#pragma once
// HYPR_ENDFIELD_WALLPAPER_STAGE16 — read-only gallery until explicit Apply.
#include <QObject>
#include <QFutureWatcher>
#include <QTimer>
#include <QVariantMap>
#include <QVariantList>

class WallpaperController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap state READ state NOTIFY changed)
public:
    explicit WallpaperController(QObject *parent = nullptr);
    ~WallpaperController() override;
    QVariantMap state() const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void syncActive();
    Q_INVOKABLE void select(int index);
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void applySelected();
signals:
    void changed();
private:
    void setCurrent(const QString &path);
    QFutureWatcher<QVariantList> m_scan;
    QFutureWatcher<QVariantMap> m_apply;
    QVariantList m_items;
    QString m_activePath;
    QString m_error;
    QString m_message;
    QString m_appliedRequest;
    int m_index = 0;
    bool m_recheck = false;
};
