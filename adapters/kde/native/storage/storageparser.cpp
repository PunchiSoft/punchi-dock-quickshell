// SPDX-License-Identifier: GPL-3.0-or-later
#include "storageparser.h"

#include <QDBusArgument>
#include <QDBusObjectPath>
#include <QHash>
#include <QStringList>

#include <algorithm>

namespace {
const QString kDriveInterface = QStringLiteral("org.freedesktop.UDisks2.Drive");
const QString kBlockInterface = QStringLiteral("org.freedesktop.UDisks2.Block");
const QString kFilesystemInterface = QStringLiteral("org.freedesktop.UDisks2.Filesystem");

QVariantMap objectInterfaces(const QVariant &value)
{
    if (value.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        QDBusArgument argument = value.value<QDBusArgument>();
        QVariantMap map;
        argument >> map;
        return map;
    }
    return value.toMap();
}

QString stringValue(const QVariant &value)
{
    if (value.metaType().id() == qMetaTypeId<QDBusObjectPath>())
        return value.value<QDBusObjectPath>().path();
    if (value.metaType().id() == QMetaType::QByteArray)
        return QString::fromUtf8(value.toByteArray());
    return value.toString();
}

QStringList mountPoints(const QVariant &value)
{
    QVariantList list = value.toList();
    if (value.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        QDBusArgument argument = value.value<QDBusArgument>();
        argument >> list;
    }
    QStringList points;
    for (const QVariant &entry : list) {
        const QString point = stringValue(entry);
        if (!point.isEmpty()) points.append(point);
    }
    return points;
}

QString baseName(const QString &path)
{
    const int slash = path.lastIndexOf(QLatin1Char('/'));
    return slash >= 0 ? path.mid(slash + 1) : path;
}
}

namespace PunchiStorage {

bool isRemovable(const QVariantMap &driveProperties)
{
    // UDisks2 exposes the removable hint of the drive and of its media; KDE's
    // device notifier filters with the same drive-level hints.
    return driveProperties.value(QStringLiteral("Removable")).toBool()
        || driveProperties.value(QStringLiteral("MediaRemovable")).toBool();
}

QVariantList drivesFromManagedObjects(const QVariantMap &managedObjects)
{
    struct DriveEntry {
        QString id;
        QVariantMap properties;
        QVariantList volumes;
    };
    QHash<QString, DriveEntry> drives;

    for (auto object = managedObjects.constBegin(); object != managedObjects.constEnd(); ++object) {
        const QVariantMap interfaces = objectInterfaces(object.value());
        if (interfaces.contains(kDriveInterface)) {
            const QVariantMap properties = objectInterfaces(interfaces.value(kDriveInterface));
            DriveEntry entry;
            entry.id = object.key();
            entry.properties = properties;
            drives.insert(entry.id, entry);
        }
    }

    for (auto object = managedObjects.constBegin(); object != managedObjects.constEnd(); ++object) {
        const QVariantMap interfaces = objectInterfaces(object.value());
        const QVariantMap block = objectInterfaces(interfaces.value(kBlockInterface));
        if (block.isEmpty()) continue;
        const QString driveId = stringValue(block.value(QStringLiteral("Drive")));
        if (driveId.isEmpty() || !drives.contains(driveId)) continue;
        if (stringValue(block.value(QStringLiteral("IdUsage"))) != QStringLiteral("filesystem"))
            continue;
        if (block.value(QStringLiteral("HintIgnore")).toBool()) continue;
        const QVariantMap filesystem = objectInterfaces(interfaces.value(kFilesystemInterface));
        const QStringList points = mountPoints(filesystem.value(QStringLiteral("MountPoints")));
        // A system device is never presented as removable storage, even when a
        // drive reports a removable hint.
        if (points.contains(QStringLiteral("/"))) continue;
        QString label = stringValue(block.value(QStringLiteral("IdLabel")));
        const QString device = stringValue(block.value(QStringLiteral("PreferredDevice")));
        if (label.isEmpty()) label = baseName(device);
        if (label.isEmpty()) label = baseName(object.key());
        QVariantMap volume;
        volume.insert(QStringLiteral("path"), object.key());
        volume.insert(QStringLiteral("label"), label);
        volume.insert(QStringLiteral("mounted"), !points.isEmpty());
        volume.insert(QStringLiteral("size"), block.value(QStringLiteral("Size")).toLongLong());
        drives[driveId].volumes.append(volume);
    }

    QVariantList result;
    for (auto drive = drives.begin(); drive != drives.end(); ++drive) {
        std::sort(drive->volumes.begin(), drive->volumes.end(),
            [](const QVariant &first, const QVariant &second) {
                const QVariantMap firstMap = first.toMap();
                const QVariantMap secondMap = second.toMap();
                const QString firstName = firstMap.value(QStringLiteral("label")).toString();
                const QString secondName = secondMap.value(QStringLiteral("label")).toString();
                if (firstName == secondName)
                    return firstMap.value(QStringLiteral("path")).toString()
                        < secondMap.value(QStringLiteral("path")).toString();
                return firstName < secondName;
            });
    }
    for (auto drive = drives.constBegin(); drive != drives.constEnd(); ++drive) {
        if (drive->volumes.isEmpty()) continue;
        if (!isRemovable(drive->properties)) continue;
        if (drive->properties.contains(QStringLiteral("MediaAvailable"))
                && !drive->properties.value(QStringLiteral("MediaAvailable")).toBool())
            continue;
        QString name = drive->properties.value(QStringLiteral("Vendor")).toString().trimmed();
        const QString model = drive->properties.value(QStringLiteral("Model")).toString().trimmed();
        if (!model.isEmpty()) name = name.isEmpty() ? model : name + QLatin1Char(' ') + model;
        if (name.isEmpty()) name = drive->properties.value(QStringLiteral("Id")).toString();
        if (name.isEmpty() && !drive->volumes.isEmpty())
            name = drive->volumes.first().toMap().value(QStringLiteral("label")).toString();
        int mounted = 0;
        for (const QVariant &volume : drive->volumes)
            if (volume.toMap().value(QStringLiteral("mounted")).toBool()) ++mounted;
        QVariantMap entry;
        entry.insert(QStringLiteral("id"), drive->id);
        entry.insert(QStringLiteral("name"), name);
        entry.insert(QStringLiteral("volumes"), drive->volumes);
        entry.insert(QStringLiteral("mountedCount"), mounted);
        entry.insert(QStringLiteral("ejectable"),
            drive->properties.value(QStringLiteral("Ejectable")).toBool());
        result.append(entry);
    }

    std::sort(result.begin(), result.end(), [](const QVariant &first, const QVariant &second) {
        const QString firstName = first.toMap().value(QStringLiteral("name")).toString();
        const QString secondName = second.toMap().value(QStringLiteral("name")).toString();
        if (firstName == secondName)
            return first.toMap().value(QStringLiteral("id")).toString()
                < second.toMap().value(QStringLiteral("id")).toString();
        return firstName < secondName;
    });
    return result;
}

QString classifyError(const QString &errorName)
{
    if (errorName.endsWith(QStringLiteral("DeviceBusy"))
            || errorName.endsWith(QStringLiteral("AlreadyUnmounting")))
        return QStringLiteral("busy");
    if (errorName.endsWith(QStringLiteral("NotMounted")))
        return QStringLiteral("not-mounted");
    if (errorName.endsWith(QStringLiteral("TimedOut")))
        return QStringLiteral("timeout");
    if (errorName.contains(QStringLiteral("NotAuthorized")))
        return QStringLiteral("rejected");
    return QStringLiteral("failed");
}
}
