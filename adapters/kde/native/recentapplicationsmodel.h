// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QSet>
#include <QSortFilterProxyModel>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// The provider supplies valid, KService-resolved applications in most-recent
// order. This proxy owns selection only; it never stores or erases history.
class RecentApplicationsModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int maximumItems READ maximumItems WRITE setMaximumItems NOTIFY maximumItemsChanged)
    Q_PROPERTY(QStringList excludedStorageIds READ excludedStorageIds WRITE setExcludedStorageIds
        NOTIFY excludedStorageIdsChanged)
    Q_PROPERTY(int count READ count NOTIFY itemsChanged)
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    static constexpr int DefaultMaximumItems = 5;
    static constexpr int MaximumItems = 20;

    explicit RecentApplicationsModel(QObject *parent = nullptr);

    void setSourceModel(QAbstractItemModel *model) override;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    bool enabled() const;
    void setEnabled(bool enabled);
    int maximumItems() const;
    void setMaximumItems(int maximumItems);
    QStringList excludedStorageIds() const;
    void setExcludedStorageIds(const QStringList &storageIds);
    int count() const;
    QVariantList items() const;
    Q_INVOKABLE QVariantMap get(int row) const;

signals:
    void enabledChanged();
    void maximumItemsChanged();
    void excludedStorageIdsChanged();
    void itemsChanged();

protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;

private:
    static QString identityKey(const QString &storageId);
    QString sourceIdentity(int row) const;
    int recentItemRole() const;
    void refreshSelection();

    bool m_enabled = false;
    int m_maximumItems = DefaultMaximumItems;
    QStringList m_excludedStorageIds;
    QSet<QString> m_excludedIdentities;
    QList<QMetaObject::Connection> m_sourceConnections;
};
