// SPDX-License-Identifier: GPL-3.0-or-later
#include "menushortcutcontroller.h"

#include <KGlobalAccel>

#include <QAction>
#include <QCoreApplication>
#include <QIcon>
#include <QKeySequence>

namespace
{
// Stable identifiers: the user's KGlobalAccel assignment is stored under this
// component/action pair, so neither may change between releases.
constexpr auto ComponentName = "punchi-dock-quickshell";
constexpr auto ActionName = "toggle-punchimenu";
}

MenuShortcutController::MenuShortcutController(QObject *parent)
    : QObject(parent)
{
    initializeAction();
}

MenuShortcutController::~MenuShortcutController() = default;

QString MenuShortcutController::normalizeShortcut(const QString &shortcut)
{
    const QString trimmed = shortcut.trimmed();
    if (trimmed.isEmpty()) return {};

    QKeySequence sequence = QKeySequence::fromString(trimmed, QKeySequence::PortableText);
    if (sequence.isEmpty())
        sequence = QKeySequence::fromString(trimmed, QKeySequence::NativeText);
    return sequence.isEmpty() ? QString()
                              : sequence.toString(QKeySequence::PortableText);
}

void MenuShortcutController::setConfiguredShortcut(const QString &shortcut)
{
    const QString normalized = normalizeShortcut(shortcut);
    // Emit even when normalization lands on the current value: a profile may
    // carry a non-canonical string that the service must write back, or the
    // same invalid string every start. Comparing the raw input prevents that
    // silent disagreement.
    if (m_configuredShortcut == normalized && shortcut == normalized) return;

    m_configuredShortcut = normalized;
    Q_EMIT configuredShortcutChanged();
    applyConfiguredShortcut();
}

void MenuShortcutController::setEnabled(bool enabled)
{
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    if (m_action) m_action->setEnabled(enabled);
    Q_EMIT enabledChanged();
}

void MenuShortcutController::initializeAction()
{
    if (m_action) return;

    m_action = new QAction(this);
    m_action->setObjectName(QString::fromLatin1(ActionName));
    m_action->setProperty("componentName", QString::fromLatin1(ComponentName));
    m_action->setProperty("componentDisplayName", QStringLiteral("Punchi Dock Quickshell"));
    m_action->setText(QCoreApplication::translate("MenuShortcut", "Open or close the menu"));
    m_action->setIcon(QIcon::fromTheme(QStringLiteral("start-here-kde")));
    m_action->setShortcutContext(Qt::ApplicationShortcut);
    m_action->setEnabled(m_enabled);

    connect(m_action, &QAction::triggered, this, &MenuShortcutController::activated);
    connect(KGlobalAccel::self(), &KGlobalAccel::globalShortcutChanged, this,
        [this](QAction *action, const QKeySequence &shortcut) {
            if (action != m_action) return;
            updateActive(shortcut.toString(QKeySequence::PortableText));
        });

    // No default: the user opts into a global key grab from Settings.
    KGlobalAccel::self()->setDefaultShortcut(m_action, {}, KGlobalAccel::NoAutoloading);
    applyConfiguredShortcut();
}

void MenuShortcutController::applyConfiguredShortcut()
{
    if (!m_action) initializeAction();
    if (!m_action) return;

    const QKeySequence requested = QKeySequence::fromString(
        m_configuredShortcut, QKeySequence::PortableText);
    const QList<QKeySequence> requestedShortcuts = requested.isEmpty()
        ? QList<QKeySequence>() : QList<QKeySequence>{requested};

    const bool registrationSucceeded = KGlobalAccel::self()->setShortcut(
        m_action, requestedShortcuts, KGlobalAccel::NoAutoloading);
    const QList<QKeySequence> active = KGlobalAccel::self()->shortcut(m_action);
    const QString nextShortcut = active.isEmpty()
        ? QString() : active.constFirst().toString(QKeySequence::PortableText);
    updateActive(nextShortcut);

    const bool registered = !m_configuredShortcut.isEmpty()
        && registrationSucceeded && nextShortcut == m_configuredShortcut;
    updateRegistered(registered);

    if (!m_configuredShortcut.isEmpty() && !registered)
        Q_EMIT shortcutRegistrationFailed(m_configuredShortcut);
}

void MenuShortcutController::updateRegistered(bool registered)
{
    if (m_registered == registered) return;
    m_registered = registered;
    Q_EMIT registeredChanged();
}

void MenuShortcutController::updateActive(const QString &shortcut)
{
    if (m_activeShortcut == shortcut) return;
    m_activeShortcut = shortcut;
    Q_EMIT activeShortcutChanged();
}
