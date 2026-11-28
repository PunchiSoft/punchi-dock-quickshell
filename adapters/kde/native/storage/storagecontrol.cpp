// SPDX-License-Identifier: GPL-3.0-or-later
#include "storagecontrol.h"
#include "storageparser.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusServiceWatcher>
#include <QVariant>

namespace {
const QString kService = QStringLiteral("org.freedesktop.UDisks2");
const QString kManagerPath = QStringLiteral("/org/freedesktop/UDisks2");
const QString kObjectManager = QStringLiteral("org.freedesktop.DBus.ObjectManager");
const QString kProperties = QStringLiteral("org.freedesktop.DBus.Properties");
const QString kFilesystem = QStringLiteral("org.freedesktop.UDisks2.Filesystem");
const QString kBlock = QStringLiteral("org.freedesktop.UDisks2.Block");
const QString kDrive = QStringLiteral("org.freedesktop.UDisks2.Drive");

QVariantMap objectInterfaces(const QVariant &value)
{
    if (value.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        QDBusArgument argument = value.value<QDBusArgument>();
        QVariantMap map;
        argument >> map;
        return map;
    }
    return value.toMap();
}

QVariantMap managedObjectsFromReply(const QDBusMessage &reply)
{
    if (reply.arguments().isEmpty()) return {};
    const QVariant argument = reply.arguments().first();
    if (argument.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        QDBusArgument objects = argument.value<QDBusArgument>();
        QVariantMap map;
        objects >> map;
        return map;
    }
    return argument.toMap();
}
}

StorageControl::StorageControl(QObject *parent) : QObject(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(0);
    connect(&m_refreshTimer, &QTimer::timeout, this, &StorageControl::refreshNow);
}

void StorageControl::setMonitoring(bool monitoring)
{
    if (m_monitoring == monitoring) return;
    m_monitoring = monitoring;
    emit monitoringChanged();
    if (monitoring) {
        QDBusConnection bus = QDBusConnection::systemBus();
        if (m_watcher == nullptr) {
            m_watcher = new QDBusServiceWatcher(kService, bus,
                QDBusServiceWatcher::WatchForOwnerChange, this);
            connect(m_watcher, &QDBusServiceWatcher::serviceOwnerChanged,
                this, &StorageControl::onServiceOwnerChanged);
        }
        setAvailable(bus.isConnected()
            && bus.interface()->isServiceRegistered(kService));
        if (available()) {
            subscribe();
            refreshNow();
        }
    } else {
        resetOperation();
        m_subscribed = false;
        m_subscribedPaths.clear();
        clearDevices();
        setAvailable(false);
    }
}

void StorageControl::setAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();
}

void StorageControl::subscribe()
{
    if (m_subscribed) return;
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) return;
    m_subscribed = true;
    bus.connect(kService, kManagerPath, kObjectManager, QStringLiteral("InterfacesAdded"),
        this, SLOT(onInterfacesAdded(QDBusObjectPath,QVariantMap)));
    bus.connect(kService, kManagerPath, kObjectManager, QStringLiteral("InterfacesRemoved"),
        this, SLOT(onInterfacesRemoved(QDBusObjectPath,QStringList)));
}

void StorageControl::ensurePropertySubscriptions(const QVariantMap &objects)
{
    QDBusConnection bus = QDBusConnection::systemBus();
    for (auto object = objects.constBegin(); object != objects.constEnd(); ++object) {
        const QVariantMap interfaces = objectInterfaces(object.value());
        if (!interfaces.contains(kBlock) && !interfaces.contains(kDrive)) continue;
        if (m_subscribedPaths.contains(object.key())) continue;
        if (bus.connect(kService, object.key(), kProperties,
                QStringLiteral("PropertiesChanged"), this,
                SLOT(onPropertiesChanged(QString,QVariantMap,QStringList))))
            m_subscribedPaths.insert(object.key());
    }
}

void StorageControl::onServiceOwnerChanged(const QString &service, const QString &oldOwner,
    const QString &newOwner)
{
    Q_UNUSED(service)
    Q_UNUSED(oldOwner)
    if (!m_monitoring) return;
    if (newOwner.isEmpty()) {
        clearDevices();
        setAvailable(false);
        if (m_pending) finishOperation(false, QStringLiteral("disconnected"));
        return;
    }
    setAvailable(true);
    subscribe();
    refreshNow();
}

void StorageControl::onInterfacesAdded(const QDBusObjectPath &path, const QVariantMap &interfaces)
{
    Q_UNUSED(path)
    Q_UNUSED(interfaces)
    if (!m_monitoring) return;
    scheduleRefresh();
}

void StorageControl::onInterfacesRemoved(const QDBusObjectPath &path,
    const QStringList &interfaces)
{
    Q_UNUSED(interfaces)
    if (!m_monitoring || !m_pending) {
        scheduleRefresh();
        return;
    }
    const QString removed = path.path();
    if (removed == m_pendingTarget || removed == m_currentBlock
            || (m_pendingKind == QStringLiteral("remove") && removed == m_pendingDrive))
        finishOperation(false, QStringLiteral("disconnected"));
    scheduleRefresh();
}

void StorageControl::onPropertiesChanged(const QString &interfaceName,
    const QVariantMap &changed, const QStringList &invalidated)
{
    Q_UNUSED(interfaceName)
    Q_UNUSED(changed)
    Q_UNUSED(invalidated)
    if (!m_monitoring) return;
    scheduleRefresh();
}

void StorageControl::refresh()
{
    if (available()) scheduleRefresh();
}

void StorageControl::scheduleRefresh()
{
    if (available()) m_refreshTimer.start();
}

void StorageControl::refreshNow()
{
    if (!available()) return;
    QDBusMessage message = QDBusMessage::createMethodCall(kService, kManagerPath,
        kObjectManager, QStringLiteral("GetManagedObjects"));
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::systemBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
        [this](QDBusPendingCallWatcher *call) {
            call->deleteLater();
            if (!m_monitoring || call->isError()) return;
            const QVariantMap objects = managedObjectsFromReply(call->reply());
            ensurePropertySubscriptions(objects);
            applyDevices(PunchiStorage::drivesFromManagedObjects(objects));
        });
}

void StorageControl::applyDevices(const QVariantList &devices)
{
    if (m_devices == devices) return;
    m_devices = devices;
    emit devicesChanged();
}

void StorageControl::clearDevices()
{
    if (m_devices.isEmpty()) return;
    m_devices.clear();
    emit devicesChanged();
}

bool StorageControl::findVolume(const QString &blockPath, bool *mounted,
    QString *driveId) const
{
    for (const QVariant &device : m_devices) {
        const QVariantMap drive = device.toMap();
        const QVariantList volumes = drive.value(QStringLiteral("volumes")).toList();
        for (const QVariant &volumeValue : volumes) {
            const QVariantMap volume = volumeValue.toMap();
            if (volume.value(QStringLiteral("path")).toString() != blockPath) continue;
            if (mounted) *mounted = volume.value(QStringLiteral("mounted")).toBool();
            if (driveId) *driveId = drive.value(QStringLiteral("id")).toString();
            return true;
        }
    }
    return false;
}

bool StorageControl::unmountVolume(const QString &blockPath)
{
    if (!available() || m_pending) return false;
    bool mounted = false;
    QString driveId;
    if (!findVolume(blockPath, &mounted, &driveId) || !mounted) return false;
    m_pendingKind = QStringLiteral("unmount");
    m_pendingTarget = blockPath;
    m_pendingDrive.clear();
    m_remainingBlocks.clear();
    m_lastOperation = m_pendingKind;
    m_lastTarget = m_pendingTarget;
    m_lastSuccess = false;
    m_lastError.clear();
    m_pending = true;
    emit pendingChanged();
    emit pendingTargetChanged();
    emit lastResultChanged();
    startUnmount(blockPath);
    return true;
}

bool StorageControl::removeDrive(const QString &drivePath)
{
    if (!available() || m_pending) return false;
    QVariantMap drive;
    bool found = false;
    for (const QVariant &device : m_devices) {
        if (device.toMap().value(QStringLiteral("id")).toString() != drivePath) continue;
        drive = device.toMap();
        found = true;
        break;
    }
    if (!found) return false;
    m_pendingKind = QStringLiteral("remove");
    m_pendingTarget = drivePath;
    m_pendingDrive = drivePath;
    m_remainingBlocks.clear();
    const QVariantList volumes = drive.value(QStringLiteral("volumes")).toList();
    for (const QVariant &volumeValue : volumes) {
        const QVariantMap volume = volumeValue.toMap();
        if (volume.value(QStringLiteral("mounted")).toBool())
            m_remainingBlocks.append(volume.value(QStringLiteral("path")).toString());
    }
    m_lastOperation = m_pendingKind;
    m_lastTarget = m_pendingTarget;
    m_lastSuccess = false;
    m_lastError.clear();
    if (m_remainingBlocks.isEmpty()) {
        // Every filesystem of the drive is already unmounted: the provider
        // confirms the state the request asked for.
        finishOperation(true, QString());
        return true;
    }
    m_pending = true;
    emit pendingChanged();
    emit pendingTargetChanged();
    emit lastResultChanged();
    advance();
    return true;
}

void StorageControl::advance()
{
    if (!m_pending) return;
    if (m_pendingKind == QStringLiteral("unmount")) {
        finishOperation(true, QString());
        return;
    }
    while (!m_remainingBlocks.isEmpty()) {
        const QString blockPath = m_remainingBlocks.takeFirst();
        bool mounted = false;
        QString driveId;
        if (!findVolume(blockPath, &mounted, &driveId)) {
            finishOperation(false, QStringLiteral("disconnected"));
            return;
        }
        // The drive may have been unmounted externally in the meantime; that is
        // already the requested end state, so it is not an error.
        if (!mounted) continue;
        if (driveId != m_pendingDrive) {
            finishOperation(false, QStringLiteral("disconnected"));
            return;
        }
        startUnmount(blockPath);
        return;
    }
    finishOperation(true, QString());
}

void StorageControl::startUnmount(const QString &blockPath)
{
    m_currentBlock = blockPath;
    QDBusMessage message = QDBusMessage::createMethodCall(kService, blockPath,
        kFilesystem, QStringLiteral("Unmount"));
    // Empty options: no force, no lazy unmount, no power management.
    message << QVariantMap{};
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::systemBus().asyncCall(message, 30000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
        [this](QDBusPendingCallWatcher *call) {
            call->deleteLater();
            if (!m_pending || !m_monitoring) return;
            if (call->isError()) {
                const QString error = PunchiStorage::classifyError(call->error().name());
                if (error == QStringLiteral("not-mounted")) {
                    advance();
                    return;
                }
                finishOperation(false, error);
                return;
            }
            // The provider only answers after the filesystem left its mount
            // points, so a successful reply is the confirmation to report.
            advance();
        });
}

void StorageControl::finishOperation(bool success, const QString &error)
{
    const QString operation = m_pendingKind;
    const QString target = m_pendingTarget;
    resetOperation();
    m_lastOperation = operation;
    m_lastTarget = target;
    m_lastSuccess = success;
    m_lastError = error;
    emit lastResultChanged();
    emit operationFinished(operation, target, success, error);
    if (success) scheduleRefresh();
}

void StorageControl::resetOperation()
{
    const bool wasPending = m_pending;
    const bool hadTarget = !m_pendingTarget.isEmpty();
    m_pending = false;
    m_pendingTarget.clear();
    m_pendingKind.clear();
    m_pendingDrive.clear();
    m_currentBlock.clear();
    m_remainingBlocks.clear();
    if (wasPending) emit pendingChanged();
    if (hadTarget) emit pendingTargetChanged();
}
