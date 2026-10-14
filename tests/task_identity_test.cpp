// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QStandardItemModel>
#include <QIcon>
#include "adapters/kde/window-state/snapshot.h"
#include "adapters/kde/window-state/windowactivation.h"
#include "adapters/kde/native/applicationcatalog.h"
#include "adapters/kde/native/dockapplicationsmodel.h"

class IdentityTasks : public QStandardItemModel {
    Q_OBJECT
public:
    enum Role { Window = Qt::UserRole+1, App, Launcher, Active, Minimized, Minimizable };
    int activated = -1, minimized = -1;
    IdentityTasks() {
        setItemRoleNames({{Window,"IsWindow"},{App,"AppId"},{Launcher,"LauncherUrlWithoutIcon"},
            {Active,"IsActive"},{Minimized,"IsMinimized"},{Minimizable,"IsMinimizable"}});
        auto *item = new QStandardItem;
        item->setData(true, Window); item->setData(true, Minimizable); appendRow(item);
    }
    Q_INVOKABLE void requestActivate(const QModelIndex &index) { activated = index.row(); }
    Q_INVOKABLE void requestToggleMinimized(const QModelIndex &index) { minimized = index.row(); }
};
class TaskIdentityTest : public QObject {
    Q_OBJECT
private slots:
    void exactMetadataAliasesAndAmbiguity() {
        const QString canonical = "punchi-owned-workstation";
        for (const QString &alias : {QString("punchi-owned-vmware"), QString("PUNCHI-OWNED-WMCLASS"),
                QString("Owned Workstation"), QString("punchi-owned-workstation.desktop")})
            QCOMPARE(resolvedTaskDesktopId(alias, {}), canonical);
        QCOMPARE(resolvedTaskDesktopId("", QUrl("file:///owned/bin/punchi-owned-vmware")), canonical);
        QCOMPARE(resolvedTaskDesktopId("unknown", QUrl("applications:punchi-owned-workstation.desktop")), canonical);
        QVERIFY(resolvedTaskDesktopId("owned-shared-runner", {}).isEmpty());
        QVERIFY(resolvedTaskDesktopId("owned-duplicate-name", {}).isEmpty());
        QVERIFY(resolvedTaskDesktopId("punchi-owned-vmware-vmx", {}).isEmpty());
        QVERIFY(resolvedTaskDesktopId("punchi-owned", {}).isEmpty());
        QVERIFY(resolvedTaskDesktopId("../punchi-owned-vmware", {}).isEmpty());
        QVERIFY(resolvedTaskDesktopId("env", {}).isEmpty());
        QVERIFY(resolvedTaskDesktopId("", QUrl("https://example.invalid/punchi-owned-vmware")).isEmpty());
    }
    void sameIdentityFeedsListingMarkerAndActivation() {
        IdentityTasks tasks;
        tasks.item(0)->setData("punchi-owned-vmware", IdentityTasks::App);
        const auto ids = runningDesktopIds(tasks);
        QCOMPARE(ids, QStringList{"punchi-owned-workstation"});
        ApplicationCatalog catalog;
        QTRY_VERIFY(catalog.rowCount() > 0);
        QStandardItemModel pins;
        DockApplicationsModel dock; dock.setPinned(&pins); dock.setCatalog(&catalog); dock.setRunningDesktopIds(ids);
        QTRY_COMPARE(dock.rowCount(), 1);
        QCOMPARE(dock.get(0).value("desktopId").toString(), "punchi-owned-workstation.desktop");
        QJsonObject request{{"version",1},{"type","activate"},{"requestId",1},{"desktopId","punchi-owned-workstation.desktop"}};
        QCOMPARE(activateWindowRequest(&tasks, true, request).value("status").toString(), "activated");
        QCOMPARE(tasks.activated, 0);
        tasks.item(0)->setData(true, IdentityTasks::Active);
        QCOMPARE(activateWindowRequest(&tasks, true, request).value("status").toString(), "minimized");
        QCOMPARE(tasks.minimized, 0);
        // Native launcher metadata is authoritative over a conflicting alias.
        tasks.item(0)->setData(QUrl("applications:punchi-owned-alternative.desktop"), IdentityTasks::Launcher);
        QCOMPARE(runningDesktopIds(tasks), QStringList{"punchi-owned-alternative"});
        QCOMPARE(activateWindowRequest(&tasks, true, request).value("status").toString(), "not-found");
        dock.setRunningDesktopIds({}); QTRY_COMPARE(dock.rowCount(), 0);
    }
    void taskMetadataAddsRunningWindowsWithoutVisibleDesktopEntries() {
        const QString desktopId = QStringLiteral("punchi-unlisted-plasmoid-settings");
        QStandardItemModel tasks;
        tasks.setItemRoleNames({{Qt::UserRole + 1, "IsWindow"}, {Qt::UserRole + 2, "SkipTaskbar"},
            {Qt::UserRole + 3, "AppId"}, {Qt::UserRole + 4, "LauncherUrlWithoutIcon"},
            {Qt::UserRole + 5, "AppName"}});
        auto *window = new QStandardItem;
        window->setData(true, Qt::UserRole + 1);
        window->setData(false, Qt::UserRole + 2);
        window->setData(desktopId, Qt::UserRole + 3);
        window->setData(QStringLiteral("Plasma Applet Settings"), Qt::UserRole + 5);
        window->setData(QIcon::fromTheme(QStringLiteral("preferences-system-windows")), Qt::DecorationRole);
        tasks.appendRow(window);

        const auto entries = runningApplicationEntries(tasks);
        QCOMPARE(entries.size(), 1);
        QCOMPARE(entries.first().toObject().value(QStringLiteral("desktopId")).toString(), desktopId);
        QCOMPARE(entries.first().toObject().value(QStringLiteral("name")).toString(),
            QStringLiteral("Plasma Applet Settings"));
        QCOMPARE(entries.first().toObject().value(QStringLiteral("iconName")).toString(),
            QStringLiteral("preferences-system-windows"));

        QStandardItemModel pins, catalog;
        DockApplicationsModel dock;
        dock.setPinned(&pins);
        dock.setCatalog(&catalog);
        dock.setRunningDesktopIds({desktopId});
        dock.setRunningApplications({QVariantMap{{QStringLiteral("desktopId"), desktopId},
            {QStringLiteral("name"), QStringLiteral("Plasma Applet Settings")},
            {QStringLiteral("iconName"), QStringLiteral("preferences-system-windows")}}});
        QTRY_COMPARE(dock.rowCount(), 1);
        const auto entry = dock.get(0);
        QCOMPARE(entry.value(QStringLiteral("appId")).toString(),
            QStringLiteral("desktop:punchi-unlisted-plasmoid-settings.desktop"));
        QCOMPARE(entry.value(QStringLiteral("desktopId")).toString(), desktopId + QStringLiteral(".desktop"));
        QCOMPARE(entry.value(QStringLiteral("title")).toString(), QStringLiteral("Plasma Applet Settings"));
        QCOMPARE(entry.value(QStringLiteral("iconName")).toString(), QStringLiteral("preferences-system-windows"));

        // Once pinned, its stable configured row replaces the transient copy.
        pins.setItemRoleNames({{Qt::UserRole + 1, "appId"}, {Qt::UserRole + 2, "desktopId"},
            {Qt::UserRole + 3, "title"}, {Qt::UserRole + 4, "iconName"}});
        auto *pinned = new QStandardItem;
        pinned->setData(QStringLiteral("desktop:punchi-unlisted-plasmoid-settings.desktop"), Qt::UserRole + 1);
        pinned->setData(desktopId + QStringLiteral(".desktop"), Qt::UserRole + 2);
        pinned->setData(QStringLiteral("Pinned settings"), Qt::UserRole + 3);
        pinned->setData(QStringLiteral("configure"), Qt::UserRole + 4);
        pins.appendRow(pinned);
        QTRY_COMPARE(dock.get(0).value(QStringLiteral("title")).toString(), QStringLiteral("Pinned settings"));
        dock.setRunningDesktopIds({});
        dock.setRunningApplications({});
        QTRY_COMPARE(dock.rowCount(), 1);
    }
};
QTEST_MAIN(TaskIdentityTest)
#include "task_identity_test.moc"
