// SPDX-License-Identifier: GPL-3.0-or-later
#include "dockapplicationsmodel.h"
#include "../window-state/taskidentity.h"
#include <QSet>
#include <QTimer>

namespace {
QVariant field(const QModelIndex &index, const QByteArray &name)
{
    if (!index.isValid()) return {};
    const auto roles = index.model()->roleNames();
    const int role = roles.key(name, -1);
    return role < 0 ? QVariant() : index.data(role);
}
}

DockApplicationsModel::DockApplicationsModel(QObject *parent) : QAbstractListModel(parent) {}

void DockApplicationsModel::connectSource(QAbstractItemModel *model)
{
    if (!model) return;
    connect(model, &QAbstractItemModel::modelReset, this, &DockApplicationsModel::schedule);
    connect(model, &QAbstractItemModel::rowsInserted, this, &DockApplicationsModel::schedule);
    connect(model, &QAbstractItemModel::rowsRemoved, this, &DockApplicationsModel::schedule);
    connect(model, &QAbstractItemModel::rowsMoved, this, &DockApplicationsModel::schedule);
    connect(model, &QAbstractItemModel::dataChanged, this, &DockApplicationsModel::schedule);
    connect(model, &QAbstractItemModel::layoutChanged, this, &DockApplicationsModel::schedule);
    connect(model, &QObject::destroyed, this, [this]() { schedule(); emit sourcesChanged(); });
}
void DockApplicationsModel::setPinned(QAbstractItemModel *model)
{
    if (model == m_pinned) return;
    if (m_pinned && m_pinned != m_catalog) disconnect(m_pinned, nullptr, this, nullptr);
    m_pinned = model;
    if (model != m_catalog) connectSource(model);
    schedule(); emit sourcesChanged();
}
void DockApplicationsModel::setCatalog(QAbstractItemModel *model)
{
    if (model == m_catalog) return;
    if (m_catalog && m_catalog != m_pinned && m_catalog != m_recent) disconnect(m_catalog, nullptr, this, nullptr);
    m_catalog = model;
    if (model != m_pinned && model != m_recent) connectSource(model);
    schedule(); emit sourcesChanged();
}
void DockApplicationsModel::setRecent(QAbstractItemModel *model)
{
    if (model == m_recent) return;
    if (m_recent && m_recent != m_pinned && m_recent != m_catalog) disconnect(m_recent, nullptr, this, nullptr);
    m_recent = model;
    if (model != m_pinned && model != m_catalog) connectSource(model);
    schedule(); emit sourcesChanged();
}
void DockApplicationsModel::setRunningDesktopIds(const QStringList &ids)
{
    QStringList normalized;
    for (const auto &id : ids.mid(0, 1024)) {
        const auto value = normalizedApplicationId(id);
        if (!value.isEmpty() && !normalized.contains(value)) normalized.append(value);
    }
    normalized.sort();
    if (m_running == normalized) return;
    m_running = normalized; schedule(); emit sourcesChanged();
}
void DockApplicationsModel::setRunningApplications(const QVariantList &applications)
{
    QVariantList normalized;
    QSet<QString> seen;
    for (const auto &value : applications.mid(0, 256)) {
        const auto entry = value.toMap();
        const auto desktopId = normalizedApplicationId(entry.value(QStringLiteral("desktopId")).toString());
        const auto name = entry.value(QStringLiteral("name")).toString().trimmed().left(128);
        auto iconName = entry.value(QStringLiteral("iconName")).toString().trimmed().left(128);
        if (desktopId.isEmpty() || name.isEmpty() || seen.contains(desktopId)) continue;
        if (iconName.isEmpty()) iconName = QStringLiteral("application-x-executable");
        normalized.append(QVariantMap{{QStringLiteral("desktopId"), desktopId},
            {QStringLiteral("name"), name}, {QStringLiteral("iconName"), iconName}});
        seen.insert(desktopId);
    }
    if (m_runningApplications == normalized) return;
    m_runningApplications = normalized;
    schedule(); emit sourcesChanged();
}
int DockApplicationsModel::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_rows.size(); }
QHash<int, QByteArray> DockApplicationsModel::roleNames() const
{
    return {{AppId, "appId"}, {DesktopId, "desktopId"}, {Title, "title"}, {Icon, "iconName"}};
}
QVariant DockApplicationsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) return {};
    if (role == Qt::DisplayRole) role = Title;
    const auto &row = m_rows.at(index.row());
    return row.source.isValid() ? field(row.source, roleNames().value(role))
        : row.fallback.value(QString::fromUtf8(roleNames().value(role)));
}
QVariantMap DockApplicationsModel::get(int row) const
{
    QVariantMap result;
    if (row < 0 || row >= m_rows.size()) return result;
    const auto roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        result.insert(QString::fromUtf8(it.value()), data(index(row), it.key()));
    return result;
}
void DockApplicationsModel::schedule()
{
    if (m_scheduled) return;
    m_scheduled = true;
    QTimer::singleShot(0, this, [this]() { m_scheduled = false; rebuild(); });
}
void DockApplicationsModel::rebuild()
{
    QList<Row> next, runningCandidates, recentCandidates;
    QList<Row> trailingItems;
    QSet<QString> identities, appIds;
    for (int row = 0; m_pinned && row < m_pinned->rowCount(); ++row) {
        const auto source = m_pinned->index(row, 0);
        const auto appId = field(source, "appId").toString();
        const auto desktopId = normalizedApplicationId(field(source, "desktopId").toString());
        if (appId.isEmpty() || appIds.contains(appId)) continue;
        next.append({appId, source, {}}); appIds.insert(appId); identities.insert(desktopId);
    }
    for (int row = 0; m_catalog && row < m_catalog->rowCount(); ++row) {
        const auto source = m_catalog->index(row, 0);
        const auto appId = field(source, "appId").toString();
        const auto desktopId = normalizedApplicationId(field(source, "desktopId").toString());
        if (appId.isEmpty() || desktopId.isEmpty() || !field(source, "installed").toBool()
            || !m_running.contains(desktopId) || identities.contains(desktopId) || appIds.contains(appId)) continue;
        runningCandidates.append({appId, source, {}}); identities.insert(desktopId); appIds.insert(appId);
    }
    // Some real window tasks (notably Plasma applet settings) have no visible
    // desktop service. Keep them as transient entries using KDE task metadata.
    for (const auto &value : m_runningApplications) {
        const auto entry = value.toMap();
        const auto desktopId = normalizedApplicationId(entry.value(QStringLiteral("desktopId")).toString());
        const auto appId = QStringLiteral("desktop:") + desktopId + QStringLiteral(".desktop");
        if (desktopId.isEmpty() || !m_running.contains(desktopId)
            || identities.contains(desktopId) || appIds.contains(appId)) continue;
        const QVariantMap fallback{{QStringLiteral("appId"), appId},
            {QStringLiteral("desktopId"), desktopId + QStringLiteral(".desktop")},
            {QStringLiteral("title"), entry.value(QStringLiteral("name"))},
            {QStringLiteral("iconName"), entry.value(QStringLiteral("iconName"))}};
        runningCandidates.append({appId, {}, fallback});
        identities.insert(desktopId); appIds.insert(appId);
    }
    // Recent applications are resolved application rows, not task entries.
    // Keep their history order and skip anything already pinned or open.
    for (int row = 0; m_recent && row < m_recent->rowCount(); ++row) {
        const auto source = m_recent->index(row, 0);
        const auto storageId = field(source, "storageId").toString();
        const auto identity = normalizedApplicationId(storageId);
        const auto appId = QStringLiteral("desktop:") + storageId;
        if (storageId.isEmpty() || identity.isEmpty()
            || identities.contains(identity) || appIds.contains(appId)) continue;
        auto iconName = field(source, "icon").toString();
        if (iconName.isEmpty()) iconName = QStringLiteral("application-x-executable");
        const QVariantMap fallback{{QStringLiteral("appId"), appId},
            {QStringLiteral("desktopId"), storageId},
            {QStringLiteral("title"), field(source, "name")},
            {QStringLiteral("iconName"), iconName}};
        recentCandidates.append({appId, {}, fallback});
        identities.insert(identity); appIds.insert(appId);
    }
    // Running applications join before trailing special items. A special item
    // explicitly moved into the middle retains its chosen position.
    while (!next.isEmpty() && next.last().id.startsWith(QLatin1String("item:")))
        trailingItems.prepend(next.takeLast());
    // Keep existing running applications in place as other windows open/close.
    for (const auto &previous : m_rows) {
        for (int row = 0; row < runningCandidates.size(); ++row) if (runningCandidates.at(row).id == previous.id) {
            next.append(runningCandidates.takeAt(row)); break;
        }
    }
    next.append(runningCandidates);
    next.append(recentCandidates);
    next.append(trailingItems);
    for (int row = m_rows.size() - 1; row >= 0; --row) {
        bool keep = false;
        for (const auto &item : next) if (item.id == m_rows.at(row).id) { keep = true; break; }
        if (keep) continue;
        beginRemoveRows({}, row, row); m_rows.removeAt(row); endRemoveRows(); emit countChanged();
    }
    for (int row = 0; row < next.size(); ++row) {
        int current = row;
        while (current < m_rows.size() && m_rows.at(current).id != next.at(row).id) ++current;
        if (current == m_rows.size()) {
            beginInsertRows({}, row, row); m_rows.insert(row, next.at(row)); endInsertRows(); emit countChanged();
        } else {
            if (current != row) {
                beginMoveRows({}, current, current, {}, row); m_rows.move(current, row); endMoveRows();
            }
            m_rows[row] = next.at(row);
            emit dataChanged(index(row), index(row));
        }
    }
}
