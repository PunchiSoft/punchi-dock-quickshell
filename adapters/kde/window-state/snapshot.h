// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QAbstractItemModel>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QUrl>
#include <QRect>
#include "../native/desktopentry.h"

inline QString normalizedApplicationId(QString id)
{
    if (id.endsWith(QLatin1String(".desktop"))) id.chop(8);
    return isValidDesktopId(id) ? id : QString();
}

inline QStringList runningDesktopIds(const QAbstractItemModel &model)
{
    QSet<QString> ids;
    const auto roles = model.roleNames();
    const int isWindow = roles.key("IsWindow", -1);
    const int skipTaskbar = roles.key("SkipTaskbar", -1);
    const int appIdRole = roles.key("AppId", -1);
    const int launcherRole = roles.key("LauncherUrlWithoutIcon", -1);
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto index = model.index(row, 0);
        if (!model.data(index, isWindow).toBool()
            || model.data(index, skipTaskbar).toBool()) continue;
        const QString appId = normalizedApplicationId(model.data(index, appIdRole).toString());
        if (!appId.isEmpty()) ids.insert(appId);
        const QUrl launcher = model.data(index, launcherRole).toUrl();
        if (launcher.scheme() == QLatin1String("applications") || launcher.isLocalFile()) {
            const QString launcherId = normalizedApplicationId(launcher.fileName());
            if (!launcherId.isEmpty()) ids.insert(launcherId);
        }
    }
    QStringList sorted = ids.values();
    sorted.sort();
    return sorted;
}

inline QJsonObject windowVisibilitySnapshot(const QAbstractItemModel *model, bool available, bool showingDesktop)
{
    QJsonArray rectangles;
    bool ready = available && model && model->rowCount() <= 512;
    if (ready) {
        const auto roles = model->roleNames();
        const int geometry = roles.key("Geometry", -1);
        const int isWindow = roles.key("IsWindow", -1);
        ready = geometry >= 0 && isWindow >= 0;
        for (int row = 0; ready && row < model->rowCount(); ++row) {
            const auto index = model->index(row, 0);
            if (!model->data(index, isWindow).toBool()) continue;
            if (model->data(index, roles.key("SkipTaskbar", -1)).toBool()) continue;
            if (model->data(index, roles.key("IsMinimized", -1)).toBool()
                || model->data(index, roles.key("IsHidden", -1)).toBool()) continue;
            const QRect rect = model->data(index, geometry).toRect();
            if (rect.isEmpty()) { ready = false; break; }
            rectangles.append(QJsonArray{rect.x(), rect.y(), rect.width(), rect.height()});
        }
    }
    return {{QStringLiteral("available"), ready},
        {QStringLiteral("showingDesktop"), ready && showingDesktop},
        {QStringLiteral("rectangles"), ready ? rectangles : QJsonArray()}};
}

inline QByteArray windowStateSnapshot(bool available, const QStringList &ids = {}, const QJsonObject &visibility = {})
{
    QJsonObject object{{QStringLiteral("version"), 1},
        {QStringLiteral("available"), available},
        {QStringLiteral("desktopIds"), QJsonArray::fromStringList(available ? ids : QStringList())}};
    if (!visibility.isEmpty()) object.insert(QStringLiteral("visibility"), visibility);
    return QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n';
}
