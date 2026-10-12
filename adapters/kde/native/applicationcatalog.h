// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QAbstractListModel>
#include <QPointer>
#include <QSortFilterProxyModel>
#include <QtQml/qqmlregistration.h>

class ApplicationCatalog : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QAbstractItemModel *presets READ presets WRITE setPresets NOTIFY presetsChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
public:
    enum Role { AppId = Qt::UserRole + 1, DesktopId, Title, Icon, Name, Description, Installed, ApplicationIcon };
    explicit ApplicationCatalog(QObject *parent = nullptr);
    QAbstractItemModel *presets() const { return m_presets; }
    void setPresets(QAbstractItemModel *presets);
    int revision() const { return m_revision; }
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE QVariantMap application(const QString &appId) const;
signals:
    void presetsChanged();
    void changed();
private:
    void reload();
    QPointer<QAbstractItemModel> m_presets;
    QList<QVariantMap> m_rows;
    int m_revision = 0;
};

class ApplicationSearchModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
public:
    explicit ApplicationSearchModel(QObject *parent = nullptr);
    QString query() const { return m_query; }
    void setQuery(const QString &query);
signals:
    void queryChanged();
    void countChanged();
protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;
private:
    QString m_query;
};
