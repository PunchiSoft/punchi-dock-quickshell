// SPDX-License-Identifier: GPL-3.0-or-later
#include "adapters/kde/native/profilefile.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include <sys/stat.h>

class ProfileFileTest : public QObject {
    Q_OBJECT

private slots:
    void readsUtf8AndStripsBom();
    void rejectsMissingDirectoryAndNonLocalPaths();
    void rejectsOversizedFile();
    void rejectsInvalidEncoding();
    void rejectsFifoWithoutBlocking();
    void writesAtomicallyWithOwnerOnlyPermissions();
    void refusesToOverwriteSymlink();
    void keepsExistingFileWhenWriteFails();
};

namespace {
void writeBytes(const QString &path, const QByteArray &bytes)
{
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    QCOMPARE(file.write(bytes), bytes.size());
}

QString errorOf(const QVariantMap &result)
{
    return result.value(QStringLiteral("error")).toString();
}
}

void ProfileFileTest::readsUtf8AndStripsBom()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("profile.json"));
    writeBytes(path, QByteArray("\xEF\xBB\xBF{\"version\":11}"));
    ProfileFile file;
    const QVariantMap result = file.read(QUrl::fromLocalFile(path), 4096);
    QVERIFY2(result.value(QStringLiteral("ok")).toBool(), qPrintable(errorOf(result)));
    QCOMPARE(result.value(QStringLiteral("text")).toString(), QStringLiteral("{\"version\":11}"));
    const QVariantMap byPath = file.readPath(path, 4096);
    QVERIFY2(byPath.value(QStringLiteral("ok")).toBool(), qPrintable(errorOf(byPath)));
    QCOMPARE(byPath.value(QStringLiteral("text")).toString(), QStringLiteral("{\"version\":11}"));
    QCOMPARE(errorOf(file.readPath(QStringLiteral("relative.json"), 4096)),
        QStringLiteral("not-local"));
}

void ProfileFileTest::rejectsMissingDirectoryAndNonLocalPaths()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    ProfileFile file;
    QCOMPARE(errorOf(file.read(QUrl::fromLocalFile(directory.filePath(QStringLiteral("absent.json"))), 4096)),
        QStringLiteral("missing"));
    QCOMPARE(errorOf(file.read(QUrl::fromLocalFile(directory.path()), 4096)),
        QStringLiteral("not-regular"));
    QCOMPARE(errorOf(file.read(QUrl(QStringLiteral("https://example.invalid/profile.json")), 4096)),
        QStringLiteral("not-local"));
}

void ProfileFileTest::rejectsOversizedFile()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("large.json"));
    writeBytes(path, QByteArray(1025, 'x'));
    ProfileFile file;
    QCOMPARE(errorOf(file.read(QUrl::fromLocalFile(path), 1024)), QStringLiteral("too-large"));
}

void ProfileFileTest::rejectsInvalidEncoding()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("invalid.json"));
    writeBytes(path, QByteArray("\xFF\xFE", 2));
    ProfileFile file;
    QCOMPARE(errorOf(file.read(QUrl::fromLocalFile(path), 4096)),
        QStringLiteral("invalid-encoding"));
}

void ProfileFileTest::rejectsFifoWithoutBlocking()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("pipe"));
    QCOMPARE(::mkfifo(QFile::encodeName(path).constData(), 0600), 0);
    ProfileFile file;
    QCOMPARE(errorOf(file.read(QUrl::fromLocalFile(path), 4096)),
        QStringLiteral("not-regular"));
}

void ProfileFileTest::writesAtomicallyWithOwnerOnlyPermissions()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("export.json"));
    ProfileFile file;
    const QVariantMap result = file.write(QUrl::fromLocalFile(path),
        QStringLiteral("{\"version\":11}"), 4096);
    QVERIFY2(result.value(QStringLiteral("ok")).toBool(), qPrintable(errorOf(result)));
    QFile written(path);
    QVERIFY(written.open(QIODevice::ReadOnly));
    QCOMPARE(written.readAll(), QByteArray("{\"version\":11}"));
    const QFile::Permissions permissions = QFileInfo(path).permissions();
    QCOMPARE(permissions & (QFileDevice::ReadOwner | QFileDevice::WriteOwner),
        QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    QVERIFY(!(permissions & (QFileDevice::ReadGroup | QFileDevice::ReadOther)));
    QVERIFY(!(permissions & (QFileDevice::WriteGroup | QFileDevice::WriteOther)));
}

void ProfileFileTest::refusesToOverwriteSymlink()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString target = directory.filePath(QStringLiteral("target.json"));
    const QString link = directory.filePath(QStringLiteral("link.json"));
    writeBytes(target, QByteArray("original"));
    QVERIFY(QFile::link(target, link));
    QVERIFY(QFileInfo(link).isSymLink());
    ProfileFile file;
    QCOMPARE(errorOf(file.write(QUrl::fromLocalFile(link), QStringLiteral("replacement"), 4096)),
        QStringLiteral("symlink"));
    QFile unchanged(target);
    QVERIFY(unchanged.open(QIODevice::ReadOnly));
    QCOMPARE(unchanged.readAll(), QByteArray("original"));
}

void ProfileFileTest::keepsExistingFileWhenWriteFails()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("existing.json"));
    writeBytes(path, QByteArray("original"));
    ProfileFile file;
    QCOMPARE(errorOf(file.write(QUrl::fromLocalFile(path), QStringLiteral("too long"), 4)),
        QStringLiteral("too-large"));
    QFile unchanged(path);
    QVERIFY(unchanged.open(QIODevice::ReadOnly));
    QCOMPARE(unchanged.readAll(), QByteArray("original"));
    QCOMPARE(errorOf(file.write(QUrl::fromLocalFile(
        directory.filePath(QStringLiteral("missing/child.json"))), QStringLiteral("x"), 4096)),
        QStringLiteral("write-failed"));
}

QTEST_GUILESS_MAIN(ProfileFileTest)
#include "profile_file_test.moc"
