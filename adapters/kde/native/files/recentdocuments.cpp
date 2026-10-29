// SPDX-License-Identifier: GPL-3.0-or-later
#include "recentdocuments.h"
#include "desktopentry.h"
#include <PlasmaActivities/Stats/ResultModel>
#include <PlasmaActivities/Stats/Terms>
#include <QMimeDatabase>
#include <QDir>

using namespace KActivities::Stats;
using namespace KActivities::Stats::Terms;

RecentDocuments::RecentDocuments(QObject *parent) : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &RecentDocuments::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &RecentDocuments::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &RecentDocuments::countChanged);
}

void RecentDocuments::setDesktopId(const QString &id)
{
    if (m_desktopId == id) return;
    auto *previous = sourceModel();
    setSourceModel(nullptr);
    if (previous && previous->parent() == this) previous->deleteLater();
    m_desktopId = id;
    const auto service = resolveDesktopApplication(id);
    if (service) {
        // Same app/activity scope and ordering as Plasma's task-menu backend.
        const auto query = UsedResources | RecentlyUsedFirst | Agent(service->desktopEntryName())
            | Type::any() | Activity::current() | Limit(5);
        setSourceModel(new ResultModel(query, this));
    }
    emit desktopIdChanged();
    emit countChanged();
}

QUrl RecentDocuments::documentUrl(const QString &resource)
{
    return QDir::isAbsolutePath(resource) ? QUrl::fromLocalFile(resource) : QUrl(resource);
}

bool RecentDocuments::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const auto url = documentUrl(sourceModel()->index(row, 0, parent).data(ResultModel::ResourceRole).toString());
    // Desktop entries and executable resources are not documents.
    return url.isValid() && !url.isEmpty() && !url.scheme().isEmpty()
        && url.scheme() != QLatin1String("applications") && url.scheme() != QLatin1String("exec")
        && !(url.isLocalFile() && url.fileName().endsWith(QLatin1String(".desktop"), Qt::CaseInsensitive));
}

QHash<int, QByteArray> RecentDocuments::roleNames() const
{
    return {{Resource, "resource"}, {Name, "name"}, {Icon, "iconName"}};
}

QVariant RecentDocuments::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) return {};
    const auto source = mapToSource(index);
    const QString resource = source.data(ResultModel::ResourceRole).toString();
    const auto url = documentUrl(resource);
    if (role == Resource) return resource;
    if (role == Name || role == Qt::DisplayRole)
        return url.isLocalFile() && !url.fileName().isEmpty() ? url.fileName() : url.toDisplayString();
    if (role == Icon) {
        // Stored MIME metadata avoids blocking filesystem/network probes while opening a menu.
        const auto mime = QMimeDatabase().mimeTypeForName(source.data(ResultModel::MimeType).toString());
        return mime.isValid() ? mime.iconName() : QStringLiteral("text-x-generic");
    }
    return QSortFilterProxyModel::data(index, role);
}

QModelIndex RecentDocuments::indexForResource(const QString &resource) const
{
    for (int row = 0; row < rowCount(); ++row) {
        const auto item = index(row, 0);
        if (item.data(Resource).toString() == resource) return item;
    }
    return {};
}

QString RecentDocuments::mimeType(const QModelIndex &index) const
{
    return mapToSource(index).data(ResultModel::MimeType).toString();
}

bool RecentDocuments::forget()
{
    auto *model = qobject_cast<ResultModel *>(sourceModel());
    if (!model || !resolveDesktopApplication(m_desktopId)) return false;
    model->forgetAllResources();
    return true;
}
