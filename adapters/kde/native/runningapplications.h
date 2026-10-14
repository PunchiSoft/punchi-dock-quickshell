// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QProcess>
#include <QSet>
#include <QtQml/qqmlregistration.h>
#include <QQmlParserStatus>
#include "windowvisibilitystate.h"
#include "windowactivation.h"

class RunningApplications : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString executable READ executable WRITE setExecutable NOTIFY executableChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QStringList desktopIds READ desktopIds NOTIFY changed)
    Q_PROPERTY(QVariantList applicationEntries READ applicationEntries NOTIFY changed)
    Q_PROPERTY(WindowVisibilityState *visibilityState READ visibilityState CONSTANT)
    Q_PROPERTY(WindowActivation *windowActivation READ windowActivation CONSTANT)
public:
    explicit RunningApplications(QObject *parent = nullptr);
    ~RunningApplications() override;
    QString executable() const { return m_executable; }
    bool enabled() const { return m_enabled; }
    bool available() const { return m_available; }
    int revision() const { return m_revision; }
    QStringList desktopIds() const { auto ids = m_ids.values(); ids.sort(); return ids; }
    QVariantList applicationEntries() const { return m_applicationEntries; }
    WindowVisibilityState *visibilityState() { return &m_visibility; }
    WindowActivation *windowActivation() { return &m_activation; }
    void setExecutable(const QString &value);
    void setEnabled(bool value);
    Q_INVOKABLE bool isRunning(const QString &desktopId) const;
    void classBegin() override {}
    void componentComplete() override { m_complete = true; restart(); }
signals:
    void changed();
    void executableChanged();
    void enabledChanged();
private:
    void restart();
    void stop();
    void consume();
    void update(bool available, const QSet<QString> &ids = {}, const QVariantList &applicationEntries = {});
    QProcess m_process;
    QString m_executable;
    QByteArray m_buffer;
    QSet<QString> m_ids;
    QVariantList m_applicationEntries;
    WindowVisibilityState m_visibility;
    WindowActivation m_activation;
    bool m_enabled = false;
    bool m_available = false;
    bool m_complete = false;
    bool m_stopping = false;
    int m_revision = 0;
};
