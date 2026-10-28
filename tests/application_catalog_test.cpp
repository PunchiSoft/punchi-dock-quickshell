// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QStandardItemModel>
#include "adapters/kde/native/applicationcatalog.h"

// The owned default browser and editor come from tests/application_catalog_test.py.
class ApplicationCatalogTest : public QObject {
    Q_OBJECT
    enum Role { App = Qt::UserRole+1, Desktop, Title, Icon, MimeTypes };
    static void initialize(QStandardItemModel &model) {
        model.setItemRoleNames({{App,"appId"},{Desktop,"desktopId"},{Title,"title"},{Icon,"iconName"},
            {MimeTypes,"defaultMimeTypes"}});
    }
    static void append(QStandardItemModel &model, QString id, QString desktop, QString title, QString icon,
        QString mimeTypes = {}) {
        auto *item = new QStandardItem;
        item->setData(id,App); item->setData(desktop,Desktop); item->setData(title,Title);
        item->setData(icon,Icon); item->setData(mimeTypes,MimeTypes); model.appendRow(item);
    }
private slots:
    void roleEntryResolvesToThePreferredApplication() {
        QStandardItemModel presets;
        initialize(presets);
        append(presets, "files", "punchi-catalog-editor", "Files", "system-file-manager");
        append(presets, "browser", "", "Browser", "internet-web-browser",
            "x-scheme-handler/https x-scheme-handler/http text/html");
        ApplicationCatalog catalog;
        catalog.setPresets(&presets);
        const auto browser = catalog.application("browser");
        QCOMPARE(browser.value("desktopId").toString(), QStringLiteral("punchi-catalog-browser.desktop"));
        QCOMPARE(browser.value("installed").toBool(), true);
        QCOMPARE(browser.value("title").toString(), QStringLiteral("Browser"));
        QCOMPARE(browser.value("name").toString(), QStringLiteral("Owned Catalog Browser"));
        QCOMPARE(browser.value("appIconName").toString(), QStringLiteral("punchi-catalog-browser"));
        // A role entry shows the application that answers it.
        QCOMPARE(browser.value("iconName").toString(), QStringLiteral("punchi-catalog-browser"));
        // An item that names a desktop entry keeps the profile's own icon.
        const auto files = catalog.application("files");
        QCOMPARE(files.value("desktopId").toString(), QStringLiteral("punchi-catalog-editor.desktop"));
        QCOMPARE(files.value("iconName").toString(), QStringLiteral("system-file-manager"));
        // The resolved default is not offered a second time by the picker.
        QVERIFY(catalog.application("desktop:punchi-catalog-browser.desktop").isEmpty());
    }
    void roleEntryFallsBackToTheNextMimeType() {
        QStandardItemModel presets;
        initialize(presets);
        append(presets, "browser", "", "Browser", "internet-web-browser",
            "application/x-punchi-unclaimed x-scheme-handler/https");
        ApplicationCatalog catalog;
        catalog.setPresets(&presets);
        const auto browser = catalog.application("browser");
        QCOMPARE(browser.value("desktopId").toString(), QStringLiteral("punchi-catalog-browser.desktop"));
        QCOMPARE(browser.value("installed").toBool(), true);
    }
    void unavailableRoleKeepsThePresetIcon() {
        QStandardItemModel presets;
        initialize(presets);
        append(presets, "browser", "", "Browser", "internet-web-browser", "application/x-punchi-unclaimed");
        ApplicationCatalog catalog;
        catalog.setPresets(&presets);
        const auto browser = catalog.application("browser");
        QVERIFY(browser.value("desktopId").toString().isEmpty());
        QCOMPARE(browser.value("installed").toBool(), false);
        QCOMPARE(browser.value("title").toString(), QStringLiteral("Browser"));
        QCOMPARE(browser.value("iconName").toString(), QStringLiteral("internet-web-browser"));
    }
    void malformedMimeTypesAreIgnored() {
        QStandardItemModel presets;
        initialize(presets);
        append(presets, "browser", "", "Browser", "internet-web-browser",
            "not-a-mime-type x-scheme-handler/https;text/html");
        ApplicationCatalog catalog;
        catalog.setPresets(&presets);
        const auto browser = catalog.application("browser");
        QVERIFY(browser.value("desktopId").toString().isEmpty());
        QCOMPARE(browser.value("installed").toBool(), false);
    }
};
QTEST_GUILESS_MAIN(ApplicationCatalogTest)
#include "application_catalog_test.moc"
