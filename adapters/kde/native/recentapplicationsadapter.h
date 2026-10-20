// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QIdentityProxyModel>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QFileSystemWatcher;
namespace KActivities { class Consumer; }

// Adapts the public Activities Stats model without owning a second history.
class RecentApplicationsAdapter : public QIdentityProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool available READ available NOTIFY availabilityChanged)
    Q_PROPERTY(bool trackingEnabled READ trackingEnabled NOTIFY trackingEnabledChanged)

public:
    enum Role { StorageIdRole = Qt::UserRole + 100, NameRole, IconRole };
    explicit RecentApplicationsAdapter(QObject *parent = nullptr);
    bool enabled() const;
    void setEnabled(bool enabled);
    bool available() const;
    // KDE's resource scoring can be set to remember no applications at all.
    // The history stays empty in that case, so the UI can explain why.
    bool trackingEnabled() const;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    // Resolves application resources only. Never interprets history as commands.
    static QVariantMap resolveResource(const QString &resource);
    Q_INVOKABLE void recordAccess(const QString &storageId);
    // Writes the two public states: remember all applications or none. KDE's
    // per-application allow/block lists are preserved.
    Q_INVOKABLE bool setTrackingEnabled(bool enabled);
    // Opens KDE's Recent Files module, which owns the tracking preference.
    Q_INVOKABLE bool openTrackingSettings();

signals:
    void enabledChanged();
    void availabilityChanged();
    void trackingEnabledChanged();

private:
    bool m_enabled = false;
    bool m_trackingEnabled = true;
    QString m_configPath;
    QFileSystemWatcher *m_configWatcher = nullptr;
    KActivities::Consumer *m_consumer = nullptr;
    void updateSource();
    void watchConfiguration();
    void reloadTracking();
    mutable QHash<QString, QVariantMap> m_applications;
};
