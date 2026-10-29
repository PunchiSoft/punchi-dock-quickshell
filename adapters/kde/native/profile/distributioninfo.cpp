// SPDX-License-Identifier: GPL-3.0-or-later
#include "distributioninfo.h"
#include <KOSRelease>

DistributionInfo::DistributionInfo(QObject *parent)
    : QObject(parent)
{
    const KOSRelease release;
    const QString pretty = release.prettyName().trimmed();
    m_name = pretty.isEmpty() ? release.name().trimmed() : pretty;
    m_logo = release.logo().trimmed();
}
