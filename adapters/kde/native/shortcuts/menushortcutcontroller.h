// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QString>
#include <qqmlregistration.h>

class QAction;

// Owns the single global shortcut that opens or closes the fullscreen menu.
// The QAction keeps a stable component/action name so KGlobalAccel remembers
// the user's assignment across restarts. An empty configured shortcut removes
// the registration without destroying the action.
class MenuShortcutController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString configuredShortcut READ configuredShortcut WRITE setConfiguredShortcut
        NOTIFY configuredShortcutChanged)
    Q_PROPERTY(QString activeShortcut READ activeShortcut NOTIFY activeShortcutChanged)
    Q_PROPERTY(bool registered READ registered NOTIFY registeredChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit MenuShortcutController(QObject *parent = nullptr);
    ~MenuShortcutController() override;

    QString configuredShortcut() const { return m_configuredShortcut; }
    void setConfiguredShortcut(const QString &shortcut);

    QString activeShortcut() const { return m_activeShortcut; }
    bool registered() const { return m_registered; }
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    // Canonical portable form of a user-entered sequence. Empty when the text
    // is empty or cannot be parsed.
    static QString normalizeShortcut(const QString &shortcut);

Q_SIGNALS:
    void configuredShortcutChanged();
    void activeShortcutChanged();
    void registeredChanged();
    void enabledChanged();
    void activated();
    void shortcutRegistrationFailed(const QString &requestedShortcut);

private:
    void initializeAction();
    void applyConfiguredShortcut();
    void updateRegistered(bool registered);
    void updateActive(const QString &shortcut);

    QAction *m_action = nullptr;
    QString m_configuredShortcut;
    QString m_activeShortcut;
    bool m_registered = false;
    bool m_enabled = true;
};
