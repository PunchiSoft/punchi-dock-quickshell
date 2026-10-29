// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QStandardItemModel>
#include <QTemporaryDir>
#include <QSaveFile>
#include <QFile>
#include <QJsonDocument>
#include <climits>
#include "adapters/kde/window-state/activationdecision.h"
#include "adapters/kde/window-state/windowtaskactions.h"
#include "adapters/kde/native/applications/runningapplications.h"

class ActivationModel : public QStandardItemModel {
    Q_OBJECT
public:
    enum Role { Window = Qt::UserRole + 1, App, Launcher, Skip, Active, Last, Minimized, Group, Minimizable, Startup };
    int activatedRow = -1;
    int minimizedRow = -1;
    int newInstanceRow = -1;
    ActivationModel() {
        setItemRoleNames({{Window, "IsWindow"}, {App, "AppId"}, {Launcher, "LauncherUrlWithoutIcon"},
            {Skip, "SkipTaskbar"}, {Active, "IsActive"}, {Last, "LastActivated"},
            {Minimized, "IsMinimized"}, {Group, "IsGroupParent"}, {Minimizable, "IsMinimizable"}, {Startup, "IsStartup"}});
    }
    void append(QString app, qint64 stamp, bool minimized = false) {
        auto *item = new QStandardItem;
        item->setData(true, Window); item->setData(app, App);
        item->setData(QDateTime::fromMSecsSinceEpoch(stamp), Last);
        item->setData(minimized, Minimized); item->setData(true, Minimizable); appendRow(item);
    }
    Q_INVOKABLE void requestActivate(const QModelIndex &index) { activatedRow = index.row(); }
    Q_INVOKABLE void requestToggleMinimized(const QModelIndex &index) { minimizedRow = index.row(); }
    Q_INVOKABLE void requestNewInstance(const QModelIndex &index) { newInstanceRow = index.row(); }
};

class WindowActionModel : public QStandardItemModel {
    Q_OBJECT
public:
    enum Role { Window = Qt::UserRole + 1, App, Launcher, Skip, Active, Last, Movable, Resizable,
        Maximizable, Maximized, Minimizable, Minimized, KeepAbove, KeepBelow, Fullscreenable,
        Fullscreen, CanNoBorder, NoBorder, Excluded, Closable, DesktopChangeable, OnAllDesktops,
        VirtualDesktops, Groupable };
    int moved = -1, resized = -1, maximized = -1, minimized = -1, keptAbove = -1, closed = -1;
    int desktopRequests = 0;
    QVariantList requestedDesktops;
    WindowActionModel() {
        setItemRoleNames({{Window,"IsWindow"},{App,"AppId"},{Launcher,"LauncherUrlWithoutIcon"},
            {Skip,"SkipTaskbar"},{Active,"IsActive"},{Last,"LastActivated"},{Movable,"IsMovable"},
            {Resizable,"IsResizable"},{Maximizable,"IsMaximizable"},{Maximized,"IsMaximized"},
            {Minimizable,"IsMinimizable"},{Minimized,"IsMinimized"},{KeepAbove,"IsKeepAbove"},
            {KeepBelow,"IsKeepBelow"},{Fullscreenable,"IsFullScreenable"},{Fullscreen,"IsFullScreen"},
            {CanNoBorder,"CanSetNoBorder"},{NoBorder,"HasNoBorder"},{Excluded,"IsExcludedFromCapture"},
            {Closable,"IsClosable"},{DesktopChangeable,"IsVirtualDesktopsChangeable"},
            {OnAllDesktops,"IsOnAllVirtualDesktops"},{VirtualDesktops,"VirtualDesktops"},{Groupable,"IsGroupable"}});
    }
    void appendWindow(QString app, qint64 stamp, bool active = false) {
        auto *item = new QStandardItem;
        item->setData(true, Window); item->setData(app, App); item->setData(false, Skip);
        item->setData(active, Active); item->setData(QDateTime::fromMSecsSinceEpoch(stamp), Last);
        item->setData(true, Movable); item->setData(true, Resizable); item->setData(true, Maximizable);
        item->setData(false, Maximized); item->setData(true, Minimizable); item->setData(false, Minimized);
        item->setData(false, KeepAbove); item->setData(false, KeepBelow); item->setData(true, Fullscreenable);
        item->setData(false, Fullscreen); item->setData(true, CanNoBorder); item->setData(false, NoBorder);
        item->setData(false, Excluded); item->setData(true, Closable); item->setData(true, DesktopChangeable);
        item->setData(false, OnAllDesktops); item->setData(QVariantList{"desktop-1"}, VirtualDesktops);
        item->setData(true, Groupable); appendRow(item);
    }
    Q_INVOKABLE void requestMove(const QModelIndex &index) { moved = index.row(); }
    Q_INVOKABLE void requestResize(const QModelIndex &index) { resized = index.row(); }
    Q_INVOKABLE void requestToggleMaximized(const QModelIndex &index) { maximized = index.row(); }
    Q_INVOKABLE void requestToggleMinimized(const QModelIndex &index) { minimized = index.row(); }
    Q_INVOKABLE void requestToggleKeepAbove(const QModelIndex &index) { keptAbove = index.row(); }
    Q_INVOKABLE void requestToggleKeepBelow(const QModelIndex &) {}
    Q_INVOKABLE void requestToggleFullScreen(const QModelIndex &) {}
    Q_INVOKABLE void requestToggleNoBorder(const QModelIndex &) {}
    Q_INVOKABLE void requestToggleExcludeFromCapture(const QModelIndex &) {}
    Q_INVOKABLE void requestClose(const QModelIndex &index) { closed = index.row(); }
    Q_INVOKABLE void requestNewVirtualDesktop(const QModelIndex &) {}
    Q_INVOKABLE void requestToggleGrouping(const QModelIndex &) {}
    Q_INVOKABLE void requestVirtualDesktops(const QModelIndex &, const QVariantList &desktops) {
        requestedDesktops = desktops; ++desktopRequests;
    }
};

class WindowActivationTest : public QObject {
    Q_OBJECT
    static QJsonObject command(QString id, int request = 1) {
        return {{"version", 1}, {"type", "activate"}, {"requestId", request}, {"desktopId", id}};
    }
    static void write(const QString &path, const QByteArray &data) {
        QSaveFile file(path); QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(data), data.size()); QVERIFY(file.commit());
    }
private slots:
    void windowActionSnapshotAndCapabilityDispatch() {
        WindowActionModel model;
        model.appendWindow("org.kde.kate", 10);
        model.appendWindow("org.kde.kate", 20, true);
        const QVariantList desktopIds{"desktop-1", "desktop-2"};
        const auto snapshot = windowActionsSnapshot(&model, true, desktopIds,
            {"Desktop 1", "Desktop 2"}, "desktop-2");
        const auto state = snapshot.value("applications").toObject().value("org.kde.kate").toObject();
        QVERIFY(state.value("available").toBool());
        QVERIFY(state.value("movable").toBool());
        QVERIFY(state.value("canHideFromCapture").toBool());
        QVERIFY(state.value("virtualDesktops").toArray().size() == 1);
        QCOMPARE(snapshot.value("desktops").toArray().at(1).toObject().value("current").toBool(), true);

        auto command = QJsonObject{{"version",1},{"type","window-action"},{"requestId",1},
            {"desktopId","org.kde.kate"},{"action","move"}};
        auto reply = windowActionRequest(&model, true, desktopIds, command);
        QCOMPARE(reply.value("status").toString(), "requested");
        QCOMPARE(model.moved, 1); // The active matching task wins over a newer inactive one.
        command.insert("requestId", 2); command.insert("action", "desktop"); command.insert("desktop", "desktop-2");
        reply = windowActionRequest(&model, true, desktopIds, command);
        QCOMPARE(reply.value("status").toString(), "requested");
        QCOMPARE(model.requestedDesktops, QVariantList{"desktop-2"});
        command.insert("requestId", 3); command.insert("desktop", "unknown-desktop");
        QCOMPARE(windowActionRequest(&model, true, desktopIds, command).value("status").toString(), "rejected");
        command.insert("requestId", 4); command.insert("action", "maximize"); command.remove("desktop");
        model.item(1)->setData(false, WindowActionModel::Maximizable);
        QCOMPARE(windowActionRequest(&model, true, desktopIds, command).value("status").toString(), "rejected");
        QCOMPARE(model.maximized, -1);
        command.insert("requestId", 5); command.insert("action", "close");
        QCOMPARE(windowActionRequest(&model, true, desktopIds, command).value("status").toString(), "requested");
        QCOMPARE(model.closed, 1);
    }
    void nativeSelectionAndDispatch() {
        ActivationModel model;
        model.append("firefox", 100);
        model.item(0)->setData(QUrl("applications:org.mozilla.firefox.desktop"), ActivationModel::Launcher);
        model.append("org.kde.kate", 1000);
        model.append("org.mozilla.firefox", 200, true);
        model.append("org.mozilla.firefox", 300);
        model.item(3)->setData(true, ActivationModel::Skip);
        model.append("org.mozilla.firefox", 500);
        model.item(4)->setData(true, ActivationModel::Group);
        QVERIFY(supportsWindowActivation(&model));
        auto reply = activateWindowRequest(&model, true, command("org.mozilla.firefox.desktop"));
        QCOMPARE(reply.value("status").toString(), "activated");
        QCOMPARE(reply.value("desktopId").toString(), "org.mozilla.firefox");
        QCOMPARE(model.activatedRow, 2); // Minimized MRU window is eligible.
        model.item(0)->setData(true, ActivationModel::Active);
        reply = activateWindowRequest(&model, true, command("org.mozilla.firefox"));
        QCOMPARE(reply.value("status").toString(), "activated");
        QCOMPARE(model.minimizedRow, -1); // Groups cycle instead of minimizing one window.
        QCOMPARE(model.activatedRow, 2);
        model.removeRow(0);
        reply = activateWindowRequest(&model, true, command("org.mozilla.firefox"));
        QCOMPARE(model.activatedRow, 1); // Select fresh indices after row removal.
        QCOMPARE(activateWindowRequest(&model, true, command("closed-app")).value("status").toString(), "not-found");
        model.activatedRow = -1;
        QCOMPARE(activateWindowRequest(&model, false, command("org.mozilla.firefox")).value("status").toString(), "unavailable");
        QCOMPARE(model.activatedRow, -1);
        QStandardItemModel unsupported;
        QCOMPARE(activateWindowRequest(&unsupported, true, command("closed-app")).value("status").toString(), "unavailable");
    }
    void activeClickMinimizeAndRestoreEligibility() {
        ActivationModel model; model.append("org.kde.kate", 100);
        model.item(0)->setData(true, ActivationModel::Active);
        QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "minimized");
        QCOMPARE(model.minimizedRow, 0); QCOMPARE(model.activatedRow, -1);
        // Minimized wins over a transient/stale active role: restore, never toggle again.
        model.item(0)->setData(true, ActivationModel::Minimized);
        model.minimizedRow = -1;
        QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "activated");
        QCOMPARE(model.activatedRow, 0); QCOMPARE(model.minimizedRow, -1);
        model.item(0)->setData(false, ActivationModel::Minimized);
        model.item(0)->setData(false, ActivationModel::Minimizable);
        model.activatedRow = -1;
        QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "activated");
        QCOMPARE(model.activatedRow, 0); QCOMPARE(model.minimizedRow, -1);
        model.item(0)->setData(false, ActivationModel::Active);
        model.item(0)->setData(true, ActivationModel::Minimizable);
        model.activatedRow = -1;
        QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "activated");
        QCOMPARE(model.activatedRow, 0); QCOMPARE(model.minimizedRow, -1);
    }
    void boundedAndInvalidRequests() {
        ActivationModel model; model.append("org.kde.kate", 100);
        for (const QString &id : {QString("../kate"), QString("kate; command"), QString(""), QString(300, 'x')})
            QCOMPARE(activateWindowRequest(&model, true, command(id)).value("status").toString(), "rejected");
        for (double id : {0.0, -1.0, 1.5, double(INT_MAX) + 1}) {
            auto request = command("org.kde.kate"); request.insert("requestId", id);
            QVERIFY(activateWindowRequest(&model, true, request).isEmpty());
        }
        auto request = command("org.kde.kate"); request.insert("type", "close");
        QCOMPARE(activateWindowRequest(&model, true, request).value("status").toString(), "rejected");
        QCOMPARE(model.activatedRow, -1);
        model.setRowCount(4097);
        QVERIFY(!supportsWindowActivation(&model));
        QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "unavailable");
    }
    void groupCyclingStartupAndExplicitNewInstance() {
        ActivationModel model;
        model.append("org.kde.kate", 300);
        model.append("org.kde.kate", 100, true);
        model.append("org.kde.kate", 200);
        for (int active = 0; active < 3; ++active) {
            for (int row = 0; row < 3; ++row) {
                model.item(row)->setData(row == active, ActivationModel::Active);
                model.item(row)->setData(false, ActivationModel::Minimized);
            }
            QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "activated");
            QCOMPARE(model.activatedRow, (active + 1) % 3);
            QCOMPARE(model.minimizedRow, -1);
        }
        auto request = command("org.kde.kate"); request.insert("type", "new-instance");
        QCOMPARE(activateWindowRequest(&model, true, request).value("status").toString(), "new-instance");
        QCOMPARE(model.newInstanceRow, 2);
        model.clear();
        model.setItemRoleNames({{ActivationModel::Window,"IsWindow"},{ActivationModel::Startup,"IsStartup"},
            {ActivationModel::App,"AppId"}});
        auto *startup = new QStandardItem;
        startup->setData(true, ActivationModel::Startup); startup->setData("org.kde.kate", ActivationModel::App);
        model.appendRow(startup);
        QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "starting");
        QCOMPARE(activateWindowRequest(&model, true, request).value("status").toString(), "not-found");
        model.removeRow(0);
        QCOMPARE(activateWindowRequest(&model, true, command("org.kde.kate")).value("status").toString(), "not-found");
    }
    void actualBackendPartialCommandsAndEof() {
        QProcess process; process.start(QStringLiteral(PUNCHI_TEST_BACKEND), {});
        QVERIFY(process.waitForStarted()); QTRY_VERIFY(process.canReadLine());
        auto snapshot = QJsonDocument::fromJson(process.readLine()).object();
        QVERIFY(!snapshot.value("available").toBool());
        QVERIFY(!snapshot.value("activationAvailable").toBool());
        const auto bytes = QJsonDocument(command("org.kde.kate", 7)).toJson(QJsonDocument::Compact) + '\n';
        process.write(bytes.left(5)); QVERIFY(process.waitForBytesWritten());
        QTest::qWait(30); QVERIFY(!process.canReadLine());
        process.write(bytes.mid(5)); QTRY_VERIFY(process.canReadLine());
        const auto reply = QJsonDocument::fromJson(process.readLine()).object();
        QCOMPARE(reply.value("requestId").toInt(), 7);
        QCOMPARE(reply.value("status").toString(), "unavailable");
        process.closeWriteChannel(); QVERIFY(process.waitForFinished(3000));
        QCOMPARE(process.exitCode(), 0);
        process.start(QStringLiteral(PUNCHI_TEST_BACKEND), {});
        QVERIFY(process.waitForStarted()); QTRY_VERIFY(process.canReadLine()); process.readLine();
        process.write(QByteArray(3000, 'x'));
        QVERIFY(process.waitForFinished(3000)); QCOMPARE(process.exitCode(), 2);
    }
    void providerReplyCorrelationFailureAndTimeout() {
        QTemporaryDir directory;
        const QString script = directory.filePath("commands.py");
        write(script, "#!/usr/bin/python3\nimport json,sys\n"
            "keys='available movable resizable maximizable maximized minimizable minimized keepAbove keepBelow fullscreenable fullscreen canSetNoBorder noBorder canHideFromCapture excludedFromCapture closable desktopChangeable onAllDesktops groupable'.split()\n"
            "state={k:(k in ('available','movable','maximizable','minimizable','closable','desktopChangeable','canHideFromCapture')) for k in keys}; state['virtualDesktops']=['desk-1']\n"
            "print(json.dumps(dict(version=1,available=True,desktopIds=['open-app'],activationAvailable=True,windowActions={'open-app':state},virtualDesktops=[dict(id='desk-1',name='',current=True)])),flush=True)\n"
            "print(json.dumps(dict(version=1,available=True,desktopIds=['open-app'],activationAvailable=True,windowActions={'open-app':state},virtualDesktops=[dict(id='desk-1',name='Desktop 1',current=True)])),flush=True)\n"
            "for line in sys.stdin:\n"
            " q=json.loads(line); app=q['desktopId']\n"
            " if q['type']=='window-action':\n"
            "  print(json.dumps(dict(version=1,type='window-action-result',requestId=q['requestId'],desktopId=app,action=q['action'],status='requested')),flush=True); continue\n"
            " if app=='hang-app': continue\n"
            " if app=='lost-app': break\n"
            " status='activated' if app=='open-app' else 'not-found'\n"
            " if app=='wrong-app': app='other-app'\n"
            " print(json.dumps(dict(version=1,type='activation-result',requestId=q['requestId'],desktopId=app,status=status)),flush=True)\n");
        QVERIFY(QFile::setPermissions(script, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        RunningApplications provider;
        provider.setExecutable(script); provider.setEnabled(true); provider.componentComplete();
        auto *activation = provider.windowActivation();
        QSignalSpy completed(activation, &WindowActivation::finished);
        QTRY_VERIFY(activation->available());
        QVERIFY(provider.isRunning("open-app"));
        QVERIFY(provider.windowActions("open-app").value("movable").toBool());
        QCOMPARE(provider.virtualDesktops().size(), 1);
        const int open = activation->requestActivate("open-app.desktop"); QVERIFY(open > 0);
        const int closed = activation->requestActivate("closed-app"); QVERIFY(closed > open);
        QTRY_COMPARE(completed.count(), 2);
        QCOMPARE(completed.at(0).at(0).toInt(), open);
        QCOMPARE(completed.at(0).at(2).toString(), "activated");
        QCOMPARE(completed.at(1).at(0).toInt(), closed);
        QCOMPARE(completed.at(1).at(2).toString(), "not-found");
        QCOMPARE(activation->requestActivate("unsafe; command"), 0);
        const int action = activation->requestWindowAction("open-app", "move"); QVERIFY(action > 0);
        QTRY_COMPARE(completed.count(), 3);
        QCOMPARE(completed.at(2).at(0).toInt(), action);
        QCOMPARE(completed.at(2).at(2).toString(), "requested");
        QCOMPARE(activation->requestWindowAction("open-app", "unknown"), 0);
        const int hang = activation->requestActivate("hang-app"); QVERIFY(hang > 0);
        QTRY_COMPARE_WITH_TIMEOUT(completed.count(), 4, 4500);
        QCOMPARE(completed.at(3).at(0).toInt(), hang);
        QCOMPARE(completed.at(3).at(2).toString(), "unavailable");
        QVERIFY(activation->acceptResult({{"version",1},{"type","activation-result"},{"requestId",hang},
            {"desktopId","hang-app"},{"status","not-found"}}));
        QTest::qWait(20); QCOMPARE(completed.count(), 4);
        const int wrong = activation->requestActivate("wrong-app"); QVERIFY(wrong > 0);
        QTRY_COMPARE(completed.count(), 5);
        QCOMPARE(completed.at(4).at(2).toString(), "unavailable");
        QTRY_VERIFY(!provider.available()); QVERIFY(!activation->available());
        provider.setEnabled(false); provider.setEnabled(true);
        QTRY_VERIFY(activation->available());
        QVERIFY(activation->requestActivate("lost-app") > 0);
        QTRY_COMPARE(completed.count(), 6);
        QCOMPARE(completed.at(5).at(2).toString(), "unavailable");
    }
};
QTEST_GUILESS_MAIN(WindowActivationTest)
#include "window_activation_test.moc"
