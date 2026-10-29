// SPDX-License-Identifier: GPL-3.0-or-later
#include "trashstate.h"
#include <KCoreDirLister>
#include <KFileItem>
#include <KIO/EmptyTrashJob>
#include <KJob>
#include <QTimer>

TrashState::TrashState(QObject *parent) : TrashState(new KCoreDirLister, parent) {
    QTimer::singleShot(0, this, &TrashState::refresh);
}
TrashState::TrashState(KCoreDirLister *lister, QObject *parent) : QObject(parent), m_lister(lister) {
    m_lister->setParent(this);
    m_lister->setAutoErrorHandlingEnabled(false);
    m_lister->setAutoUpdate(true);
    m_lister->setShowHiddenFiles(true);
    connect(m_lister, &KCoreDirLister::clear, this, [this] { m_rebuilding = true; m_pendingItems.clear(); });
    connect(m_lister, &KCoreDirLister::itemsAdded, this, [this](const QUrl &, const KFileItemList &items) {
        auto &target = m_rebuilding ? m_pendingItems : m_items;
        for (const auto &item : items) target.insert(item.url());
        if (!m_rebuilding) emit changed();
    });
    connect(m_lister, &KCoreDirLister::itemsDeleted, this, [this](const KFileItemList &items) {
        auto &target = m_rebuilding ? m_pendingItems : m_items;
        for (const auto &item : items) target.remove(item.url());
        if (!m_rebuilding) emit changed();
    });
    connect(m_lister, &KCoreDirLister::completed, this, &TrashState::listingFinished);
    connect(m_lister, &KCoreDirLister::canceled, this, &TrashState::listingFailed);
    connect(m_lister, &KCoreDirLister::jobError, this, &TrashState::listingFailed);
}
TrashState::~TrashState() {
    if (m_job) m_job->kill(KJob::Quietly);
}
void TrashState::refresh() {
    if (m_lister->url() != QUrl(QStringLiteral("trash:/"))) m_lister->openUrl(QUrl(QStringLiteral("trash:/")));
    else if (!m_lister->isFinished()) m_refreshPending = true;
    else m_lister->updateDirectory(m_lister->url());
}
void TrashState::listingFinished() {
    if (m_rebuilding) m_items.swap(m_pendingItems);
    m_pendingItems.clear(); m_rebuilding = false; m_available = true;
    emit changed();
    if (m_refreshPending) { m_refreshPending = false; QTimer::singleShot(0, this, &TrashState::refresh); }
}
void TrashState::listingFailed() {
    m_pendingItems.clear(); m_rebuilding = false; m_available = false; m_refreshPending = false;
    emit changed();
}
KJob *TrashState::createEmptyJob() { return KIO::emptyTrash(); }
bool TrashState::emptyAfterConfirmation() {
    if (!available() || !hasItems() || busy()) return false;
    auto *job = createEmptyJob();
    if (!job) return false;
    job->setParent(this);
    job->setUiDelegate(nullptr);
    m_job = job;
    emit changed();
    connect(job, &KJob::result, this, [this, job] {
        m_job = nullptr;
        const bool success = !job->error();
        // Refresh through the native provider even after partial failure. Do not
        // invent an empty state before the directory listing confirms it.
        refresh();
        emit changed();
        emit operationFinished(success, success ? QString() : job->errorString());
    });
    return true;
}
