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
    Q_PROPERTY(QAbstractItemModel *recent READ recent WRITE setRecent NOTIFY sourcesChanged)
    Q_PROPERTY(QStringList runningDesktopIds READ runningDesktopIds WRITE setRunningDesktopIds NOTIFY sourcesChanged)
    Q_PROPERTY(QVariantList runningApplications READ runningApplications WRITE setRunningApplications NOTIFY sourcesChanged)
    // One item standing for the whole history. The container popup reads the
    // entries from the selection model, so the dock publishes no recent rows of
    // its own while this is on.
    Q_PROPERTY(bool recentContainer READ recentContainer WRITE setRecentContainer NOTIFY recentContainerChanged)
    Q_PROPERTY(QString recentContainerTitle READ recentContainerTitle WRITE setRecentContainerTitle NOTIFY recentContainerChanged)
    Q_PROPERTY(QString recentContainerIcon READ recentContainerIcon WRITE setRecentContainerIcon NOTIFY recentContainerChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
public:
    enum Role { AppId = Qt::UserRole + 1, DesktopId, Title, Icon };
    explicit DockApplicationsModel(QObject *parent = nullptr);
    QAbstractItemModel *pinned() const { return m_pinned; }
    QAbstractItemModel *catalog() const { return m_catalog; }
    QAbstractItemModel *recent() const { return m_recent; }
    QStringList runningDesktopIds() const { return m_running; }
    QVariantList runningApplications() const { return m_runningApplications; }
    bool recentContainer() const { return m_recentContainer; }
    QString recentContainerTitle() const { return m_recentContainerTitle; }
    QString recentContainerIcon() const { return m_recentContainerIcon; }
    void setPinned(QAbstractItemModel *model);
    void setCatalog(QAbstractItemModel *model);
    void setRecent(QAbstractItemModel *model);
    void setRunningDesktopIds(const QStringList &ids);
    void setRunningApplications(const QVariantList &applications);
    void setRecentContainer(bool enabled);
    void setRecentContainerTitle(const QString &title);
    void setRecentContainerIcon(const QString &icon);
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariantMap get(int row) const;
signals:
    void sourcesChanged();
    void countChanged();
    void recentContainerChanged();
private:
    struct Row { QString id; QPersistentModelIndex source; QVariantMap fallback; };
    void connectSource(QAbstractItemModel *model);
    void schedule();
    void rebuild();
    QPointer<QAbstractItemModel> m_pinned, m_catalog, m_recent;
    QStringList m_running;
    QVariantList m_runningApplications;
    bool m_recentContainer = false;
    QString m_recentContainerTitle, m_recentContainerIcon;
    QList<Row> m_rows;
    bool m_scheduled = false;
};
