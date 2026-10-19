// SPDX-License-Identifier: GPL-3.0-or-later
#include "registration.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDebug>

namespace {
bool isPunchiRegistration(const QByteArray &content)
{
    bool desktopEntry = false;
    bool name = false;
    bool interfaces = false;
    for (const auto &line : content.split('\n')) {
        if (line == "[Desktop Entry]") desktopEntry = true;
        else if (line == "Name=Punchi Dock Quickshell Window State"
            || line == "Name=Punchi Shell Window State") name = true;
        else if (line == "X-KDE-Wayland-Interfaces=org_kde_plasma_window_management") interfaces = true;
    }
    return desktopEntry && name && interfaces;
}
}

int registerWindowBackend(bool remove)
{
    const auto desktopEntry = [](QString name, QString executable) {
        if (executable.isEmpty() || executable.contains('\n') || executable.contains('\r')) return QByteArray();
        executable.replace('\\', QStringLiteral("\\\\"));
        executable.replace('"', QStringLiteral("\\\""));
        executable.replace('`', QStringLiteral("\\`"));
        executable.replace('$', QStringLiteral("\\$"));
        executable.replace('%', QStringLiteral("%%"));
        return QStringLiteral("[Desktop Entry]\nType=Application\nName=%1\nNoDisplay=true\nTerminal=false\n"
            "Exec=\"%2\"\nX-KDE-Wayland-Interfaces=org_kde_plasma_window_management\n")
            .arg(name, executable).toUtf8();
    };
    const QString executable = QFileInfo(QCoreApplication::applicationFilePath()).canonicalFilePath();
    const QByteArray expected = desktopEntry(QStringLiteral("Punchi Dock Quickshell Window State"), executable);
    if (expected.isEmpty()) return 1;
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/applications");
    const QString path = directory + QStringLiteral("/org.punchi.Shell.WindowState.desktop");
    QFile existing(path);
    bool changed = false;
    if (QFileInfo::exists(path) || QFileInfo(path).isSymLink()) {
        if (QFileInfo(path).isSymLink() || !existing.open(QIODevice::ReadOnly) || existing.size() > 4096) {
            qCritical() << "Window backend registration collision";
            return 1;
        }
        const QByteArray content = existing.readAll();
        existing.close();
        if (content == expected) {
            if (!remove) return 0;
            if (!existing.remove()) return 1;
            changed = true;
        } else if (isPunchiRegistration(content)) {
            if (remove) {
                if (!existing.remove()) return 1;
            } else {
                QSaveFile file(path);
                if (!file.open(QIODevice::WriteOnly) || file.write(expected) != expected.size() || !file.commit())
                    return 1;
            }
            changed = true;
        } else {
            qCritical() << "Window backend registration collision";
            return 1;
        }
    } else {
        if (remove) return 0;
        if (!QDir().mkpath(directory)) return 1;
        QSaveFile file(path);
        if (!file.open(QIODevice::WriteOnly) || file.write(expected) != expected.size() || !file.commit()) return 1;
        changed = true;
    }
    if (!changed) return 0;
    const QString indexer = QStandardPaths::findExecutable(QStringLiteral("kbuildsycoca6"));
    if (indexer.isEmpty()) { qCritical() << "KDE service cache builder unavailable"; return 1; }
    QProcess cache;
    cache.start(indexer, {QStringLiteral("--noincremental")});
    if (!cache.waitForFinished(10000)) { cache.kill(); cache.waitForFinished(); return 1; }
    if (cache.exitStatus() != QProcess::NormalExit || cache.exitCode() != 0) {
        qCritical() << "KDE service cache refresh failed";
        return 1;
    }
    return 0;
}
