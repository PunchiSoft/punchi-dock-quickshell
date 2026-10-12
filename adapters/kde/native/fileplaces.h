// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QPersistentModelIndex>
#include <QSortFilterProxyModel>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class KFilePlacesModel;

class FilePlaces : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString desktopId READ desktopId WRITE setDesktopId NOTIFY desktopIdChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int remainingCount READ remainingCount NOTIFY countChanged)
    Q_PROPERTY(bool showAll READ showAll WRITE setShowAll NOTIFY navigationChanged)
    Q_PROPERTY(QString groupName READ groupName NOTIFY navigationChanged)
public:
    enum Role { Resource = Qt::UserRole + 200, Name, Icon, Group, IsGroup, Available };
    explicit FilePlaces(QObject *parent = nullptr);
    QString desktopId() const { return m_desktopId; }
    void setDesktopId(const QString &id);
    bool showAll() const { return m_showAll; }
    void setShowAll(bool all);
    QString groupName() const { return m_group; }
    int remainingCount() const;
    Q_INVOKABLE bool enterGroup(const QString &group);
    Q_INVOKABLE void leaveGroup();
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QUrl urlForResource(const QString &resource) const;
signals:
    void desktopIdChanged();
    void countChanged();
    void navigationChanged();
protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;
private:
    void refresh();
    bool groupNode(const QModelIndex &source) const;
    KFilePlacesModel *m_places = nullptr;
    QString m_desktopId;
    QString m_firstGroup;
    QString m_group;
    QList<QPersistentModelIndex> m_visibleIndexes;
    int m_total = 0;
    bool m_enabled = false;
    bool m_showAll = false;
};
