// SPDX-License-Identifier: GPL-3.0-or-later
#include "notificationstatecontrol.h"

#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QVariant>

namespace {
const QString kService = QStringLiteral("org.freedesktop.Notifications");
const QString kPath = QStringLiteral("/org/freedesktop/Notifications");
const QString kInterface = QStringLiteral("org.freedesktop.Notifications");
const QString kProperties = QStringLiteral("org.freedesktop.DBus.Properties");

QVariant unwrap(QVariant value)
{
    if (value.metaType().id() == qMetaTypeId<QDBusVariant>())
        value = value.value<QDBusVariant>().variant();
    return value;
}
}

NotificationStateControl::NotificationStateControl(QObject *parent) : QObject(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(50);
    connect(&m_refreshTimer, &QTimer::timeout, this,
        &NotificationStateControl::onRefreshTimeout);
}

void NotificationStateControl::setMonitoring(bool monitoring)
{
    if (m_monitoring == monitoring) return;
    m_monitoring = monitoring;
    emit monitoringChanged();
    if (monitoring) {
        if (m_watcher == nullptr) {
            m_watcher = new QDBusServiceWatcher(kService, m_bus,
                QDBusServiceWatcher::WatchForOwnerChange, this);
            connect(m_watcher, &QDBusServiceWatcher::serviceOwnerChanged,
                this, &NotificationStateControl::onServiceOwnerChanged);
        }
        m_owner = m_bus.isConnected()
            ? m_bus.interface()->serviceOwner(kService).value() : QString();
        setAvailable(!m_owner.isEmpty());
        if (m_owner.isEmpty()) {
            invalidate(QStringLiteral("no-service"));
            return;
        }
        subscribe();
        readState();
    } else {
        m_refreshTimer.stop();
        unsubscribe();
        m_owner.clear();
        ++m_readGeneration;
        setAvailable(false);
        invalidate(QStringLiteral("disabled"));
    }
}

void NotificationStateControl::setAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();
}

void NotificationStateControl::setReading(bool reading)
{
    if (m_reading == reading) return;
    m_reading = reading;
    emit readingChanged();
}

void NotificationStateControl::setValid(bool valid)
{
    if (m_valid == valid) return;
    m_valid = valid;
    emit validChanged();
}

void NotificationStateControl::setInhibited(bool inhibited)
{
    if (m_inhibited == inhibited) return;
    m_inhibited = inhibited;
    emit inhibitedChanged();
}

void NotificationStateControl::setLastError(const QString &error)
{
    if (m_lastError == error) return;
    m_lastError = error;
    emit lastErrorChanged();
}

void NotificationStateControl::invalidate(const QString &error)
{
    ++m_readGeneration;
    setReading(false);
    setValid(false);
    setInhibited(false);
    setLastError(error);
}

void NotificationStateControl::subscribe()
{
    if (m_subscribed || m_owner.isEmpty() || !m_monitoring) return;
    m_subscribed = m_bus.connect(kService, kPath, kProperties,
        QStringLiteral("PropertiesChanged"), this,
        SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));
}

void NotificationStateControl::unsubscribe()
{
    if (!m_subscribed) return;
    m_bus.disconnect(kService, kPath, kProperties,
        QStringLiteral("PropertiesChanged"), this,
        SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));
    m_subscribed = false;
}

void NotificationStateControl::readState()
{
    if (!m_monitoring || m_owner.isEmpty()) return;
    const quint64 generation = ++m_readGeneration;
    const QString owner = m_owner;
    QDBusMessage message = QDBusMessage::createMethodCall(kService, kPath,
        kProperties, QStringLiteral("Get"));
    message << kInterface << QStringLiteral("Inhibited");
    setReading(true);
    auto *watcher = new QDBusPendingCallWatcher(
        m_bus.asyncCall(message, 3000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
        [this, generation, owner](QDBusPendingCallWatcher *call) {
            call->deleteLater();
            if (!m_monitoring || generation != m_readGeneration || owner != m_owner)
                return;
            setReading(false);
            if (call->isError()) {
                setValid(false);
                setInhibited(false);
                setLastError(call->error().name().endsWith(
                    QStringLiteral("UnknownProperty"))
                    ? QStringLiteral("unknown-property") : QStringLiteral("read-failed"));
                return;
            }
            if (call->reply().arguments().isEmpty()) {
                setValid(false);
                setInhibited(false);
                setLastError(QStringLiteral("empty-reply"));
                return;
            }
            const QVariant value = unwrap(call->reply().arguments().first());
            if (value.metaType().id() != QMetaType::Bool) {
                setValid(false);
                setInhibited(false);
                setLastError(QStringLiteral("invalid-type"));
                return;
            }
            setInhibited(value.toBool());
            setValid(true);
            setLastError(QString());
        });
}

void NotificationStateControl::refresh()
{
    if (m_monitoring && !m_owner.isEmpty()) m_refreshTimer.start();
}

void NotificationStateControl::onRefreshTimeout()
{
    readState();
}

void NotificationStateControl::onPropertiesChanged(const QString &interfaceName,
    const QVariantMap &changed, const QStringList &invalidated)
{
    Q_UNUSED(interfaceName)
    Q_UNUSED(changed)
    Q_UNUSED(invalidated)
    if (!m_monitoring || !m_subscribed) return;
    refresh();
}

void NotificationStateControl::onServiceOwnerChanged(const QString &service,
    const QString &oldOwner, const QString &newOwner)
{
    Q_UNUSED(service)
    Q_UNUSED(oldOwner)
    if (!m_monitoring) return;
    unsubscribe();
    if (newOwner.isEmpty()) {
        m_owner.clear();
        setAvailable(false);
        invalidate(QStringLiteral("no-service"));
        return;
    }
    m_owner = newOwner;
    setAvailable(true);
    subscribe();
    invalidate(QStringLiteral("owner-changed"));
    readState();
}
