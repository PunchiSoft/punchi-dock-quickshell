// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QAbstractItemModel>
#include <QUrl>
#include "../native/desktopentry.h"

inline QString normalizedApplicationId(QString id)
{
    if (id.endsWith(QLatin1String(".desktop"))) id.chop(8);
    return isValidDesktopId(id) ? id : QString();
}

QString resolvedTaskDesktopId(const QString &appId, const QUrl &launcher);

inline QStringList taskApplicationIds(const QAbstractItemModel &model, const QModelIndex &index,
                                     const QHash<int, QByteArray> &roles)
{
    QStringList ids;
    const QString rawId = model.data(index, roles.key("AppId", -1)).toString();
    const QUrl launcher = model.data(index, roles.key("LauncherUrlWithoutIcon", -1)).toUrl();
    const QString resolved = resolvedTaskDesktopId(rawId, launcher);
    if (!resolved.isEmpty()) return {resolved};
    const QString appId = normalizedApplicationId(rawId);
    if (!appId.isEmpty()) ids.append(appId);
    if (launcher.scheme() == QLatin1String("applications")
        || (launcher.isLocalFile() && launcher.fileName().endsWith(QLatin1String(".desktop")))) {
        const QString launcherId = normalizedApplicationId(launcher.fileName());
        if (!launcherId.isEmpty() && !ids.contains(launcherId)) ids.append(launcherId);
    }
    return ids;
}
