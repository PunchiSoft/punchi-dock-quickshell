// SPDX-License-Identifier: GPL-3.0-or-later
#include "desktoplauncher.h"
#include "desktopentry.h"
#include "recentdocuments.h"
#include <KApplicationTrader>

#include <KIO/ApplicationLauncherJob>
#include <KWaylandExtras>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QTimer>

void DesktopLauncher::setActivationItem(QQuickItem *item)
{
    if (m_activationItem == item) return;
    m_activationItem = item;
    emit activationItemChanged();
}

KService::Ptr DesktopLauncher::resolve(const QString &desktopId) const
{
    return resolveDesktopApplication(desktopId);
}

bool DesktopLauncher::canLaunchNewWindow(const QString &desktopId) const
{
    const auto service = resolve(desktopId);
    if (!service || service->noDisplay() || service->property<bool>(QStringLiteral("SingleMainWindow"))
        || service->property<bool>(QStringLiteral("X-GNOME-SingleWindow"))) return false;
    for (const auto &action : service->actions()) {
        if ((action.name().startsWith(QLatin1String("new"), Qt::CaseInsensitive)
                && action.name().endsWith(QLatin1String("window"), Qt::CaseInsensitive))
            || action.name() == QLatin1String("WindowNew")) return false;
    }
    return true;
}

bool DesktopLauncher::openRecent(RecentDocuments *documents, const QString &resource)
{
    if (!documents) return false;
    const auto index = documents->indexForResource(resource);
    auto service = resolve(documents->desktopId());
    if (!index.isValid() || !service) return false;
    const auto mime = documents->mimeType(index);
    if (!mime.isEmpty() && mime != QLatin1String("application/octet-stream") && !service->hasMimeType(mime))
        service = KApplicationTrader::preferredService(mime);
    return enqueue(service, documents->desktopId(), {}, {RecentDocuments::documentUrl(resource)});
}

bool DesktopLauncher::openPlace(FilePlaces *places, const QString &resource)
{
    if (!places) return false;
    const auto service = resolve(places->desktopId());
    const auto url = places->urlForResource(resource);
    if (!service || !service->categories().contains(QStringLiteral("FileManager")) || url.isEmpty()) return false;
    return enqueue(service, places->desktopId(), {}, {url});
}

QVariantList DesktopLauncher::actions(const QString &desktopId) const
{
    QVariantList result;
    const auto service = resolve(desktopId);
    if (!service) return result;
    for (const auto &action : service->actions()) {
        if (action.noDisplay() || action.isSeparator() || action.name().isEmpty() || action.exec().isEmpty()) continue;
        result.append(QVariantMap{{QStringLiteral("actionId"), action.name()},
            {QStringLiteral("name"), action.text()}, {QStringLiteral("icon"), action.icon()}});
    }
    return result;
}

bool DesktopLauncher::launch(const QString &desktopId)
{
    return enqueue(resolve(desktopId), desktopId);
}

bool DesktopLauncher::launchAction(const QString &desktopId, const QString &actionId)
{
    const auto service = resolve(desktopId);
    if (!service || actionId.isEmpty()) return false;
    for (const auto &action : service->actions()) {
        if (action.name() == actionId && !action.noDisplay() && !action.isSeparator() && !action.exec().isEmpty())
            return enqueue(service, desktopId, action);
    }
    return false;
}

bool DesktopLauncher::enqueue(const KService::Ptr &service, const QString &desktopId, const KServiceAction &action,
    const QList<QUrl> &urls)
{
    if (!service || m_pending >= 16) return false;

    const bool wayland = QGuiApplication::platformName() == QLatin1String("wayland");
    QWindow *window = m_activationItem ? m_activationItem->window() : nullptr;
    if (wayland && (!window || !window->isVisible())) return false;
    ++m_pending;
    if (!wayland) {
        startJob(service, desktopId, {}, action, urls);
        return true;
    }

    // Capture the input serial synchronously inside the user's activation handler.
    const quint32 serial = KWaylandExtras::lastInputSerial(window);
    auto *watcher = new QFutureWatcher<QString>(this);
    auto *timeout = new QTimer(watcher);
    timeout->setSingleShot(true);
    connect(timeout, &QTimer::timeout, this, [this, watcher, desktopId] {
        disconnect(watcher, nullptr, this, nullptr);
        watcher->deleteLater();
        --m_pending;
        emit launchFinished(desktopId, false, QStringLiteral("Wayland activation request timed out"));
    });
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, timeout, service, desktopId, action, urls] {
        timeout->stop();
        const QString token = !watcher->future().isCanceled() && watcher->future().resultCount() > 0
            ? watcher->result() : QString();
        watcher->deleteLater();
        if (token.isEmpty()) {
            --m_pending;
            emit launchFinished(desktopId, false, QStringLiteral("Wayland activation token was unavailable"));
            return;
        }
        startJob(service, desktopId, token.toUtf8(), action, urls);
    });
    timeout->start(2000);
    watcher->setFuture(KWaylandExtras::xdgActivationToken(window, serial, service->desktopEntryName()));
    return true;
}

void DesktopLauncher::startJob(const KService::Ptr &service, const QString &desktopId,
    const QByteArray &token, const KServiceAction &action, const QList<QUrl> &urls)
{
    auto *job = action.name().isEmpty() ? new KIO::ApplicationLauncherJob(service, this)
        : new KIO::ApplicationLauncherJob(action, this);
    job->setUiDelegate(nullptr);
    if (!urls.isEmpty()) job->setUrls(urls);
    if (!token.isEmpty()) job->setStartupId(token);
    connect(job, &KJob::result, this, [this, desktopId](KJob *finished) {
        --m_pending;
        emit launchFinished(desktopId, finished->error() == 0, finished->errorString());
    });
    job->start();
}
