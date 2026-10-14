// SPDX-License-Identifier: GPL-3.0-or-later
#include "registration.h"
#include "snapshot.h"
#include "windowactivation.h"
#include "commandreader.h"
#include "../native/kwinminimizeeffect.h"
#include <QGuiApplication>
#include <QtGui/qguiapplication_platform.h>
#include <QSocketNotifier>
#include <QTimer>
#include <QQmlComponent>
#include <QQmlEngine>
#include <KWindowSystem>
#include <wayland-client.h>
#include <cstdio>
#include <unistd.h>
#include <memory>

class WindowObserver : public QObject
{
public:
    explicit WindowObserver(QObject *parent) : QObject(parent) {}
    ~WindowObserver() override {
        m_object.reset();
        if (m_sync) wl_callback_destroy(m_sync);
        if (m_registry) wl_registry_destroy(m_registry);
    }
    void start() {
        const auto native = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
        if (!native) { publish(); return; }
        m_registry = wl_display_get_registry(native->display());
        static const wl_registry_listener registryListener = {
            [](void *data, wl_registry *, uint32_t name, const char *interface, uint32_t) {
                auto self = static_cast<WindowObserver *>(data);
                if (QByteArray(interface) == "org_kde_plasma_window_management") self->m_global = name;
            },
            [](void *data, wl_registry *, uint32_t name) {
                auto self = static_cast<WindowObserver *>(data);
                if (self->m_global == name) {
                    self->m_available = false;
                    self->publish();
                }
            }};
        wl_registry_add_listener(m_registry, &registryListener, this);
        m_sync = wl_display_sync(native->display());
        static const wl_callback_listener syncListener = {
            [](void *data, wl_callback *callback, uint32_t) {
                auto self = static_cast<WindowObserver *>(data);
                wl_callback_destroy(callback);
                self->m_sync = nullptr;
                if (!self->m_global) { self->publish(); return; }
                QQmlComponent component(&self->m_engine,
                    QUrl(QStringLiteral("qrc:/adapters/kde/window-state/WindowModels.qml")));
                self->m_object.reset(component.create());
                self->m_model = self->m_object ? qobject_cast<QAbstractItemModel *>(
                    self->m_object->property("allTasks").value<QObject *>()) : nullptr;
                self->m_visibleModel = self->m_object ? qobject_cast<QAbstractItemModel *>(
                    self->m_object->property("visibleTasks").value<QObject *>()) : nullptr;
                if (!self->m_model || !self->m_model->roleNames().values().contains("AppId")
                    || !self->m_model->roleNames().values().contains("IsWindow")) {
                    qWarning() << "KDE task model unavailable";
                    self->publish();
                    return;
                }
                const auto update = [self]() { self->schedule(); };
                for (auto *model : {self->m_model, self->m_visibleModel}) {
                    if (!model) continue;
                    connect(model, &QAbstractItemModel::rowsInserted, self, update);
                    connect(model, &QAbstractItemModel::rowsRemoved, self, update);
                    connect(model, &QAbstractItemModel::rowsMoved, self, update);
                    connect(model, &QAbstractItemModel::dataChanged, self, update);
                    connect(model, &QAbstractItemModel::modelReset, self, update);
                }
                connect(KWindowSystem::self(), &KWindowSystem::showingDesktopChanged, self, update);
                self->m_available = true;
                self->publish();
            }};
        wl_callback_add_listener(m_sync, &syncListener, this);
        wl_display_flush(native->display());
    }
    void activate(const QJsonObject &request) {
        const auto reply = activateWindowRequest(m_model, m_available, request);
        if (reply.isEmpty()) { QCoreApplication::exit(2); return; }
        send(QJsonDocument(reply).toJson(QJsonDocument::Compact) + '\n');
    }
private:
    void send(const QByteArray &message) {
        if (std::fwrite(message.constData(), 1, message.size(), stdout) != size_t(message.size())) QCoreApplication::quit();
        std::fflush(stdout);
    }
    void schedule() {
        if (m_pending) return;
        m_pending = true;
        // Plasma settles newly created-window positions before deciding overlap.
        QTimer::singleShot(10, this, [this]() { m_pending = false; publish(); });
    }
    void publish() {
        const bool ready = m_available && m_model && m_model->rowCount() <= 4096;
        const QStringList ids = ready ? runningDesktopIds(*m_model) : QStringList();
        const QJsonArray applications = ready ? runningApplicationEntries(*m_model) : QJsonArray();
        auto object = QJsonDocument::fromJson(windowStateSnapshot(ready && ids.size() <= 1024, ids,
            windowVisibilitySnapshot(m_visibleModel, ready, ready && KWindowSystem::showingDesktop()),
            applications)).object();
        object.insert(QStringLiteral("activationAvailable"), ready && supportsWindowActivation(m_model));
        const QByteArray snapshot = QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n';
        if (snapshot == m_previous) return;
        m_previous = snapshot;
        send(snapshot);
    }
    wl_registry *m_registry = nullptr;
    wl_callback *m_sync = nullptr;
    uint32_t m_global = 0;
    bool m_available = false;
    bool m_pending = false;
    QByteArray m_previous;
    QQmlEngine m_engine;
    std::unique_ptr<QObject> m_object;
    QAbstractItemModel *m_model = nullptr;
    QAbstractItemModel *m_visibleModel = nullptr;
};

int main(int argc, char **argv)
{
    if (argc == 2 && QByteArray(argv[1]) == "--restore-desktop-settings") {
        QCoreApplication app(argc, argv);
        app.setApplicationName(QStringLiteral("punchi-window-state"));
        return KWinMinimizeEffectController::restoreOwnedSettings() ? 0 : 1;
    }
    if (argc == 2 && (QByteArray(argv[1]) == "--register" || QByteArray(argv[1]) == "--unregister")) {
        QCoreApplication app(argc, argv);
        return registerWindowBackend(QByteArray(argv[1]) == "--unregister");
    }
    if (argc != 1) return 2;
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("punchi-window-state"));
    app.setDesktopFileName(QStringLiteral("org.punchi.Shell.WindowState"));
    app.setQuitOnLastWindowClosed(false);
    WindowObserver observer(&app);
    WindowCommandReader commands([&](const QJsonObject &request) { observer.activate(request); }, &app);
    QTimer::singleShot(0, &observer, [&]() { observer.start(); });
    return app.exec();
}
