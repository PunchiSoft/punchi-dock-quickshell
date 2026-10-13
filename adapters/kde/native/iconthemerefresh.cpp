// SPDX-License-Identifier: GPL-3.0-or-later
#include "iconthemerefresh.h"
#include <QCoreApplication>
#include <QDBusConnection>
#include <QThread>

// Share the official KDE event subscription; KIconLoader owns cache invalidation.
class IconThemeNotifications : public QObject
{
    Q_OBJECT
public:
    explicit IconThemeNotifications(QObject *parent) : QObject(parent)
    {
        QDBusConnection::sessionBus().connect(QString(), QStringLiteral("/KIconLoader"),
            QStringLiteral("org.kde.KIconLoader"), QStringLiteral("iconChanged"),
            this, SLOT(onIconsChanged(int)));
    }
    static IconThemeNotifications *instance()
    {
        Q_ASSERT(QThread::currentThread() == QCoreApplication::instance()->thread());
        static QPointer<IconThemeNotifications> notifications;
        if (!notifications)
            notifications = new IconThemeNotifications(QCoreApplication::instance());
        return notifications;
    }
Q_SIGNALS:
    void iconsChanged();
private Q_SLOTS:
    void onIconsChanged(int) { Q_EMIT iconsChanged(); }
};

IconThemeRefreshAttached::IconThemeRefreshAttached(QObject *target)
    : QObject(target), m_item(qobject_cast<QQuickItem *>(target))
{
    if (!m_item) return;
    connect(IconThemeNotifications::instance(), &IconThemeNotifications::iconsChanged, this, [this] {
        // Queue after KDE handles the notification. Polish regenerates the icon
        // on the GUI thread before rendering, without replacing source or state.
        if (m_enabled && m_item) m_item->polish();
    }, Qt::QueuedConnection);
}

void IconThemeRefreshAttached::setEnabled(bool value)
{
    if (m_enabled == value) return;
    m_enabled = value;
    Q_EMIT enabledChanged();
}

#include "iconthemerefresh.moc"
