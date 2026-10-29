// SPDX-License-Identifier: GPL-3.0-or-later
#include "fileplaces.h"
#include "desktopentry.h"
#include <KFilePlacesModel>
#include <QSet>

namespace {
bool usableUrl(const QUrl &url)
{
    return url.isValid() && !url.isEmpty() && !url.scheme().isEmpty()
        && url.scheme() != QLatin1String("exec") && url.scheme() != QLatin1String("applications");
}
}

FilePlaces::FilePlaces(QObject *parent) : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &FilePlaces::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &FilePlaces::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &FilePlaces::countChanged);
}

void FilePlaces::setDesktopId(const QString &id)
{
    if (id == m_desktopId) return;
    m_desktopId = id;
    m_showAll = false;
    m_group.clear();
    const auto service = resolveDesktopApplication(id);
    m_enabled = service && service->categories().contains(QStringLiteral("FileManager"));
    if (m_enabled && !m_places) {
        m_places = new KFilePlacesModel(this);
        setSourceModel(m_places);
        connect(m_places, &QAbstractItemModel::rowsInserted, this, &FilePlaces::refresh);
        connect(m_places, &QAbstractItemModel::rowsRemoved, this, &FilePlaces::refresh);
        connect(m_places, &QAbstractItemModel::rowsMoved, this, &FilePlaces::refresh);
        connect(m_places, &QAbstractItemModel::modelReset, this, &FilePlaces::refresh);
        connect(m_places, &QAbstractItemModel::dataChanged, this, &FilePlaces::refresh);
        connect(m_places, &KFilePlacesModel::groupHiddenChanged, this, &FilePlaces::refresh);
    }
    refresh();
    emit desktopIdChanged();
    emit navigationChanged();
}

void FilePlaces::refresh()
{
    // Cache native indexes only; the KDE model remains the owner of row data.
    QList<QPersistentModelIndex> rootIndexes, groupIndexes;
    QSet<QString> groups;
    m_firstGroup.clear();
    if (m_enabled && m_places) {
        for (int row = 0; row < m_places->rowCount(); ++row) {
            const auto item = m_places->index(row, 0);
            if (m_places->isHidden(item)) continue;
            const auto group = item.data(KFilePlacesModel::GroupRole).toString();
            if (rootIndexes.isEmpty()) m_firstGroup = group;
            if (group == m_firstGroup || !groups.contains(group)) rootIndexes.append(item);
            groups.insert(group);
            if (group == m_group) groupIndexes.append(item);
        }
    }
    if (!m_group.isEmpty() && groupIndexes.isEmpty()) {
        m_group.clear();
        emit navigationChanged();
    }
    m_total = rootIndexes.size();
    m_visibleIndexes = m_group.isEmpty() ? rootIndexes : groupIndexes;
    // Plasma counts group entries once and expands only when there are >7.
    if (m_group.isEmpty() && !m_showAll && m_total > 7) m_visibleIndexes = rootIndexes.mid(0, 5);
    invalidate();
    if (rowCount() > 0) emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
    emit countChanged();
}

bool FilePlaces::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    return sourceModel() && m_visibleIndexes.contains(sourceModel()->index(row, 0, parent));
}

bool FilePlaces::groupNode(const QModelIndex &source) const
{
    return m_group.isEmpty() && source.data(KFilePlacesModel::GroupRole).toString() != m_firstGroup;
}

QHash<int, QByteArray> FilePlaces::roleNames() const
{
    return {{Resource, "resource"}, {Name, "name"}, {Icon, "iconName"}, {Group, "groupName"},
        {IsGroup, "isGroup"}, {Available, "available"}};
}

QVariant FilePlaces::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) return {};
    const auto source = mapToSource(index);
    const bool group = groupNode(source);
    if (role == Resource) return group ? QString() : m_places->url(source).toString(QUrl::FullyEncoded);
    if (role == Name || role == Qt::DisplayRole)
        return source.data(group ? int(KFilePlacesModel::GroupRole) : int(Qt::DisplayRole));
    if (role == Icon) return group ? QString() : source.data(KFilePlacesModel::IconNameRole).toString();
    if (role == Group) return source.data(KFilePlacesModel::GroupRole);
    if (role == IsGroup) return group;
    if (role == Available) return group || (!m_places->setupNeeded(source) && usableUrl(m_places->url(source)));
    return QSortFilterProxyModel::data(index, role);
}

int FilePlaces::remainingCount() const
{
    return m_group.isEmpty() ? qMax(0, m_total - rowCount()) : 0;
}

void FilePlaces::setShowAll(bool all)
{
    if (m_showAll == all) return;
    m_showAll = all;
    refresh();
    emit navigationChanged();
}

bool FilePlaces::enterGroup(const QString &group)
{
    if (group.isEmpty() || !m_group.isEmpty()) return false;
    for (int row = 0; row < rowCount(); ++row) {
        const auto item = index(row, 0);
        if (item.data(IsGroup).toBool() && item.data(Group).toString() == group) {
            m_group = group;
            refresh();
            emit navigationChanged();
            return true;
        }
    }
    return false;
}

void FilePlaces::leaveGroup()
{
    if (m_group.isEmpty()) return;
    m_group.clear();
    refresh();
    emit navigationChanged();
}

QUrl FilePlaces::urlForResource(const QString &resource) const
{
    for (int row = 0; row < rowCount(); ++row) {
        const auto item = index(row, 0);
        if (!item.data(IsGroup).toBool() && item.data(Available).toBool()
            && item.data(Resource).toString() == resource) {
            // Recheck the source: a stale delegate must not open a hidden or unmounted place.
            const auto source = mapToSource(item);
            const auto url = KFilePlacesModel::convertedUrl(m_places->url(source));
            if (!m_places->isHidden(source) && !m_places->setupNeeded(source) && usableUrl(url)) return url;
        }
    }
    return {};
}
