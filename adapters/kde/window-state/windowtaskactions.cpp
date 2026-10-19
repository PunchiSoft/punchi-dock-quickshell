// SPDX-License-Identifier: GPL-3.0-or-later
#include "windowtaskactions.h"
#include "snapshot.h"
#include <QDateTime>
#include <QMetaObject>
#include <QJsonArray>
#include <climits>
#include <cmath>

namespace {
QModelIndex selectedWindow(const QAbstractItemModel *model, const QString &desktopId)
{
    if (!model || model->rowCount() > 4096) return {};
    const QString id = normalizedApplicationId(desktopId);
    if (id.isEmpty()) return {};
    const auto roles = model->roleNames();
    const int isWindow = roles.key("IsWindow", -1);
    if (isWindow < 0) return {};
    QModelIndex best;
    qint64 lastActivated = LLONG_MIN;
    for (int row = 0; row < model->rowCount(); ++row) {
        const auto index = model->index(row, 0);
        if (!model->data(index, isWindow).toBool()
            || model->data(index, roles.key("SkipTaskbar", -1)).toBool()
            || model->data(index, roles.key("IsGroupParent", -1)).toBool()
            || !taskApplicationIds(*model, index, roles).contains(id)) continue;
        if (model->data(index, roles.key("IsActive", -1)).toBool()) return index;
        const auto stamp = model->data(index, roles.key("LastActivated", -1)).toDateTime();
        const qint64 time = stamp.isValid() ? stamp.toMSecsSinceEpoch() : LLONG_MIN;
        if (!best.isValid() || time > lastActivated) { best = index; lastActivated = time; }
    }
    return best;
}

bool role(const QAbstractItemModel &model, const QModelIndex &index, const char *name)
{
    const int roleId = model.roleNames().key(name, -1);
    return roleId >= 0 && model.data(index, roleId).toBool();
}

QJsonValue jsonValue(const QVariant &value)
{
    const auto converted = QJsonValue::fromVariant(value);
    return converted.isUndefined() || converted.isNull() ? QJsonValue() : converted;
}

QVariantList desktopsFor(const QAbstractItemModel &model, const QModelIndex &index)
{
    const int desktopRole = model.roleNames().key("VirtualDesktops", -1);
    if (desktopRole < 0) return {};
    return model.data(index, desktopRole).toList();
}

QJsonObject actionState(const QAbstractItemModel &model, const QModelIndex &index)
{
    const auto taskDesktops = desktopsFor(model, index);
    QJsonArray assignedDesktops;
    if (taskDesktops.size() <= 128) {
        for (const auto &desktop : taskDesktops) {
            const auto value = jsonValue(desktop);
            if (value.isUndefined() || (value.isString() && value.toString().size() > 128)) {
                assignedDesktops = {};
                break;
            }
            assignedDesktops.append(value);
        }
    }
    const bool desktopChangeable = role(model, index, "IsVirtualDesktopsChangeable")
        && taskDesktops.size() <= 128 && assignedDesktops.size() == taskDesktops.size();
    return {{"available", true}, {"movable", role(model, index, "IsMovable")},
        {"resizable", role(model, index, "IsResizable")}, {"maximizable", role(model, index, "IsMaximizable")},
        {"maximized", role(model, index, "IsMaximized")}, {"minimizable", role(model, index, "IsMinimizable")},
        {"minimized", role(model, index, "IsMinimized")}, {"keepAbove", role(model, index, "IsKeepAbove")},
        {"keepBelow", role(model, index, "IsKeepBelow")}, {"fullscreenable", role(model, index, "IsFullScreenable")},
        {"fullscreen", role(model, index, "IsFullScreen")}, {"canSetNoBorder", role(model, index, "CanSetNoBorder")},
        {"noBorder", role(model, index, "HasNoBorder")},
        {"canHideFromCapture", model.roleNames().key("IsExcludedFromCapture", -1) >= 0},
        {"excludedFromCapture", role(model, index, "IsExcludedFromCapture")},
        {"closable", role(model, index, "IsClosable")},
        {"desktopChangeable", desktopChangeable},
        {"onAllDesktops", role(model, index, "IsOnAllVirtualDesktops")},
        {"virtualDesktops", assignedDesktops}, {"groupable", role(model, index, "IsGroupable")}};
}

bool invoke(QAbstractItemModel *model, const QModelIndex &index, const char *method)
{
    const QByteArray signature = QByteArray(method) + "(QModelIndex)";
    return model->metaObject()->indexOfMethod(signature.constData()) >= 0
        && QMetaObject::invokeMethod(model, method, Qt::DirectConnection, Q_ARG(QModelIndex, index));
}
}

QJsonObject windowActionsSnapshot(const QAbstractItemModel *model, bool available,
    const QVariantList &desktopIds, const QStringList &desktopNames, const QVariant &currentDesktop)
{
    QJsonArray desktops;
    const int count = qMin(desktopIds.size(), desktopNames.size());
    if (available && count <= 128) {
        for (int i = 0; i < count; ++i) {
            const auto id = jsonValue(desktopIds.at(i));
            if (id.isUndefined() || (id.isString() && id.toString().size() > 128)
                || desktopNames.at(i).size() > 128) { desktops = {}; break; }
            desktops.append(QJsonObject{{"id", id}, {"name", desktopNames.at(i)},
                {"current", desktopIds.at(i) == currentDesktop}});
        }
    }
    QJsonObject applications;
    if (available && model && model->rowCount() <= 4096) {
        const auto roles = model->roleNames();
        QMap<QString, QModelIndex> targets;
        QMap<QString, qint64> timestamps;
        const int isWindow = roles.key("IsWindow", -1);
        for (int row = 0; isWindow >= 0 && row < model->rowCount(); ++row) {
            const auto index = model->index(row, 0);
            if (!model->data(index, isWindow).toBool()
                || model->data(index, roles.key("SkipTaskbar", -1)).toBool()
                || model->data(index, roles.key("IsGroupParent", -1)).toBool()) continue;
            const bool active = model->data(index, roles.key("IsActive", -1)).toBool();
            const auto stamp = model->data(index, roles.key("LastActivated", -1)).toDateTime();
            const qint64 time = stamp.isValid() ? stamp.toMSecsSinceEpoch() : LLONG_MIN;
            for (const auto &id : taskApplicationIds(*model, index, roles)) {
                if (id.isEmpty() || (!active && targets.contains(id) && timestamps.value(id) >= time)) continue;
                targets.insert(id, index);
                timestamps.insert(id, active ? LLONG_MAX : time);
            }
        }
        for (auto it = targets.cbegin(); it != targets.cend() && applications.size() < 1024; ++it)
            applications.insert(it.key(), actionState(*model, it.value()));
    }
    return {{"desktops", desktops}, {"applications", applications}};
}

QJsonObject windowActionRequest(QAbstractItemModel *model, bool available,
    const QVariantList &desktopIds, const QJsonObject &request)
{
    const auto requestId = request.value("requestId");
    const double numericId = requestId.toDouble();
    const QString desktopId = normalizedApplicationId(request.value("desktopId").toString());
    const QString action = request.value("action").toString();
    if (request.value("version").toInt() != 1 || request.value("type").toString() != QLatin1String("window-action")
        || !requestId.isDouble() || !std::isfinite(numericId) || numericId < 1 || numericId > INT_MAX
        || std::floor(numericId) != numericId || desktopId.isEmpty() || action.isEmpty()) return {};
    const int safeRequestId = int(numericId);
    QString status = "rejected";
    if (!available || !model || model->rowCount() > 4096) status = "unavailable";
        else {
            const auto index = selectedWindow(model, desktopId);
            if (!index.isValid()) status = "not-found";
            else {
                const auto roles = model->roleNames();
                const auto roleValue = [&](const char *name) { return role(*model, index, name); };
                if (action == QLatin1String("move") && roleValue("IsMovable"))
                    status = invoke(model, index, "requestMove") ? "requested" : "unavailable";
                else if (action == QLatin1String("resize") && roleValue("IsResizable"))
                    status = invoke(model, index, "requestResize") ? "requested" : "unavailable";
                else if (action == QLatin1String("maximize") && roleValue("IsMaximizable"))
                    status = invoke(model, index, "requestToggleMaximized") ? "requested" : "unavailable";
                else if (action == QLatin1String("minimize") && roleValue("IsMinimizable"))
                    status = invoke(model, index, "requestToggleMinimized") ? "requested" : "unavailable";
                else if (action == QLatin1String("keep-above"))
                    status = invoke(model, index, "requestToggleKeepAbove") ? "requested" : "unavailable";
                else if (action == QLatin1String("keep-below"))
                    status = invoke(model, index, "requestToggleKeepBelow") ? "requested" : "unavailable";
                else if (action == QLatin1String("fullscreen") && roleValue("IsFullScreenable"))
                    status = invoke(model, index, "requestToggleFullScreen") ? "requested" : "unavailable";
                else if (action == QLatin1String("no-border") && roleValue("CanSetNoBorder"))
                    status = invoke(model, index, "requestToggleNoBorder") ? "requested" : "unavailable";
                else if (action == QLatin1String("hide-capture") && roles.key("IsExcludedFromCapture", -1) >= 0)
                    status = invoke(model, index, "requestToggleExcludeFromCapture") ? "requested" : "unavailable";
                else if (action == QLatin1String("new-desktop") && roleValue("IsVirtualDesktopsChangeable")
                    && desktopIds.size() > 1)
                    status = invoke(model, index, "requestNewVirtualDesktop") ? "requested" : "unavailable";
                else if (action == QLatin1String("close") && roleValue("IsClosable"))
                    status = invoke(model, index, "requestClose") ? "requested" : "unavailable";
                else if (action == QLatin1String("grouping") && roleValue("IsWindow"))
                    status = invoke(model, index, "requestToggleGrouping") ? "requested" : "unavailable";
                else if (action == QLatin1String("desktop") && roleValue("IsVirtualDesktopsChangeable")) {
                    const auto desktopValue = request.value("desktop");
                    const auto target = desktopValue.toVariant();
                    if (desktopValue.isArray() && desktopValue.toArray().isEmpty()) {
                        const QVariantList values;
                        const char *signature = "requestVirtualDesktops(QModelIndex,QVariantList)";
                        status = model->metaObject()->indexOfMethod(signature) >= 0
                            && QMetaObject::invokeMethod(model, "requestVirtualDesktops", Qt::DirectConnection,
                                Q_ARG(QModelIndex, index), Q_ARG(QVariantList, values)) ? "requested" : "unavailable";
                    } else if (desktopIds.contains(target)) {
                        const QVariantList values{target};
                        const char *signature = "requestVirtualDesktops(QModelIndex,QVariantList)";
                        status = model->metaObject()->indexOfMethod(signature) >= 0
                            && QMetaObject::invokeMethod(model, "requestVirtualDesktops", Qt::DirectConnection,
                                Q_ARG(QModelIndex, index), Q_ARG(QVariantList, values)) ? "requested" : "unavailable";
                    }
                }
            }
        }
    return {{"version", 1}, {"type", "window-action-result"}, {"requestId", safeRequestId},
        {"desktopId", desktopId}, {"action", action}, {"status", status}};
}
