// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QFile>
#include <QTemporaryDir>
#include "adapters/kde/native/recentapplicationsadapter.h"

// kactivitymanagerd's StatsPlugin::WhatToRemember values.
class RecentApplicationsTrackingTest : public QObject {
    Q_OBJECT
    static constexpr auto ScoringGroup = "Plugin-org.kde.ActivityManager.Resources.Scoring";
    QTemporaryDir m_configHome;
    static QString configPath() {
        return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
            + QStringLiteral("/kactivitymanagerd-pluginsrc");
    }
    static void writeWhatToRemember(int value) {
        QFile file(configPath());
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
        file.write(QByteArray("[") + ScoringGroup + "]\nwhat-to-remember="
            + QByteArray::number(value) + '\n');
        file.close();
    }
private slots:
    void initTestCase() {
        QVERIFY(m_configHome.isValid());
        qputenv("XDG_CONFIG_HOME", m_configHome.path().toUtf8());
        QDir().mkpath(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation));
    }
    void trackingFollowsTheKdeSetting() {
        writeWhatToRemember(0);
        RecentApplicationsAdapter adapter;
        QCOMPARE(adapter.trackingEnabled(), true);
        writeWhatToRemember(2);
        QTRY_COMPARE(adapter.trackingEnabled(), false);
        writeWhatToRemember(1);
        QTRY_COMPARE(adapter.trackingEnabled(), true);
    }
    void missingConfigurationKeepsTrackingEnabled() {
        QFile::remove(configPath());
        RecentApplicationsAdapter adapter;
        QCOMPARE(adapter.trackingEnabled(), true);
    }
};
QTEST_GUILESS_MAIN(RecentApplicationsTrackingTest)
#include "recent_applications_tracking_test.moc"
