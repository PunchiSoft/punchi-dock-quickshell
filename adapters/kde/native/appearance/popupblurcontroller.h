// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QPointF>
#include <QQuickWindow>
#include <QRegion>
#include <QRectF>
#include <QtQml/qqmlregistration.h>

class PopupBlurController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(QRectF geometry READ geometry WRITE setGeometry NOTIFY geometryChanged)
    Q_PROPERTY(QString tailEdge READ tailEdge WRITE setTailEdge NOTIFY shapeChanged)
    Q_PROPERTY(QPointF pointer READ pointer WRITE setPointer NOTIFY shapeChanged)
    Q_PROPERTY(qreal tailExtent READ tailExtent WRITE setTailExtent NOTIFY shapeChanged)
    Q_PROPERTY(qreal cornerRadius READ cornerRadius WRITE setCornerRadius NOTIFY shapeChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit PopupBlurController(QObject *parent = nullptr);
    ~PopupBlurController() override;

    QQuickWindow *window() const;
    void setWindow(QQuickWindow *window);
    QRectF geometry() const;
    void setGeometry(const QRectF &geometry);
    QString tailEdge() const;
    void setTailEdge(const QString &edge);
    QPointF pointer() const;
    void setPointer(const QPointF &pointer);
    qreal tailExtent() const;
    void setTailExtent(qreal extent);
    qreal cornerRadius() const;
    void setCornerRadius(qreal radius);
    bool enabled() const;
    void setEnabled(bool enabled);
    bool available() const;

signals:
    void windowChanged();
    void geometryChanged();
    void shapeChanged();
    void enabledChanged();
    void availableChanged();

private:
    void updateEffect();
    QRegion blurRegion() const;

    QPointer<QQuickWindow> m_window;
    QRectF m_geometry;
    QString m_tailEdge = QStringLiteral("bottom");
    QPointF m_pointer;
    qreal m_tailExtent = 0;
    qreal m_cornerRadius = 0;
    bool m_enabled = false;
    bool m_available = false;
    bool m_effectApplied = false;
    QRegion m_lastAppliedRegion;
};
