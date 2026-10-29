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
        auto *current = qobject_cast<QAbstractItemModel *>(models->property("currentDesktopTasks").value<QObject *>());
        QVERIFY(all); QVERIFY(visible); QVERIFY(current);
        QVERIFY(all->metaObject()->indexOfMethod("requestActivate(QModelIndex)") >= 0);
        QVERIFY(all->metaObject()->indexOfMethod("requestToggleMinimized(QModelIndex)") >= 0);
        QVERIFY(all->metaObject()->indexOfMethod("requestNewInstance(QModelIndex)") >= 0);
        QVERIFY(all != visible);
        QVERIFY(!all->property("filterMinimized").toBool());
        QVERIFY(!all->property("filterByActivity").toBool());
        QVERIFY(!all->property("filterByVirtualDesktop").toBool());
        for (const char *filter : {"filterMinimized", "filterHidden", "filterByVirtualDesktop", "filterByActivity"})
            QVERIFY2(visible->property(filter).toBool(), filter);
        // Running markers keep minimized windows but follow the active desktop
        // and activity, unlike the overlap projection.
        QVERIFY(!current->property("filterMinimized").toBool());
        QVERIFY(!current->property("filterHidden").toBool());
        QVERIFY(current->property("filterByVirtualDesktop").toBool());
        QVERIFY(current->property("filterByActivity").toBool());
        // Offscreen has no platform task source: successful resource loading and
        // filter configuration do not establish compositor roles or access.
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
