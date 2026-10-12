// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include "adapters/kde/window-state/snapshot.h"

class WindowModelsTest : public QObject {
    Q_OBJECT
private slots:
    void nativeResourceModelsAndGeometryRoles() {
        QQmlEngine engine;
        QQmlComponent component(&engine,
            QUrl(QStringLiteral("qrc:/adapters/kde/window-state/WindowModels.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> models(component.create());
        QVERIFY(models);
        auto *all = qobject_cast<QAbstractItemModel *>(models->property("allTasks").value<QObject *>());
        auto *visible = qobject_cast<QAbstractItemModel *>(models->property("visibleTasks").value<QObject *>());
        QVERIFY(all); QVERIFY(visible);
        QVERIFY(all != visible);
        QVERIFY(!all->property("filterMinimized").toBool());
        QVERIFY(!all->property("filterByActivity").toBool());
        QVERIFY(!all->property("filterByVirtualDesktop").toBool());
        for (const char *filter : {"filterMinimized", "filterHidden", "filterByCurrentVirtualDesktop", "filterByActivity"})
            QVERIFY2(visible->property(filter).toBool(), filter);
        QVERIFY(visible->roleNames().values().contains("Geometry"));
        QVERIFY(visible->roleNames().values().contains("IsWindow"));
        // An offscreen model is a load contract, never proof of compositor access.
        const auto unavailable = windowVisibilitySnapshot(visible, false, false);
        QVERIFY(!unavailable.value("available").toBool());
    }
};
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    WindowModelsTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "window_models_test.moc"
