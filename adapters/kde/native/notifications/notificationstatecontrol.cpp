// SPDX-License-Identifier: GPL-3.0-or-later
#include "notificationstatecontrol.h"

#include <QDBusConnectionInterface>
#include <QDBusMessage>
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
        setAvailable(m_bus.isConnected()
            && m_bus.interface()->isServiceRegistered(kService));
        if (m_available) {
            m_bus.connect(kService, kPath, kProperties,
                QStringLiteral("PropertiesChanged"), this,
                SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));
            readState();
        }
    } else {
        m_refreshTimer.stop();
        setAvailable(false);
        setInhibited(false);
    }
}

void NotificationStateControl::setAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();
}

void NotificationStateControl::setInhibited(bool inhibited)
{
    if (m_inhibited == inhibited) return;
    m_inhibited = inhibited;
    emit inhibitedChanged();
}

void NotificationStateControl::readState()
{
    if (!m_monitoring || !m_available) return;
    QDBusMessage message = QDBusMessage::createMethodCall(kService, kPath,
        kProperties, QStringLiteral("Get"));
    message << kInterface << QStringLiteral("Inhibited");
    const QDBusMessage reply = m_bus.call(message, QDBus::Block, 1000);
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty())
        return;
    setInhibited(unwrap(reply.arguments().first()).toBool());
}

void NotificationStateControl::refresh()
{
    if (m_monitoring && m_available) m_refreshTimer.start();
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
    if (!m_monitoring) return;
    refresh();
}

void NotificationStateControl::onServiceOwnerChanged(const QString &service,
    const QString &oldOwner, const QString &newOwner)
{
    Q_UNUSED(service)
    Q_UNUSED(oldOwner)
    if (!m_monitoring) return;
    if (newOwner.isEmpty()) {
        setAvailable(false);
        setInhibited(false);
        return;
    }
    setAvailable(true);
    m_bus.connect(kService, kPath, kProperties, QStringLiteral("PropertiesChanged"),
        this, SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));
    readState();
}
