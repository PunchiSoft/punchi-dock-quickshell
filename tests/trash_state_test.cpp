// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <KCoreDirLister>
#include <KFileItem>
#include <KJob>
#include <QStandardItemModel>
#include <QAbstractItemModelTester>
#include "adapters/kde/native/files/trashstate.h"
#include "adapters/kde/native/applications/dockitemcatalog.h"
#include "adapters/kde/native/applications/applicationcatalog.h"
#include "adapters/kde/native/applications/dockapplicationsmodel.h"

class OwnedLister : public KCoreDirLister {
    Q_OBJECT
public:
    void replace(bool full) {
        emit clear();
        if (full) add();
        emit completed();
    }
    void add() { emit itemsAdded(QUrl("trash:/"), {KFileItem(QUrl("trash:/owned-item"),"application/octet-stream",0100000)}); }
    void remove() { emit itemsDeleted({KFileItem(QUrl("trash:/owned-item"),"application/octet-stream",0100000)}); }
    void fail() { emit canceled(); }
};
class OwnedEmptyJob : public KJob {
public:
    void start() override {}
    void finish(bool success) { if (!success) { setError(1); setErrorText("Owned failure"); } emitResult(); }
};
class OwnedTrash : public TrashState {
public:
    OwnedLister *lister;
    OwnedEmptyJob *job = nullptr;
    int refreshes = 0, dispatched = 0;
    OwnedTrash() : TrashState(new OwnedLister, nullptr), lister(findChild<OwnedLister *>()) {}
    void refresh() override { ++refreshes; }
protected:
    KJob *createEmptyJob() override { ++dispatched; return job = new OwnedEmptyJob; }
};
class TrashStateTest : public QObject {
    Q_OBJECT
private slots:
    void specialMetadataIsTypedBeforeQmlBindings() {
        DockItemCatalog catalog;
        const auto trash = catalog.get(0);
        for (const char *field : {"appId", "desktopId", "title", "name", "description", "iconName", "appIconName"}) {
            const auto value = trash.value(QLatin1String(field));
            QVERIFY2(value.isValid(), field);
            QCOMPARE(value.metaType(), QMetaType::fromType<QString>());
        }
        QCOMPARE(trash.value("installed").metaType(), QMetaType::fromType<bool>());
        QCOMPARE(trash.value("title").toString(), QString());
        catalog.setTrashTitle("Owned translated title");
        QCOMPARE(catalog.get(0).value("title").toString(), "Owned translated title");
    }
    void nativeListingAndGuardedOwnedJobs() {
        OwnedTrash trash;
        QVERIFY(trash.lister);
        QVERIFY(trash.lister->showHiddenFiles());
        QSignalSpy changed(&trash,&TrashState::changed);
        QSignalSpy finished(&trash,&TrashState::operationFinished);
        QVERIFY(!trash.available()); QVERIFY(!trash.emptyAfterConfirmation());
        trash.lister->replace(false);
        QVERIFY(trash.available()); QVERIFY(!trash.hasItems()); QVERIFY(!trash.emptyAfterConfirmation());
        trash.lister->add(); QVERIFY(trash.hasItems());
        // Listing reloads must not flash an empty icon before completion.
        trash.lister->clear(); QVERIFY(trash.hasItems());
        trash.lister->add(); trash.lister->completed(); QVERIFY(trash.hasItems());
        QVERIFY(trash.emptyAfterConfirmation()); QVERIFY(trash.busy());
        QVERIFY(!trash.emptyAfterConfirmation()); QCOMPARE(trash.dispatched,1);
        trash.job->finish(true);
        QVERIFY(!trash.busy()); QCOMPARE(trash.refreshes,1);
        QVERIFY(trash.hasItems()); // Only the listing, not job success, owns icon state.
        QCOMPARE(finished.count(),1); QVERIFY(finished.first().first().toBool());
        trash.lister->remove(); QVERIFY(!trash.hasItems());
        trash.lister->replace(true);
        QVERIFY(trash.emptyAfterConfirmation()); trash.job->finish(false);
        QCOMPARE(finished.count(),2); QVERIFY(!finished.last().first().toBool());
        QCOMPARE(trash.refreshes,2); QVERIFY(trash.hasItems());
        trash.lister->fail(); QVERIFY(!trash.available()); QVERIFY(!trash.emptyAfterConfirmation());
        QVERIFY(changed.count()>0);
    }
    void specialCatalogIsReactiveOrderableAndNeverAnApplication() {
        QStandardItemModel apps, pins;
        apps.setItemRoleNames({{ApplicationCatalog::AppId,"appId"},{ApplicationCatalog::DesktopId,"desktopId"},
            {ApplicationCatalog::Title,"title"},{ApplicationCatalog::Icon,"iconName"},{ApplicationCatalog::Installed,"installed"}});
        auto *app=new QStandardItem;
        app->setData("files",ApplicationCatalog::AppId); app->setData("org.kde.dolphin.desktop",ApplicationCatalog::DesktopId);
        app->setData(true,ApplicationCatalog::Installed); apps.appendRow(app);
        DockItemCatalog catalog; catalog.setApplications(&apps); catalog.setTrashTitle("Owned Trash");
        QAbstractItemModelTester tester(&catalog,QAbstractItemModelTester::FailureReportingMode::QtTest);
        QCOMPARE(catalog.rowCount(),3);
        const auto trash=catalog.get(0);
        QCOMPARE(trash.value("appId").toString(),"item:trash"); QVERIFY(trash.value("desktopId").toString().isEmpty());
        QVERIFY(!trash.value("installed").toBool()); QVERIFY(catalog.application("item:trash").isEmpty());
        ApplicationSearchModel search; search.setSourceModel(&catalog); QCOMPARE(search.rowCount(),1);
        catalog.setTrashIconName("user-trash-full"); QCOMPARE(catalog.get(0).value("iconName").toString(),"user-trash-full");
        pins.setItemRoleNames(apps.roleNames());
        auto *pin=new QStandardItem;pin->setData("item:trash",ApplicationCatalog::AppId);pins.appendRow(pin);
        DockApplicationsModel dock;dock.setPinned(&pins);dock.setCatalog(&catalog);dock.setRunningDesktopIds({"org.kde.dolphin"});
        QTRY_COMPARE(dock.rowCount(),2); QCOMPARE(dock.get(1).value("appId").toString(),"item:trash");
        auto *filePin=app->clone(); pins.insertRow(1,filePin);
        QTRY_COMPARE(dock.get(0).value("appId").toString(),"item:trash"); // Explicitly moved before Files.
        QCOMPARE(dock.rowCount(),2);
    }
};
QTEST_GUILESS_MAIN(TrashStateTest)
#include "trash_state_test.moc"
