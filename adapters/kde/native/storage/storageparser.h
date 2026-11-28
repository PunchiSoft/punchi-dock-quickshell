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
// Inspects every filesystem of a drive, including the volumes the panel hides.
// Returns "confirmed" only when no relevant mount remains, "protected" when a
// hidden or system volume is still mounted, "busy" when a visible volume is
// still mounted, and "disconnected" when the drive is no longer present.
QString confirmDriveRemoval(const QVariantMap &managedObjects, const QString &drivePath);
// Maps a UDisks2 error name to the small code set the panel presents.
QString classifyError(const QString &errorName);
bool isRemovable(const QVariantMap &driveProperties);
}
