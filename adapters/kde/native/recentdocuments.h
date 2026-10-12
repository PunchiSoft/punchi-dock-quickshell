// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QSortFilterProxyModel>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class RecentDocuments : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString desktopId READ desktopId WRITE setDesktopId NOTIFY desktopIdChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
public:
    enum Role { Resource = Qt::UserRole + 100, Name, Icon };
    explicit RecentDocuments(QObject *parent = nullptr);
    QString desktopId() const { return m_desktopId; }
    void setDesktopId(const QString &id);
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role) const override;
    Q_INVOKABLE bool forget();
    QModelIndex indexForResource(const QString &resource) const;
    QString mimeType(const QModelIndex &index) const;
    static QUrl documentUrl(const QString &resource);
signals:
    void desktopIdChanged();
    void countChanged();
protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;
private:
    QString m_desktopId;
};
