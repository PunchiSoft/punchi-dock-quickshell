// SPDX-License-Identifier: GPL-3.0-or-later
#include "windowactivation.h"
#include <QDateTime>
#include <QMetaObject>
#include <climits>
#include <cmath>

namespace {
QList<QModelIndex> applicationWindows(const QAbstractItemModel &model, const QString &id)
{
    QList<QModelIndex> windows;
    const auto roles = model.roleNames();
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto index = model.index(row, 0);
        if (model.data(index, roles.key("IsWindow", -1)).toBool()
            && !model.data(index, roles.key("SkipTaskbar", -1)).toBool()
            && !model.data(index, roles.key("IsGroupParent", -1)).toBool()
            && taskApplicationIds(model, index, roles).contains(id)) windows.append(index);
    }
    return windows;
}

bool applicationStarting(const QAbstractItemModel &model, const QString &id)
{
    const auto roles = model.roleNames();
    if (!roles.values().contains("IsStartup")) return false;
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto index = model.index(row, 0);
        if (model.data(index, roles.key("IsStartup", -1)).toBool()
            && taskApplicationIds(model, index, roles).contains(id)) return true;
    }
    return false;
}
}

bool supportsWindowActivation(const QAbstractItemModel *model)
{
    if (!model || model->rowCount() > 4096) return false;
    const auto roles = model->roleNames().values();
    return roles.contains("IsWindow") && (roles.contains("AppId") || roles.contains("LauncherUrlWithoutIcon"))
        && model->metaObject()->indexOfMethod("requestActivate(QModelIndex)") >= 0;
}

QModelIndex applicationWindow(const QAbstractItemModel &model, const QString &desktopId)
{
    const QString id = normalizedApplicationId(desktopId);
    if (id.isEmpty() || model.rowCount() > 4096) return {};
    const auto roles = model.roleNames();
    if (!roles.values().contains("IsWindow")) return {};
    QModelIndex best;
    qint64 lastActivated = LLONG_MIN;
    for (const auto &index : applicationWindows(model, id)) {
        // Prefer the active matching window so a click can minimize it.
        if (model.data(index, roles.key("IsActive", -1)).toBool()) return index;
        const auto stamp = model.data(index, roles.key("LastActivated", -1)).toDateTime();
        const qint64 time = stamp.isValid() ? stamp.toMSecsSinceEpoch() : LLONG_MIN;
        if (!best.isValid() || time > lastActivated) { best = index; lastActivated = time; }
    }
    return best;
}

QJsonObject activateWindowRequest(QAbstractItemModel *model, bool available, const QJsonObject &request)
{
    const double number = request.value(QStringLiteral("requestId")).toDouble();
    if (!request.value(QStringLiteral("requestId")).isDouble() || !std::isfinite(number)
        || number < 1 || number > INT_MAX || std::floor(number) != number) return {};
    const QString id = normalizedApplicationId(request.value(QStringLiteral("desktopId")).toString());
    const QString type = request.value(QStringLiteral("type")).toString();
    const bool newInstance = type == QLatin1String("new-instance");
    QString status = QStringLiteral("rejected");
    if (request.value(QStringLiteral("version")).toInt() == 1
        && (type == QLatin1String("activate") || newInstance) && !id.isEmpty()) {
        if (!available || !supportsWindowActivation(model)) status = QStringLiteral("unavailable");
        else {
            auto index = applicationWindow(*model, id);
            if (!index.isValid()) status = !newInstance && applicationStarting(*model, id)
                ? QStringLiteral("starting") : QStringLiteral("not-found");
            else {
                const auto roles = model->roleNames();
                const auto windows = applicationWindows(*model, id);
                const bool active = model->data(index, roles.key("IsActive", -1)).toBool()
                    && !model->data(index, roles.key("IsMinimized", -1)).toBool();
                // Native indices are selected afresh; no IDs or cycle cache leave KDE.
                if (!newInstance && active && windows.size() > 1)
                    index = windows.at((windows.indexOf(index) + 1) % windows.size());
                const bool minimize = !newInstance && windows.size() == 1 && active
                    && !model->data(index, roles.key("IsMinimized", -1)).toBool()
                    && model->data(index, roles.key("IsMinimizable", -1)).toBool();
                const char *method = newInstance ? "requestNewInstance" : minimize ? "requestToggleMinimized" : "requestActivate";
                const char *signature = newInstance ? "requestNewInstance(QModelIndex)"
                    : minimize ? "requestToggleMinimized(QModelIndex)" : "requestActivate(QModelIndex)";
                status = model->metaObject()->indexOfMethod(signature) >= 0
                    && QMetaObject::invokeMethod(model, method, Qt::DirectConnection,
                    Q_ARG(QModelIndex, index))
                    ? (newInstance ? QStringLiteral("new-instance")
                        : minimize ? QStringLiteral("minimized") : QStringLiteral("activated"))
                    : QStringLiteral("unavailable");
            }
        }
    }
    return {{QStringLiteral("version"), 1}, {QStringLiteral("type"), QStringLiteral("activation-result")},
        {QStringLiteral("requestId"), int(number)}, {QStringLiteral("desktopId"), id}, {QStringLiteral("status"), status}};
}
