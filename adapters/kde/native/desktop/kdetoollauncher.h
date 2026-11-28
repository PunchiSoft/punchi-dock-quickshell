// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// Complementary KDE entry points of the top panel. Every target is a fixed
// identifier: KRunner, the Bluetooth pairing wizard and a small allowlist of
// settings modules. Programs are started detached with an argument list and
// never through a shell.
class KdeToolLauncher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit KdeToolLauncher(QObject *parent = nullptr);

    // Shows the running KRunner through its D-Bus interface; when no instance
    // owns org.kde.krunner the fixed executable is started instead.
    Q_INVOKABLE bool launchKRunner();
    // The KDE pairing wizard owns discovery and the BlueZ agent, so Punchi only
    // opens it and never registers an agent of its own.
    Q_INVOKABLE bool launchBluetoothWizard();
    // Fixed module identifiers verified with kcmshell6 --list on the tested
    // Plasma release. An unknown identifier is rejected before any process.
    Q_INVOKABLE bool openSettingsModule(const QString &moduleId) const;
    Q_INVOKABLE bool settingsModuleSupported(const QString &moduleId) const;

    static QStringList supportedSettingsModules();
    static bool startDetachedProgram(const QString &program, const QStringList &arguments);

private:
    static bool startDetachedExecutable(const QString &name, const QStringList &arguments);
};
