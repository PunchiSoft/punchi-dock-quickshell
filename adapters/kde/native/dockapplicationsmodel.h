// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QAbstractListModel>
#include <QPersistentModelIndex>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

// References the two source models; never copies catalog metadata into QML.
class DockApplicationsModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QAbstractItemModel *pinned READ pinned WRITE setPinned NOTIFY sourcesChanged)
    Q_PROPERTY(QAbstractItemModel *catalog READ catalog WRITE setCatalog NOTIFY sourcesChanged)
    Q_PROPERTY(QStringList runningDesktopIds READ runningDesktopIds WRITE setRunningDesktopIds NOTIFY sourcesChanged)
    Q_PROPERTY(QVariantList runningApplications READ runningApplications WRITE setRunningApplications NOTIFY sourcesChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
public:
    enum Role { AppId = Qt::UserRole + 1, DesktopId, Title, Icon };
    explicit DockApplicationsModel(QObject *parent = nullptr);
    QAbstractItemModel *pinned() const { return m_pinned; }
    QAbstractItemModel *catalog() const { return m_catalog; }
    QStringList runningDesktopIds() const { return m_running; }
    QVariantList runningApplications() const { return m_runningApplications; }
    void setPinned(QAbstractItemModel *model);
    void setCatalog(QAbstractItemModel *model);
    void setRunningDesktopIds(const QStringList &ids);
    void setRunningApplications(const QVariantList &applications);
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariantMap get(int row) const;
signals:
    void sourcesChanged();
    void countChanged();
private:
    struct Row { QString id; QPersistentModelIndex source; QVariantMap fallback; };
    void connectSource(QAbstractItemModel *model);
    void schedule();
    void rebuild();
    QPointer<QAbstractItemModel> m_pinned, m_catalog;
    QStringList m_running;
    QVariantList m_runningApplications;
    QList<Row> m_rows;
    bool m_scheduled = false;
};
