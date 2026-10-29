// SPDX-License-Identifier: GPL-3.0-or-later
#include "windowvisibilitystate.h"
#include <QJsonArray>
#include <cmath>
#include <climits>

namespace {
bool safeRect(const QRectF &r) {
    return std::isfinite(r.x()) && std::isfinite(r.y()) && std::isfinite(r.width())
        && std::isfinite(r.height()) && std::abs(r.x()) <= 1000000
        && std::abs(r.y()) <= 1000000 && r.width() > 0 && r.width() <= 1000000
        && r.height() > 0 && r.height() <= 1000000;
}
}
bool WindowVisibilityState::overlaps(const QRectF &region) const {
    if (!m_available || m_showingDesktop || !safeRect(region)) return false;
    for (const auto &window : m_windows) if (window.intersects(region)) return true;
    return false;
}
void WindowVisibilityState::accept(const QJsonObject &snapshot) {
    if (!snapshot.value("available").isBool() || !snapshot.value("available").toBool()
        || !snapshot.value("showingDesktop").isBool() || !snapshot.value("rectangles").isArray()) { clear(); return; }
    const auto array = snapshot.value("rectangles").toArray();
    if (array.size() > 512) { clear(); return; }
    QVector<QRectF> windows;
    for (const auto value : array) {
        if (!value.isArray() || value.toArray().size() != 4) { clear(); return; }
        const auto r = value.toArray();
        for (const auto coordinate : r) if (!coordinate.isDouble()) { clear(); return; }
        const QRectF rect(r[0].toDouble(), r[1].toDouble(), r[2].toDouble(), r[3].toDouble());
        if (!safeRect(rect)) { clear(); return; }
        windows.append(rect);
    }
    update(true, snapshot.value("showingDesktop").toBool(), windows);
}
void WindowVisibilityState::clear() { update(false, false); }
void WindowVisibilityState::update(bool available, bool showingDesktop, const QVector<QRectF> &windows) {
    if (m_available == available && m_showingDesktop == showingDesktop && m_windows == windows) return;
    m_available = available; m_showingDesktop = showingDesktop; m_windows = windows;
    m_revision = m_revision == INT_MAX ? 0 : m_revision + 1;
    emit changed();
}
