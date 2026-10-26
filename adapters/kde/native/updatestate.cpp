// SPDX-License-Identifier: GPL-3.0-or-later
#include "updatestate.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QProcess>
#include <QTimer>
#include <QVariantMap>

namespace {
// PackageKit and fwupd are optional desktop services: a missing name or a failed
// reply only removes that source from the count.
constexpr auto packageKitService = "org.freedesktop.PackageKit";
constexpr auto packageKitPath = "/org/freedesktop/PackageKit";
constexpr auto packageKitInterface = "org.freedesktop.PackageKit";
constexpr auto transactionInterface = "org.freedesktop.PackageKit.Transaction";
constexpr auto fwupdService = "org.freedesktop.fwupd";
constexpr auto fwupdPath = "/";
constexpr auto fwupdInterface = "org.freedesktop.fwupd";
// FWUPD_DEVICE_FLAG_UPDATABLE from fwupd.h; the headers stay out of the build.
constexpr qulonglong fwupdUpdatableFlag = 1ull << 1;
// PkInfoEnum security value reported by the Package signal (0 unknown .. 7 enhancement).
constexpr uint pkInfoSecurity = 5;
constexpr int initialDelayMs = 1500;
constexpr int refreshDeadlineMs = 60000;
constexpr int flatpakTimeoutMs = 20000;
constexpr int debounceMs = 2000;
constexpr int pollIntervalMs = 6 * 60 * 60 * 1000;

QVariantList mapArray(const QVariant &value)
{
    QVariantList entries;
    const QDBusArgument argument = value.value<QDBusArgument>();
    if (argument.currentType() != QDBusArgument::ArrayType) return entries;
    argument.beginArray();
    while (!argument.atEnd()) {
        QVariantMap entry;
        argument >> entry;
        entries.append(entry);
    }
    argument.endArray();
    return entries;
}
}

UpdateState::UpdateState(QObject *parent) : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::systemBus();
    bus.connect(QString::fromLatin1(packageKitService), QString::fromLatin1(packageKitPath),
        QString::fromLatin1(packageKitInterface), QStringLiteral("UpdatesChanged"), this,
        SLOT(scheduleRefresh()));
    bus.connect(QString::fromLatin1(fwupdService), QString::fromLatin1(fwupdPath),
        QString::fromLatin1(fwupdInterface), QStringLiteral("DeviceChanged"), this,
        SLOT(scheduleRefresh()));

    m_debounce = new QTimer(this);
    m_debounce->setSingleShot(true);
    m_debounce->setInterval(debounceMs);
    connect(m_debounce, &QTimer::timeout, this, &UpdateState::refresh);

    m_deadline = new QTimer(this);
    m_deadline->setSingleShot(true);
    m_deadline->setInterval(refreshDeadlineMs);
    connect(m_deadline, &QTimer::timeout, this, [this] {
        if (m_state != Checking) return;
        abortPending();
        completeRefreshIfDone();
    });

    m_flatpakTimeout = new QTimer(this);
    m_flatpakTimeout->setSingleShot(true);
    m_flatpakTimeout->setInterval(flatpakTimeoutMs);
    connect(m_flatpakTimeout, &QTimer::timeout, this, [this] {
        if (m_flatpak) m_flatpak->kill();
    });

    m_poll = new QTimer(this);
    m_poll->setInterval(pollIntervalMs);
    connect(m_poll, &QTimer::timeout, this, &UpdateState::refresh);
    m_poll->start();

    QTimer::singleShot(initialDelayMs, this, &UpdateState::refresh);
}

UpdateState::~UpdateState()
{
    if (m_flatpak) m_flatpak->kill();
    cancelTransaction();
}

void UpdateState::scheduleRefresh()
{
    m_debounce->start();
}

void UpdateState::refresh()
{
    if (m_state == Checking) return;
    abortPending();
    m_debounce->stop();
    const int generation = ++m_generation;
    m_systemCount = 0;
    m_securityCount = 0;
    m_flatpakCount = 0;
    m_firmwareCount = 0;
    m_firmwareUpgrades = 0;
    m_firmwareRemaining = 0;
    m_systemPending = true;
    m_flatpakPending = true;
    m_firmwarePending = true;
    m_systemOk = false;
    m_flatpakOk = false;
    m_firmwareOk = false;
    m_state = Checking;
    commit();
    m_deadline->start();
    readBackendName(generation);
    startSystem(generation);
    startFlatpak(generation);
    startFirmware(generation);
}

void UpdateState::readBackendName(int generation)
{
    QDBusMessage message = QDBusMessage::createMethodCall(QString::fromLatin1(packageKitService),
        QString::fromLatin1(packageKitPath), QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("Get"));
    message << QString::fromLatin1(packageKitInterface) << QStringLiteral("BackendName");
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *self) {
        self->deleteLater();
        if (generation != m_generation) return;
        const QDBusPendingReply<QDBusVariant> reply = *self;
        const QString name = reply.isError() ? QString() : reply.value().variant().toString();
        if (name == m_backendName) return;
        m_backendName = name;
        commit();
    });
}

void UpdateState::startSystem(int generation)
{
    QDBusMessage message = QDBusMessage::createMethodCall(QString::fromLatin1(packageKitService),
        QString::fromLatin1(packageKitPath), QString::fromLatin1(packageKitInterface),
        QStringLiteral("CreateTransaction"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *self) {
        self->deleteLater();
        if (generation != m_generation || !m_systemPending) return;
        const QDBusPendingReply<QDBusObjectPath> reply = *self;
        const QString path = reply.isError() ? QString() : reply.value().path();
        if (path.isEmpty()) {
            finishSystem(generation, false, 0, 0);
            return;
        }
        m_transactionPath = path;
        QDBusConnection bus = QDBusConnection::systemBus();
        bus.connect(QString::fromLatin1(packageKitService), path,
            QString::fromLatin1(transactionInterface), QStringLiteral("Package"), this,
            SLOT(packageReceived(uint, QString, QString)));
        bus.connect(QString::fromLatin1(packageKitService), path,
            QString::fromLatin1(transactionInterface), QStringLiteral("Finished"), this,
            SLOT(packageKitFinished(uint, uint)));
        bus.connect(QString::fromLatin1(packageKitService), path,
            QString::fromLatin1(transactionInterface), QStringLiteral("ErrorCode"), this,
            SLOT(packageKitError(uint, QString)));
        QDBusMessage hints = QDBusMessage::createMethodCall(QString::fromLatin1(packageKitService),
            path, QString::fromLatin1(transactionInterface), QStringLiteral("SetHints"));
        hints << QStringList{QStringLiteral("background")};
        bus.asyncCall(hints);
        QDBusMessage updates = QDBusMessage::createMethodCall(QString::fromLatin1(packageKitService),
            path, QString::fromLatin1(transactionInterface), QStringLiteral("GetUpdates"));
        updates << QVariant::fromValue<qulonglong>(0);
        bus.asyncCall(updates);
    });
}

void UpdateState::packageReceived(uint info, const QString &, const QString &)
{
    if (!m_systemPending) return;
    ++m_systemCount;
    if (isSecurityInfo(info)) ++m_securityCount;
}

void UpdateState::packageKitFinished(uint exit, uint)
{
    if (!m_systemPending) return;
    const bool success = exit == 1; // PK_EXIT_ENUM_SUCCESS
    cancelTransaction();
    finishSystem(m_generation, success, success ? m_systemCount : 0, success ? m_securityCount : 0);
}

void UpdateState::packageKitError(uint, const QString &)
{
    if (!m_systemPending) return;
    cancelTransaction();
    finishSystem(m_generation, false, 0, 0);
}

void UpdateState::startFlatpak(int generation)
{
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this,
        [this, process, generation](int code, QProcess::ExitStatus status) {
            const QString output = QString::fromUtf8(process->readAllStandardOutput());
            process->deleteLater();
            if (generation != m_generation || !m_flatpakPending) return;
            m_flatpakTimeout->stop();
            const bool ok = status == QProcess::NormalExit && code == 0;
            finishFlatpak(generation, ok, ok ? countFlatpakUpdates(output) : 0);
        });
    connect(process, &QProcess::errorOccurred, this, [this, process, generation](QProcess::ProcessError error) {
        // Other errors surface through finished(); only a missing binary skips it.
        if (error != QProcess::FailedToStart) return;
        process->deleteLater();
        if (generation != m_generation || !m_flatpakPending) return;
        m_flatpakTimeout->stop();
        finishFlatpak(generation, false, 0);
    });
    m_flatpak = process;
    process->start(QStringLiteral("flatpak"),
        {QStringLiteral("remote-ls"), QStringLiteral("--updates"),
            QStringLiteral("--columns=application"), QStringLiteral("--cached")});
    m_flatpakTimeout->start();
}

void UpdateState::startFirmware(int generation)
{
    QDBusMessage message = QDBusMessage::createMethodCall(QString::fromLatin1(fwupdService),
        QString::fromLatin1(fwupdPath), QString::fromLatin1(fwupdInterface), QStringLiteral("GetDevices"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *self) {
        self->deleteLater();
        if (generation != m_generation || !m_firmwarePending) return;
        const QDBusPendingReply<> reply = *self;
        if (reply.isError()) {
            finishFirmware(generation, false, 0);
            return;
        }
        const QStringList devices = updatableDeviceIds(mapArray(reply.reply().arguments().value(0)));
        m_firmwareRemaining = devices.size();
        m_firmwareUpgrades = 0;
        if (devices.isEmpty()) {
            finishFirmware(generation, true, 0);
            return;
        }
        for (const QString &device : devices) {
            QDBusMessage upgrade = QDBusMessage::createMethodCall(QString::fromLatin1(fwupdService),
                QString::fromLatin1(fwupdPath), QString::fromLatin1(fwupdInterface),
                QStringLiteral("GetUpgrades"));
            upgrade << device;
            auto *call = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(upgrade), this);
            connect(call, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *self) {
                self->deleteLater();
                if (generation != m_generation || !m_firmwarePending) return;
                const QDBusPendingReply<> reply = *self;
                if (!reply.isError() && !mapArray(reply.reply().arguments().value(0)).isEmpty())
                    ++m_firmwareUpgrades;
                if (--m_firmwareRemaining > 0) return;
                finishFirmware(generation, true, m_firmwareUpgrades);
            });
        }
    });
}

void UpdateState::finishSystem(int generation, bool success, int count, int securityCount)
{
    if (generation != m_generation) return;
    m_systemPending = false;
    m_systemOk = success;
    m_systemCount = count;
    m_securityCount = securityCount;
    completeRefreshIfDone();
}

void UpdateState::finishFlatpak(int generation, bool success, int count)
{
    if (generation != m_generation) return;
    m_flatpakPending = false;
    m_flatpakOk = success;
    m_flatpakCount = count;
    completeRefreshIfDone();
}

void UpdateState::finishFirmware(int generation, bool success, int count)
{
    if (generation != m_generation) return;
    m_firmwarePending = false;
    m_firmwareOk = success;
    m_firmwareCount = count;
    completeRefreshIfDone();
}

void UpdateState::completeRefreshIfDone()
{
    if (m_systemPending || m_flatpakPending || m_firmwarePending) {
        commit();
        return;
    }
    m_deadline->stop();
    m_state = (m_systemOk || m_flatpakOk || m_firmwareOk) ? Ready : Unavailable;
    m_transactionPath.clear();
    commit();
}

void UpdateState::abortPending()
{
    m_systemPending = false;
    m_flatpakPending = false;
    m_firmwarePending = false;
    m_firmwareRemaining = 0;
    m_flatpakTimeout->stop();
    if (m_flatpak) {
        QProcess *process = m_flatpak;
        m_flatpak = nullptr;
        process->kill();
    }
    cancelTransaction();
}

void UpdateState::cancelTransaction()
{
    if (m_transactionPath.isEmpty()) return;
    const QString path = m_transactionPath;
    m_transactionPath.clear();
    QDBusConnection bus = QDBusConnection::systemBus();
    const QString service = QString::fromLatin1(packageKitService);
    const QString interface = QString::fromLatin1(transactionInterface);
    bus.disconnect(service, path, interface, QStringLiteral("Package"), this,
        SLOT(packageReceived(uint, QString, QString)));
    bus.disconnect(service, path, interface, QStringLiteral("Finished"), this,
        SLOT(packageKitFinished(uint, uint)));
    bus.disconnect(service, path, interface, QStringLiteral("ErrorCode"), this,
        SLOT(packageKitError(uint, QString)));
    QDBusMessage cancel = QDBusMessage::createMethodCall(service, path, interface,
        QStringLiteral("Cancel"));
    bus.asyncCall(cancel);
}

void UpdateState::commit()
{
    ++m_revision;
    emit changed();
}

QStringList UpdateState::updatableDeviceIds(const QVariantList &devices)
{
    QStringList ids;
    for (const QVariant &entry : devices) {
        const QVariantMap device = entry.toMap();
        bool flagOk = false;
        const qulonglong flags = device.value(QStringLiteral("Flags")).toULongLong(&flagOk);
        const QString id = device.value(QStringLiteral("DeviceId")).toString();
        if (!flagOk || id.isEmpty() || !(flags & fwupdUpdatableFlag)) continue;
        if (!ids.contains(id)) ids.append(id);
    }
    return ids;
}

bool UpdateState::isSecurityInfo(uint info)
{
    return info == pkInfoSecurity;
}

int UpdateState::countFlatpakUpdates(const QString &output)
{
    int found = 0;
    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines)
        if (!line.trimmed().isEmpty()) ++found;
    return found;
}
