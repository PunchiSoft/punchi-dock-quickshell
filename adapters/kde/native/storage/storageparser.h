// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QVariantList>
#include <QVariantMap>
#include <QString>

// Pure parsing of the UDisks2 ObjectManager snapshot. The panel only lists
// removable drives with a filesystem volume, and it never derives an unmount
// or ejection from an internal or system device.
namespace PunchiStorage {
QVariantList drivesFromManagedObjects(const QVariantMap &managedObjects);
// Maps a UDisks2 error name to the small code set the panel presents.
QString classifyError(const QString &errorName);
bool isRemovable(const QVariantMap &driveProperties);
}
