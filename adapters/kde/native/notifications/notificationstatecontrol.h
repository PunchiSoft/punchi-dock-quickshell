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
//
// A presence-only "available" is not enough: the row may show On/Off only after
// an asynchronous read produced a real boolean for the current owner. Reads are
// coalesced, replies from an older owner or an older read are discarded, and a
// failed or mistyped reply invalidates the state instead of keeping a default.
class NotificationStateControl : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool monitoring READ monitoring WRITE setMonitoring NOTIFY monitoringChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool reading READ reading NOTIFY readingChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY validChanged)
    Q_PROPERTY(bool inhibited READ inhibited NOTIFY inhibitedChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
public:
    explicit NotificationStateControl(QObject *parent = nullptr);
    bool monitoring() const { return m_monitoring; }
    void setMonitoring(bool monitoring);
    bool available() const { return m_available; }
    bool reading() const { return m_reading; }
    bool valid() const { return m_valid; }
    bool inhibited() const { return m_inhibited; }
    QString lastError() const { return m_lastError; }
    Q_INVOKABLE void refresh();

signals:
    void monitoringChanged();
    void availableChanged();
    void readingChanged();
    void validChanged();
    void inhibitedChanged();
    void lastErrorChanged();

private slots:
    void onServiceOwnerChanged(const QString &service, const QString &oldOwner,
        const QString &newOwner);
    void onPropertiesChanged(const QString &interfaceName, const QVariantMap &changed,
        const QStringList &invalidated);
    void onRefreshTimeout();

private:
    void setAvailable(bool available);
    void setReading(bool reading);
    void setValid(bool valid);
    void setInhibited(bool inhibited);
    void setLastError(const QString &error);
    void invalidate(const QString &error);
    void subscribe();
    void unsubscribe();
    void readState();

    QDBusConnection m_bus = QDBusConnection::sessionBus();
    QDBusServiceWatcher *m_watcher = nullptr;
    QTimer m_refreshTimer;
    QString m_owner;
    quint64 m_readGeneration = 0;
    bool m_monitoring = false;
    bool m_available = false;
    bool m_reading = false;
    bool m_valid = false;
    bool m_inhibited = false;
    bool m_subscribed = false;
    QString m_lastError;
};
