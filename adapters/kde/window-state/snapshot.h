// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QAbstractItemModel>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QUrl>
#include <QRect>
#include <QIcon>
#include <QMap>
#include <QVariantMap>
#include "taskidentity.h"

inline QStringList runningDesktopIds(const QAbstractItemModel &model)
{
    QSet<QString> ids;
    const auto roles = model.roleNames();
    const int isWindow = roles.key("IsWindow", -1);
    const int skipTaskbar = roles.key("SkipTaskbar", -1);
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto index = model.index(row, 0);
        if (!model.data(index, isWindow).toBool()
            || model.data(index, skipTaskbar).toBool()) continue;
        for (const auto &id : taskApplicationIds(model, index, roles)) ids.insert(id);
    }
    QStringList sorted = ids.values();
    sorted.sort();
    return sorted;
}

// Preserve task-level application presentation when KDE has no visible
// desktop entry for a window (for example, an applet configuration dialog).
// Window titles and per-window identifiers intentionally stay out of this
// app-level snapshot.
inline QJsonArray runningApplicationEntries(const QAbstractItemModel &model)
{
    QMap<QString, QJsonObject> applications;
    const auto roles = model.roleNames();
    const int isWindow = roles.key("IsWindow", -1);
    const int skipTaskbar = roles.key("SkipTaskbar", -1);
    const int appName = roles.key("AppName", -1);
    const int decoration = Qt::DecorationRole;
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto index = model.index(row, 0);
        if (!model.data(index, isWindow).toBool() || model.data(index, skipTaskbar).toBool()) continue;
        QString name = appName >= 0 ? model.data(index, appName).toString().trimmed() : QString();
        name = name.left(128);
        QString iconName;
        if (decoration >= 0) iconName = model.data(index, decoration).value<QIcon>().name().left(128);
        for (const auto &id : taskApplicationIds(model, index, roles)) {
            if (applications.size() >= 256 && !applications.contains(id)) continue;
            auto entry = applications.value(id);
            entry.insert(QStringLiteral("desktopId"), id);
            if (entry.value(QStringLiteral("name")).toString().isEmpty() && !name.isEmpty())
                entry.insert(QStringLiteral("name"), name);
            if (entry.value(QStringLiteral("iconName")).toString().isEmpty() && !iconName.isEmpty())
                entry.insert(QStringLiteral("iconName"), iconName);
            applications.insert(id, entry);
        }
    }
    QJsonArray result;
    for (auto entry : applications) {
        if (entry.value(QStringLiteral("name")).toString().isEmpty())
            entry.insert(QStringLiteral("name"), entry.value(QStringLiteral("desktopId")));
        if (entry.value(QStringLiteral("iconName")).toString().isEmpty())
            entry.insert(QStringLiteral("iconName"), QStringLiteral("application-x-executable"));
        result.append(entry);
    }
    return result;
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

inline QByteArray windowStateSnapshot(bool available, const QStringList &ids = {},
    const QJsonObject &visibility = {}, const QJsonArray &applications = {})
{
    QJsonObject object{{QStringLiteral("version"), 1},
        {QStringLiteral("available"), available},
        {QStringLiteral("desktopIds"), QJsonArray::fromStringList(available ? ids : QStringList())}};
    if (available) object.insert(QStringLiteral("applications"), applications);
    if (!visibility.isEmpty()) object.insert(QStringLiteral("visibility"), visibility);
    return QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n';
}
