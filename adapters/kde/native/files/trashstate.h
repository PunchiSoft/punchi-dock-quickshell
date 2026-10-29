// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QUrl>
#include <QtQml/qqmlregistration.h>
class KCoreDirLister;
class KJob;

class TrashState : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool hasItems READ hasItems NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
public:
    explicit TrashState(QObject *parent = nullptr);
    ~TrashState() override;
    bool available() const { return m_available; }
    bool hasItems() const { return !m_items.isEmpty(); }
    bool busy() const { return !m_job.isNull(); }
    Q_INVOKABLE virtual void refresh();
    // Only the confirmation coordinator calls this after an explicit acceptance.
    Q_INVOKABLE bool emptyAfterConfirmation();
signals:
    void changed();
    void operationFinished(bool success, const QString &error);
protected:
    // Tests substitute owned listers/jobs; never empty real mounted-volume trash.
    explicit TrashState(KCoreDirLister *lister, QObject *parent);
    virtual KJob *createEmptyJob();
private:
    void listingFinished();
    void listingFailed();
    KCoreDirLister *m_lister;
    QPointer<KJob> m_job;
    QSet<QUrl> m_items, m_pendingItems;
    bool m_available = false, m_rebuilding = false, m_refreshPending = false;
};
