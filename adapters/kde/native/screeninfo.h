// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QString>
#include <qqmlintegration.h>

// Read-only desktop topology that Quickshell does not expose: the connector
// name of the screen the session treats as primary. Used as the fallback when
// every configured screen is disconnected.
class ScreenInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString primaryName READ primaryName NOTIFY primaryChanged)
public:
    explicit ScreenInfo(QObject *parent = nullptr);
    QString primaryName() const { return m_primaryName; }
Q_SIGNALS:
    void primaryChanged();
private:
    void refresh();
    QString m_primaryName;
};
