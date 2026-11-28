// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QDBusObjectPath>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QDBusPendingCallWatcher;
class QDBusServiceWatcher;

// Removable storage boundary of the top panel. It reads the public UDisks2
// object manager, unmounts one filesystem per explicit request and unmounts
// every mounted filesystem of a drive for "safe to remove". It never forces an
// unmount, never ejects media and never powers a drive off.
class StorageControl : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool monitoring READ monitoring WRITE setMonitoring NOTIFY monitoringChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool pending READ pending NOTIFY pendingChanged)
    Q_PROPERTY(QString pendingTarget READ pendingTarget NOTIFY pendingTargetChanged)
    Q_PROPERTY(QString lastOperation READ lastOperation NOTIFY lastResultChanged)
    Q_PROPERTY(QString lastTarget READ lastTarget NOTIFY lastResultChanged)
    Q_PROPERTY(bool lastSuccess READ lastSuccess NOTIFY lastResultChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastResultChanged)
public:
    explicit StorageControl(QObject *parent = nullptr);

    bool monitoring() const { return m_monitoring; }
    void setMonitoring(bool monitoring);
    bool available() const { return m_monitoring && m_available; }
    QVariantList devices() const { return m_devices; }
    bool pending() const { return m_pending; }
    QString pendingTarget() const { return m_pendingTarget; }
    QString lastOperation() const { return m_lastOperation; }
    QString lastTarget() const { return m_lastTarget; }
    bool lastSuccess() const { return m_lastSuccess; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool unmountVolume(const QString &blockPath);
    Q_INVOKABLE bool removeDrive(const QString &drivePath);

signals:
    void monitoringChanged();
    void availableChanged();
    void devicesChanged();
    void pendingChanged();
    void pendingTargetChanged();
    void lastResultChanged();
    void operationFinished(const QString &operation, const QString &target, bool success,
        const QString &error);

private slots:
    void onServiceOwnerChanged(const QString &service, const QString &oldOwner,
        const QString &newOwner);
    void onInterfacesAdded(const QDBusObjectPath &path, const QVariantMap &interfaces);
    void onInterfacesRemoved(const QDBusObjectPath &path, const QStringList &interfaces);
    void onPropertiesChanged(const QString &interfaceName, const QVariantMap &changed,
        const QStringList &invalidated);

private:
    void subscribe();
    void ensurePropertySubscriptions(const QVariantMap &objects);
    void refreshNow();
    void scheduleRefresh();
    void applyDevices(const QVariantList &devices);
    void setAvailable(bool available);
    void clearDevices();
    bool findVolume(const QString &blockPath, bool *mounted, QString *driveId) const;
    void startUnmount(const QString &blockPath);
    void advance();
    void finishOperation(bool success, const QString &error);
    void resetOperation();

    bool m_monitoring = false;
    bool m_available = false;
    QVariantList m_devices;
    QDBusServiceWatcher *m_watcher = nullptr;
    QSet<QString> m_subscribedPaths;
    QTimer m_refreshTimer;
    bool m_subscribed = false;

    bool m_pending = false;
    QString m_pendingTarget;
    QString m_pendingKind;
    QString m_pendingDrive;
    QString m_currentBlock;
    QStringList m_remainingBlocks;

    QString m_lastOperation;
    QString m_lastTarget;
    bool m_lastSuccess = false;
    QString m_lastError;
};
