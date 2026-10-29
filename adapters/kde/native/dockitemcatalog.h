// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QConcatenateTablesProxyModel>
#include <QPointer>
#include <QStandardItemModel>
#include <QtQml/qqmlregistration.h>

// One catalog interface for pinned application and special-item metadata.
class DockItemCatalog : public QConcatenateTablesProxyModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QAbstractItemModel *applications READ applications WRITE setApplications NOTIFY applicationsChanged)
    Q_PROPERTY(QString trashTitle READ trashTitle WRITE setTrashTitle NOTIFY trashChanged)
    Q_PROPERTY(QString trashIconName READ trashIconName WRITE setTrashIconName NOTIFY trashChanged)
    Q_PROPERTY(QString downloadsTitle READ downloadsTitle WRITE setDownloadsTitle NOTIFY downloadsChanged)
    // User folder containers, in profile order. The built-in Downloads row stays
    // hardcoded; these are appended after it so existing profiles and tests keep
    // the same rows.
    Q_PROPERTY(QVariantList containers READ containers WRITE setContainers NOTIFY containersChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
public:
    explicit DockItemCatalog(QObject *parent = nullptr);
    QAbstractItemModel *applications() const { return m_applications; }
    void setApplications(QAbstractItemModel *model);
    QString trashTitle() const;
    void setTrashTitle(const QString &value);
    QString trashIconName() const;
    void setTrashIconName(const QString &value);
    QString downloadsTitle() const;
    void setDownloadsTitle(const QString &value);
    QVariantList containers() const { return m_containers; }
    void setContainers(const QVariantList &value);
    int revision() const { return m_revision; }
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE QVariantMap application(const QString &appId) const;
signals:
    void applicationsChanged();
    void trashChanged();
    void downloadsChanged();
    void containersChanged();
    void changed();
private:
    void notifyChange();
    void rebuildContainers();
    QPointer<QAbstractItemModel> m_applications;
    QStandardItemModel m_specials;
    QVariantList m_containers;
    int m_containerRows = 0;
    int m_revision = 0;
};
