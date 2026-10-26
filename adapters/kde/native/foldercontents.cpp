// SPDX-License-Identifier: GPL-3.0-or-later
#include "foldercontents.h"
#include <KDirLister>
#include <KIO/Job>
#include <QStandardPaths>
#include <QDir>
#include <QCollator>
#include <QDateTime>
#include <QSet>

class FolderContents::FolderSortModel : public KDirSortFilterProxyModel
{
public:
    explicit FolderSortModel(QObject *parent = nullptr) : KDirSortFilterProxyModel(parent) {}
    QString mode = QStringLiteral("modified");
    // Names the popup must skip. Filtering lives in the proxy so the model the
    // settings preview reads stays complete.
    void setHidden(const QSet<QString> &names)
    {
        if (hidden == names) return;
#if QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)
        beginFilterChange();
        hidden = names;
        endFilterChange(Direction::Rows);
#else
        hidden = names;
        invalidateFilter();
#endif
    }
protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override
    {
        if (!KDirSortFilterProxyModel::filterAcceptsRow(row, parent)) return false;
        if (hidden.isEmpty()) return true;
        const auto index = sourceModel()->index(row, 0, parent);
        const auto item = index.data(KDirModel::FileItemRole).value<KFileItem>();
        return item.isNull() || !hidden.contains(item.text());
    }
    QSet<QString> hidden;

    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override
    {
        if (mode != QLatin1String("created")) return KDirSortFilterProxyModel::lessThan(left, right);
        const auto leftItem = left.data(KDirModel::FileItemRole).value<KFileItem>();
        const auto rightItem = right.data(KDirModel::FileItemRole).value<KFileItem>();
        const auto leftTime = leftItem.time(KFileItem::CreationTime);
        const auto rightTime = rightItem.time(KFileItem::CreationTime);
        if (leftTime != rightTime) return leftTime > rightTime;
        QCollator collator;
        collator.setNumericMode(true);
        return collator.compare(leftItem.text(), rightItem.text()) < 0;
    }
};

FolderContents::FolderContents(QObject *parent) : QIdentityProxyModel(parent)
{
    m_location = downloadsUrl();
    m_sorted = new FolderSortModel(this);
    m_sorted->setSourceModel(&m_directory);
    m_sorted->setSortFoldersFirst(false);
    setSourceModel(m_sorted);
    setSortMode(QStringLiteral("modified"));
    auto *lister = m_directory.dirLister();
    lister->setAutoErrorHandlingEnabled(false);
    lister->setShowHiddenFiles(false);
    lister->setAutoUpdate(false);
    connect(lister, &KCoreDirLister::started, this, [this] { m_loading = true; m_error.clear(); emit stateChanged(); });
    connect(lister, qOverload<>(&KCoreDirLister::completed), this, [this] { m_loading = false; emit stateChanged(); });
    connect(lister, qOverload<>(&KCoreDirLister::canceled), this, [this] { m_loading = false; emit stateChanged(); });
    connect(lister, &KCoreDirLister::jobError, this, [this](KIO::Job *job) {
        m_error = job->errorString(); m_loading = false; emit stateChanged();
    });
    connect(this, &QAbstractItemModel::rowsInserted, this, &FolderContents::changed);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &FolderContents::changed);
    connect(this, &QAbstractItemModel::modelReset, this, &FolderContents::changed);
    connect(this, &QAbstractItemModel::layoutChanged, this, &FolderContents::changed);
    connect(this, &QAbstractItemModel::dataChanged, this, &FolderContents::changed);
}
void FolderContents::setHiddenEntries(const QStringList &names)
{
    // The stored list is untrusted input: bound it and drop anything that could
    // name a path instead of a sibling entry.
    QStringList bounded;
    for (const auto &name : names) {
        if (name.isEmpty() || name.size() > 200 || name == QLatin1String(".")
            || name == QLatin1String("..") || name.contains(QLatin1Char('/'))
            || name.contains(QLatin1Char('\\')))
            continue;
        if (!bounded.contains(name)) bounded.append(name);
        if (bounded.size() >= 2000) break;
    }
    if (bounded == m_hiddenEntries) return;
    m_hiddenEntries = bounded;
    m_sorted->setHidden(QSet<QString>(bounded.cbegin(), bounded.cend()));
    emit hiddenEntriesChanged();
}
void FolderContents::setSortMode(const QString &mode)
{
    if (mode != QLatin1String("name") && mode != QLatin1String("modified")
        && mode != QLatin1String("created") && mode != QLatin1String("kind")
        && mode != QLatin1String("size")) return;
    if (m_sortMode == mode) return;
    m_sortMode = mode;
    m_sorted->mode = mode;
    if (mode == QLatin1String("name")) m_sorted->sort(KDirModel::Name, Qt::AscendingOrder);
    else if (mode == QLatin1String("size")) m_sorted->sort(KDirModel::Size, Qt::DescendingOrder);
    else if (mode == QLatin1String("modified")) m_sorted->sort(KDirModel::ModifiedTime, Qt::DescendingOrder);
    else if (mode == QLatin1String("created")) m_sorted->sort(KDirModel::Name, Qt::AscendingOrder);
    else m_sorted->sort(KDirModel::Type, Qt::AscendingOrder);
    emit sortModeChanged();
}
QUrl FolderContents::downloadsUrl() const
{
    return QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation));
}
bool FolderContents::localUrl(const QUrl &url)
{
    return url.isValid() && url.isLocalFile() && url.host().isEmpty()
        && QDir::isAbsolutePath(url.toLocalFile()) && !url.hasQuery() && !url.hasFragment();
}
void FolderContents::setLocation(const QUrl &url)
{
    if (!localUrl(url) || url == m_location) return;
    m_location = url;
    emit locationChanged();
    if (m_active) refresh();
}
void FolderContents::setActive(bool value)
{
    if (m_active == value) return;
    m_active = value;
    m_directory.dirLister()->setAutoUpdate(value);
    if (value) refresh();
    else { m_directory.dirLister()->stop(); m_loading = false; emit stateChanged(); }
    emit activeChanged();
}
void FolderContents::refresh()
{
    m_directory.dirLister()->stop();
    m_error.clear();
    m_loading = true;
    emit stateChanged();
    m_directory.openUrl(m_location, KDirModel::Reload);
}
void FolderContents::changed() { ++m_revision; emit entriesChanged(); }
QHash<int, QByteArray> FolderContents::roleNames() const
{
    return {{EntryUrl, "entryUrl"}, {EntryName, "entryName"}, {EntryIcon, "entryIcon"},
            {Directory, "directory"}, {Description, "description"}};
}
QVariant FolderContents::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= count()) return {};
    const auto item = QIdentityProxyModel::data(index, KDirModel::FileItemRole).value<KFileItem>();
    if (item.isNull()) return {};
    switch (role) {
    case EntryUrl: return item.url();
    case EntryName: return item.text();
    case EntryIcon: {
        const auto icon = item.iconName();
        const QUrl iconUrl(icon);
        if (iconUrl.scheme().isEmpty() || localUrl(iconUrl)) return icon;
        return item.currentMimeType().iconName();
    }
    case Directory: return item.isDir();
    case Description: return item.mimeComment();
    default: return QIdentityProxyModel::data(index, role);
    }
}
QVariantMap FolderContents::get(int row) const
{
    if (row < 0 || row >= count()) return {};
    QVariantMap result;
    const auto item = index(row, 0);
    const auto roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it)
        result.insert(QString::fromUtf8(it.value()), data(item, it.key()));
    return result;
}
int FolderContents::indexOfUrl(const QUrl &url) const
{
    const auto original = m_directory.indexForUrl(url);
    return original.isValid() ? m_sorted->mapFromSource(original).row() : -1;
}
KFileItem FolderContents::itemForUrl(const QUrl &url) const
{
    if (!m_active || !localUrl(url) || indexOfUrl(url) < 0) return {};
    return m_directory.dirLister()->findByUrl(url);
}

FolderEntriesModel::FolderEntriesModel(QObject *parent) : QConcatenateTablesProxyModel(parent)
{
    m_action.setItemRoleNames(roleNames());
    auto *row = new QStandardItem;
    row->setData(QUrl(), FolderContents::EntryUrl);
    row->setData(QString(), FolderContents::EntryName);
    row->setData(QStringLiteral("folder-open"), FolderContents::EntryIcon);
    row->setData(false, FolderContents::Directory);
    row->setData(QString(), FolderContents::Description);
    m_action.appendRow(row);
    addSourceModel(&m_action);
}
void FolderEntriesModel::setContents(FolderContents *contents)
{
    if (m_contents == contents) return;
    if (m_contents) removeSourceModel(m_contents);
    removeSourceModel(&m_action);
    m_contents = contents;
    if (contents) addSourceModel(contents);
    addSourceModel(&m_action);
    emit contentsChanged();
}
QHash<int, QByteArray> FolderEntriesModel::roleNames() const
{
    return {{FolderContents::EntryUrl, "entryUrl"}, {FolderContents::EntryName, "entryName"},
            {FolderContents::EntryIcon, "entryIcon"}, {FolderContents::Directory, "directory"},
            {FolderContents::Description, "description"}, {LocationAction, "locationAction"}};
}
QVariant FolderEntriesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= liveRowCount()) return {};
    if (role == LocationAction) return index.row() == (m_contents ? m_contents->count() : 0);
    return QConcatenateTablesProxyModel::data(index, role);
}

int FolderEntriesModel::liveRowCount() const
{
    return (m_contents ? m_contents->rowCount() : 0) + m_action.rowCount();
}

QModelIndex FolderEntriesModel::index(int row, int column, const QModelIndex &parent) const
{
    // Qt Quick asks for a row while it applies a model change, so the listing
    // can already have fewer rows than the concatenated proxy still counts.
    // The base implementation then dereferences the missing source model.
    if (!hasIndex(row, column, parent) || row >= liveRowCount()) return {};
    return QConcatenateTablesProxyModel::index(row, column, parent);
}
