// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QtQml/qqmlregistration.h>
#include <KService>
#include "recentdocuments.h"
#include "fileplaces.h"
#include "foldercontents.h"

class DesktopLauncher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickItem *activationItem READ activationItem WRITE setActivationItem NOTIFY activationItemChanged)
public:
    explicit DesktopLauncher(QObject *parent = nullptr) : QObject(parent) {}
    QQuickItem *activationItem() const { return m_activationItem; }
    void setActivationItem(QQuickItem *item);
    Q_INVOKABLE bool launch(const QString &desktopId);
    Q_INVOKABLE QVariantList actions(const QString &desktopId) const;
    Q_INVOKABLE bool launchAction(const QString &desktopId, const QString &actionId);
    Q_INVOKABLE bool canLaunchNewWindow(const QString &desktopId) const;
    Q_INVOKABLE bool openPlace(FilePlaces *places, const QString &resource);
    Q_INVOKABLE bool openRecent(RecentDocuments *documents, const QString &resource);
    Q_INVOKABLE bool openTrash();
    Q_INVOKABLE bool openDownloads();
    Q_INVOKABLE bool openFolderUrl(FolderContents *contents, const QUrl &url);
    Q_INVOKABLE bool openFolderLocation(const QUrl &url);
    Q_INVOKABLE bool openFolderPath(const QString &path);
signals:
    void activationItemChanged();
    void launchFinished(const QString &desktopId, bool success, const QString &error);
private:
    KService::Ptr resolve(const QString &desktopId) const;
    bool enqueue(const KService::Ptr &service, const QString &desktopId, const KServiceAction &action = {},
        const QList<QUrl> &urls = {});
    void startJob(const KService::Ptr &service, const QString &desktopId, const QByteArray &token,
        const KServiceAction &action, const QList<QUrl> &urls);
    QPointer<QQuickItem> m_activationItem;
    int m_pending = 0;
};
