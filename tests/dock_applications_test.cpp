// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QStandardItemModel>
#include <QAbstractItemModelTester>
#include "adapters/kde/native/dockapplicationsmodel.h"

class DockApplicationsTest : public QObject {
    Q_OBJECT
    enum Role { App = Qt::UserRole+1, Desktop, Title, Icon, Installed };
    static void initialize(QStandardItemModel &model) {
        model.setItemRoleNames({{App,"appId"},{Desktop,"desktopId"},{Title,"title"},{Icon,"iconName"},{Installed,"installed"}});
    }
    static void append(QStandardItemModel &model, QString id, QString desktop, bool installed=true) {
        auto *item=new QStandardItem;
        item->setData(id,App); item->setData(desktop,Desktop); item->setData(id,Title);
        item->setData("application-x-executable",Icon); item->setData(installed,Installed); model.appendRow(item);
    }
    static void appendRecent(QStandardItemModel &model, const QString &storageId, const QString &name,
        const QString &icon) {
        auto *item = new QStandardItem;
        item->setData(storageId, Qt::UserRole + 1);
        item->setData(name, Qt::UserRole + 2);
        item->setData(icon, Qt::UserRole + 3);
        model.appendRow(item);
    }
    static void initializeRecent(QStandardItemModel &model) {
        model.setItemRoleNames({{Qt::UserRole + 1, "storageId"}, {Qt::UserRole + 2, "name"},
            {Qt::UserRole + 3, "icon"}});
    }
private slots:
    void pinsRunningMutationAndSourceLifetime() {
        QStandardItemModel pins, catalog; initialize(pins); initialize(catalog);
        append(pins,"files","org.kde.dolphin.desktop");
        append(catalog,"files","org.kde.dolphin.desktop");
        append(catalog,"browser","org.mozilla.firefox.desktop");
        append(catalog,"kate","org.kde.kate.desktop");
        append(catalog,"duplicate-browser","org.mozilla.firefox.desktop");
        append(catalog,"hidden","hidden.desktop",false);
        DockApplicationsModel dock;
        QAbstractItemModelTester tester(&dock,QAbstractItemModelTester::FailureReportingMode::QtTest);
        QSignalSpy resets(&dock,&QAbstractItemModel::modelReset);
        dock.setPinned(&pins); dock.setCatalog(&catalog);
        dock.setRunningDesktopIds({"org.mozilla.firefox","org.kde.dolphin","hidden","unknown","../invalid"});
        QTRY_COMPARE(dock.rowCount(),2);
        QCOMPARE(dock.get(0).value("appId").toString(),"files");
        QCOMPARE(dock.get(1).value("appId").toString(),"browser");
        QPersistentModelIndex browser(dock.index(1));
        append(pins,"kate","org.kde.kate.desktop");
        QTRY_COMPARE(dock.rowCount(),3);
        QCOMPARE(browser.row(),2); QCOMPARE(browser.data(DockApplicationsModel::AppId).toString(),"browser");
        pins.removeRow(0);
        QTRY_COMPARE(dock.get(0).value("appId").toString(),"kate");
        QCOMPARE(dock.rowCount(),3); // Unpinned but running Files remains transient.
        dock.setRunningDesktopIds({"org.kde.dolphin"});
        QTRY_COMPARE(dock.rowCount(),2); QVERIFY(!browser.isValid());
        catalog.item(0)->setData("Native updated name",Title);
        QTRY_COMPARE(dock.get(1).value("title").toString(),"Native updated name");
        dock.setRunningDesktopIds({}); QTRY_COMPARE(dock.rowCount(),1);
        QCOMPARE(dock.get(0).value("appId").toString(),"kate"); QCOMPARE(resets.count(),0);
        auto *temporary=new QStandardItemModel; initialize(*temporary); append(*temporary,"temporary","temporary.desktop");
        dock.setPinned(temporary); QTRY_COMPARE(dock.get(0).value("appId").toString(),"temporary");
        delete temporary; QTRY_COMPARE(dock.rowCount(),0);
    }
    void recentRowsAreDeduplicatedAndAppendedBeforeSpecials() {
        QStandardItemModel pins, catalog, recent;
        initialize(pins); initialize(catalog); initializeRecent(recent);
        append(pins, "files", "org.kde.dolphin.desktop");
        append(catalog, "files", "org.kde.dolphin.desktop");
        append(catalog, "browser", "org.mozilla.firefox.desktop");
        appendRecent(recent, "org.kde.dolphin.desktop", "Dolphin recent", "folder");
        appendRecent(recent, "org.kde.kate.desktop", "Kate recent", "kate");
        appendRecent(recent, "org.kde.kate.desktop", "Kate duplicate", "kate-duplicate");
        DockApplicationsModel dock;
        QAbstractItemModelTester tester(&dock, QAbstractItemModelTester::FailureReportingMode::QtTest);
        dock.setPinned(&pins);
        dock.setCatalog(&catalog);
        dock.setRecent(&recent);
        dock.setRunningDesktopIds({"org.mozilla.firefox"});
        QTRY_COMPARE(dock.rowCount(), 3);
        QCOMPARE(dock.get(0).value("appId").toString(), "files");
        QCOMPARE(dock.get(1).value("appId").toString(), "browser");
        QCOMPARE(dock.get(2).value("appId").toString(), "desktop:org.kde.kate.desktop");
        QCOMPARE(dock.get(2).value("title").toString(), "Kate recent");
        QCOMPARE(dock.get(2).value("iconName").toString(), "kate");
        recent.removeRows(1, 2);
        QTRY_COMPARE(dock.rowCount(), 2);
    }
    void recentContainerReplacesTheResolvedRows() {
        QStandardItemModel pins, catalog, recent;
        initialize(pins); initialize(catalog); initializeRecent(recent);
        append(pins, "files", "org.kde.dolphin.desktop");
        append(pins, "item:trash", "");
        append(catalog, "files", "org.kde.dolphin.desktop");
        appendRecent(recent, "org.kde.kate.desktop", "Kate recent", "kate");
        appendRecent(recent, "org.kde.gwenview.desktop", "Gwenview recent", "gwenview");
        DockApplicationsModel dock;
        QAbstractItemModelTester tester(&dock, QAbstractItemModelTester::FailureReportingMode::QtTest);
        dock.setPinned(&pins);
        dock.setCatalog(&catalog);
        dock.setRecent(&recent);
        dock.setRecentContainerTitle("Recent applications");
        dock.setRecentContainerIcon("folder-temp");
        QSignalSpy changes(&dock, &DockApplicationsModel::recentContainerChanged);
        dock.setRecentContainer(true);
        QCOMPARE(changes.count(), 1);
        // One item stands for both entries, before the trailing special items.
        QTRY_COMPARE(dock.rowCount(), 3);
        QCOMPARE(dock.get(0).value("appId").toString(), "files");
        QCOMPARE(dock.get(1).value("appId").toString(), "item:recent");
        QCOMPARE(dock.get(1).value("desktopId").toString(), QString());
        QCOMPARE(dock.get(1).value("title").toString(), "Recent applications");
        QCOMPARE(dock.get(1).value("iconName").toString(), "folder-temp");
        QCOMPARE(dock.get(2).value("appId").toString(), "item:trash");
        dock.setRecentContainerIcon("view-history");
        QTRY_COMPARE(dock.get(1).value("iconName").toString(), "view-history");
        // An empty history keeps the dock unchanged in both presentations.
        recent.removeRows(0, 2);
        QTRY_COMPARE(dock.rowCount(), 2);
        QCOMPARE(dock.get(1).value("appId").toString(), "item:trash");
        appendRecent(recent, "org.kde.kate.desktop", "Kate recent", "kate");
        QTRY_COMPARE(dock.rowCount(), 3);
        // Returning to icons restores one row per resolved application.
        dock.setRecentContainer(false);
        QTRY_COMPARE(dock.get(1).value("appId").toString(), "desktop:org.kde.kate.desktop");
        QCOMPARE(dock.rowCount(), 3);
        QCOMPARE(dock.get(2).value("appId").toString(), "item:trash");
    }
};
QTEST_GUILESS_MAIN(DockApplicationsTest)
#include "dock_applications_test.moc"
