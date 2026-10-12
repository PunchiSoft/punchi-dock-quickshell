// SPDX-License-Identifier: GPL-3.0-or-later
#include "adapters/kde/native/autohideedge.h"
#include "kde-screen-edge-v1-server.h"
#include "wlr-layer-shell-unstable-v1-server.h"
#include <QtTest>
#include <QSocketNotifier>
#include <wayland-server.h>

// A parent-isolated Wayland server exercises actual protocol requests/events.
// It cannot connect to the user's compositor or modify its panel configuration.
struct EdgeCompositor {
    wl_display *display = nullptr;
    QSocketNotifier *notifier = nullptr;
    wl_resource *surface = nullptr, *layer = nullptr, *pointer = nullptr, *edge = nullptr;
    bool configured = false, acceptsInput = false;
    int activated = 0, deactivated = 0, width = 0, height = 0;
    int anchor = 0, zone = 0, keyboard = -1, layerKind = -1, border = 0;
    uint32_t output = 0;
    QString namespaceName;
    static void destroy(wl_client *, wl_resource *r) { wl_resource_destroy(r); }
    template<typename T> static T *owner(wl_resource *r) { return static_cast<T *>(wl_resource_get_user_data(r)); }
    explicit EdgeCompositor(bool supportsEdge = true) {
        display = wl_display_create();
        QVERIFY(display);
        QVERIFY(wl_display_add_socket(display, "punchi-edge-test") == 0);
        qputenv("WAYLAND_DISPLAY", "punchi-edge-test");
        wl_display_init_shm(display);
        wl_global_create(display, &wl_compositor_interface, 1, this, bindCompositor);
        wl_global_create(display, &wl_output_interface, 4, this, bindOutput);
        wl_global_create(display, &wl_seat_interface, 1, this, bindSeat);
        wl_global_create(display, &zwlr_layer_shell_v1_interface, 3, this, bindShell);
        if (supportsEdge) wl_global_create(display, &kde_screen_edge_manager_v1_interface, 1, this, bindEdge);
        notifier = new QSocketNotifier(wl_event_loop_get_fd(wl_display_get_event_loop(display)), QSocketNotifier::Read);
        QObject::connect(notifier, &QSocketNotifier::activated, [this] {
            wl_event_loop_dispatch(wl_display_get_event_loop(display), 0);
            wl_display_flush_clients(display);
        });
    }
    ~EdgeCompositor() {
        delete notifier;
        wl_display_destroy_clients(display);
        wl_display_destroy(display);
        qunsetenv("WAYLAND_DISPLAY");
    }
    static void bindCompositor(wl_client *client, void *data, uint32_t, uint32_t id) {
        static const struct wl_compositor_interface api = {
            [](wl_client *c, wl_resource *r, uint32_t newId) {
                auto *self = owner<EdgeCompositor>(r);
                self->configured = false;
                self->surface = wl_resource_create(c, &wl_surface_interface, 1, newId);
                static const struct wl_surface_interface api = [] {
                    struct wl_surface_interface a{};
                    a.destroy = destroy;
                    a.attach = [](wl_client *, wl_resource *, wl_resource *, int32_t, int32_t) {};
                    a.damage = [](wl_client *, wl_resource *, int32_t, int32_t, int32_t, int32_t) {};
                    a.set_input_region = [](wl_client *, wl_resource *s, wl_resource *region) {
                        owner<EdgeCompositor>(s)->acceptsInput = region && wl_resource_get_user_data(region);
                    };
                    a.commit = [](wl_client *, wl_resource *s) {
                        auto *self = owner<EdgeCompositor>(s);
                        if (self->layer && !self->configured) {
                            self->configured = true;
                            zwlr_layer_surface_v1_send_configure(self->layer, 1, self->width, self->height);
                        }
                    };
                    return a;
                }();
                wl_resource_set_implementation(self->surface, &api, self, [](wl_resource *r) { owner<EdgeCompositor>(r)->surface = nullptr; });
            },
            [](wl_client *c, wl_resource *, uint32_t id) {
                auto *region = wl_resource_create(c, &wl_region_interface, 1, id);
                static const struct wl_region_interface api = {destroy,
                    [](wl_client *, wl_resource *r, int32_t, int32_t, int32_t, int32_t) { wl_resource_set_user_data(r, reinterpret_cast<void *>(1)); },
                    [](wl_client *, wl_resource *, int32_t, int32_t, int32_t, int32_t) {}};
                wl_resource_set_implementation(region, &api, nullptr, nullptr);
            }
        };
        auto *r = wl_resource_create(client, &wl_compositor_interface, 1, id);
        wl_resource_set_implementation(r, &api, data, nullptr);
    }
    static void bindOutput(wl_client *c, void *data, uint32_t, uint32_t id) {
        static const struct wl_output_interface api = {destroy};
        auto *r = wl_resource_create(c, &wl_output_interface, 4, id);
        wl_resource_set_implementation(r, &api, data, nullptr);
        wl_output_send_name(r, "TEST-1");
        wl_output_send_description(r, "Owned test output");
        wl_output_send_done(r);
    }
    static void bindSeat(wl_client *c, void *data, uint32_t, uint32_t id) {
        static const struct wl_seat_interface api = [] {
            struct wl_seat_interface a{};
            a.get_pointer = [](wl_client *c, wl_resource *s, uint32_t id) {
                auto *self = owner<EdgeCompositor>(s);
                self->pointer = wl_resource_create(c, &wl_pointer_interface, 1, id);
                static const struct wl_pointer_interface api{};
                wl_resource_set_implementation(self->pointer, &api, self, [](wl_resource *r) { owner<EdgeCompositor>(r)->pointer = nullptr; });
            };
            return a;
        }();
        auto *r = wl_resource_create(c, &wl_seat_interface, 1, id);
        wl_resource_set_implementation(r, &api, data, nullptr);
        wl_seat_send_capabilities(r, WL_SEAT_CAPABILITY_POINTER);
    }
    static void bindShell(wl_client *c, void *data, uint32_t, uint32_t id) {
        static const struct zwlr_layer_shell_v1_interface api = {
            [](wl_client *c, wl_resource *s, uint32_t id, wl_resource *, wl_resource *output, uint32_t kind, const char *name) {
                auto *self = owner<EdgeCompositor>(s);
                self->output = wl_resource_get_id(output);
                self->layerKind = kind;
                self->namespaceName = QString::fromUtf8(name);
                self->layer = wl_resource_create(c, &zwlr_layer_surface_v1_interface, 3, id);
                static const struct zwlr_layer_surface_v1_interface api = [] {
                    struct zwlr_layer_surface_v1_interface a{};
                    a.set_size = [](wl_client *, wl_resource *r, uint32_t w, uint32_t h) { auto *s = owner<EdgeCompositor>(r); s->width = w; s->height = h; };
                    a.set_anchor = [](wl_client *, wl_resource *r, uint32_t v) { owner<EdgeCompositor>(r)->anchor = v; };
                    a.set_exclusive_zone = [](wl_client *, wl_resource *r, int32_t v) { owner<EdgeCompositor>(r)->zone = v; };
                    a.set_keyboard_interactivity = [](wl_client *, wl_resource *r, uint32_t v) { owner<EdgeCompositor>(r)->keyboard = v; };
                    a.ack_configure = [](wl_client *, wl_resource *, uint32_t) {};
                    a.destroy = destroy;
                    return a;
                }();
                wl_resource_set_implementation(self->layer, &api, self, [](wl_resource *r) { owner<EdgeCompositor>(r)->layer = nullptr; });
            }, destroy
        };
        auto *r = wl_resource_create(c, &zwlr_layer_shell_v1_interface, 3, id);
        wl_resource_set_implementation(r, &api, data, nullptr);
    }
    static void bindEdge(wl_client *c, void *data, uint32_t, uint32_t id) {
        static const struct kde_screen_edge_manager_v1_interface api = {destroy,
            [](wl_client *c, wl_resource *r, uint32_t id, uint32_t border, wl_resource *) {
                auto *self = owner<EdgeCompositor>(r);
                self->border = border;
                self->edge = wl_resource_create(c, &kde_auto_hide_screen_edge_v1_interface, 1, id);
                static const struct kde_auto_hide_screen_edge_v1_interface api = {destroy,
                    [](wl_client *, wl_resource *r) { ++owner<EdgeCompositor>(r)->deactivated; },
                    [](wl_client *, wl_resource *r) { ++owner<EdgeCompositor>(r)->activated; }};
                wl_resource_set_implementation(self->edge, &api, self, [](wl_resource *r) { owner<EdgeCompositor>(r)->edge = nullptr; });
            }};
        auto *r = wl_resource_create(c, &kde_screen_edge_manager_v1_interface, 1, id);
        wl_resource_set_implementation(r, &api, data, nullptr);
    }
    void trigger() {
        QVERIFY(pointer && surface);
        wl_pointer_send_enter(pointer, 1, surface, 0, 0);
        wl_display_flush_clients(display);
    }
    void leave() {
        QVERIFY(pointer && surface);
        wl_pointer_send_leave(pointer, 2, surface);
        wl_display_flush_clients(display);
    }
};

class AutoHideEdgeTest : public QObject {
    Q_OBJECT
private slots:
    void retainedPointerSurvivesDisarmUntilActualLeave() {
        EdgeCompositor server;
        AutoHideEdge sensor;
        QSignalSpy reveal(&sensor, &AutoHideEdge::revealRequested);
        QSignalSpy containment(&sensor, &AutoHideEdge::pointerInsideChanged);
        sensor.setRetainPointer(true);
        sensor.setScreenName("TEST-1"); sensor.setWidth(480); sensor.setHeight(4);
        sensor.setEnabled(true); sensor.setArmed(true); sensor.componentComplete();
        QTRY_COMPARE(server.activated, 1);
        server.trigger();
        QTRY_COMPARE(reveal.count(), 1);
        QVERIFY(sensor.pointerInside());
        QCOMPARE(containment.count(), 1);
        QVERIFY(server.acceptsInput);
        sensor.setArmed(false); // Production disarms when the dock is revealed.
        QTest::qWait(550); // Stationary pointer exceeds Plasma's leave grace.
        QVERIFY(sensor.pointerInside()); QVERIFY(server.acceptsInput);
        QCOMPARE(reveal.count(), 1); QCOMPARE(containment.count(), 1);
        server.leave();
        QTRY_VERIFY(!sensor.pointerInside());
        QTRY_VERIFY(!server.acceptsInput);
        QCOMPARE(containment.count(), 2);
        sensor.setArmed(true);
        QTRY_COMPARE(server.activated, 2);
        server.trigger(); QTRY_COMPARE(reveal.count(), 2);
        QVERIFY(sensor.pointerInside());
        sensor.setEnabled(false);
        QVERIFY(!sensor.pointerInside()); QVERIFY(!sensor.available());
        QTRY_VERIFY(!server.surface && !server.edge);
    }
    void retainedPointerClearsOnCompositorLoss() {
        EdgeCompositor server;
        AutoHideEdge sensor;
        sensor.setRetainPointer(true);
        sensor.setScreenName("TEST-1"); sensor.setWidth(200); sensor.setHeight(4);
        sensor.setEnabled(true); sensor.setArmed(true); sensor.componentComplete();
        QTRY_COMPARE(server.activated, 1);
        server.trigger(); QTRY_VERIFY(sensor.pointerInside());
        sensor.setArmed(false);
        zwlr_layer_surface_v1_send_closed(server.layer);
        wl_display_flush_clients(server.display);
        QTRY_VERIFY(!sensor.available());
        QVERIFY(!sensor.pointerInside());
        QTRY_VERIFY(!server.surface);
    }
    void containmentObserverCanDestroySensorDuringReveal() {
        EdgeCompositor server;
        auto sensor = std::make_unique<AutoHideEdge>();
        sensor->setRetainPointer(true);
        sensor->setScreenName("TEST-1"); sensor->setWidth(200); sensor->setHeight(4);
        sensor->setEnabled(true); sensor->setArmed(true); sensor->componentComplete();
        QTRY_COMPARE(server.activated, 1);
        QObject::connect(sensor.get(), &AutoHideEdge::pointerInsideChanged, this, [&] {
            if (sensor && sensor->pointerInside()) sensor.reset();
        });
        server.trigger();
        QTRY_VERIFY(!sensor);
        QTRY_VERIFY(!server.surface && !server.edge && !server.pointer);
    }
    void containmentObserverCanDestroySensorAfterNativeLeave() {
        EdgeCompositor server;
        auto sensor = std::make_unique<AutoHideEdge>();
        sensor->setRetainPointer(true);
        sensor->setScreenName("TEST-1"); sensor->setWidth(200); sensor->setHeight(4);
        sensor->setEnabled(true); sensor->setArmed(true); sensor->componentComplete();
        QTRY_COMPARE(server.activated, 1);
        server.trigger(); QTRY_VERIFY(sensor->pointerInside());
        sensor->setArmed(false);
        QObject::connect(sensor.get(), &AutoHideEdge::pointerInsideChanged, this, [&] {
            if (sensor && !sensor->pointerInside()) sensor.reset();
        });
        server.leave();
        QTRY_VERIFY(!sensor);
        QTRY_VERIFY(!server.surface && !server.edge && !server.pointer);
    }
    void nativeLifecycleAndRearming() {
        EdgeCompositor server;
        AutoHideEdge sensor;
        QSignalSpy reveal(&sensor, &AutoHideEdge::revealRequested);
        sensor.setScreenName("TEST-1"); sensor.setWidth(480); sensor.setHeight(4);
        sensor.setEnabled(true); sensor.setArmed(true); sensor.componentComplete();
        QTRY_VERIFY(sensor.available());
        QTRY_COMPARE(server.activated, 1);
        QCOMPARE(server.width, 480); QCOMPARE(server.height, 4);
        QCOMPARE(server.zone, -1); QCOMPARE(server.keyboard, 0);
        QCOMPARE(server.anchor, int(ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM));
        QCOMPARE(server.border, int(KDE_SCREEN_EDGE_MANAGER_V1_BORDER_BOTTOM));
        QCOMPARE(server.layerKind, int(ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY));
        QVERIFY(server.output != 0); QCOMPARE(server.namespaceName, "dock");
        QVERIFY(server.acceptsInput);
        server.trigger();
        QTRY_COMPARE(reveal.count(), 1);
        QTRY_VERIFY(!server.acceptsInput);
        server.trigger(); QTest::qWait(30); QCOMPARE(reveal.count(), 1);
        sensor.setArmed(false); sensor.setArmed(true);
        QTRY_COMPARE(server.activated, 2);
        server.trigger(); QTRY_COMPARE(reveal.count(), 2);
        sensor.setArmed(false);
        sensor.setWidth(540);
        QTRY_COMPARE(server.width, 540);
        QTRY_VERIFY(sensor.available());
        QTRY_VERIFY(!server.acceptsInput);
        sensor.setEnabled(false);
        QVERIFY(!sensor.available());
        QTRY_VERIFY(!server.surface && !server.edge);
        sensor.setEnabled(true); QTRY_VERIFY(sensor.available());
        sensor.setScreenName("MISSING");
        QVERIFY(!sensor.available()); QTRY_VERIFY(!server.surface);
    }
    void unsupportedAndBoundedGeometry() {
        EdgeCompositor server(false);
        AutoHideEdge sensor;
        sensor.setEnabled(true); sensor.setScreenName("TEST-1"); sensor.componentComplete();
        QTest::qWait(100);
        QVERIFY(!sensor.available()); QVERIFY(!server.surface);
        sensor.setWidth(20000); sensor.setHeight(-1);
        QVERIFY(!sensor.available());
        sensor.setEnabled(false);
    }
    void compositorClosureFallsBack() {
        EdgeCompositor server;
        AutoHideEdge sensor;
        sensor.setScreenName("TEST-1"); sensor.setWidth(200); sensor.setHeight(4);
        sensor.setEnabled(true); sensor.componentComplete();
        QTRY_VERIFY(sensor.available());
        zwlr_layer_surface_v1_send_closed(server.layer);
        wl_display_flush_clients(server.display);
        QTRY_VERIFY(!sensor.available());
        QTRY_VERIFY(!server.surface);
    }
    void armedDestructionAndInvalidConfigureAreSafe() {
        EdgeCompositor server;
        auto sensor = std::make_unique<AutoHideEdge>();
        sensor->setScreenName("TEST-1"); sensor->setWidth(200); sensor->setHeight(4);
        sensor->setEnabled(true); sensor->setArmed(true); sensor->componentComplete();
        QTRY_COMPARE(server.activated, 1);
        sensor.reset();
        QTRY_VERIFY(!server.surface && !server.edge && !server.pointer);
        sensor = std::make_unique<AutoHideEdge>();
        sensor->setScreenName("TEST-1"); sensor->setWidth(200); sensor->setHeight(4);
        sensor->setEnabled(true); sensor->componentComplete();
        QTRY_VERIFY(sensor->available());
        zwlr_layer_surface_v1_send_configure(server.layer, 2, 16385, 4);
        wl_display_flush_clients(server.display);
        QTRY_VERIFY(!sensor->available());
        QTRY_VERIFY(!server.surface);
    }
};
QTEST_GUILESS_MAIN(AutoHideEdgeTest)
#include "autohide_edge_test.moc"
