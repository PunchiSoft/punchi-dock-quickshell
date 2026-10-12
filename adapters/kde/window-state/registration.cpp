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

int registerWindowBackend(bool remove)
{
    QString executable = QFileInfo(QCoreApplication::applicationFilePath()).canonicalFilePath();
    if (executable.isEmpty() || executable.contains('\n') || executable.contains('\r')) return 1;
    executable.replace('\\', QStringLiteral("\\\\"));
    executable.replace('"', QStringLiteral("\\\""));
    executable.replace('`', QStringLiteral("\\`"));
    executable.replace('$', QStringLiteral("\\$"));
    executable.replace('%', QStringLiteral("%%"));
    const QByteArray expected = QStringLiteral("[Desktop Entry]\nType=Application\n"
        "Name=Punchi Shell Window State\nNoDisplay=true\nTerminal=false\n"
        "Exec=\"%1\"\nX-KDE-Wayland-Interfaces=org_kde_plasma_window_management;\n")
        .arg(executable).toUtf8();
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/applications");
    const QString path = directory + QStringLiteral("/org.punchi.Shell.WindowState.desktop");
    QFile existing(path);
    if (QFileInfo::exists(path) || QFileInfo(path).isSymLink()) {
        if (QFileInfo(path).isSymLink() || !existing.open(QIODevice::ReadOnly)
            || existing.size() > 4096 || existing.readAll() != expected) {
            qCritical() << "Window backend registration collision";
            return 1;
        }
        existing.close();
        if (!remove) return 0;
        if (!existing.remove()) return 1;
    } else {
        if (remove) return 0;
        if (!QDir().mkpath(directory)) return 1;
        QSaveFile file(path);
        if (!file.open(QIODevice::WriteOnly) || file.write(expected) != expected.size() || !file.commit()) return 1;
    }
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
