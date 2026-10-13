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
    int revision() const { return m_revision; }
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE QVariantMap application(const QString &appId) const;
signals:
    void applicationsChanged();
    void trashChanged();
    void changed();
private:
    void notifyChange();
    QPointer<QAbstractItemModel> m_applications;
    QStandardItemModel m_specials;
    int m_revision = 0;
};
