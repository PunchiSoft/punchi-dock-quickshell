// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QAbstractItemModelTester>
#include <QFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <KIO/DeleteJob>
#include "adapters/kde/native/foldercontents.h"

class FolderContentsTest : public QObject {
    Q_OBJECT
    static void write(const QString &path) {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QVERIFY(file.write("Owned fixture.\n") > 0);
    }
private slots:
    void standardLocationsResolveThroughQt() {
        FolderContents contents;
        QCOMPARE(contents.homeUrl(),
            QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::HomeLocation)));
        QCOMPARE(contents.downloadsUrl(),
            QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)));
        QVERIFY(!contents.standardUserDirsOnly());
    }
    void nativeRowsWatchChangesAndCancel() {
        QTemporaryDir owned;
        QVERIFY(owned.isValid());
        write(owned.filePath("first.txt"));
        write(owned.filePath(".hidden"));
        QVERIFY(QDir(owned.path()).mkdir("nested"));
        FolderContents contents;
        QAbstractItemModelTester tester(&contents, QAbstractItemModelTester::FailureReportingMode::QtTest);
        FolderEntriesModel grid;
        grid.setContents(&contents);
        QAbstractItemModelTester gridTester(&grid, QAbstractItemModelTester::FailureReportingMode::QtTest);
        contents.setLocation(QUrl::fromLocalFile(owned.path()));
        QCOMPARE(contents.count(), 0);
        contents.setActive(true);
        QTRY_VERIFY(!contents.loading());
        QCOMPARE(contents.error(), QString());
        QCOMPARE(contents.count(), 2);
        QCOMPARE(grid.rowCount(), 3);
        QVERIFY(grid.data(grid.index(2, 0), FolderEntriesModel::LocationAction).toBool());
        QVERIFY(!grid.data(grid.index(0, 0), FolderEntriesModel::LocationAction).toBool());
        const auto firstUrl = QUrl::fromLocalFile(owned.filePath("first.txt"));
        const auto first = contents.indexOfUrl(firstUrl);
        QVERIFY(first >= 0);
        QCOMPARE(contents.get(first).value("entryName").toString(), "first.txt");
        QCOMPARE(contents.sortMode(), "modified");
        contents.setSortMode("invalid");
        QCOMPARE(contents.sortMode(), "modified");
        contents.setSortMode("name");
        QCOMPARE(contents.sortMode(), "name");
        contents.setSortMode("created");
        QCOMPARE(contents.sortMode(), "created");
        contents.setSortMode("kind");
        QCOMPARE(contents.sortMode(), "kind");
        contents.setSortMode("modified");
        QVERIFY(!contents.get(first).value("description").toString().isEmpty());
        QVERIFY(!contents.itemForUrl(firstUrl).isNull());
        QVERIFY(contents.itemForUrl(QUrl::fromLocalFile(owned.filePath(".hidden"))).isNull());
        QVERIFY(contents.itemForUrl(QUrl("https://example.invalid/file")).isNull());
        const auto revision = contents.revision();
        write(owned.filePath("added.txt"));
        QTRY_COMPARE(contents.count(), 3);
        QVERIFY(contents.revision() > revision);
        QCOMPARE(grid.rowCount(), 4);
        QVERIFY(QFile::rename(owned.filePath("first.txt"), owned.filePath("renamed.txt")));
        QTRY_VERIFY(contents.indexOfUrl(firstUrl) < 0);
        const auto renamed = QUrl::fromLocalFile(owned.filePath("renamed.txt"));
        QTRY_VERIFY(contents.indexOfUrl(renamed) >= 0);
        // KDE file operations notify the native directory cache as well as
        // changing the filesystem; exercise that contract with an owned file.
        int deleteError = -1;
        QObject completionContext;
        auto *removal = KIO::del(QUrl::fromLocalFile(owned.filePath("added.txt")), KIO::HideProgressInfo);
        removal->setUiDelegate(nullptr);
        connect(removal, &KJob::result, &completionContext, [&deleteError](KJob *job) { deleteError = job->error(); });
        QTRY_COMPARE(deleteError, 0);
        QTRY_COMPARE(contents.count(), 2);
        contents.setActive(false);
        QVERIFY(!contents.loading());
        QVERIFY(contents.itemForUrl(renamed).isNull());
        write(owned.filePath("closed.txt"));
        contents.setActive(true);
        QTRY_VERIFY(!contents.loading());
        QTRY_COMPARE(contents.count(), 3);
        contents.setLocation(QUrl::fromLocalFile(owned.filePath("nested")));
        contents.setActive(false);
        QVERIFY(!contents.loading());
    }
    void sortsFilesBySizeLargestFirst() {
        QTemporaryDir owned;
        QVERIFY(owned.isValid());
        const auto writeSized = [&owned](const QString &name, qsizetype size) {
            QFile file(owned.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
            QCOMPARE(file.write(QByteArray(size, 'x')), size);
        };
        writeSized("small.txt", 1);
        writeSized("medium.pdf", 10);
        writeSized("large.txt", 100);

        FolderContents contents;
        contents.setLocation(QUrl::fromLocalFile(owned.path()));
        contents.setActive(true);
        QTRY_VERIFY(!contents.loading());
        QCOMPARE(contents.count(), 3);
        contents.setSortMode("size");
        QCOMPARE(contents.sortMode(), "size");
        QCOMPARE(contents.get(0).value("entryName").toString(), "large.txt");
        QCOMPARE(contents.get(1).value("entryName").toString(), "medium.pdf");
        QCOMPARE(contents.get(2).value("entryName").toString(), "small.txt");
        contents.setActive(false);
    }
    void hiddenNamesFilterTheListingWithoutHidingThemFromSettings() {
        QTemporaryDir owned;
        QVERIFY(owned.isValid());
        write(owned.filePath("keep.txt"));
        write(owned.filePath("skip.txt"));
        QVERIFY(QDir(owned.path()).mkdir("nested"));

        FolderContents contents;
        QAbstractItemModelTester tester(&contents, QAbstractItemModelTester::FailureReportingMode::QtTest);
        FolderEntriesModel grid;
        grid.setContents(&contents);
        contents.setLocation(QUrl::fromLocalFile(owned.path()));
        contents.setActive(true);
        QTRY_VERIFY(!contents.loading());
        QCOMPARE(contents.count(), 3);
        QCOMPARE(grid.rowCount(), 4);

        contents.setHiddenEntries({QStringLiteral("skip.txt")});
        QCOMPARE(contents.hiddenEntries(), QStringList({QStringLiteral("skip.txt")}));
        QCOMPARE(contents.count(), 2);
        QCOMPARE(grid.rowCount(), 3);
        for (int row = 0; row < contents.count(); ++row)
            QVERIFY(contents.get(row).value("entryName").toString() != "skip.txt");
        QVERIFY(contents.indexOfUrl(QUrl::fromLocalFile(owned.filePath("skip.txt"))) < 0);
        QVERIFY(contents.indexOfUrl(QUrl::fromLocalFile(owned.filePath("keep.txt"))) >= 0);

        // Names that could leave the folder are refused instead of stored.
        contents.setHiddenEntries({QStringLiteral("../keep.txt"), QStringLiteral(""),
            QStringLiteral(".."), QStringLiteral("keep.txt"), QStringLiteral("keep.txt")});
        QCOMPARE(contents.hiddenEntries(), QStringList({QStringLiteral("keep.txt")}));
        QCOMPARE(contents.count(), 2);

        // A cleared list shows everything again, so new files need no new choice.
        contents.setHiddenEntries({});
        QVERIFY(contents.hiddenEntries().isEmpty());
        QCOMPARE(contents.count(), 3);
        write(owned.filePath("added.txt"));
        QTRY_COMPARE(contents.count(), 4);
        contents.setHiddenEntries({QStringLiteral("added.txt")});
        QCOMPARE(contents.count(), 3);
        contents.setActive(false);
    }
    // Qt Quick asks for a row while it applies a model change, so the popup can
    // request a row the listing already dropped. Every reported row must map to
    // a live source instead of reaching a missing one.
    void entriesIndexStaysValidWhileTheListingChanges() {
        QTemporaryDir owned;
        QVERIFY(owned.isValid());
        for (const QString &name : {QStringLiteral("a.txt"), QStringLiteral("b.txt"), QStringLiteral("c.txt")})
            write(owned.filePath(name));

        FolderContents contents;
        FolderEntriesModel grid;
        grid.setContents(&contents);
        QAbstractItemModelTester tester(&grid, QAbstractItemModelTester::FailureReportingMode::QtTest);
        contents.setLocation(QUrl::fromLocalFile(owned.path()));
        contents.setActive(true);
        QTRY_VERIFY(!contents.loading());
        QCOMPARE(contents.count(), 3);
        QCOMPARE(grid.rowCount(), 4);

        const auto verifyRows = [&grid]() {
            for (int row = 0; row < grid.rowCount(); ++row) {
                const auto index = grid.index(row, 0);
                if (!index.isValid() || index.model() != &grid) return false;
            }
            return !grid.index(grid.rowCount(), 0).isValid() && !grid.index(-1, 0).isValid();
        };
        QVERIFY(verifyRows());

        // A row a delegate still holds becomes invalid, with empty data, instead
        // of reading a source the listing no longer has.
        const QPersistentModelIndex heldEntry(grid.index(2, 0));
        QVERIFY(heldEntry.isValid());
        contents.setHiddenEntries({QStringLiteral("a.txt"), QStringLiteral("b.txt")});
        QCOMPARE(contents.count(), 1);
        QCOMPARE(grid.rowCount(), 2);
        QVERIFY(!heldEntry.isValid());
        QCOMPARE(grid.data(heldEntry, FolderEntriesModel::LocationAction), QVariant());
        QVERIFY(verifyRows());

        // Dropping the listing keeps only the open-location cell.
        grid.setContents(nullptr);
        QCOMPARE(grid.rowCount(), 1);
        QVERIFY(grid.index(0, 0).isValid());
        QVERIFY(grid.data(grid.index(0, 0), FolderEntriesModel::LocationAction).toBool());
        QVERIFY(!grid.index(1, 0).isValid());
        QCOMPARE(grid.data(grid.index(5, 0), FolderContents::EntryName), QVariant());
        contents.setActive(false);
    }
    void rejectRemoteUrlsAndReportMissingFolders() {
        QTemporaryDir owned;
        FolderContents contents;
        const auto original = contents.location();
        for (const QUrl &invalid : {QUrl("https://example.invalid/"), QUrl("file://remote/path"),
                                   QUrl("file:relative"), QUrl("file:///tmp/file?query"), QUrl("file:///tmp/file#fragment")}) {
            contents.setLocation(invalid);
            QCOMPARE(contents.location(), original);
            QVERIFY(!FolderContents::localUrl(invalid));
        }
        contents.setLocation(QUrl::fromLocalFile(owned.filePath("missing")));
        contents.setActive(true);
        QTRY_VERIFY(!contents.loading());
        QVERIFY(!contents.error().isEmpty());
        QCOMPARE(contents.count(), 0);
        contents.setLocation(QUrl::fromLocalFile(owned.path()));
        QTRY_VERIFY(!contents.loading());
        QCOMPARE(contents.error(), QString());
        contents.setActive(false);
    }
};
QTEST_MAIN(FolderContentsTest)
#include "folder_contents_test.moc"
