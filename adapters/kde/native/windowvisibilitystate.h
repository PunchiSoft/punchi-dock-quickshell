// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QJsonObject>
#include <QRectF>
#include <QVector>
#include <QtQml/qqmlregistration.h>

// Visibility is separate from application identity and launch state.
class WindowVisibilityState : public QObject {
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool showingDesktop READ showingDesktop NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
public:
    explicit WindowVisibilityState(QObject *parent = nullptr) : QObject(parent) {}
    bool available() const { return m_available; }
    bool showingDesktop() const { return m_showingDesktop; }
    int revision() const { return m_revision; }
    Q_INVOKABLE bool overlaps(const QRectF &region) const;
    void accept(const QJsonObject &snapshot);
    void clear();
signals:
    void changed();
private:
    void update(bool available, bool showingDesktop, const QVector<QRectF> &windows = {});
    bool m_available = false, m_showingDesktop = false;
    int m_revision = 0;
    QVector<QRectF> m_windows;
};
