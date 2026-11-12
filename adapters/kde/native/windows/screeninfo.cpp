// SPDX-License-Identifier: GPL-3.0-or-later
#include "screeninfo.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QGuiApplication>
#include <QScreen>

ScreenInfo::ScreenInfo(QObject *parent)
    : QObject(parent)
{
    refresh();
    connect(qGuiApp, &QGuiApplication::primaryScreenChanged, this, &ScreenInfo::refresh);
    connect(qGuiApp, &QGuiApplication::screenAdded, this, &ScreenInfo::refresh);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, &ScreenInfo::refresh);
}

void ScreenInfo::refresh()
{
    const auto *screen = QGuiApplication::primaryScreen();
    const QString name = screen ? screen->name() : QString();
    if (name == m_primaryName) return;
    m_primaryName = name;
    Q_EMIT primaryChanged();
}

QString ScreenInfo::activeName() const
{
    const QDBusMessage reply = QDBusConnection::sessionBus().call(
        QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
            QStringLiteral("/KWin"), QStringLiteral("org.kde.KWin"),
            QStringLiteral("activeOutputName")),
        QDBus::Block, 100);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
        return {};
    return reply.arguments().constFirst().toString();
}
