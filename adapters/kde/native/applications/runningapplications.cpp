// SPDX-License-Identifier: GPL-3.0-or-later
#include "runningapplications.h"
#include "desktopentry.h"
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QMap>

namespace {
QString normalized(QString id)
{
    if (id.endsWith(QLatin1String(".desktop"))) id.chop(8);
    return isValidDesktopId(id) ? id : QString();
}
}

RunningApplications::RunningApplications(QObject *parent)
    : QObject(parent), m_visibility(this), m_activation(&m_process, this)
{
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &RunningApplications::consume);
    connect(&m_process, &QProcess::readyReadStandardError, this, [this]() {
        const QByteArray diagnostic = m_process.readAllStandardError();
        if (!diagnostic.isEmpty()) qWarning().noquote() << "Punchi window backend:" << QString::fromUtf8(diagnostic.left(4096)).trimmed();
    });
    connect(&m_process, &QProcess::finished, this, [this]() { update(false); m_buffer.clear(); });
    connect(&m_process, &QProcess::errorOccurred, this, [this]() { update(false); });
}
RunningApplications::~RunningApplications() { stop(); }
void RunningApplications::setExecutable(const QString &value)
{
    if (value == m_executable) return;
    m_executable = value;
    emit executableChanged();
    if (m_complete) restart();
}
void RunningApplications::setEnabled(bool value)
{
    if (value == m_enabled) return;
    m_enabled = value;
    emit enabledChanged();
    if (m_complete) restart();
}
bool RunningApplications::isRunning(const QString &desktopId) const
{
    return m_available && m_ids.contains(normalized(desktopId));
}
QVariantMap RunningApplications::windowActions(const QString &desktopId) const
{
    return m_available ? m_windowActions.value(normalized(desktopId)).toMap() : QVariantMap();
}
void RunningApplications::update(bool available, const QSet<QString> &ids, const QVariantList &applicationEntries,
    const QVariantMap &windowActions, const QVariantList &virtualDesktops,
    const QStringList &currentDesktopIds, const QVariantList &activities)
{
    if (!available) { m_visibility.clear(); m_activation.setAvailable(false); }
    const QSet<QString> next = available ? ids : QSet<QString>();
    const QVariantList nextEntries = available ? applicationEntries : QVariantList();
    const QVariantMap nextWindowActions = available ? windowActions : QVariantMap();
    const QVariantList nextDesktops = available ? virtualDesktops : QVariantList();
    const QStringList nextCurrentDesktopIds = available ? currentDesktopIds : QStringList();
    const QVariantList nextActivities = available ? activities : QVariantList();
    if (available == m_available && next == m_ids && nextEntries == m_applicationEntries
        && nextWindowActions == m_windowActions && nextDesktops == m_virtualDesktops
        && nextCurrentDesktopIds == m_currentDesktopIds && nextActivities == m_activities) return;
    m_available = available;
    m_ids = next;
    m_applicationEntries = nextEntries;
    m_windowActions = nextWindowActions;
    m_virtualDesktops = nextDesktops;
    m_currentDesktopIds = nextCurrentDesktopIds;
    m_activities = nextActivities;
    m_revision = m_revision == INT_MAX ? 0 : m_revision + 1;
    emit changed();
}
void RunningApplications::stop()
{
    if (m_stopping) return;
    m_stopping = true;
    if (m_process.state() != QProcess::NotRunning) {
        m_process.closeWriteChannel();
        if (!m_process.waitForFinished(500)) {
            m_process.terminate();
            if (!m_process.waitForFinished(500)) { m_process.kill(); m_process.waitForFinished(500); }
        }
    }
    m_buffer.clear();
    update(false);
    m_stopping = false;
}
void RunningApplications::restart()
{
    stop();
    const QFileInfo file(m_executable);
    if (!m_enabled || !file.isAbsolute() || !file.isFile() || !file.isExecutable()) return;
    m_process.setProgram(file.canonicalFilePath());
    m_process.setArguments({});
    m_process.start();
}
void RunningApplications::consume()
{
    if (m_stopping) { m_process.readAllStandardOutput(); return; }
    m_buffer += m_process.readAllStandardOutput();
    if (m_buffer.size() > 524288) { stop(); return; }
    while (m_buffer.contains('\n')) {
        const int newline = m_buffer.indexOf('\n');
        const QByteArray line = m_buffer.left(newline);
        m_buffer.remove(0, newline + 1);
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(line, &error);
        const auto object = document.object();
        if (error.error == QJsonParseError::NoError && document.isObject()
            && (object.value(QStringLiteral("type")).toString() == QLatin1String("activation-result")
                || object.value(QStringLiteral("type")).toString() == QLatin1String("window-action-result"))) {
            if (!m_activation.acceptResult(object)) { stop(); return; }
            continue;
        }
        if (error.error != QJsonParseError::NoError || !document.isObject()
            || object.value(QStringLiteral("version")).toInt() != 1
            || !object.value(QStringLiteral("available")).isBool()
            || !object.value(QStringLiteral("desktopIds")).isArray()
            || (object.contains(QStringLiteral("applications"))
                && !object.value(QStringLiteral("applications")).isArray())
            || (object.contains(QStringLiteral("activationAvailable"))
                && !object.value(QStringLiteral("activationAvailable")).isBool())
            || (object.contains(QStringLiteral("windowActions")) && !object.value(QStringLiteral("windowActions")).isObject())
            || (object.contains(QStringLiteral("virtualDesktops")) && !object.value(QStringLiteral("virtualDesktops")).isArray())
            || (object.contains(QStringLiteral("currentDesktopIds")) && !object.value(QStringLiteral("currentDesktopIds")).isArray())
            || (object.contains(QStringLiteral("activities")) && !object.value(QStringLiteral("activities")).isArray())) { stop(); return; }
        const auto array = object.value(QStringLiteral("desktopIds")).toArray();
        if (array.size() > 1024) { stop(); return; }
        QSet<QString> ids;
        for (const auto value : array) {
            if (!value.isString() || normalized(value.toString()).isEmpty()) { stop(); return; }
            ids.insert(normalized(value.toString()));
        }
        QVariantList applications;
        const auto applicationArray = object.value(QStringLiteral("applications")).toArray();
        if (applicationArray.size() > 256) { stop(); return; }
        QMap<QString, QVariantMap> uniqueApplications;
        static const QRegularExpression iconNamePattern(QStringLiteral("^[A-Za-z0-9_.-]{1,128}$"));
        for (const auto value : applicationArray) {
            if (!value.isObject()) { stop(); return; }
            const auto entry = value.toObject();
            const QString id = normalized(entry.value(QStringLiteral("desktopId")).toString());
            const QString name = entry.value(QStringLiteral("name")).toString().trimmed();
            QString iconName = entry.value(QStringLiteral("iconName")).toString();
            if (id.isEmpty() || name.isEmpty() || name.size() > 128
                || iconName.size() > 128
                || (!iconName.isEmpty() && !iconNamePattern.match(iconName).hasMatch())) { stop(); return; }
            if (!ids.contains(id)) { stop(); return; }
            iconName = iconName.isEmpty() ? QStringLiteral("application-x-executable") : iconName;
            uniqueApplications.insert(id, {{QStringLiteral("desktopId"), id},
                {QStringLiteral("name"), name}, {QStringLiteral("iconName"), iconName}});
        }
        for (auto it = uniqueApplications.cbegin(); it != uniqueApplications.cend(); ++it)
            applications.append(it.value());
        QVariantMap windowActions;
        const auto windowActionObject = object.value(QStringLiteral("windowActions")).toObject();
        if (windowActionObject.size() > 1024) { stop(); return; }
        for (auto it = windowActionObject.begin(); it != windowActionObject.end(); ++it) {
            const QString id = normalized(it.key());
            if (id.isEmpty() || !ids.contains(id) || !it.value().isObject()) { stop(); return; }
            const auto state = it.value().toObject();
            static const QStringList boolKeys{"available", "movable", "resizable", "maximizable", "maximized",
                "minimizable", "minimized", "keepAbove", "keepBelow", "fullscreenable", "fullscreen",
                "canSetNoBorder", "noBorder", "canHideFromCapture", "excludedFromCapture", "closable", "desktopChangeable",
                "onAllDesktops", "groupable"};
            QVariantMap values;
            for (const auto &key : boolKeys) {
                if (!state.value(key).isBool()) { stop(); return; }
                values.insert(key, state.value(key).toBool());
            }
            const auto assigned = state.value(QStringLiteral("virtualDesktops"));
            if (!assigned.isArray() || assigned.toArray().size() > 128) { stop(); return; }
            QVariantList assignedIds;
            for (const auto desktop : assigned.toArray()) {
                if (!(desktop.isString() || desktop.isDouble())) { stop(); return; }
                assignedIds.append(desktop.toVariant());
            }
            values.insert(QStringLiteral("virtualDesktops"), assignedIds);
            windowActions.insert(id, values);
        }
        QVariantList virtualDesktops;
        const auto desktopArray = object.value(QStringLiteral("virtualDesktops")).toArray();
        if (desktopArray.size() > 128) { stop(); return; }
        for (const auto desktop : desktopArray) {
            if (!desktop.isObject()) { stop(); return; }
            const auto value = desktop.toObject();
            const auto desktopId = value.value(QStringLiteral("id"));
            const auto name = value.value(QStringLiteral("name")).toString().trimmed();
            // KDE publishes desktop names after the first snapshot; an empty name is valid.
            if (!(desktopId.isString() || desktopId.isDouble()) || name.size() > 128
                || !value.value(QStringLiteral("current")).isBool()) { stop(); return; }
            virtualDesktops.append(QVariantMap{{QStringLiteral("id"), desktopId.toVariant()},
                {QStringLiteral("name"), name}, {QStringLiteral("current"), value.value(QStringLiteral("current")).toBool()}});
        }
        QVariantList activities;
        const auto activityArray = object.value(QStringLiteral("activities")).toArray();
        if (activityArray.size() > 64) { stop(); return; }
        for (const auto activity : activityArray) {
            if (!activity.isObject()) { stop(); return; }
            const auto value = activity.toObject();
            const QString id = value.value(QStringLiteral("id")).toString();
            const QString name = value.value(QStringLiteral("name")).toString().trimmed();
            if (id.isEmpty() || id.size() > 128 || name.size() > 128
                || !value.value(QStringLiteral("current")).isBool()) { stop(); return; }
            activities.append(QVariantMap{{QStringLiteral("id"), id}, {QStringLiteral("name"), name},
                {QStringLiteral("current"), value.value(QStringLiteral("current")).toBool()}});
        }
        QStringList currentDesktopIds;
        const auto currentArray = object.value(QStringLiteral("currentDesktopIds")).toArray();
        if (currentArray.size() > 1024) { stop(); return; }
        for (const auto value : currentArray) {
            if (!value.isString() || normalized(value.toString()).isEmpty()) { stop(); return; }
            const QString id = normalized(value.toString());
            if (!ids.contains(id)) { stop(); return; }
            currentDesktopIds.append(id);
        }
        update(object.value(QStringLiteral("available")).toBool(), ids, applications, windowActions,
            virtualDesktops, currentDesktopIds, activities);
        if (m_available) m_visibility.accept(object.value(QStringLiteral("visibility")).toObject());
        m_activation.setAvailable(m_available && object.value(QStringLiteral("activationAvailable")).toBool());
    }
}
