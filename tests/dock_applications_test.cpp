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
};
QTEST_GUILESS_MAIN(DockApplicationsTest)
#include "dock_applications_test.moc"
