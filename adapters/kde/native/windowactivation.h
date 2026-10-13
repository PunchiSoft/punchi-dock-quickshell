// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QProcess>
#include <QJsonObject>
#include <QHash>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Command domain over the provider-owned pipe; no window indices leave KDE.
class WindowActivation : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool available READ available NOTIFY changed)
public:
    explicit WindowActivation(QProcess *process, QObject *parent);
    bool available() const { return m_available; }
    void setAvailable(bool value);
    bool acceptResult(const QJsonObject &object);
    Q_INVOKABLE int requestActivate(const QString &desktopId);
    Q_INVOKABLE int requestNewInstance(const QString &desktopId);
signals:
    void changed();
    void finished(int requestId, const QString &desktopId, const QString &status);
private:
    struct Pending { QString desktopId; QTimer *timer; };
    void complete(int requestId, const QString &status);
    int request(const QString &desktopId, const QString &type);
    QProcess *m_process;
    QHash<int, Pending> m_pending;
    bool m_available = false;
    int m_nextId = 0;
};
