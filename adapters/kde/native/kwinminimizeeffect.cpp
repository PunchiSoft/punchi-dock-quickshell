// SPDX-License-Identifier: GPL-3.0-or-later
#include "kwinminimizeeffect.h"

#include <KConfig>
#include <KConfigGroup>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusServiceWatcher>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QMap>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>

namespace {
constexpr qint64 MaximumMetadataBytes = 1024 * 1024;
constexpr qint64 MaximumOwnershipBytes = 64 * 1024;

struct ConfigValue {
    bool present = false;
    bool value = false;
};

struct OwnershipRecord {
    QMap<QString, ConfigValue> original;
    QMap<QString, ConfigValue> written;
};

bool validPluginId(const QString &id)
{
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9_.-]{1,128}$"));
    return pattern.match(id).hasMatch();
}

QString ownershipPath()
{
    QString stateHome = qEnvironmentVariable("XDG_STATE_HOME");
    if (stateHome.isEmpty() || !QDir::isAbsolutePath(stateHome)) {
        stateHome = QDir::home().filePath(QStringLiteral(".local/state"));
    }
    return QDir(stateHome).filePath(QStringLiteral("punchi-dock-quickshell/owned-settings.json"));
}

QString legacyOwnershipPath()
{
    QString stateHome = qEnvironmentVariable("XDG_STATE_HOME");
    if (stateHome.isEmpty() || !QDir::isAbsolutePath(stateHome)) {
        stateHome = QDir::home().filePath(QStringLiteral(".local/state"));
    }
    return QDir(stateHome).filePath(QStringLiteral("punchi-shell/owned-settings.json"));
}

ConfigValue readValue(const KConfigGroup &group, const QString &pluginId)
{
    const auto key = pluginId + QStringLiteral("Enabled");
    return {group.hasKey(key), group.readEntry(key, false)};
}

QJsonObject encodeValues(const QMap<QString, ConfigValue> &values)
{
    QJsonObject object;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        object.insert(it.key(), QJsonObject{
            {QStringLiteral("present"), it.value().present},
            {QStringLiteral("value"), it.value().value}});
    }
    return object;
}

bool decodeValues(const QJsonValue &value, QMap<QString, ConfigValue> &values)
{
    if (!value.isObject()) return false;
    const auto object = value.toObject();
    if (object.size() > 512) return false;
    for (auto it = object.begin(); it != object.end(); ++it) {
        if (!validPluginId(it.key()) || !it.value().isObject()) return false;
        const auto entry = it.value().toObject();
        if (!entry.value(QStringLiteral("present")).isBool()
            || !entry.value(QStringLiteral("value")).isBool()) return false;
        values.insert(it.key(), {entry.value(QStringLiteral("present")).toBool(),
            entry.value(QStringLiteral("value")).toBool()});
    }
    return true;
}

QByteArray encodeRecord(const OwnershipRecord &record)
{
    const QJsonObject object{
        {QStringLiteral("version"), 1},
        {QStringLiteral("original"), encodeValues(record.original)},
        {QStringLiteral("written"), encodeValues(record.written)}};
    return QJsonDocument(object).toJson(QJsonDocument::Compact);
}

bool readRecord(OwnershipRecord &record, bool &exists, QString *sourcePath = nullptr)
{
    auto path = ownershipPath();
    if (!QFileInfo(path).exists() && !QFileInfo(path).isSymLink()) path = legacyOwnershipPath();
    if (sourcePath) *sourcePath = path;
    const QFileInfo info(path);
    exists = info.exists() || info.isSymLink();
    if (!exists) return true;
    if (info.isSymLink() || !info.isFile() || info.size() > MaximumOwnershipBytes) return false;

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return false;
    const auto bytes = file.read(MaximumOwnershipBytes + 1);
    if (file.error() != QFileDevice::NoError || bytes.size() > MaximumOwnershipBytes) return false;

    QJsonParseError error;
    const auto document = QJsonDocument::fromJson(bytes, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) return false;
    const auto object = document.object();
    if (object.value(QStringLiteral("version")).toInt() != 1
        || !decodeValues(object.value(QStringLiteral("original")), record.original)
        || !decodeValues(object.value(QStringLiteral("written")), record.written)) return false;
    for (auto it = record.written.cbegin(); it != record.written.cend(); ++it) {
        if (!record.original.contains(it.key())) return false;
    }
    return true;
}

bool saveRecord(const OwnershipRecord &record)
{
    const auto bytes = encodeRecord(record);
    if (bytes.size() > MaximumOwnershipBytes) return false;
    const auto path = ownershipPath();
    if (QFileInfo(path).isSymLink() || !QDir().mkpath(QFileInfo(path).absolutePath())) return false;
    QSaveFile file(path);
    file.setDirectWriteFallback(false);
    if (!file.open(QIODevice::WriteOnly)) return false;
    if (!file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner)
        || file.write(bytes) != bytes.size()) {
        file.cancelWriting();
        return false;
    }
    return file.commit();
}

bool removeRecord(const QString &path = ownershipPath())
{
    if (!QFileInfo::exists(path) && !QFileInfo(path).isSymLink()) return true;
    if (QFileInfo(path).isSymLink()) return false;
    return QFile::remove(path);
}

QString pluginIdFromMetadata(const QString &path, const QString &fallback)
{
    QFile metadata(path);
    if (!metadata.open(QIODevice::ReadOnly) || metadata.size() > MaximumMetadataBytes) return {};
    const auto bytes = metadata.read(MaximumMetadataBytes + 1);
    if (metadata.error() != QFileDevice::NoError || bytes.size() > MaximumMetadataBytes) return {};

    QJsonParseError error;
    const auto document = QJsonDocument::fromJson(bytes, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) return {};
    const auto object = document.object();
    if (object.value(QStringLiteral("org.kde.kwin.effect")).toObject()
            .value(QStringLiteral("exclusiveGroup")).toString() != QStringLiteral("minimize")) return {};
    const auto id = object.value(QStringLiteral("KPlugin")).toObject()
        .value(QStringLiteral("Id")).toString(fallback);
    return validPluginId(id) ? id : QString();
}

QStringList minimizeEffectIds()
{
    QSet<QString> ids;
    for (const auto &dataRoot : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)) {
        const QDir root(dataRoot);
        for (const auto &kwinDirectory : root.entryList({QStringLiteral("kwin*")}, QDir::Dirs | QDir::NoDotAndDotDot)) {
            const auto pluginRoot = root.filePath(kwinDirectory);
            const auto effectsPath = QDir(pluginRoot).filePath(QStringLiteral("effects"));
            QDirIterator effects(effectsPath, {QStringLiteral("metadata.json")}, QDir::Files,
                QDirIterator::Subdirectories);
            while (effects.hasNext()) {
                const auto path = effects.next();
                const auto id = pluginIdFromMetadata(path, QFileInfo(QFileInfo(path).absolutePath()).fileName());
                if (!id.isEmpty()) ids.insert(id);
            }

            const auto builtinPath = QDir(pluginRoot).filePath(QStringLiteral("builtin-effects"));
            QDirIterator builtins(builtinPath, {QStringLiteral("*.json")}, QDir::Files);
            while (builtins.hasNext()) {
                const auto path = builtins.next();
                const auto id = pluginIdFromMetadata(path, QFileInfo(path).completeBaseName());
                if (!id.isEmpty()) ids.insert(id);
            }
        }
    }
    auto result = ids.values();
    result.sort(Qt::CaseSensitive);
    return result;
}

bool kwinServiceAvailable()
{
    const auto bus = QDBusConnection::sessionBus();
    const auto *interface = bus.interface();
    return bus.isConnected() && interface && interface->isServiceRegistered(QStringLiteral("org.kde.KWin")).value();
}

void requestKWinReconfigure(QObject *owner = nullptr)
{
    const auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"), QStringLiteral("reconfigure"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, 2000), owner);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, watcher,
        [watcher](QDBusPendingCallWatcher *call) {
            if (call->isError()) qWarning() << "KWin reconfigure failed:" << call->error().message();
            call->deleteLater();
        });
}
}

KWinMinimizeEffectController::KWinMinimizeEffectController(QObject *parent)
    : QObject(parent)
    , m_config(KSharedConfig::openConfig(QStringLiteral("kwinrc")))
    , m_watcher(KConfigWatcher::create(m_config))
{
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this,
        [this](const KConfigGroup &group, const QByteArrayList &) {
            if (group.name() == QStringLiteral("Plugins")) {
                m_minimizePlugins = minimizeEffectIds();
                emit effectsChanged();
                refresh();
            }
        });
    auto *serviceWatcher = new QDBusServiceWatcher(QStringLiteral("org.kde.KWin"),
        QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(serviceWatcher, &QDBusServiceWatcher::serviceOwnerChanged, this,
        [this](const QString &, const QString &, const QString &) { refreshAvailability(); });
    m_minimizePlugins = minimizeEffectIds();
    refreshAvailability();
    refresh();
}

KWinMinimizeEffectController::~KWinMinimizeEffectController()
{
    if (!restoreOwnedSettings()) qWarning() << "Punchi Dock Quickshell could not restore its owned KWin settings";
}

bool KWinMinimizeEffectController::setEffect(const QString &effect)
{
    if (!m_available || (effect != QStringLiteral("none")
            && !m_minimizePlugins.contains(effect))) return false;

    m_config->reparseConfiguration();
    auto plugins = KConfigGroup(m_config, QStringLiteral("Plugins"));
    OwnershipRecord record;
    bool hasRecord = false;
    QString sourcePath;
    if (!readRecord(record, hasRecord, &sourcePath)) {
        qWarning() << "Punchi Dock Quickshell refused to modify KWin settings because its recovery record is invalid";
        return false;
    }

    for (const auto &pluginId : m_minimizePlugins) {
        if (!record.original.contains(pluginId)) record.original.insert(pluginId, readValue(plugins, pluginId));
    }

    bool changed = false;
    for (const auto &pluginId : m_minimizePlugins) {
        const auto key = pluginId + QStringLiteral("Enabled");
        const bool target = pluginId == effect;
        const auto current = readValue(plugins, pluginId);
        if (current.value != target) {
            plugins.writeEntry(key, target, KConfigBase::Notify);
            record.written.insert(pluginId, {true, target});
            changed = true;
        } else if (record.written.contains(pluginId)) {
            record.written.insert(pluginId, current);
        }
    }

    if (record.written.isEmpty()) {
        if (hasRecord && !removeRecord()) return false;
        refresh();
        return true;
    }
    if (!saveRecord(record)) {
        qWarning() << "Punchi Dock Quickshell could not persist the KWin settings recovery record";
        return false;
    }
    if (hasRecord && sourcePath == legacyOwnershipPath()
        && !removeRecord(legacyOwnershipPath())) return false;
    if (changed && !m_config->sync()) {
        m_config->reparseConfiguration();
        refresh();
        return false;
    }

    m_config->reparseConfiguration();
    refresh();
    if (changed) requestKWinReconfigure(this);
    return true;
}

bool KWinMinimizeEffectController::restoreOwnedSettings()
{
    OwnershipRecord record;
    bool exists = false;
    QString sourcePath;
    if (!readRecord(record, exists, &sourcePath)) {
        qWarning() << "Punchi Dock Quickshell found an invalid KWin settings recovery record";
        return false;
    }
    if (!exists) return true;

    auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    config->reparseConfiguration();
    auto plugins = KConfigGroup(config, QStringLiteral("Plugins"));
    bool changed = false;
    for (auto it = record.written.cbegin(); it != record.written.cend(); ++it) {
        const auto current = readValue(plugins, it.key());
        if (current.present != it.value().present || current.value != it.value().value) continue;
        const auto original = record.original.value(it.key());
        const auto key = it.key() + QStringLiteral("Enabled");
        if (original.present) plugins.writeEntry(key, original.value, KConfigBase::Notify);
        else plugins.deleteEntry(key, KConfigBase::Notify);
        changed = true;
    }

    if (changed && !config->sync()) return false;
    if (!removeRecord(sourcePath)) return false;
    if (changed && kwinServiceAvailable()) requestKWinReconfigure();
    return true;
}

void KWinMinimizeEffectController::refresh()
{
    const auto plugins = KConfigGroup(m_config, QStringLiteral("Plugins"));
    QStringList enabled;
    for (const auto &pluginId : m_minimizePlugins) {
        if (plugins.readEntry(pluginId + QStringLiteral("Enabled"), false)) enabled.append(pluginId);
    }

    const auto effect = enabled.isEmpty() ? QStringLiteral("none")
        : enabled.size() == 1 && (enabled.first() == QStringLiteral("squash")
            || enabled.first() == QStringLiteral("magiclamp")) ? enabled.first() : QStringLiteral("other");
    if (effect == m_effect) return;
    m_effect = effect;
    emit effectChanged();
}

void KWinMinimizeEffectController::refreshAvailability()
{
    const bool available = kwinServiceAvailable();
    if (available == m_available) return;
    m_available = available;
    emit availableChanged();
}
