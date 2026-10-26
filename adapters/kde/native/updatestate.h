// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QProcess;
class QTimer;

// Read-only aggregation of pending updates reported by PackageKit, fwupd and
// Flatpak. It never installs, refreshes caches or requests authorization.
class UpdateState : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(State state READ state NOTIFY changed)
    Q_PROPERTY(bool checking READ checking NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(int count READ count NOTIFY changed)
    Q_PROPERTY(int securityCount READ securityCount NOTIFY changed)
    Q_PROPERTY(int systemCount READ systemCount NOTIFY changed)
    Q_PROPERTY(int flatpakCount READ flatpakCount NOTIFY changed)
    Q_PROPERTY(int firmwareCount READ firmwareCount NOTIFY changed)
    // Which sources answered the last check. They differ per distribution and
    // per installation, so the UI can explain what the count really covers.
    Q_PROPERTY(bool systemAvailable READ systemAvailable NOTIFY changed)
    Q_PROPERTY(bool flatpakAvailable READ flatpakAvailable NOTIFY changed)
    Q_PROPERTY(bool firmwareAvailable READ firmwareAvailable NOTIFY changed)
    // Backend reported by PackageKit (dnf5, apt, alpm, zypper...), so callers
    // never need distribution detection of their own.
    Q_PROPERTY(QString backendName READ backendName NOTIFY changed)

public:
    enum State { Unknown, Checking, Ready, Unavailable };
    Q_ENUM(State)

    explicit UpdateState(QObject *parent = nullptr);
    ~UpdateState() override;

    State state() const { return m_state; }
    bool checking() const { return m_state == Checking; }
    int revision() const { return m_revision; }
    int count() const { return m_systemCount + m_flatpakCount + m_firmwareCount; }
    int securityCount() const { return m_securityCount; }
    int systemCount() const { return m_systemCount; }
    int flatpakCount() const { return m_flatpakCount; }
    int firmwareCount() const { return m_firmwareCount; }
    bool systemAvailable() const { return m_systemOk; }
    bool flatpakAvailable() const { return m_flatpakOk; }
    bool firmwareAvailable() const { return m_firmwareOk; }
    QString backendName() const { return m_backendName; }

    Q_INVOKABLE void refresh();

    // Pure helpers, exercised by the native test without a live bus.
    static QStringList updatableDeviceIds(const QVariantList &devices);
    static bool isSecurityInfo(uint info);
    static int countFlatpakUpdates(const QString &output);

signals:
    void changed();

private slots:
    void scheduleRefresh();
    void packageReceived(uint info, const QString &packageId, const QString &summary);
    void packageKitFinished(uint exit, uint runtime);
    void packageKitError(uint code, const QString &details);

private:
    void readBackendName(int generation);
    void startSystem(int generation);
    void startFlatpak(int generation);
    void startFirmware(int generation);
    void finishSystem(int generation, bool success, int count, int securityCount);
    void finishFlatpak(int generation, bool success, int count);
    void finishFirmware(int generation, bool success, int count);
    void completeRefreshIfDone();
    void abortPending();
    void cancelTransaction();
    void commit();

    State m_state = Unknown;
    int m_revision = 0;
    int m_generation = 0;
    int m_systemCount = 0;
    int m_securityCount = 0;
    int m_flatpakCount = 0;
    int m_firmwareCount = 0;
    int m_firmwareUpgrades = 0;
    int m_firmwareRemaining = 0;
    bool m_systemPending = false;
    bool m_systemOk = false;
    bool m_flatpakPending = false;
    bool m_flatpakOk = false;
    bool m_firmwarePending = false;
    bool m_firmwareOk = false;
    QString m_transactionPath;
    QString m_backendName;
    QPointer<QProcess> m_flatpak;
    QTimer *m_debounce = nullptr;
    QTimer *m_deadline = nullptr;
    QTimer *m_flatpakTimeout = nullptr;
    QTimer *m_poll = nullptr;
};
