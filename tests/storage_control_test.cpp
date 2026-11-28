// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QDBusObjectPath>

#include "storage/storageparser.h"

using namespace PunchiStorage;

namespace {
const QString kDrivePath = QStringLiteral("/org/freedesktop/UDisks2/drives/Kingston");
const QString kInternalPath = QStringLiteral("/org/freedesktop/UDisks2/drives/Internal");
const QString kBlockOne = QStringLiteral("/org/freedesktop/UDisks2/block_devices/sdb1");
const QString kBlockTwo = QStringLiteral("/org/freedesktop/UDisks2/block_devices/sdb2");
const QString kDriveInterface = QStringLiteral("org.freedesktop.UDisks2.Drive");
const QString kBlockInterface = QStringLiteral("org.freedesktop.UDisks2.Block");
const QString kFilesystemInterface = QStringLiteral("org.freedesktop.UDisks2.Filesystem");

QVariantMap driveObject(bool removable)
{
    QVariantMap properties;
    properties.insert(QStringLiteral("Removable"), removable);
    properties.insert(QStringLiteral("MediaRemovable"), removable);
    properties.insert(QStringLiteral("Ejectable"), true);
    properties.insert(QStringLiteral("MediaAvailable"), true);
    properties.insert(QStringLiteral("Vendor"), QStringLiteral("Kingston"));
    properties.insert(QStringLiteral("Model"), QStringLiteral("DataTraveler"));
    return {{kDriveInterface, properties}};
}

QVariantMap blockObject(const QString &drivePath, const QString &label,
    const QStringList &mountPoints, bool ignore = false)
{
    QVariantMap block;
    block.insert(QStringLiteral("Drive"), QVariant::fromValue(QDBusObjectPath(drivePath)));
    block.insert(QStringLiteral("IdUsage"), QStringLiteral("filesystem"));
    block.insert(QStringLiteral("IdLabel"), label);
    block.insert(QStringLiteral("PreferredDevice"),
        QByteArray("/dev/") + label.toUtf8());
    block.insert(QStringLiteral("Size"), qint64(32000000000));
    block.insert(QStringLiteral("HintIgnore"), ignore);
    QVariantMap filesystem;
    QVariantList points;
    for (const QString &point : mountPoints) points.append(point.toUtf8());
    filesystem.insert(QStringLiteral("MountPoints"), points);
    return {{kBlockInterface, block}, {kFilesystemInterface, filesystem}};
}
}

class StorageControlTest : public QObject
{
    Q_OBJECT
private slots:
    void removableDriveListsMountedVolumes();
    void internalDriveIsExcluded();
    void ignoredVolumeIsExcluded();
    void rootMountIsExcluded();
    void hiddenMountedVolumeBlocksWholeDriveRemoval();
    void rootMountedVolumeBlocksWholeDriveRemoval();
    void hiddenUnmountedVolumeDoesNotBlockWholeDriveRemoval();
    void providerConfirmationUsesEveryRelevantMount();
    void unavailableMediaIsExcluded();
    void unknownDriveBlockIsExcluded();
    void drivesKeepAStableOrder();
    void errorNamesMapToThePresentedCodes();
};

void StorageControlTest::removableDriveListsMountedVolumes()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Photos"),
        {QStringLiteral("/run/media/user/Photos")}));
    objects.insert(kBlockTwo, blockObject(kDrivePath, QStringLiteral("Backup"), {}));

    const QVariantList drives = drivesFromManagedObjects(objects);
    QCOMPARE(drives.size(), 1);
    const QVariantMap drive = drives.first().toMap();
    QCOMPARE(drive.value(QStringLiteral("name")).toString(),
        QStringLiteral("Kingston DataTraveler"));
    QCOMPARE(drive.value(QStringLiteral("mountedCount")).toInt(), 1);
    QCOMPARE(drive.value(QStringLiteral("ejectable")).toBool(), true);
    const QVariantList volumes = drive.value(QStringLiteral("volumes")).toList();
    QCOMPARE(volumes.size(), 2);
    // Volume labels keep a stable order inside a drive.
    QCOMPARE(volumes.first().toMap().value(QStringLiteral("label")).toString(),
        QStringLiteral("Backup"));
    QCOMPARE(volumes.last().toMap().value(QStringLiteral("mounted")).toBool(), true);
    QCOMPARE(volumes.last().toMap().value(QStringLiteral("path")).toString(), kBlockOne);
}

void StorageControlTest::internalDriveIsExcluded()
{
    QVariantMap objects;
    objects.insert(kInternalPath, driveObject(false));
    objects.insert(kBlockOne, blockObject(kInternalPath, QStringLiteral("Root"),
        {QStringLiteral("/")}));
    QVERIFY(drivesFromManagedObjects(objects).isEmpty());
}

void StorageControlTest::ignoredVolumeIsExcluded()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Hidden"), {}, true));
    QVERIFY(drivesFromManagedObjects(objects).isEmpty());
}

void StorageControlTest::rootMountIsExcluded()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Root"),
        {QStringLiteral("/")}));
    QVERIFY(drivesFromManagedObjects(objects).isEmpty());
}

void StorageControlTest::hiddenMountedVolumeBlocksWholeDriveRemoval()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Photos"), {}));
    objects.insert(kBlockTwo, blockObject(kDrivePath, QStringLiteral("Hidden"),
        {QStringLiteral("/run/media/user/Hidden")}, true));

    const QVariantList drives = drivesFromManagedObjects(objects);
    QCOMPARE(drives.size(), 1);
    const QVariantMap drive = drives.first().toMap();
    QCOMPARE(drive.value(QStringLiteral("volumes")).toList().size(), 1);
    QCOMPARE(drive.value(QStringLiteral("mountedCount")).toInt(), 1);
    QCOMPARE(drive.value(QStringLiteral("protectedMounted")).toBool(), true);
    QCOMPARE(drive.value(QStringLiteral("canRemove")).toBool(), false);
    QCOMPARE(confirmDriveRemoval(objects, kDrivePath), QStringLiteral("protected"));
}

void StorageControlTest::rootMountedVolumeBlocksWholeDriveRemoval()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Photos"), {}));
    objects.insert(kBlockTwo, blockObject(kDrivePath, QStringLiteral("System"),
        {QStringLiteral("/")}));

    const QVariantList drives = drivesFromManagedObjects(objects);
    QCOMPARE(drives.size(), 1);
    const QVariantMap drive = drives.first().toMap();
    QCOMPARE(drive.value(QStringLiteral("mountedCount")).toInt(), 1);
    QCOMPARE(drive.value(QStringLiteral("canRemove")).toBool(), false);
    QCOMPARE(confirmDriveRemoval(objects, kDrivePath), QStringLiteral("protected"));
}

void StorageControlTest::hiddenUnmountedVolumeDoesNotBlockWholeDriveRemoval()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Photos"),
        {QStringLiteral("/run/media/user/Photos")}));
    objects.insert(kBlockTwo, blockObject(kDrivePath, QStringLiteral("Hidden"), {}, true));

    const QVariantList drives = drivesFromManagedObjects(objects);
    QCOMPARE(drives.size(), 1);
    const QVariantMap drive = drives.first().toMap();
    QCOMPARE(drive.value(QStringLiteral("mountedCount")).toInt(), 1);
    QCOMPARE(drive.value(QStringLiteral("protectedMounted")).toBool(), false);
    QCOMPARE(drive.value(QStringLiteral("canRemove")).toBool(), true);
    QCOMPARE(confirmDriveRemoval(objects, kDrivePath), QStringLiteral("busy"));
}

void StorageControlTest::providerConfirmationUsesEveryRelevantMount()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Photos"), {}));
    objects.insert(kBlockTwo, blockObject(kDrivePath, QStringLiteral("Backup"),
        {QStringLiteral("/run/media/user/Backup")}));
    QCOMPARE(confirmDriveRemoval(objects, kDrivePath), QStringLiteral("busy"));

    objects.remove(kBlockTwo);
    QCOMPARE(confirmDriveRemoval(objects, kDrivePath), QStringLiteral("confirmed"));
    objects.remove(kDrivePath);
    QCOMPARE(confirmDriveRemoval(objects, kDrivePath), QStringLiteral("disconnected"));
}

void StorageControlTest::unavailableMediaIsExcluded()
{
    QVariantMap objects;
    QVariantMap drive = driveObject(true);
    QVariantMap properties = drive.value(kDriveInterface).toMap();
    properties.insert(QStringLiteral("MediaAvailable"), false);
    drive.insert(kDriveInterface, properties);
    objects.insert(kDrivePath, drive);
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Card"), {}));
    QVERIFY(drivesFromManagedObjects(objects).isEmpty());
}

void StorageControlTest::unknownDriveBlockIsExcluded()
{
    QVariantMap objects;
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Orphan"), {}));
    QVERIFY(drivesFromManagedObjects(objects).isEmpty());
}

void StorageControlTest::drivesKeepAStableOrder()
{
    QVariantMap objects;
    objects.insert(kDrivePath, driveObject(true));
    objects.insert(kBlockOne, blockObject(kDrivePath, QStringLiteral("Photos"), {}));
    QVariantMap second = driveObject(true);
    QVariantMap secondProperties = second.value(kDriveInterface).toMap();
    secondProperties.insert(QStringLiteral("Vendor"), QStringLiteral("SanDisk"));
    secondProperties.insert(QStringLiteral("Model"), QStringLiteral("Ultra"));
    second.insert(kDriveInterface, secondProperties);
    objects.insert(QStringLiteral("/org/freedesktop/UDisks2/drives/SanDisk"), second);
    objects.insert(kBlockTwo, blockObject(QStringLiteral("/org/freedesktop/UDisks2/drives/SanDisk"),
        QStringLiteral("Music"), {}));

    const QVariantList drives = drivesFromManagedObjects(objects);
    QCOMPARE(drives.size(), 2);
    QCOMPARE(drives.first().toMap().value(QStringLiteral("name")).toString(),
        QStringLiteral("Kingston DataTraveler"));
    QCOMPARE(drives.last().toMap().value(QStringLiteral("name")).toString(),
        QStringLiteral("SanDisk Ultra"));
}

void StorageControlTest::errorNamesMapToThePresentedCodes()
{
    QCOMPARE(classifyError(QStringLiteral("org.freedesktop.UDisks2.Error.DeviceBusy")),
        QStringLiteral("busy"));
    QCOMPARE(classifyError(QStringLiteral("org.freedesktop.UDisks2.Error.NotMounted")),
        QStringLiteral("not-mounted"));
    QCOMPARE(classifyError(QStringLiteral("org.freedesktop.UDisks2.Error.NotAuthorized")),
        QStringLiteral("rejected"));
    QCOMPARE(classifyError(QStringLiteral("org.freedesktop.UDisks2.Error.NotAuthorizedCanObtain")),
        QStringLiteral("rejected"));
    QCOMPARE(classifyError(QStringLiteral("org.freedesktop.UDisks2.Error.TimedOut")),
        QStringLiteral("timeout"));
    QCOMPARE(classifyError(QStringLiteral("org.freedesktop.UDisks2.Error.Failed")),
        QStringLiteral("failed"));
    QCOMPARE(classifyError(QStringLiteral("org.freedesktop.DBus.Error.NoReply")),
        QStringLiteral("failed"));
}

QTEST_GUILESS_MAIN(StorageControlTest)
#include "storage_control_test.moc"
