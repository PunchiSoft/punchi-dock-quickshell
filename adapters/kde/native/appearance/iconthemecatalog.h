// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QAbstractListModel>
#include <QSortFilterProxyModel>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// Names of the icons installed in the active Plasma icon theme, including the
// themes it inherits. The settings picker lists names only: Qt resolves each
// name through the same theme when the preview is painted.
class IconThemeCatalog : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString themeName READ themeName NOTIFY changed)
    Q_PROPERTY(int count READ rowCount NOTIFY changed)
    Q_PROPERTY(bool loaded READ loaded NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    // True when the current contents came from the scan cache on disk.
    Q_PROPERTY(bool cached READ cached NOTIFY changed)
    // Contexts the theme declares, in the order the picker lists them.
    Q_PROPERTY(QStringList contexts READ contexts NOTIFY changed)
public:
    enum Role { IconName = Qt::UserRole + 1, IconContext };

    // Scanned theme contents, independent of the model so the work can run on
    // a worker thread.
    struct Snapshot {
        QString theme;
        QStringList names;
        QStringList rowContexts;
        QStringList contextNames;
        bool cached = false;
    };

    explicit IconThemeCatalog(QObject *parent = nullptr);
    ~IconThemeCatalog() override;
    QString themeName() const { return m_themeName; }
    bool loaded() const { return m_loaded; }
    bool loading() const { return m_loading; }
    bool cached() const { return m_cached; }
    QStringList contexts() const { return m_contextNames; }
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE void reload();
    // Enumerates one theme plus the themes it inherits, reusing the scan cache
    // when the theme is unchanged since the previous run.
    static Snapshot buildSnapshot(const QString &theme, const QStringList &searchPaths);
signals:
    void changed();
private:
    void load();
    void apply(const Snapshot &snapshot);
    QStringList m_names;
    // Context of each row, parallel to m_names, and the distinct names offered
    // by the picker in a stable order.
    QStringList m_rowContexts;
    QStringList m_contextNames;
    QString m_themeName;
    bool m_loaded = false;
    bool m_loading = false;
    bool m_cached = false;
};

class IconThemeSearchModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)
    // Empty shows every context; otherwise only that context's icons.
    Q_PROPERTY(QString context READ context WRITE setContext NOTIFY contextChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
public:
    explicit IconThemeSearchModel(QObject *parent = nullptr);
    QString query() const { return m_query; }
    void setQuery(const QString &query);
    QString context() const { return m_context; }
    void setContext(const QString &context);
signals:
    void queryChanged();
    void contextChanged();
    void countChanged();
protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;
private:
    QString m_query;
    QString m_context;
};
