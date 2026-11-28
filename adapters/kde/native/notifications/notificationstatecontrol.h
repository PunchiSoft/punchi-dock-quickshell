// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QDBusConnection>
#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class QDBusServiceWatcher;

// Read-only Do Not Disturb state of Plasma's notification server. Plasma owns
// org.freedesktop.Notifications and exposes the effective state as the
// Inhibited property; there is no public setter for its persistent mode, so
// this boundary never writes and the panel delegates configuration to KDE.
class NotificationStateControl : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool monitoring READ monitoring WRITE setMonitoring NOTIFY monitoringChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool inhibited READ inhibited NOTIFY inhibitedChanged)
public:
    explicit NotificationStateControl(QObject *parent = nullptr);
    bool monitoring() const { return m_monitoring; }
    void setMonitoring(bool monitoring);
    bool available() const { return m_available; }
    bool inhibited() const { return m_inhibited; }
    Q_INVOKABLE void refresh();

signals:
    void monitoringChanged();
    void availableChanged();
    void inhibitedChanged();

private slots:
    void onServiceOwnerChanged(const QString &service, const QString &oldOwner,
        const QString &newOwner);
    void onPropertiesChanged(const QString &interfaceName, const QVariantMap &changed,
        const QStringList &invalidated);
    void onRefreshTimeout();

private:
    void setAvailable(bool available);
    void setInhibited(bool inhibited);
    void readState();

    QDBusConnection m_bus = QDBusConnection::sessionBus();
    QDBusServiceWatcher *m_watcher = nullptr;
    QTimer m_refreshTimer;
    bool m_monitoring = false;
    bool m_available = false;
    bool m_inhibited = false;
};
