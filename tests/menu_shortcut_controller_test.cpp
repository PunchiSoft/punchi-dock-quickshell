// SPDX-License-Identifier: GPL-3.0-or-later
#include "adapters/kde/native/shortcuts/menushortcutcontroller.h"

#include <QTest>

class MenuShortcutControllerTest : public QObject
{
    Q_OBJECT

private slots:
    void normalizesPortableText();
    void rejectsEmptyAndInvalid();
};

void MenuShortcutControllerTest::normalizesPortableText()
{
    QCOMPARE(MenuShortcutController::normalizeShortcut(QStringLiteral("Ctrl+Alt+M")),
        QStringLiteral("Ctrl+Alt+M"));
    QCOMPARE(MenuShortcutController::normalizeShortcut(QStringLiteral("Ctrl+Shift+S")),
        QStringLiteral("Ctrl+Shift+S"));
    QCOMPARE(MenuShortcutController::normalizeShortcut(QStringLiteral("  Meta  ")),
        QStringLiteral("Meta"));
}

void MenuShortcutControllerTest::rejectsEmptyAndInvalid()
{
    QCOMPARE(MenuShortcutController::normalizeShortcut(QString()), QString());
    QCOMPARE(MenuShortcutController::normalizeShortcut(QStringLiteral("not a shortcut")),
        QString());
}

QTEST_GUILESS_MAIN(MenuShortcutControllerTest)
#include "menu_shortcut_controller_test.moc"
