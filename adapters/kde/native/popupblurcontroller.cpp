// SPDX-License-Identifier: GPL-3.0-or-later
#include "popupblurcontroller.h"

#include <KWindowEffects>

#include <QPainterPath>
#include <QGuiApplication>
#include <QPolygon>
#include <QRegion>
#include <QtMath>

PopupBlurController::PopupBlurController(QObject *parent)
    : QObject(parent)
{
}

PopupBlurController::~PopupBlurController()
{
    if (m_window && m_effectApplied) {
        KWindowEffects::enableBlurBehind(m_window, false);
    }
}

QQuickWindow *PopupBlurController::window() const
{
    return m_window;
}

void PopupBlurController::setWindow(QQuickWindow *window)
{
    if (m_window == window) {
        return;
    }
    if (m_window && m_effectApplied) {
        KWindowEffects::enableBlurBehind(m_window, false);
    }
    m_window = window;
    const QString platform = QGuiApplication::platformName();
    const bool desktopPlatform = platform == QLatin1String("xcb") || platform.contains(QLatin1String("wayland"));
    m_available = m_window && desktopPlatform
        && KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
    m_effectApplied = false;
    m_lastAppliedRegion = {};
    if (m_window) {
        QQuickWindow *const observedWindow = m_window;
        connect(m_window, &QObject::destroyed, this, [this, observedWindow] {
            if (m_window != observedWindow) return;
            m_window = nullptr;
            m_available = false;
            emit availableChanged();
            emit windowChanged();
        });
    }
    emit windowChanged();
    emit availableChanged();
    updateEffect();
}

QRectF PopupBlurController::geometry() const { return m_geometry; }
void PopupBlurController::setGeometry(const QRectF &geometry)
{
    if (m_geometry == geometry) return;
    m_geometry = geometry;
    emit geometryChanged();
    updateEffect();
}

QString PopupBlurController::tailEdge() const { return m_tailEdge; }
void PopupBlurController::setTailEdge(const QString &edge)
{
    if (m_tailEdge == edge) return;
    m_tailEdge = edge;
    emit shapeChanged();
    updateEffect();
}

QPointF PopupBlurController::pointer() const { return m_pointer; }
void PopupBlurController::setPointer(const QPointF &pointer)
{
    if (m_pointer == pointer) return;
    m_pointer = pointer;
    emit shapeChanged();
    updateEffect();
}

qreal PopupBlurController::tailExtent() const { return m_tailExtent; }
void PopupBlurController::setTailExtent(qreal extent)
{
    extent = qMax<qreal>(0, extent);
    if (qFuzzyCompare(m_tailExtent + 1, extent + 1)) return;
    m_tailExtent = extent;
    emit shapeChanged();
    updateEffect();
}

qreal PopupBlurController::cornerRadius() const { return m_cornerRadius; }
void PopupBlurController::setCornerRadius(qreal radius)
{
    radius = qMax<qreal>(0, radius);
    if (qFuzzyCompare(m_cornerRadius + 1, radius + 1)) return;
    m_cornerRadius = radius;
    emit shapeChanged();
    updateEffect();
}

bool PopupBlurController::enabled() const { return m_enabled; }
void PopupBlurController::setEnabled(bool enabled)
{
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    emit enabledChanged();
    updateEffect();
}

bool PopupBlurController::available() const { return m_available; }

QRegion PopupBlurController::blurRegion() const
{
    if (!m_window || m_geometry.isEmpty() || !m_geometry.isValid()) return {};

    const QRectF localBounds(QPointF(0, 0), m_geometry.size());
    const qreal maximumTail = qMax<qreal>(0, qMin(localBounds.width(), localBounds.height()) / 3);
    const qreal tail = qMin(m_tailExtent, maximumTail);
    QPainterPath path;
    QRectF body = localBounds;
    if (m_tailEdge == QLatin1String("bottom")) body.setHeight(qMax<qreal>(0, body.height() - tail));
    else if (m_tailEdge == QLatin1String("left")) { body.setX(tail); body.setWidth(qMax<qreal>(0, body.width() - tail)); }
    else if (m_tailEdge == QLatin1String("right")) body.setWidth(qMax<qreal>(0, body.width() - tail));

    const qreal radius = qMax<qreal>(0, qMin(m_cornerRadius, qMin(body.width(), body.height()) / 2));
    path.addRoundedRect(body, radius, radius);
    if (tail > 0) {
        QPolygonF pointer;
        if (m_tailEdge == QLatin1String("left")) {
            const qreal y = qBound(radius + tail, m_pointer.y(), localBounds.height() - radius - tail);
            pointer << QPointF(body.left(), y - tail) << QPointF(0, y) << QPointF(body.left(), y + tail);
        } else if (m_tailEdge == QLatin1String("right")) {
            const qreal y = qBound(radius + tail, m_pointer.y(), localBounds.height() - radius - tail);
            pointer << QPointF(body.right(), y - tail) << QPointF(localBounds.width(), y) << QPointF(body.right(), y + tail);
        } else if (m_tailEdge == QLatin1String("bottom")) {
            const qreal x = qBound(radius + tail, m_pointer.x(), localBounds.width() - radius - tail);
            pointer << QPointF(x - tail, body.bottom()) << QPointF(x, localBounds.height()) << QPointF(x + tail, body.bottom());
        }
        if (!pointer.isEmpty()) path.addPolygon(pointer);
    }

    QPolygon polygon;
    const QPolygonF points = path.toFillPolygon();
    polygon.reserve(points.size());
    for (const QPointF &point : points) {
        polygon << QPoint(qRound(point.x() + m_geometry.x()), qRound(point.y() + m_geometry.y()));
    }
    QRegion region(polygon, Qt::WindingFill);
    region &= QRegion(QRect(0, 0, m_window->width(), m_window->height()));
    return region;
}

void PopupBlurController::updateEffect()
{
    if (!m_window) return;
    if (!m_enabled || !m_available) {
        if (m_effectApplied) KWindowEffects::enableBlurBehind(m_window, false);
        m_effectApplied = false;
        m_lastAppliedRegion = {};
        return;
    }
    const QRegion region = blurRegion();
    if (m_effectApplied && region == m_lastAppliedRegion) return;
    KWindowEffects::enableBlurBehind(m_window, !region.isEmpty(), region);
    m_effectApplied = !region.isEmpty();
    m_lastAppliedRegion = region;
}
