// SPDX-License-Identifier: GPL-3.0-or-later
#include "screenbrightnesscontrol.h"

#include <QDBusArgument>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QDBusVariant>

#include <algorithm>

namespace {
const QString kService = QStringLiteral("org.kde.ScreenBrightness");
const QString kControllerPath = QStringLiteral("/org/kde/ScreenBrightness");
const QString kControllerInterface = QStringLiteral("org.kde.ScreenBrightness");
const QString kDisplayInterface = QStringLiteral("org.kde.ScreenBrightness.Display");
const QString kProperties = QStringLiteral("org.freedesktop.DBus.Properties");

QVariant unwrap(QVariant value)
{
    if (value.metaType().id() == qMetaTypeId<QDBusVariant>())
        value = value.value<QDBusVariant>().variant();
    return value;
}

QVariantMap toMap(const QVariant &value)
{
    if (value.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        QDBusArgument argument = value.value<QDBusArgument>();
        QVariantMap map;
        argument >> map;
        return map;
    }
    return value.toMap();
}

QString stringValue(const QVariant &value)
{
    if (value.metaType().id() == QMetaType::QByteArray)
        return QString::fromUtf8(value.toByteArray());
    return value.toString();
}
}

ScreenBrightnessControl::ScreenBrightnessControl(QObject *parent) : QObject(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(50);
    connect(&m_refreshTimer, &QTimer::timeout, this, &ScreenBrightnessControl::onRefreshTimeout);
    m_commitTimer.setSingleShot(true);
    m_commitTimer.setInterval(60);
    connect(&m_commitTimer, &QTimer::timeout, this, &ScreenBrightnessControl::onCommitTimeout);
}

QString ScreenBrightnessControl::displayPath(const QString &displayId)
{
    return kControllerPath + QLatin1Char('/') + displayId;
}

void ScreenBrightnessControl::setMonitoring(bool monitoring)
{
    if (m_monitoring == monitoring) return;
    m_monitoring = monitoring;
    emit monitoringChanged();
    if (monitoring) {
        if (m_watcher == nullptr) {
            m_watcher = new QDBusServiceWatcher(kService, m_bus,
                QDBusServiceWatcher::WatchForOwnerChange, this);
            connect(m_watcher, &QDBusServiceWatcher::serviceOwnerChanged,
                this, &ScreenBrightnessControl::onServiceOwnerChanged);
        }
        // A service that is activatable but not running is treated as absent;
        // the panel must not activate PowerDevil on its own.
        setAvailable(m_bus.isConnected()
            && m_bus.interface()->isServiceRegistered(kService));
        if (m_available) {
            subscribeController();
            rebuild();
        }
    } else {
        m_refreshTimer.stop();
        m_commitTimer.stop();
        m_requested.clear();
        setPending(false);
        m_subscribed.clear();
        m_displays.clear();
        emit displaysChanged();
        setAvailable(false);
    }
}

void ScreenBrightnessControl::setAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();
}

void ScreenBrightnessControl::subscribeController()
{
    if (!m_subscribed.contains(kControllerPath)) {
        if (m_bus.connect(kService, kControllerPath, kProperties,
                QStringLiteral("PropertiesChanged"), this,
                SLOT(onPropertiesChanged(QString,QVariantMap,QStringList))))
            m_subscribed.insert(kControllerPath);
    }
}

void ScreenBrightnessControl::subscribeDisplay(const QString &path)
{
    if (m_subscribed.contains(path)) return;
    if (m_bus.connect(kService, path, kProperties, QStringLiteral("PropertiesChanged"),
            this, SLOT(onPropertiesChanged(QString,QVariantMap,QStringList))))
        m_subscribed.insert(path);
}

QStringList ScreenBrightnessControl::displayNames() const
{
    QDBusMessage message = QDBusMessage::createMethodCall(kService, kControllerPath,
        kProperties, QStringLiteral("Get"));
    message << kControllerInterface << QStringLiteral("DisplaysDBusNames");
    const QDBusMessage reply = m_bus.call(message, QDBus::Block, 1000);
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty())
        return {};
    const QVariant value = unwrap(reply.arguments().first());
    return value.toStringList();
}

QVariantMap ScreenBrightnessControl::displayProperties(const QString &displayId) const
{
    QDBusMessage message = QDBusMessage::createMethodCall(kService,
        displayPath(displayId), kProperties, QStringLiteral("GetAll"));
    message << kDisplayInterface;
    const QDBusMessage reply = m_bus.call(message, QDBus::Block, 1000);
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty())
        return {};
    return toMap(unwrap(reply.arguments().first()));
}

int ScreenBrightnessControl::readBrightness(const QString &displayId) const
{
    QDBusMessage message = QDBusMessage::createMethodCall(kService,
        displayPath(displayId), kProperties, QStringLiteral("Get"));
    message << kDisplayInterface << QStringLiteral("Brightness");
    const QDBusMessage reply = m_bus.call(message, QDBus::Block, 1000);
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty())
        return -1;
    return unwrap(reply.arguments().first()).toInt();
}

void ScreenBrightnessControl::rebuild()
{
    if (!m_monitoring || !m_available) return;
    const QStringList names = displayNames();
    if (names.isEmpty()) {
        if (!m_displays.isEmpty()) {
            m_displays.clear();
            emit displaysChanged();
        }
        return;
    }
    QVariantList next;
    for (const QString &name : names) {
        const QString path = displayPath(name);
        subscribeDisplay(path);
        const QVariantMap properties = displayProperties(name);
        const int maximum = properties.value(QStringLiteral("MaxBrightness")).toInt();
        if (maximum <= 0) continue;
        const int brightness = properties.value(QStringLiteral("Brightness")).toInt();
        QString label = stringValue(properties.value(QStringLiteral("Label")));
        if (label.isEmpty()) label = name;
        QVariantMap display;
        display.insert(QStringLiteral("id"), name);
        display.insert(QStringLiteral("label"), label);
        display.insert(QStringLiteral("internal"),
            properties.value(QStringLiteral("IsInternal")).toBool());
        display.insert(QStringLiteral("brightness"), brightness);
        display.insert(QStringLiteral("maximum"), maximum);
        display.insert(QStringLiteral("percent"),
            qRound(brightness * 100.0 / maximum));
        next.append(display);
    }
    std::sort(next.begin(), next.end(), [](const QVariant &first, const QVariant &second) {
        const QVariantMap firstMap = first.toMap();
        const QVariantMap secondMap = second.toMap();
        const bool firstInternal = firstMap.value(QStringLiteral("internal")).toBool();
        const bool secondInternal = secondMap.value(QStringLiteral("internal")).toBool();
        if (firstInternal != secondInternal) return firstInternal;
        return firstMap.value(QStringLiteral("label")).toString()
            < secondMap.value(QStringLiteral("label")).toString();
    });
    if (next == m_displays) return;
    m_displays = next;
    emit displaysChanged();
}

void ScreenBrightnessControl::refresh()
{
    if (m_monitoring && m_available) m_refreshTimer.start();
}

void ScreenBrightnessControl::onRefreshTimeout()
{
    rebuild();
}

void ScreenBrightnessControl::onPropertiesChanged(const QString &interfaceName,
    const QVariantMap &changed, const QStringList &invalidated)
{
    Q_UNUSED(interfaceName)
    Q_UNUSED(changed)
    Q_UNUSED(invalidated)
    if (!m_monitoring) return;
    refresh();
}

void ScreenBrightnessControl::onServiceOwnerChanged(const QString &service,
    const QString &oldOwner, const QString &newOwner)
{
    Q_UNUSED(service)
    Q_UNUSED(oldOwner)
    if (!m_monitoring) return;
    if (newOwner.isEmpty()) {
        setAvailable(false);
        m_displays.clear();
        emit displaysChanged();
        setPending(false);
        return;
    }
    setAvailable(true);
    subscribeController();
    rebuild();
}

QVariantMap ScreenBrightnessControl::findDisplay(const QString &displayId) const
{
    for (const QVariant &value : m_displays) {
        const QVariantMap display = value.toMap();
        if (display.value(QStringLiteral("id")).toString() == displayId)
            return display;
    }
    return {};
}

void ScreenBrightnessControl::setPending(bool pending)
{
    if (m_pending == pending) return;
    m_pending = pending;
    emit pendingChanged();
}

bool ScreenBrightnessControl::setPercent(const QString &displayId, int percent)
{
    if (!m_available || !m_monitoring) return false;
    const QVariantMap display = findDisplay(displayId);
    if (display.isEmpty()) return false;
    const int maximum = display.value(QStringLiteral("maximum")).toInt();
    if (maximum <= 0) return false;
    const int clamped = std::clamp(percent, 0, 100);
    m_requested.insert(displayId, clamped);
    setPending(true);
    m_commitTimer.start();
    return true;
}

void ScreenBrightnessControl::onCommitTimeout()
{
    if (m_requested.isEmpty()) {
        setPending(false);
        return;
    }
    const QHash<QString, int> requests = m_requested;
    m_requested.clear();
    for (auto request = requests.constBegin(); request != requests.constEnd(); ++request) {
        if (findDisplay(request.key()).isEmpty()) continue;
        writeDisplay(request.key(), request.value());
    }
    setPending(false);
}

void ScreenBrightnessControl::writeDisplay(const QString &displayId, int percent)
{
    const QVariantMap display = findDisplay(displayId);
    if (display.isEmpty()) return;
    const int maximum = display.value(QStringLiteral("maximum")).toInt();
    const int target = qRound(maximum * percent / 100.0);
    QDBusMessage message = QDBusMessage::createMethodCall(kService, displayPath(displayId),
        kDisplayInterface, QStringLiteral("SetBrightness"));
    // The second argument is PowerDevil's flags field; zero keeps its own
    // indicator behaviour untouched.
    message << target << 0u;
    const QDBusMessage reply = m_bus.call(message, QDBus::Block, 1000);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        finishOperation(displayId, percent, false, errorCode(reply.errorName()));
        return;
    }
    const int readBack = readBrightness(displayId);
    const bool confirmed = readBack >= 0
        && qAbs(readBack - target) <= qMax(1, maximum / 100);
    finishOperation(displayId, percent, confirmed, confirmed ? QString()
        : QStringLiteral("unconfirmed"));
    refresh();
}

void ScreenBrightnessControl::finishOperation(const QString &displayId, int percent,
    bool success, const QString &error)
{
    m_lastTarget = displayId;
    m_lastPercent = percent;
    m_lastSuccess = success;
    m_lastError = error;
    setPending(false);
    emit lastResultChanged();
    emit operationFinished(displayId, percent, success, error);
}

QString ScreenBrightnessControl::errorCode(const QString &name) const
{
    if (name.contains(QStringLiteral("ServiceUnknown"))
            || name.contains(QStringLiteral("NameHasNoOwner")))
        return QStringLiteral("unavailable");
    if (name.contains(QStringLiteral("TimedOut"))
            || name.contains(QStringLiteral("NoReply")))
        return QStringLiteral("timeout");
    if (name.contains(QStringLiteral("NotAuthorized")))
        return QStringLiteral("rejected");
    return QStringLiteral("failed");
}
