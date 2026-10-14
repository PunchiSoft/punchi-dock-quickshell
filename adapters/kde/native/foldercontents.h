// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QIdentityProxyModel>
#include <QConcatenateTablesProxyModel>
#include <QStandardItemModel>
#include <QUrl>
#include <QPointer>
#include <QtQml/qqmlregistration.h>
#include <KDirModel>
#include <KDirSortFilterProxyModel>
#include <KFileItem>

// Native directory rows remain owned by KDirModel; this exposes a flat QML view.
class FolderContents : public QIdentityProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QUrl downloadsUrl READ downloadsUrl CONSTANT)
    Q_PROPERTY(QUrl location READ location WRITE setLocation NOTIFY locationChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(int count READ count NOTIFY entriesChanged)
    Q_PROPERTY(int revision READ revision NOTIFY entriesChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
public:
    enum Role { EntryUrl = Qt::UserRole + 400, EntryName, EntryIcon, Directory, Description };
    explicit FolderContents(QObject *parent = nullptr);
    QUrl downloadsUrl() const;
    QUrl location() const { return m_location; }
    void setLocation(const QUrl &url);
    bool active() const { return m_active; }
    void setActive(bool value);
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    int count() const { return rowCount(); }
    int revision() const { return m_revision; }
    QString sortMode() const { return m_sortMode; }
    void setSortMode(const QString &mode);
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role) const override;
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int indexOfUrl(const QUrl &url) const;
    KFileItem itemForUrl(const QUrl &url) const;
    static bool localUrl(const QUrl &url);
Q_SIGNALS:
    void locationChanged();
    void activeChanged();
    void stateChanged();
    void entriesChanged();
    void sortModeChanged();
private:
    void refresh();
    void changed();
    KDirModel m_directory;
    class FolderSortModel;
    FolderSortModel *m_sorted = nullptr;
    QString m_sortMode;
    QUrl m_location;
    bool m_active = false, m_loading = false;
    QString m_error;
    int m_revision = 0;
};

// Append the open-location cell to Grid without inventing a filesystem entry.
class FolderEntriesModel : public QConcatenateTablesProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(FolderContents *contents READ contents WRITE setContents NOTIFY contentsChanged)
public:
    enum { LocationAction = Qt::UserRole + 450 };
    explicit FolderEntriesModel(QObject *parent = nullptr);
    FolderContents *contents() const { return m_contents; }
    void setContents(FolderContents *contents);
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role) const override;
Q_SIGNALS:
    void contentsChanged();
private:
    QPointer<FolderContents> m_contents;
    QStandardItemModel m_action;
};
