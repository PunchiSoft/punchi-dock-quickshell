// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QStandardItemModel>
#include <QAbstractItemModelTester>
#include "adapters/kde/native/applications/recentapplicationsmodel.h"

class RecentApplicationsModelTest : public QObject {
    Q_OBJECT
    enum Role { StorageId = Qt::UserRole + 1, Name, Icon };
    static void initialize(QStandardItemModel &model) {
        model.setItemRoleNames({{StorageId, "storageId"}, {Name, "name"}, {Icon, "icon"}});
    }
    static void append(QStandardItemModel &model, const QString &storageId, const QString &name) {
        auto *item = new QStandardItem;
        item->setData(storageId, StorageId);
        item->setData(name, Name);
        item->setData("application-x-executable", Icon);
        model.appendRow(item);
    }
private slots:
    void selectionOrderMaximumExclusionsAndMutations() {
        QStandardItemModel source;
        initialize(source);
        append(source, "org.kde.dolphin.desktop", "Dolphin");
        append(source, "org.kde.kate.desktop", "Kate");
        append(source, "org.kde.dolphin.desktop", "Dolphin duplicate");
        append(source, "org.kde.okular.desktop", "Okular");
        append(source, "org.kde.gwenview.desktop", "Gwenview");
        append(source, "org.kde.ark.desktop", "Ark");
        RecentApplicationsModel selection;
        QAbstractItemModelTester tester(&selection, QAbstractItemModelTester::FailureReportingMode::QtTest);
        selection.setSourceModel(&source);
        QCOMPARE(selection.count(), 0);
        selection.setEnabled(true);
        QCOMPARE(selection.count(), 5);
        QCOMPARE(selection.items().at(0).toMap().value("storageId").toString(), "org.kde.dolphin.desktop");
        selection.setMaximumItems(3);
        QCOMPARE(selection.count(), 3);
        QCOMPARE(selection.items().at(2).toMap().value("storageId").toString(), "org.kde.okular.desktop");
        selection.setExcludedStorageIds({"org.kde.kate.desktop"});
        QCOMPARE(selection.count(), 3);
        QCOMPARE(selection.items().at(1).toMap().value("storageId").toString(), "org.kde.okular.desktop");
        source.item(0)->setData("Dolphin renamed", Name);
        QCOMPARE(selection.items().at(0).toMap().value("name").toString(), "Dolphin renamed");
        selection.setEnabled(false);
        QCOMPARE(selection.count(), 0);
        selection.setEnabled(true);
        QCOMPARE(selection.count(), 3);
        selection.setSourceModel(nullptr);
        QCOMPARE(selection.count(), 0);
    }
    // The dock only receives application rows: a document or place row has no
    // application identity, even if the history query changes.
    void selectionKeepsApplicationRowsOnly() {
        QStandardItemModel source;
        initialize(source);
        append(source, "org.kde.dolphin.desktop", "Dolphin");
        append(source, QString(), "");
        append(source, "file:///home/user/report.pdf", "");
        append(source, "/home/user/Documents", "");
        append(source, "org/kde/path.desktop", "");
        append(source, "org.kde.kate.desktop", "Kate");
        RecentApplicationsModel selection;
        QAbstractItemModelTester tester(&selection, QAbstractItemModelTester::FailureReportingMode::QtTest);
        selection.setSourceModel(&source);
        selection.setEnabled(true);
        QCOMPARE(selection.count(), 2);
        const auto items = selection.items();
        QCOMPARE(items.at(0).toMap().value("storageId").toString(), "org.kde.dolphin.desktop");
        QCOMPARE(items.at(1).toMap().value("storageId").toString(), "org.kde.kate.desktop");
        for (const QVariant &item : items) {
            QCOMPARE(item.toMap().value("type").toString(), QStringLiteral("app"));
            QVERIFY(!item.toMap().value("storageId").toString().isEmpty());
        }
    }
    // The shared container views read the same rows: the selection publishes
    // entryName/entryIcon aliases instead of a QML copy of its entries.
    void selectionPublishesEntryAliases() {
        QStandardItemModel source;
        initialize(source);
        append(source, "org.kde.dolphin.desktop", "Dolphin");
        append(source, "org.kde.kate.desktop", "Kate");
        RecentApplicationsModel selection;
        QAbstractItemModelTester tester(&selection, QAbstractItemModelTester::FailureReportingMode::QtTest);
        selection.setSourceModel(&source);
        selection.setEnabled(true);
        QCOMPARE(selection.count(), 2);
        const auto roles = selection.roleNames();
        const int nameRole = roles.key("entryName", -1);
        const int iconRole = roles.key("entryIcon", -1);
        QVERIFY(nameRole >= 0);
        QVERIFY(iconRole >= 0);
        QCOMPARE(selection.index(0, 0).data(nameRole).toString(), "Dolphin");
        QCOMPARE(selection.index(0, 0).data(iconRole).toString(), "application-x-executable");
        const auto entry = selection.get(1);
        QCOMPARE(entry.value("entryName").toString(), "Kate");
        QCOMPARE(entry.value("entryIcon").toString(), "application-x-executable");
        QCOMPARE(entry.value("name").toString(), entry.value("entryName").toString());
        QCOMPARE(entry.value("icon").toString(), entry.value("entryIcon").toString());
    }
};
QTEST_GUILESS_MAIN(RecentApplicationsModelTest)
#include "recent_applications_model_test.moc"
