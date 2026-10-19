// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "taskidentity.h"
#include <QAbstractItemModel>
#include <QJsonObject>
#include <QVariantList>

QJsonObject windowActionsSnapshot(const QAbstractItemModel *model, bool available,
    const QVariantList &desktopIds, const QStringList &desktopNames, const QVariant &currentDesktop);
QJsonObject windowActionRequest(QAbstractItemModel *model, bool available,
    const QVariantList &desktopIds, const QJsonObject &request);
