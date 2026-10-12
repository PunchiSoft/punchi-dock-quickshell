// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <KService>
#include <QRegularExpression>

inline bool isValidDesktopId(const QString &desktopId)
{
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,254}$"));
    return pattern.match(desktopId).hasMatch();
}

inline KService::Ptr resolveDesktopApplication(const QString &desktopId)
{
    if (!isValidDesktopId(desktopId)) return {};
    const auto service = KService::serviceByStorageId(desktopId.endsWith(QLatin1String(".desktop"))
        ? desktopId : desktopId + QStringLiteral(".desktop"));
    return service && service->isValid() && service->isApplication() && !service->exec().isEmpty()
        ? service : KService::Ptr();
}
