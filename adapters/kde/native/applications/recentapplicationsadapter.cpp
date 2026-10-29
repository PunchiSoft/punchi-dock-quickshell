// SPDX-License-Identifier: GPL-3.0-or-later
#include "recentapplicationsadapter.h"

#include <KConfig>
#include <KConfigGroup>
#include <KIO/ApplicationLauncherJob>
#include <KService>
#include <KSycoca>
#include <PlasmaActivities/Consumer>
#include <PlasmaActivities/ResourceInstance>
#include <PlasmaActivities/Stats/ResultModel>
#include <PlasmaActivities/Stats/Terms>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

namespace {
// Matches kactivitymanagerd's StatsPlugin::WhatToRemember: AllApplications = 0,
// SpecificApplications = 1, NoApplications = 2.
constexpr int NoApplications = 2;
constexpr auto ScoringGroup = "Plugin-org.kde.ActivityManager.Resources.Scoring";
constexpr auto WhatToRemember = "what-to-remember";
}

RecentApplicationsAdapter::RecentApplicationsAdapter(QObject *parent)
    : QIdentityProxyModel(parent)
    , m_configPath(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
          + QStringLiteral("/kactivitymanagerd-pluginsrc"))
    , m_configWatcher(new QFileSystemWatcher(this))
{
    // KConfigWatcher depends on a session-bus notification the writer must
    // send, so watch the file KDE rewrites instead and fall back to the
    // directory for atomic replacement.
    connect(m_configWatcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        reloadTracking();
        watchConfiguration();
    });
    connect(m_configWatcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        reloadTracking();
        watchConfiguration();
    });
    watchConfiguration();
    reloadTracking();
    // The history service is owned for the adapter's lifetime: reporting KDE
    // launches must not depend on whether the dock list is visible.
    m_consumer = new KActivities::Consumer(this);
    connect(m_consumer, &KActivities::Consumer::serviceStatusChanged, this, [this]() {
        updateSource();
        emit availabilityChanged();
    });
    connect(m_consumer, &KActivities::Consumer::currentActivityChanged, this,
        &RecentApplicationsAdapter::updateSource);
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, [this]() {
        m_applications.clear();
        if (rowCount() > 0) emit dataChanged(index(0, 0), index(rowCount() - 1, 0), {StorageIdRole, NameRole, IconRole});
    });
}

void RecentApplicationsAdapter::watchConfiguration()
{
    const QString directory = QFileInfo(m_configPath).absolutePath();
    if (QFileInfo::exists(m_configPath) && !m_configWatcher->files().contains(m_configPath))
        m_configWatcher->addPath(m_configPath);
    if (!m_configWatcher->directories().contains(directory)) m_configWatcher->addPath(directory);
}

void RecentApplicationsAdapter::reloadTracking()
{
    // A fresh KConfig reads the file instead of reusing a cached state whose
    // change detection can miss a same-size rewrite within the same second.
    const KConfig config(QStringLiteral("kactivitymanagerd-pluginsrc"));
    const KConfigGroup group(&config, QString::fromLatin1(ScoringGroup));
    const bool enabled = group.readEntry(WhatToRemember, 0) != NoApplications;
    if (m_trackingEnabled == enabled) return;
    m_trackingEnabled = enabled;
    emit trackingEnabledChanged();
}

bool RecentApplicationsAdapter::trackingEnabled() const
{
    return m_trackingEnabled;
}

bool RecentApplicationsAdapter::enabled() const
{
    return m_enabled;
}

void RecentApplicationsAdapter::setEnabled(bool enabled)
{
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    updateSource();
    emit enabledChanged();
}

bool RecentApplicationsAdapter::available() const
{
    return m_consumer && m_consumer->serviceStatus() == KActivities::Consumer::Running;
}

void RecentApplicationsAdapter::updateSource()
{
    m_applications.clear();
    QAbstractItemModel *previous = sourceModel();
    setSourceModel(nullptr);
    if (previous && previous->parent() == this) previous->deleteLater();
    // Do not ask Stats to open a nonexistent database when its service is
    // absent. Service recovery and activity changes rebuild this source.
    if (m_enabled && available()) {
        using namespace KActivities::Stats;
        using namespace KActivities::Stats::Terms;
        // Fetch candidates, not just the visible count: pinned, open and
        // invalid entries are removed by the selection proxy first.
        const QString activityId = historyActivityId(m_consumer->currentActivity(), m_consumer->activities());
        const auto baseQuery = UsedResources | RecentlyUsedFirst | Agent::any() | Type::any()
            | Url::startsWith(QStringLiteral("applications:")) | Limit(128);
        // KDE can report a running history service without a current activity,
        // for example after a session start that never activated one. The
        // current-activity scope would then match nothing, while every activity
        // still keeps the launch history that the dock is meant to show.
        const auto query = activityId.isEmpty()
            ? baseQuery | Activity::any() : baseQuery | Activity(activityId);
        setSourceModel(new ResultModel(query, this));
        while (sourceModel()->canFetchMore({}) && sourceModel()->rowCount() < 128) {
            const int previousCount = sourceModel()->rowCount();
            sourceModel()->fetchMore({});
            if (sourceModel()->rowCount() <= previousCount) break;
        }
    }
}

QHash<int, QByteArray> RecentApplicationsAdapter::roleNames() const
{
    return {{StorageIdRole, "storageId"}, {NameRole, "name"}, {IconRole, "icon"}};
}

QVariantMap RecentApplicationsAdapter::resolveResource(const QString &resource)
{
    const QString prefix = QStringLiteral("applications:");
    if (!resource.startsWith(prefix) || resource.size() > 512) return {};
    const QString id = resource.mid(prefix.size());
    if (id.isEmpty()) return {};
    for (const QChar ch : id) {
        if (ch.isSpace() || ch.category() == QChar::Other_Control || ch.category() == QChar::Other_Format
            || ch == QLatin1Char('/') || ch == QLatin1Char('\\') || ch == QLatin1Char(':')) return {};
    }
    KService::Ptr service = KService::serviceByStorageId(id);
    if (!service && !id.endsWith(QLatin1String(".desktop"))) service = KService::serviceByDesktopName(id);
    if (!service || !service->isValid() || !service->isApplication() || service->noDisplay()
        || service->isDeleted() || service->exec().trimmed().isEmpty()) return {};
    return {{QStringLiteral("storageId"), service->storageId()},
        {QStringLiteral("name"), service->name()},
        {QStringLiteral("icon"), service->icon()}};
}

QString RecentApplicationsAdapter::historyActivityId(const QString &currentActivity, const QStringList &activities)
{
    const QString id = currentActivity.trimmed();
    // The all-zero UUID is KDE's null activity, reported while the service is
    // still starting or when no activity has been activated.
    if (id.isEmpty() || id == QStringLiteral("00000000-0000-0000-0000-000000000000")) return {};
    // A current activity the service no longer lists is stale. Querying it
    // cannot match, so treat it like an absent one.
    if (!activities.isEmpty() && !activities.contains(id)) return {};
    return id;
}

QVariant RecentApplicationsAdapter::data(const QModelIndex &item, int role) const
{
    if (!item.isValid() || item.model() != this || !sourceModel()) return {};
    const QString resource = mapToSource(item).data(KActivities::Stats::ResultModel::ResourceRole).toString();
    if (!m_applications.contains(resource)) {
        if (m_applications.size() >= 256) m_applications.clear();
        m_applications.insert(resource, resolveResource(resource));
    }
    const QVariantMap app = m_applications.value(resource);
    switch (role) {
    case StorageIdRole: return app.value(QStringLiteral("storageId"));
    case NameRole:
    case Qt::DisplayRole: return app.value(QStringLiteral("name"));
    case IconRole: return app.value(QStringLiteral("icon"));
    default: return {};
    }
}

bool RecentApplicationsAdapter::setTrackingEnabled(bool enabled)
{
    KConfig config(QStringLiteral("kactivitymanagerd-pluginsrc"));
    KConfigGroup group(&config, QString::fromLatin1(ScoringGroup));
    group.writeEntry(WhatToRemember, enabled ? 0 : NoApplications, KConfigBase::Notify);
    const bool written = group.sync();
    reloadTracking();
    return written;
}

bool RecentApplicationsAdapter::openTrackingSettings()
{
    // A standalone module window matches this single preference; KDE's own
    // desktop entry is the fallback when kcmshell6 is unavailable.
    if (QProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_recentFiles")}))
        return true;
    const auto service = KService::serviceByStorageId(QStringLiteral("kcm_recentFiles.desktop"));
    if (!service || !service->isValid() || !service->isApplication() || service->exec().trimmed().isEmpty())
        return false;
    auto *job = new KIO::ApplicationLauncherJob(service, this);
    job->start();
    return true;
}

void RecentApplicationsAdapter::recordAccess(const QString &storageId)
{
    if (!available()) return;
    const QVariantMap app = resolveResource(QStringLiteral("applications:") + storageId);
    if (!app.isEmpty()) {
        KActivities::ResourceInstance::notifyAccessed(
            QUrl(QStringLiteral("applications:") + app.value(QStringLiteral("storageId")).toString()),
            QStringLiteral("punchi-dock-quickshell"));
    }
}
