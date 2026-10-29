// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QString>
#include <qqmlintegration.h>

// Distribution identity for the menu header. Quickshell exposes no os-release
// reader, and the value is constant for the life of the session, so one small
// adapter answers both questions the header asks.
class DistributionInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString logo READ logo CONSTANT)
public:
    explicit DistributionInfo(QObject *parent = nullptr);
    QString name() const { return m_name; }
    QString logo() const { return m_logo; }
private:
    QString m_name;
    QString m_logo;
};
