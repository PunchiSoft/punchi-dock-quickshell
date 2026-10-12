// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QtQml/QQmlParserStatus>
#include <QtQml/qqmlregistration.h>
#include <memory>

// Owns only an invisible, nonexclusive edge sensor. It never owns the dock scene.
class AutoHideEdge : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool armed READ armed WRITE setArmed NOTIFY armedChanged)
    Q_PROPERTY(int width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(QString screenName READ screenName WRITE setScreenName NOTIFY screenNameChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
public:
    explicit AutoHideEdge(QObject *parent = nullptr);
    ~AutoHideEdge() override;
    void classBegin() override {}
    void componentComplete() override;
    bool enabled() const { return m_enabled; }
    bool armed() const { return m_armed; }
    int width() const { return m_width; }
    int height() const { return m_height; }
    QString screenName() const { return m_screenName; }
    bool available() const { return m_available; }
    void setEnabled(bool value);
    void setArmed(bool value);
    void setWidth(int value);
    void setHeight(int value);
    void setScreenName(const QString &value);
signals:
    void enabledChanged();
    void armedChanged();
    void widthChanged();
    void heightChanged();
    void screenNameChanged();
    void availableChanged();
    void revealRequested();
private:
    struct Connection;
    std::unique_ptr<Connection> m_connection;
    void refresh(bool rebuild = false);
    void setAvailable(bool value);
    bool m_complete = false, m_enabled = false, m_armed = false, m_available = false;
    int m_width = 1, m_height = 1;
    QString m_screenName;
};
