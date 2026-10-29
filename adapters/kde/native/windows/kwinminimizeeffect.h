// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <KConfigWatcher>
#include <KSharedConfig>

class KWinMinimizeEffectController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString effect READ effect NOTIFY effectChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool squashAvailable READ squashAvailable NOTIFY effectsChanged)
    Q_PROPERTY(bool magicLampAvailable READ magicLampAvailable NOTIFY effectsChanged)
public:
    explicit KWinMinimizeEffectController(QObject *parent = nullptr);
    ~KWinMinimizeEffectController() override;

    QString effect() const { return m_effect; }
    bool available() const { return m_available; }
    bool squashAvailable() const { return m_minimizePlugins.contains(QStringLiteral("squash")); }
    bool magicLampAvailable() const { return m_minimizePlugins.contains(QStringLiteral("magiclamp")); }
    Q_INVOKABLE bool setEffect(const QString &effect);
    static bool restoreOwnedSettings();

signals:
    void effectChanged();
    void availableChanged();
    void effectsChanged();

private:
    void refresh();
    void refreshAvailability();

    KSharedConfig::Ptr m_config;
    KConfigWatcher::Ptr m_watcher;
    QString m_effect = QStringLiteral("none");
    QStringList m_minimizePlugins;
    bool m_available = false;
};
