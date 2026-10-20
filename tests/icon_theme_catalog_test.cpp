// SPDX-License-Identifier: GPL-3.0-or-later
#include "adapters/kde/native/iconthemecatalog.h"
#include <QDir>
#include <QFile>
#include <QLoggingCategory>
#include <QTemporaryDir>
#include <QTest>

// Mirrors the category Qt uses while painting a theme asset. The prefix is what
// the picker folds, so an owned sub-category exercises the same branch.
Q_LOGGING_CATEGORY(svgWarning, "qt.svg.owned", QtWarningMsg)

namespace {
QStringList recordedMessages;

void recordMessage(QtMsgType, const QMessageLogContext &, const QString &message)
{
    recordedMessages.append(message);
}

// Builds an owned theme so the scan never depends on the icons installed on the
// machine running the test.
bool writeIcon(const QString &path, const QString &entry)
{
    QFile icon(path + QStringLiteral("/apps/48/") + entry);
    if (!icon.open(QIODevice::WriteOnly)) return false;
    return icon.write("<svg xmlns=\"http://www.w3.org/2000/svg\"/>\n") > 0;
}

bool writeTheme(const QString &path, const QStringList &entries)
{
    if (!QDir().mkpath(path + QStringLiteral("/apps/48"))) return false;
    QFile index(path + QStringLiteral("/index.theme"));
    if (!index.open(QIODevice::WriteOnly)) return false;
    index.write("[Icon Theme]\n"
                "Name=Owned\n"
                "Directories=apps/48\n"
                "\n"
                "[apps/48]\n"
                "Size=48\n"
                "Type=Fixed\n"
                "Context=Applications\n");
    index.close();
    for (const auto &entry : entries)
        if (!writeIcon(path, entry)) return false;
    return true;
}
}

class IconThemeCatalogTest : public QObject
{
    Q_OBJECT
private slots:
    void reusesTheScanOfAnUnchangedTheme();
    void rescansWhenTheThemeGainsAnIcon();
    void reportsAnUnparsableIconWarningOnce();
};

void IconThemeCatalogTest::reusesTheScanOfAnUnchangedTheme()
{
    QTemporaryDir owned;
    QVERIFY(owned.isValid());
    const QString iconsPath = owned.path() + QStringLiteral("/icons");
    const QString themePath = iconsPath + QStringLiteral("/Owned");
    QVERIFY(writeTheme(themePath,
        {QStringLiteral("owned-one.svg"), QStringLiteral("owned-two.png")}));

    const auto scanned = IconThemeCatalog::buildSnapshot(QStringLiteral("Owned"), {iconsPath});
    QCOMPARE(scanned.names,
        QStringList({QStringLiteral("owned-one"), QStringLiteral("owned-two")}));
    QCOMPARE(scanned.rowContexts,
        QStringList({QStringLiteral("Applications"), QStringLiteral("Applications")}));
    QCOMPARE(scanned.contextNames, QStringList({QStringLiteral("Applications")}));
    QVERIFY(!scanned.cached);

    // The second run reuses the entry the first one wrote.
    const auto reused = IconThemeCatalog::buildSnapshot(QStringLiteral("Owned"), {iconsPath});
    QVERIFY(reused.cached);
    QCOMPARE(reused.names, scanned.names);
    QCOMPARE(reused.rowContexts, scanned.rowContexts);
    QCOMPARE(reused.contextNames, scanned.contextNames);
}

void IconThemeCatalogTest::rescansWhenTheThemeGainsAnIcon()
{
    QTemporaryDir owned;
    QVERIFY(owned.isValid());
    const QString iconsPath = owned.path() + QStringLiteral("/icons");
    const QString themePath = iconsPath + QStringLiteral("/Owned");
    QVERIFY(writeTheme(themePath, {QStringLiteral("owned-one.svg")}));
    const auto before = IconThemeCatalog::buildSnapshot(QStringLiteral("Owned"), {iconsPath});
    QCOMPARE(before.names.size(), 1);

    QVERIFY(writeIcon(themePath, QStringLiteral("owned-three.svg")));

    const auto after = IconThemeCatalog::buildSnapshot(QStringLiteral("Owned"), {iconsPath});
    QVERIFY(!after.cached);
    QVERIFY(after.names.contains(QStringLiteral("owned-three")));
}

void IconThemeCatalogTest::reportsAnUnparsableIconWarningOnce()
{
    recordedMessages.clear();
    const QtMessageHandler previous = qInstallMessageHandler(&recordMessage);
    {
        IconThemeCatalog catalog;
        // The picker paints the same asset once per visible tile.
        for (int paint = 0; paint < 5; ++paint)
            qCWarning(svgWarning, "<input>:1:17106: Could not resolve property: t");
        qCWarning(svgWarning, "<input>:1:1262: Could not resolve property: c");
        QCOMPARE(recordedMessages.size(), 2);
        QCOMPARE(recordedMessages.at(1),
            QStringLiteral("<input>:1:1262: Could not resolve property: c"));

        // Messages outside the SVG categories are never folded.
        qWarning("unrelated warning");
        QCOMPARE(recordedMessages.size(), 3);
    }
    // The final count is reported through the handler that was active before.
    QCOMPARE(recordedMessages.size(), 4);
    QVERIFY(recordedMessages.last().contains(QStringLiteral("4 repeated icon warnings suppressed")));
    qInstallMessageHandler(previous);
}

QTEST_GUILESS_MAIN(IconThemeCatalogTest)
#include "icon_theme_catalog_test.moc"
