// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QDBusConnection>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QVariantList>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

class QDBusServiceWatcher;

// PowerDevil screen-brightness boundary. PowerDevil owns the backlight and DDC
// paths; the panel only reads the per-display properties and asks it to set a
// value inside the reported range. No generic sysfs write exists here.
class ScreenBrightnessControl : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool monitoring READ monitoring WRITE setMonitoring NOTIFY monitoringChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QVariantList displays READ displays NOTIFY displaysChanged)
    Q_PROPERTY(bool pending READ pending NOTIFY pendingChanged)
    Q_PROPERTY(QString lastTarget READ lastTarget NOTIFY lastResultChanged)
    Q_PROPERTY(int lastPercent READ lastPercent NOTIFY lastResultChanged)
    Q_PROPERTY(bool lastSuccess READ lastSuccess NOTIFY lastResultChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastResultChanged)
public:
    explicit ScreenBrightnessControl(QObject *parent = nullptr);

    bool monitoring() const { return m_monitoring; }
    void setMonitoring(bool monitoring);
    bool available() const { return m_available; }
    QVariantList displays() const { return m_displays; }
    bool pending() const { return m_pending; }
    QString lastTarget() const { return m_lastTarget; }
    int lastPercent() const { return m_lastPercent; }
    bool lastSuccess() const { return m_lastSuccess; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool setPercent(const QString &displayId, int percent);

signals:
    void monitoringChanged();
    void availableChanged();
    void displaysChanged();
    void pendingChanged();
    void lastResultChanged();
    void operationFinished(const QString &displayId, int percent, bool success,
        const QString &error);

private slots:
    void onServiceOwnerChanged(const QString &service, const QString &oldOwner,
        const QString &newOwner);
    void onPropertiesChanged(const QString &interfaceName, const QVariantMap &changed,
        const QStringList &invalidated);
    void onRefreshTimeout();
    void onCommitTimeout();

private:
    void subscribeController();
    void subscribeDisplay(const QString &path);
    void rebuild();
    QStringList displayNames() const;
    QVariantMap displayProperties(const QString &displayId) const;
    int readBrightness(const QString &displayId) const;
    QVariantMap findDisplay(const QString &displayId) const;
    void setPending(bool pending);
    void writeDisplay(const QString &displayId, int percent);
    void finishOperation(const QString &displayId, int percent, bool success,
        const QString &error);
    void setAvailable(bool available);
    QString errorCode(const QString &name) const;
    static QString displayPath(const QString &displayId);

    QDBusConnection m_bus = QDBusConnection::sessionBus();
    QDBusServiceWatcher *m_watcher = nullptr;
    QSet<QString> m_subscribed;
    QTimer m_refreshTimer;
    QTimer m_commitTimer;
    QHash<QString, int> m_requested;
    QVariantList m_displays;
    bool m_monitoring = false;
    bool m_available = false;
    bool m_pending = false;
    QString m_lastTarget;
    int m_lastPercent = 0;
    bool m_lastSuccess = false;
    QString m_lastError;
};
