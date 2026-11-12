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

    // KWin exposes the output under the cursor as org.kde.KWin.activeOutputName.
    // Quickshell has no portable global cursor API, so the shortcut asks KWin
    // once per activation and treats an empty reply as "unknown".
    Q_INVOKABLE QString activeName() const;
Q_SIGNALS:
    void primaryChanged();
private:
    void refresh();
    QString m_primaryName;
};
