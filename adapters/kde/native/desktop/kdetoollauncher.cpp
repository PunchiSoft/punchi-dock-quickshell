// SPDX-License-Identifier: GPL-3.0-or-later
#include "kdetoollauncher.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QProcess>
#include <QStandardPaths>

namespace {
const QStringList kSettingsModules = {
    QStringLiteral("kcm_networkmanagement"),
    QStringLiteral("kcm_bluetooth"),
    QStringLiteral("kcm_pulseaudio"),
    QStringLiteral("kcm_device_automounter"),
    QStringLiteral("kcm_solid_actions"),
};
}

KdeToolLauncher::KdeToolLauncher(QObject *parent) : QObject(parent) {}

QStringList KdeToolLauncher::supportedSettingsModules()
{
    return kSettingsModules;
}

bool KdeToolLauncher::settingsModuleSupported(const QString &moduleId) const
{
    // Empty identifiers and anything outside the allowlist are refused; no
    // caller string ever becomes a command or a shell fragment.
    return kSettingsModules.contains(moduleId);
}

bool KdeToolLauncher::startDetachedProgram(const QString &program, const QStringList &arguments)
{
    if (program.isEmpty()) return false;
    return QProcess::startDetached(program, arguments);
}

bool KdeToolLauncher::startDetachedExecutable(const QString &name, const QStringList &arguments)
{
    const QString executable = QStandardPaths::findExecutable(name);
    if (executable.isEmpty()) return false;
    return startDetachedProgram(executable, arguments);
}

bool KdeToolLauncher::launchKRunner()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()
            && bus.interface()->isServiceRegistered(QStringLiteral("org.kde.krunner"))) {
        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("org.kde.krunner"), QStringLiteral("/App"),
            QStringLiteral("org.kde.krunner.App"), QStringLiteral("display"));
        // The call is asynchronous: one request per gesture, no blocking of the
        // shell, and the provider owns activation and placement.
        if (bus.send(message)) return true;
    }
    return startDetachedExecutable(QStringLiteral("krunner"), {});
}

bool KdeToolLauncher::launchBluetoothWizard()
{
    return startDetachedExecutable(QStringLiteral("bluedevil-wizard"), {});
}

bool KdeToolLauncher::openSettingsModule(const QString &moduleId) const
{
    if (!settingsModuleSupported(moduleId)) return false;
    return startDetachedExecutable(QStringLiteral("kcmshell6"), {moduleId});
}
