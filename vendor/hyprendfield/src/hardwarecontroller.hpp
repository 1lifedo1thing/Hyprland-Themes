#pragma once

#include <QFutureWatcher>
#include <QObject>
#include <QVariantMap>

// Leitura de inventario local, sem privilegios administrativos e sem gravacoes.
// HYPR_ENDFIELD_HARDWARE_STAGE15
class HardwareController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap state READ state NOTIFY changed)
public:
    explicit HardwareController(QObject *parent = nullptr);
    ~HardwareController() override;
    QVariantMap state() const;
    Q_INVOKABLE void refresh();
signals:
    void changed();
private:
    static QVariantMap collect();
    QFutureWatcher<QVariantMap> m_reader;
    QVariantMap m_data;
    bool m_loading = false;
};
