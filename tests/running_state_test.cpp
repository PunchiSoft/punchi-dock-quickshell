// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QStandardItemModel>
#include <QDir>
#include <QTemporaryDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QStandardPaths>
#include <KApplicationTrader>
#include <KSycoca>
#include "adapters/kde/window-state/snapshot.h"
#include "adapters/kde/native/applications/runningapplications.h"

class RunningStateTest : public QObject
{
    Q_OBJECT
private:
    static void write(const QString &path, const QByteArray &data) {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QSaveFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(data), data.size());
        QVERIFY(file.commit());
    }
    static QString fixture(QTemporaryDir &directory) {
        const QString path = directory.filePath(QStringLiteral("observer.py"));
        write(path, "#!/usr/bin/python3\nimport pathlib,sys,select,time\n"
            "root=pathlib.Path(__file__).parent\nlast=None\n"
            "while True:\n"
            " if select.select([sys.stdin],[],[],0.02)[0] and sys.stdin.read(1)=='':\n"
            "  (root/'closed').write_text('EOF'); break\n"
            " current=(root/'state').read_bytes()\n"
            " if current!=last:\n"
            "  sys.stdout.buffer.write(current[:3]); sys.stdout.flush(); time.sleep(0.01)\n"
            "  sys.stdout.buffer.write(current[3:]); sys.stdout.flush(); last=current\n");
        QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        return path;
    }
private slots:
    void visibilityProjectionAndDesktopState() {
        QStandardItemModel model;
        model.setItemRoleNames({{Qt::UserRole + 1, "IsWindow"}, {Qt::UserRole + 2, "Geometry"},
            {Qt::UserRole + 3, "IsHidden"}, {Qt::UserRole + 4, "IsMinimized"}, {Qt::UserRole + 5, "SkipTaskbar"}});
        auto append = [&](QRect rect, bool hidden, bool minimized, bool helper) {
            auto item = new QStandardItem;
            item->setData(true, Qt::UserRole + 1); item->setData(rect, Qt::UserRole + 2);
            item->setData(hidden, Qt::UserRole + 3); item->setData(minimized, Qt::UserRole + 4);
            item->setData(helper, Qt::UserRole + 5); model.appendRow(item);
        };
        append(QRect(-1200, 800, 300, 100), false, false, false);
        append(QRect(-1200, 800, 300, 100), true, false, false);
        append(QRect(-1200, 800, 300, 100), false, true, false);
        append(QRect(-1200, 800, 300, 100), false, false, true);
        const auto snapshot = windowVisibilitySnapshot(&model, true, false);
        QCOMPARE(snapshot.value("rectangles").toArray().size(), 1);
        WindowVisibilityState visibility;
        visibility.accept(snapshot);
        QVERIFY(visibility.available());
        QVERIFY(visibility.overlaps(QRectF(-1200, 820, 480, 54)));
        QVERIFY(!visibility.overlaps(QRectF(1000, 820, 480, 54)));
        visibility.accept(windowVisibilitySnapshot(&model, true, true));
        QVERIFY(visibility.showingDesktop());
        QVERIFY(!visibility.overlaps(QRectF(-1200, 820, 480, 54)));
        model.item(0)->setData(QRect(), Qt::UserRole + 2);
        visibility.accept(windowVisibilitySnapshot(&model, true, false));
        QVERIFY(!visibility.available());
    }
    void visibilityChannelIsReactiveIndependentAndBounded() {
        QTemporaryDir directory;
        const auto state = directory.filePath(QStringLiteral("state"));
        const QStringList ids{QStringLiteral("org.kde.konsole")};
        auto snapshot = [&](bool desktop, QJsonArray rectangles) {
            return windowStateSnapshot(true, ids, QJsonObject{{"available", true},
                {"showingDesktop", desktop}, {"rectangles", rectangles}});
        };
        write(state, snapshot(false, QJsonArray{QJsonArray{0, 0, 100, 100}}));
        RunningApplications provider;
        provider.setExecutable(fixture(directory)); provider.setEnabled(true); provider.componentComplete();
        auto *visibility = provider.visibilityState();
        QTRY_VERIFY(visibility->available());
        const int revision = provider.revision();
        QVERIFY(visibility->overlaps(QRectF(50, 50, 20, 20)));
        write(state, snapshot(false, QJsonArray{QJsonArray{500, 500, 100, 100}}));
        QTRY_VERIFY(!visibility->overlaps(QRectF(50, 50, 20, 20)));
        QCOMPARE(provider.revision(), revision);
        QVERIFY(provider.isRunning(ids.first()));
        write(state, snapshot(true, QJsonArray{QJsonArray{0, 0, 100, 100}}));
        QTRY_VERIFY(visibility->showingDesktop());
        QVERIFY(!visibility->overlaps(QRectF(50, 50, 20, 20)));
        write(state, snapshot(false, QJsonArray{QJsonArray{0, 0, -1, 100}}));
        QTRY_VERIFY(!visibility->available());
        QVERIFY(provider.available());
        QVERIFY(provider.isRunning(ids.first()));
        write(state, snapshot(false, QJsonArray{QJsonArray{0, 0, 100, 100}}));
        QTRY_VERIFY(visibility->available());
        provider.setEnabled(false);
        QVERIFY(!visibility->available());
        QTRY_VERIFY(QFileInfo::exists(directory.filePath(QStringLiteral("closed"))));
    }
    void windowsNotClicksAndLastWindowRemoval() {
        QStandardItemModel model;
        model.setItemRoleNames({{Qt::UserRole + 1, "IsWindow"}, {Qt::UserRole + 2, "SkipTaskbar"},
            {Qt::UserRole + 3, "AppId"}, {Qt::UserRole + 4, "LauncherUrlWithoutIcon"}});
        auto append = [&](QString id, bool window = true, bool skip = false) {
            auto item = new QStandardItem;
            item->setData(window, Qt::UserRole + 1);
            item->setData(skip, Qt::UserRole + 2);
            item->setData(id, Qt::UserRole + 3);
            item->setData(QUrl(QStringLiteral("applications:") + id + QStringLiteral(".desktop")), Qt::UserRole + 4);
            model.appendRow(item);
        };
        append(QStringLiteral("org.kde.konsole"));
        append(QStringLiteral("org.kde.konsole"));
        append(QStringLiteral("launcher-only"), false);
        append(QStringLiteral("helper"), true, true);
        QCOMPARE(runningDesktopIds(model), QStringList{QStringLiteral("org.kde.konsole")});
        model.removeRow(0);
        QCOMPARE(runningDesktopIds(model), QStringList{QStringLiteral("org.kde.konsole")});
        model.removeRow(0);
        QVERIFY(runningDesktopIds(model).isEmpty());
        QCOMPARE(normalizedApplicationId(QStringLiteral("org.kde.konsole.desktop")), QStringLiteral("org.kde.konsole"));
        QVERIFY(normalizedApplicationId(QStringLiteral("../unsafe.desktop")).isEmpty());
    }
    void applicationMetadataIsParsedAndClearedWithWindowState() {
        QTemporaryDir directory;
        const QString state = directory.filePath(QStringLiteral("state"));
        const QString desktopId = QStringLiteral("punchi-unlisted-plasmoid-settings");
        const QJsonArray applications{QJsonObject{{QStringLiteral("desktopId"), desktopId},
            {QStringLiteral("name"), QStringLiteral("Plasma Applet Settings")},
            {QStringLiteral("iconName"), QStringLiteral("preferences-system-windows")}}};
        write(state, windowStateSnapshot(true, {desktopId}, {}, applications));
        RunningApplications provider;
        provider.setExecutable(fixture(directory));
        provider.setEnabled(true);
        provider.componentComplete();
        QTRY_VERIFY_WITH_TIMEOUT(provider.available(), 3000);
        QCOMPARE(provider.applicationEntries().size(), 1);
        const auto entry = provider.applicationEntries().first().toMap();
        QCOMPARE(entry.value(QStringLiteral("desktopId")).toString(), desktopId);
        QCOMPARE(entry.value(QStringLiteral("name")).toString(), QStringLiteral("Plasma Applet Settings"));
        QCOMPARE(entry.value(QStringLiteral("iconName")).toString(), QStringLiteral("preferences-system-windows"));
        write(state, windowStateSnapshot(true, {desktopId}));
        QTRY_VERIFY_WITH_TIMEOUT(provider.applicationEntries().isEmpty(), 3000);
        provider.setEnabled(false);
    }
    void providerStreamingUpdatesUnavailableAndLifetime() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString state = directory.filePath(QStringLiteral("state"));
        write(state, windowStateSnapshot(false));
        RunningApplications provider;
        provider.setExecutable(fixture(directory));
        provider.setEnabled(true);
        provider.componentComplete();
        write(state, windowStateSnapshot(true, {QStringLiteral("org.kde.konsole")}));
        QTRY_VERIFY_WITH_TIMEOUT(provider.available(), 3000);
        QVERIFY(provider.isRunning(QStringLiteral("org.kde.konsole.desktop")));
        QVERIFY(!provider.isRunning(QStringLiteral("other-app")));
        const int revision = provider.revision();
        write(state, windowStateSnapshot(true, {}));
        QTRY_VERIFY_WITH_TIMEOUT(!provider.isRunning(QStringLiteral("org.kde.konsole")), 3000);
        QVERIFY(provider.available());
        QVERIFY(provider.revision() > revision);
        write(state, windowStateSnapshot(false));
        QTRY_VERIFY_WITH_TIMEOUT(!provider.available(), 3000);
        provider.setEnabled(false);
        QTRY_VERIFY_WITH_TIMEOUT(QFileInfo::exists(directory.filePath(QStringLiteral("closed"))), 3000);
    }
    void malformedSnapshotStopsAndClearsProvider() {
        QTemporaryDir directory;
        const QString state = directory.filePath(QStringLiteral("state"));
        write(state, windowStateSnapshot(true, {QStringLiteral("org.kde.konsole")}));
        RunningApplications provider;
        provider.setExecutable(fixture(directory));
        provider.setEnabled(true);
        provider.componentComplete();
        QTRY_VERIFY_WITH_TIMEOUT(provider.available(), 3000);
        write(state, "{\"version\":1,\"available\":true,\"desktopIds\":[\"../unsafe\"]}\n");
        QTRY_VERIFY_WITH_TIMEOUT(!provider.available(), 3000);
        QVERIFY(!provider.isRunning(QStringLiteral("org.kde.konsole")));
        QTRY_VERIFY_WITH_TIMEOUT(QFileInfo::exists(directory.filePath(QStringLiteral("closed"))), 3000);
    }
    void currentDesktopAndActivitiesAreParsed() {
        QTemporaryDir directory;
        const QString state = directory.filePath(QStringLiteral("state"));
        const QString first = QStringLiteral("org.kde.konsole");
        const QString second = QStringLiteral("org.kde.dolphin");
        const QJsonArray activities{
            QJsonObject{{QStringLiteral("id"), QStringLiteral("a-1")}, {QStringLiteral("name"),
                QStringLiteral("Desktop activity")}, {QStringLiteral("current"), true}},
            QJsonObject{{QStringLiteral("id"), QStringLiteral("a-2")}, {QStringLiteral("name"),
                QStringLiteral("Work")}, {QStringLiteral("current"), false}}};
        write(state, windowStateSnapshot(true, {first, second}, {}, {}, {first}, activities));
        RunningApplications provider;
        provider.setExecutable(fixture(directory));
        provider.setEnabled(true);
        provider.componentComplete();
        QTRY_VERIFY_WITH_TIMEOUT(provider.available(), 3000);
        QCOMPARE(provider.currentDesktopIds(), QStringList{first});
        QCOMPARE(provider.activities().size(), 2);
        const auto activity = provider.activities().first().toMap();
        QCOMPARE(activity.value(QStringLiteral("id")).toString(), QStringLiteral("a-1"));
        QCOMPARE(activity.value(QStringLiteral("name")).toString(), QStringLiteral("Desktop activity"));
        QCOMPARE(activity.value(QStringLiteral("current")).toBool(), true);
        // An app outside the running list is rejected as malformed.
        write(state, windowStateSnapshot(true, {first}, {}, {}, {QStringLiteral("other-app")}, activities));
        QTRY_VERIFY_WITH_TIMEOUT(!provider.available(), 3000);
        provider.setEnabled(false);
    }
    void backendUnavailableAndEofExit() {
        QProcess backend;
        backend.start(QStringLiteral(PUNCHI_TEST_BACKEND), {});
        QVERIFY(backend.waitForStarted());
        QTRY_VERIFY_WITH_TIMEOUT(backend.canReadLine(), 3000);
        const auto data = QJsonDocument::fromJson(backend.readLine()).object();
        QCOMPARE(data.value(QStringLiteral("available")).toBool(), false);
        QVERIFY(data.value(QStringLiteral("desktopIds")).toArray().isEmpty());
        backend.closeWriteChannel();
        QVERIFY(backend.waitForFinished(3000));
        QCOMPARE(backend.exitCode(), 0);
    }
    void scopedDesktopRegistrationAndCollision() {
        const QString path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QStringLiteral("/applications/org.punchi.Shell.WindowState.desktop");
        const QString backend = QStringLiteral(PUNCHI_TEST_BACKEND);
        QVERIFY(backend.endsWith(QStringLiteral("/punchi-window-state")));
        // A registration from another checkout, which this backend must migrate.
        const QString legacyExecutable
            = QStringLiteral("/tmp/punchi-shell/build/punchi-window-state");
        const QByteArray legacyRegistration = QStringLiteral("[Desktop Entry]\nType=Application\n"
            "Name=Punchi Shell Window State\nNoDisplay=true\nTerminal=false\n"
            "Exec=\"%1\"\nX-KDE-Wayland-Interfaces=org_kde_plasma_window_management\n")
            .arg(legacyExecutable).toUtf8();
        write(path, legacyRegistration);
        auto run = [&](QString argument) {
            QProcess process;
            process.start(QStringLiteral(PUNCHI_TEST_BACKEND), {argument});
            if (!process.waitForFinished(15000)) { process.kill(); process.waitForFinished(); return -1; }
            return process.exitCode();
        };
        QCOMPARE(run(QStringLiteral("--restore-desktop-settings")), 0);
        // KService compares directory and cache timestamps; separate the
        // initial cache load from the registration rebuild deterministically.
        QTest::qWait(1100);
        QCOMPARE(run(QStringLiteral("--register")), 0);
        QFile migrated(path);
        QVERIFY(migrated.open(QIODevice::ReadOnly));
        QVERIFY(migrated.readAll().contains("Name=Punchi Dock Quickshell Window State"));
        migrated.close();
        QCOMPARE(run(QStringLiteral("--register")), 0);
        KSycoca::self()->ensureCacheValid();
        const auto matches = KApplicationTrader::query([](const KService::Ptr &service) {
            const auto command = QProcess::splitCommand(service->exec());
            return !command.isEmpty() && QFileInfo(command.first()).canonicalFilePath()
                == QFileInfo(QStringLiteral(PUNCHI_TEST_BACKEND)).canonicalFilePath();
        });
        QCOMPARE(matches.size(), 1);
        QVERIFY(matches.first()->noDisplay());
        QCOMPARE(matches.first()->property<QStringList>(QStringLiteral("X-KDE-Wayland-Interfaces")),
                 QStringList{QStringLiteral("org_kde_plasma_window_management")});
        QCOMPARE(run(QStringLiteral("--unregister")), 0);
        QVERIFY(!QFileInfo::exists(path));
        const QByteArray otherInstallation = QStringLiteral("[Desktop Entry]\nType=Application\n"
            "Name=Punchi Dock Quickshell Window State\nNoDisplay=true\nTerminal=false\n"
            "Exec=\"/tmp/punchi-other/build/punchi-window-state\"\n"
            "X-KDE-Wayland-Interfaces=org_kde_plasma_window_management\n").toUtf8();
        write(path, otherInstallation);
        QCOMPARE(run(QStringLiteral("--register")), 0);
        QFile replaced(path);
        QVERIFY(replaced.open(QIODevice::ReadOnly));
        QVERIFY(replaced.readAll().contains(QStringLiteral(PUNCHI_TEST_BACKEND).toUtf8()));
        replaced.close();
        QCOMPARE(run(QStringLiteral("--unregister")), 0);
        QVERIFY(!QFileInfo::exists(path));
        write(path, "unrelated existing desktop entry\n");
        QVERIFY(run(QStringLiteral("--register")) != 0);
        QVERIFY(run(QStringLiteral("--unregister")) != 0);
        QFile existing(path);
        QVERIFY(existing.open(QIODevice::ReadOnly));
        QCOMPARE(existing.readAll(), QByteArray("unrelated existing desktop entry\n"));
        existing.close();
        QVERIFY(existing.remove());
    }
};
QTEST_GUILESS_MAIN(RunningStateTest)
#include "running_state_test.moc"
