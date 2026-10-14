// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>
#include <memory>
#include "kwinminimizeeffect.h"

class KWinMock final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.KWin")
public:
    int reconfigureCount = 0;
public slots:
    void reconfigure() { ++reconfigureCount; }
};

class KWinMinimizeEffectTest final : public QObject
{
    Q_OBJECT
private:
    KWinMock m_kwin;
    bool writeFile(const QString &path, const QByteArray &content)
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file(path);
        return file.open(QIODevice::WriteOnly) && file.write(content) == content.size();
    }

    QString recoveryPath() const
    {
        return qEnvironmentVariable("XDG_STATE_HOME")
            + QStringLiteral("/punchi-dock-quickshell/owned-settings.json");
    }

    QString legacyRecoveryPath() const
    {
        return qEnvironmentVariable("XDG_STATE_HOME")
            + QStringLiteral("/punchi-shell/owned-settings.json");
    }

private slots:
    void initTestCase()
    {
        const auto dataRoot = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
        const auto configRoot = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
        QVERIFY(!dataRoot.isEmpty());
        QVERIFY(!configRoot.isEmpty());
        QVERIFY(writeFile(dataRoot + QStringLiteral("/kwin-test/effects/squash/metadata.json"),
            R"({"KPlugin":{"Id":"squash"},"org.kde.kwin.effect":{"exclusiveGroup":"minimize"}})"));
        QVERIFY(writeFile(dataRoot + QStringLiteral("/kwin-test/effects/custom/metadata.json"),
            R"({"KPlugin":{"Id":"custom"},"org.kde.kwin.effect":{"exclusiveGroup":"minimize"}})"));
        QVERIFY(writeFile(dataRoot + QStringLiteral("/kwin-test/builtin-effects/magiclamp.json"),
            R"({"KPlugin":{"Name":"Magic Lamp"},"org.kde.kwin.effect":{"exclusiveGroup":"minimize"}})"));
        QVERIFY(writeFile(dataRoot + QStringLiteral("/kwin-test/effects/oversized/metadata.json"),
            QByteArray(1024 * 1024 + 1, 'x')));
        QVERIFY(writeFile(configRoot + QStringLiteral("/kwinrc"),
            "[Plugins]\nblurEnabled=true\nsquashEnabled=true\ncustomEnabled=true\n"));
    }

    void init()
    {
        auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
        auto plugins = KConfigGroup(config, QStringLiteral("Plugins"));
        plugins.writeEntry("blurEnabled", true, KConfigBase::Notify);
        plugins.writeEntry("squashEnabled", true, KConfigBase::Notify);
        plugins.writeEntry("customEnabled", true, KConfigBase::Notify);
        plugins.deleteEntry(QStringLiteral("magiclampEnabled"), KConfigBase::Notify);
        QVERIFY(config->sync());
        QFile::remove(recoveryPath());
        QFile::remove(legacyRecoveryPath());
        m_kwin.reconfigureCount = 0;
        auto bus = QDBusConnection::sessionBus();
        if (!bus.interface()->isServiceRegistered(QStringLiteral("org.kde.KWin")).value())
            QVERIFY(bus.registerService(QStringLiteral("org.kde.KWin")));
        if (!bus.objectRegisteredAt(QStringLiteral("/KWin")))
            QVERIFY(bus.registerObject(QStringLiteral("/KWin"), &m_kwin, QDBusConnection::ExportAllSlots));
    }

    void discoversExclusiveGroupAndAppliesGlobalSelection()
    {
        auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
        auto plugins = KConfigGroup(config, QStringLiteral("Plugins"));
        {
            KWinMinimizeEffectController controller;
            QVERIFY(controller.available());
            QVERIFY(controller.squashAvailable());
            QVERIFY(controller.magicLampAvailable());
            QCOMPARE(controller.effect(), QStringLiteral("other"));

            QVERIFY(controller.setEffect(QStringLiteral("magiclamp")));
            QCOMPARE(controller.effect(), QStringLiteral("magiclamp"));
            QTRY_COMPARE(m_kwin.reconfigureCount, 1);
            config->reparseConfiguration();
            QVERIFY(plugins.readEntry("magiclampEnabled", false));
            QVERIFY(!plugins.readEntry("squashEnabled", false));
            QVERIFY(!plugins.readEntry("customEnabled", false));
            QVERIFY(plugins.readEntry("blurEnabled", false));
            QVERIFY(QFileInfo::exists(recoveryPath()));
            const auto permissions = QFileInfo(recoveryPath()).permissions();
            QVERIFY(!(permissions & (QFileDevice::ReadGroup | QFileDevice::WriteGroup
                | QFileDevice::ReadOther | QFileDevice::WriteOther)));

            QVERIFY(controller.setEffect(QStringLiteral("none")));
            QCOMPARE(controller.effect(), QStringLiteral("none"));
            QTRY_COMPARE(m_kwin.reconfigureCount, 2);
            config->reparseConfiguration();
            QVERIFY(!plugins.readEntry("magiclampEnabled", false));
            QVERIFY(!plugins.readEntry("squashEnabled", false));
            QVERIFY(!plugins.readEntry("customEnabled", false));
            QVERIFY(plugins.readEntry("blurEnabled", false));
        }
        config->reparseConfiguration();
        QVERIFY(plugins.readEntry("squashEnabled", false));
        QVERIFY(plugins.readEntry("customEnabled", false));
        QVERIFY(!plugins.hasKey(QStringLiteral("magiclampEnabled")));
        QVERIFY(plugins.readEntry("blurEnabled", false));
        QTRY_COMPARE(m_kwin.reconfigureCount, 3);
        QVERIFY(!QFileInfo::exists(recoveryPath()));
    }

    void preservesExternalChangesWhenRestoring()
    {
        auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
        auto plugins = KConfigGroup(config, QStringLiteral("Plugins"));
        {
            KWinMinimizeEffectController controller;
            QVERIFY(controller.setEffect(QStringLiteral("magiclamp")));
            QTRY_COMPARE(m_kwin.reconfigureCount, 1);
            plugins.writeEntry("squashEnabled", true, KConfigBase::Notify);
            QVERIFY(config->sync());
            QVERIFY(KWinMinimizeEffectController::restoreOwnedSettings());
        }
        config->reparseConfiguration();
        QVERIFY(plugins.readEntry("squashEnabled", false));
        QVERIFY(plugins.readEntry("customEnabled", false));
        QVERIFY(!plugins.hasKey(QStringLiteral("magiclampEnabled")));
        QVERIFY(!QFileInfo::exists(recoveryPath()));
        QTRY_COMPARE(m_kwin.reconfigureCount, 2);
    }

    void restoresLegacyRecoveryRecordWithoutLosingIt()
    {
        const QByteArray record = R"({"version":1,"original":{"squash":{"present":true,"value":true},"custom":{"present":true,"value":true},"magiclamp":{"present":false,"value":false}},"written":{"squash":{"present":true,"value":false},"custom":{"present":true,"value":false},"magiclamp":{"present":true,"value":true}}})";
        QVERIFY(writeFile(legacyRecoveryPath(), record));
        auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
        auto plugins = KConfigGroup(config, QStringLiteral("Plugins"));
        plugins.writeEntry("squashEnabled", false, KConfigBase::Notify);
        plugins.writeEntry("customEnabled", false, KConfigBase::Notify);
        plugins.writeEntry("magiclampEnabled", true, KConfigBase::Notify);
        QVERIFY(config->sync());
        QVERIFY(KWinMinimizeEffectController::restoreOwnedSettings());
        QVERIFY(!QFileInfo::exists(legacyRecoveryPath()));
        QVERIFY(!QFileInfo::exists(recoveryPath()));
        config->reparseConfiguration();
        plugins = KConfigGroup(config, QStringLiteral("Plugins"));
        QVERIFY(plugins.readEntry("squashEnabled", false));
        QVERIFY(plugins.readEntry("customEnabled", false));
        QVERIFY(!plugins.hasKey(QStringLiteral("magiclampEnabled")));
    }

    void restoreScriptRecoversSettingsWhenShellIsAlreadyStopped()
    {
        auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
        auto plugins = KConfigGroup(config, QStringLiteral("Plugins"));
        std::unique_ptr<KWinMinimizeEffectController> controller(new KWinMinimizeEffectController);
        QVERIFY(controller->setEffect(QStringLiteral("magiclamp")));
        QTRY_COMPARE(m_kwin.reconfigureCount, 1);
        QVERIFY(QFileInfo::exists(recoveryPath()));

        QTemporaryDir emptyPath;
        QVERIFY(emptyPath.isValid());
        const auto qsPath = emptyPath.path() + QStringLiteral("/qs");
        QVERIFY(writeFile(qsPath, "#!/bin/sh\nprintf '%s\\n' '[]'\n"));
        QVERIFY(QFile::setPermissions(qsPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner
            | QFileDevice::ExeOwner));
        QVERIFY(QFile::link(QStandardPaths::findExecutable(QStringLiteral("dirname")),
            emptyPath.path() + QStringLiteral("/dirname")));
        QProcess process;
        auto environment = QProcessEnvironment::systemEnvironment();
        environment.insert(QStringLiteral("PATH"), emptyPath.path());
        process.setProcessEnvironment(environment);
        process.start(QStringLiteral("/bin/bash"), {QStringLiteral(PUNCHI_RESTORE_SCRIPT)});
        QVERIFY(process.waitForFinished(10000));
        const auto output = process.readAllStandardOutput();
        const auto error = process.readAllStandardError();
        QVERIFY2(process.exitCode() == 0,
            qPrintable(QString::fromLocal8Bit(output + error)));

        config->reparseConfiguration();
        QVERIFY(plugins.readEntry("squashEnabled", false));
        QVERIFY(plugins.readEntry("customEnabled", false));
        QVERIFY(!plugins.hasKey(QStringLiteral("magiclampEnabled")));
        QVERIFY(!QFileInfo::exists(recoveryPath()));
        QTRY_COMPARE(m_kwin.reconfigureCount, 2);
        controller.reset();
    }

    void rejectsUnsupportedEffectsAndTracksExternalConfiguration()
    {
        KWinMinimizeEffectController controller;
        QVERIFY(!controller.setEffect(QStringLiteral("scale")));
        QVERIFY(!controller.setEffect(QStringLiteral("oversized")));
        auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
        auto plugins = KConfigGroup(config, QStringLiteral("Plugins"));
        plugins.writeEntry("customEnabled", false, KConfigBase::Notify);
        plugins.writeEntry("squashEnabled", true, KConfigBase::Notify);
        QVERIFY(config->sync());
        QTRY_COMPARE(controller.effect(), QStringLiteral("squash"));
        QVERIFY(QDBusConnection::sessionBus().unregisterService(QStringLiteral("org.kde.KWin")));
        QTRY_VERIFY(!controller.available());
        QVERIFY(!controller.setEffect(QStringLiteral("none")));
    }
};

QTEST_MAIN(KWinMinimizeEffectTest)
#include "kwin_minimize_effect_test.moc"
