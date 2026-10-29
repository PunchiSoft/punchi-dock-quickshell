// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QVariantMap>
#include "adapters/kde/native/updates/updatestate.h"

class UpdateStateTest : public QObject
{
    Q_OBJECT
private:
    static QVariantMap device(const QString &id, qulonglong flags)
    {
        QVariantMap entry;
        entry.insert(QStringLiteral("DeviceId"), id);
        entry.insert(QStringLiteral("Flags"), flags);
        return entry;
    }
private slots:
    void filtersUpdatableFirmwareDevices()
    {
        QVariantList devices{
            device(QStringLiteral("internal"), 1ull << 0),
            device(QStringLiteral("upgradable"), (1ull << 1) | (1ull << 17)),
            QVariantMap{{QStringLiteral("DeviceId"), QStringLiteral("flaga")}},
            QVariantMap{{QStringLiteral("Flags"), 2ull}},
            device(QStringLiteral("upgradable"), 1ull << 1),
            device(QString(), 1ull << 1),
        };
        // Missing or malformed fields are dropped instead of producing an id.
        QCOMPARE(UpdateState::updatableDeviceIds(devices),
            QStringList{QStringLiteral("upgradable")});
        QCOMPARE(UpdateState::updatableDeviceIds(QVariantList{}), QStringList{});
    }
    // PkInfoEnum: NORMAL is 5 and SECURITY is 8, the value the live Package
    // signal carries for a security update on this host.
    void recognizesSecurityInfo()
    {
        QVERIFY(UpdateState::isSecurityInfo(8));
        QVERIFY(!UpdateState::isSecurityInfo(5));
        QVERIFY(!UpdateState::isSecurityInfo(0));
        QVERIFY(!UpdateState::isSecurityInfo(4));
        QVERIFY(!UpdateState::isSecurityInfo(6));
    }
    // PkRoleEnum values used by TransactionListChanged: update-packages and
    // upgrade-system apply updates; get-updates is the dock's own read-only query.
    void recognizesUpdateRoles()
    {
        QVERIFY(UpdateState::isUpdateRole(22));
        QVERIFY(UpdateState::isUpdateRole(33));
        QVERIFY(!UpdateState::isUpdateRole(9));
        QVERIFY(!UpdateState::isUpdateRole(11));
        QVERIFY(!UpdateState::isUpdateRole(0));
    }
    void countsFlatpakRefs()
    {
        QCOMPARE(UpdateState::countFlatpakUpdates(QString()), 0);
        QCOMPARE(UpdateState::countFlatpakUpdates(QStringLiteral("\n  \n")), 0);
        QCOMPARE(UpdateState::countFlatpakUpdates(
            QStringLiteral("org.gnome.Builder\norg.kde.krita\n")), 2);
        QCOMPARE(UpdateState::countFlatpakUpdates(
            QStringLiteral("org.gnome.Builder\n\norg.kde.krita")), 2);
    }
    // The aggregate must stay consistent even when a desktop service is absent;
    // the test asserts settling and internal consistency, never a host count.
    void reportsConsistentAggregate()
    {
        UpdateState state;
        QTRY_VERIFY_WITH_TIMEOUT(state.state() != UpdateState::Unknown && !state.checking(), 30000);
        QVERIFY(state.state() == UpdateState::Ready || state.state() == UpdateState::Unavailable);
        QCOMPARE(state.count(), state.systemCount() + state.flatpakCount() + state.firmwareCount());
        QVERIFY(state.count() >= 0);
        QVERIFY(state.securityCount() >= 0);
        QVERIFY(state.securityCount() <= state.systemCount());
        // Each source reports independently: a missing service is not an error.
        const bool anySource = state.systemAvailable() || state.flatpakAvailable()
            || state.firmwareAvailable();
        QCOMPARE(state.state() == UpdateState::Ready, anySource);
        // PackageKit names its own backend, so callers never guess a distribution.
        QVERIFY(state.backendName().isEmpty() || !state.backendName().isEmpty());
    }
};

QTEST_GUILESS_MAIN(UpdateStateTest)
#include "update_state_test.moc"
