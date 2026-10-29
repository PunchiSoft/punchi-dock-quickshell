// SPDX-License-Identifier: GPL-3.0-or-later
#include "applicationcatalog.h"
#include "desktopentry.h"
#include <KApplicationTrader>
#include <KService>
#include <KSycoca>
#include <QCollator>
#include <QRegularExpression>
#include <QSet>
#include <QTimer>
#include <QUrl>
#include <algorithm>

namespace {
QString applicationIcon(const KService::Ptr &service)
{
    const auto icon = service ? service->icon() : QString();
    const QUrl url(icon);
    return icon.isEmpty() || (!url.scheme().isEmpty() && !url.isLocalFile())
        ? QStringLiteral("application-x-executable") : icon;
}

// A launcher that names a role shows the icon of the application that answers
// it, and keeps the profile's own icon when that application ships none.
QString roleIcon(const KService::Ptr &service, const QString &fallback)
{
    const auto icon = applicationIcon(service);
    return icon == QLatin1String("application-x-executable") ? fallback : icon;
}

bool launchableService(const KService::Ptr &service)
{
    return service && service->isValid() && service->isApplication() && !service->exec().isEmpty()
        && !service->noDisplay();
}

// The preferred application is KDE's answer, not this project's guess: it
// follows the association the user set in System Settings and the one a
// distribution ships, including a replaced or removed default.
KService::Ptr preferredApplication(const QStringList &mimeTypes)
{
    static const QRegularExpression pattern(
        QStringLiteral("^[a-z0-9][a-z0-9.+-]{0,126}/[a-z0-9][a-z0-9.+-]{0,126}$"));
    for (const auto &mimeType : mimeTypes) {
        if (!pattern.match(mimeType).hasMatch()) continue;
        if (const auto service = KApplicationTrader::preferredService(mimeType); launchableService(service))
            return service;
    }
    return {};
}
}

ApplicationCatalog::ApplicationCatalog(QObject *parent) : QAbstractListModel(parent)
{
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, &ApplicationCatalog::reload);
    QTimer::singleShot(0, this, &ApplicationCatalog::reload);
}

void ApplicationCatalog::setPresets(QAbstractItemModel *presets)
{
    if (presets == m_presets) return;
    if (m_presets) disconnect(m_presets, nullptr, this, nullptr);
    m_presets = presets;
    if (presets) {
        connect(presets, &QAbstractItemModel::modelReset, this, &ApplicationCatalog::reload);
        connect(presets, &QAbstractItemModel::dataChanged, this, &ApplicationCatalog::reload);
        connect(presets, &QAbstractItemModel::rowsInserted, this, &ApplicationCatalog::reload);
        connect(presets, &QAbstractItemModel::rowsRemoved, this, &ApplicationCatalog::reload);
        connect(presets, &QObject::destroyed, this, &ApplicationCatalog::reload);
    }
    reload();
    emit presetsChanged();
}

QHash<int, QByteArray> ApplicationCatalog::roleNames() const
{
    return {{AppId, "appId"}, {DesktopId, "desktopId"}, {Title, "title"}, {Icon, "iconName"},
        {Name, "name"}, {Description, "description"}, {Installed, "installed"}, {ApplicationIcon, "appIconName"}};
}

int ApplicationCatalog::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_rows.size(); }

QVariant ApplicationCatalog::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) return {};
    if (role == Qt::DisplayRole) role = Title;
    return m_rows.at(index.row()).value(QString::fromUtf8(roleNames().value(role)));
}

QVariantMap ApplicationCatalog::get(int row) const
{
    return row >= 0 && row < m_rows.size() ? m_rows.at(row) : QVariantMap();
}

QVariantMap ApplicationCatalog::application(const QString &appId) const
{
    for (const auto &row : m_rows) if (row.value(QStringLiteral("appId")) == appId) return row;
    return {};
}

void ApplicationCatalog::reload()
{
    QList<QVariantMap> rows, discovered;
    QSet<QString> presetStorageIds;
    const auto roles = m_presets ? m_presets->roleNames() : QHash<int, QByteArray>();
    const auto value = [this, &roles](int row, const QByteArray &name) -> QVariant {
        for (auto it = roles.cbegin(); it != roles.cend(); ++it)
            if (it.value() == name) return m_presets->index(row, 0).data(it.key());
        return {};
    };
    const auto field = [&value](int row, const QByteArray &name) { return value(row, name).toString(); };
    for (int row = 0; m_presets && row < m_presets->rowCount(); ++row) {
        const auto desktopId = field(row, "desktopId");
        // A role entry resolves to the application this session prefers, so the
        // catalogue publishes a real desktop id to every consumer: launching,
        // running markers, window actions and media control keep working.
        const auto presetMimeTypes = value(row, "defaultMimeTypes").toString().split(u' ', Qt::SkipEmptyParts);
        const auto service = presetMimeTypes.isEmpty() ? resolveDesktopApplication(desktopId)
            : preferredApplication(presetMimeTypes);
        const bool installed = service && !service->noDisplay();
        if (service) presetStorageIds.insert(service->storageId());
        const auto presetIcon = field(row, "iconName");
        rows.append({{QStringLiteral("appId"), field(row, "appId")},
            {QStringLiteral("desktopId"), service ? service->storageId() : desktopId},
            {QStringLiteral("title"), field(row, "title")},
            {QStringLiteral("iconName"), presetMimeTypes.isEmpty() ? presetIcon
                : roleIcon(service, presetIcon)},
            {QStringLiteral("name"), service ? service->name() : field(row, "title")},
            {QStringLiteral("description"), service ? service->comment() : QString()},
            {QStringLiteral("appIconName"), applicationIcon(service)},
            {QStringLiteral("installed"), installed}});
    }
    for (const auto &service : KService::allServices()) {
        if (!service->isApplication() || service->noDisplay() || service->exec().isEmpty()
            || !isValidDesktopId(service->storageId()) || presetStorageIds.contains(service->storageId())) continue;
        discovered.append({{QStringLiteral("appId"), QStringLiteral("desktop:") + service->storageId()},
            {QStringLiteral("desktopId"), service->storageId()}, {QStringLiteral("title"), service->name()},
            {QStringLiteral("name"), service->name()}, {QStringLiteral("iconName"), applicationIcon(service)},
            {QStringLiteral("appIconName"), applicationIcon(service)},
            {QStringLiteral("description"), service->comment()}, {QStringLiteral("installed"), true}});
    }
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(discovered.begin(), discovered.end(), [&collator](const QVariantMap &a, const QVariantMap &b) {
        return collator.compare(a.value(QStringLiteral("name")).toString(), b.value(QStringLiteral("name")).toString()) < 0;
    });
    rows.append(discovered);
    if (rows == m_rows) return;
    beginResetModel();
    m_rows = std::move(rows);
    ++m_revision;
    endResetModel();
    emit changed();
}

ApplicationSearchModel::ApplicationSearchModel(QObject *parent) : QSortFilterProxyModel(parent)
{
    setSortRole(ApplicationCatalog::Name);
    setSortCaseSensitivity(Qt::CaseInsensitive);
    sort(0);
    connect(this, &QAbstractItemModel::rowsInserted, this, &ApplicationSearchModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &ApplicationSearchModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &ApplicationSearchModel::countChanged);
}

void ApplicationSearchModel::setQuery(const QString &query)
{
    const auto bounded = query.left(256).trimmed();
    if (bounded == m_query) return;
#if QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)
    beginFilterChange();
    m_query = bounded;
    endFilterChange(Direction::Rows);
#else
    m_query = bounded;
    invalidateFilter();
#endif
    emit queryChanged();
    emit countChanged();
}

bool ApplicationSearchModel::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const auto item = sourceModel()->index(row, 0, parent);
    if (!item.data(ApplicationCatalog::Installed).toBool()) return false;
    if (m_query.isEmpty()) return true;
    for (int role : {ApplicationCatalog::Name, ApplicationCatalog::Title, ApplicationCatalog::AppId,
                     ApplicationCatalog::DesktopId, ApplicationCatalog::Description})
        if (item.data(role).toString().contains(m_query, Qt::CaseInsensitive)) return true;
    return false;
}
