// SPDX-License-Identifier: GPL-3.0-or-later
#include "screeninfo.h"
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
