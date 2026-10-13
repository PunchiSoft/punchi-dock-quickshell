// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "taskidentity.h"
#include <QJsonObject>

bool supportsWindowActivation(const QAbstractItemModel *model);
QModelIndex applicationWindow(const QAbstractItemModel &model, const QString &desktopId);
QJsonObject activateWindowRequest(QAbstractItemModel *model, bool available, const QJsonObject &request);
