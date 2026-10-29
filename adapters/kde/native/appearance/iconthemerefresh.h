// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <qqmlintegration.h>

class IconThemeRefreshAttached : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
public:
    explicit IconThemeRefreshAttached(QObject *target);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool value);
Q_SIGNALS:
    void enabledChanged();
private:
    QPointer<QQuickItem> m_item;
    bool m_enabled = false;
};

class IconThemeRefresh : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Attach IconThemeRefresh to a themed icon item.")
    QML_ATTACHED(IconThemeRefreshAttached)
public:
    static IconThemeRefreshAttached *qmlAttachedProperties(QObject *target)
    {
        return new IconThemeRefreshAttached(target);
    }
};
