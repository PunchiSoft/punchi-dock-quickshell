// SPDX-License-Identifier: GPL-3.0-or-later
#include "autohideedge.h"
#include "kde-screen-edge-v1-client.h"
#include "wlr-layer-shell-unstable-v1-client.h"
#include <QSocketNotifier>
#include <QTimer>
#include <wayland-client.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cerrno>
#include <algorithm>
#include <cstring>
#include <vector>

struct AutoHideEdge::Connection {
    AutoHideEdge *owner;
    wl_display *display = nullptr;
    wl_registry *registry = nullptr;
    wl_compositor *compositor = nullptr;
    wl_shm *shm = nullptr;
    wl_seat *seat = nullptr;
    wl_pointer *pointer = nullptr;
    zwlr_layer_shell_v1 *shell = nullptr;
    kde_screen_edge_manager_v1 *manager = nullptr;
    wl_surface *surface = nullptr;
    zwlr_layer_surface_v1 *layer = nullptr;
    kde_auto_hide_screen_edge_v1 *edge = nullptr;
    wl_buffer *buffer = nullptr;
    QSocketNotifier *reader = nullptr, *writer = nullptr;
    struct Output { uint32_t id; wl_output *proxy; QString name; };
    std::vector<Output> outputs;
    bool configured = false, failed = false, active = false, triggered = false;
    uint32_t compositorId = 0, shmId = 0, seatId = 0, shellId = 0, managerId = 0;

    explicit Connection(AutoHideEdge *value) : owner(value) {}
    ~Connection() { close(); }
    void fail() {
        if (failed) return;
        failed = true;
        owner->setAvailable(false);
        // Destruction is deferred until the current Wayland callback returns.
        QTimer::singleShot(0, owner, [this] { if (failed) close(); });
    }
    void flush() {
        if (!display || failed) return;
        if (wl_display_flush(display) < 0) {
            if (errno == EAGAIN) writer->setEnabled(true);
            else fail();
        } else writer->setEnabled(false);
    }
    void open() {
        display = wl_display_connect(nullptr);
        if (!display) return;
        failed = false;
        const int fd = wl_display_get_fd(display);
        reader = new QSocketNotifier(fd, QSocketNotifier::Read, owner);
        writer = new QSocketNotifier(fd, QSocketNotifier::Write, owner);
        writer->setEnabled(false);
        QObject::connect(reader, &QSocketNotifier::activated, owner, [this] {
            // This connection has one reader and no roundtrip or secondary queue.
            if (display && !failed && wl_display_dispatch(display) < 0) fail();
            flush();
        });
        QObject::connect(writer, &QSocketNotifier::activated, owner, [this] { flush(); });
        registry = wl_display_get_registry(display);
        static const wl_registry_listener listener = {global, removed};
        wl_registry_add_listener(registry, &listener, this);
        flush();
    }
    void disposeSurface() {
        owner->setAvailable(false);
        configured = false; active = false; triggered = false;
        if (edge) { kde_auto_hide_screen_edge_v1_destroy(edge); edge = nullptr; }
        if (layer) { zwlr_layer_surface_v1_destroy(layer); layer = nullptr; }
        if (surface) { wl_surface_destroy(surface); surface = nullptr; }
        if (buffer) { wl_buffer_destroy(buffer); buffer = nullptr; }
    }
    void close() {
        delete reader; reader = nullptr;
        delete writer; writer = nullptr;
        disposeSurface();
        if (pointer) { wl_pointer_destroy(pointer); pointer = nullptr; }
        if (seat) { wl_seat_destroy(seat); seat = nullptr; }
        for (auto &output : outputs) wl_output_destroy(output.proxy);
        outputs.clear();
        if (manager) { kde_screen_edge_manager_v1_destroy(manager); manager = nullptr; }
        if (shell) { zwlr_layer_shell_v1_destroy(shell); shell = nullptr; }
        if (shm) { wl_shm_destroy(shm); shm = nullptr; }
        if (compositor) { wl_compositor_destroy(compositor); compositor = nullptr; }
        if (registry) { wl_registry_destroy(registry); registry = nullptr; }
        if (display) { wl_display_flush(display); wl_display_disconnect(display); display = nullptr; }
        failed = false;
    }
    static void global(void *data, wl_registry *registry, uint32_t id, const char *name, uint32_t version) {
        auto *self = static_cast<Connection *>(data);
        if (!std::strcmp(name, "wl_compositor") && !self->compositor) {
            self->compositorId = id;
            self->compositor = static_cast<wl_compositor *>(wl_registry_bind(registry, id, &wl_compositor_interface, 1));
        } else if (!std::strcmp(name, "wl_shm") && !self->shm) {
            self->shmId = id;
            self->shm = static_cast<wl_shm *>(wl_registry_bind(registry, id, &wl_shm_interface, 1));
        } else if (!std::strcmp(name, "wl_seat") && !self->seat) {
            self->seatId = id;
            self->seat = static_cast<wl_seat *>(wl_registry_bind(registry, id, &wl_seat_interface, 1));
            static const wl_seat_listener listener = {capabilities, seatName};
            wl_seat_add_listener(self->seat, &listener, self);
        } else if (!std::strcmp(name, "zwlr_layer_shell_v1") && version >= 3 && !self->shell) {
            self->shellId = id;
            self->shell = static_cast<zwlr_layer_shell_v1 *>(wl_registry_bind(registry, id, &zwlr_layer_shell_v1_interface, 3));
        } else if (!std::strcmp(name, "kde_screen_edge_manager_v1") && !self->manager) {
            self->managerId = id;
            self->manager = static_cast<kde_screen_edge_manager_v1 *>(wl_registry_bind(registry, id, &kde_screen_edge_manager_v1_interface, 1));
        } else if (!std::strcmp(name, "wl_output") && version >= 4 && self->outputs.size() < 64) {
            auto *output = static_cast<wl_output *>(wl_registry_bind(registry, id, &wl_output_interface, 4));
            self->outputs.push_back({id, output, {}});
            static const wl_output_listener listener = {outputGeometry, outputMode, outputDone, outputScale, outputName, outputDescription};
            wl_output_add_listener(output, &listener, self);
        }
        self->update();
    }
    static void removed(void *data, wl_registry *, uint32_t id) {
        auto *self = static_cast<Connection *>(data);
        if (id == self->compositorId || id == self->shmId || id == self->seatId
                || id == self->shellId || id == self->managerId
                || std::any_of(self->outputs.begin(), self->outputs.end(), [id](const Output &o) { return o.id == id; })) self->fail();
    }
    static void outputGeometry(void *, wl_output *, int32_t, int32_t, int32_t, int32_t, int32_t, const char *, const char *, int32_t) {}
    static void outputMode(void *, wl_output *, uint32_t, int32_t, int32_t, int32_t) {}
    static void outputDone(void *, wl_output *) {}
    static void outputScale(void *, wl_output *, int32_t) {}
    static void outputDescription(void *, wl_output *, const char *) {}
    static void outputName(void *data, wl_output *proxy, const char *name) {
        auto *self = static_cast<Connection *>(data);
        for (auto &output : self->outputs) if (output.proxy == proxy) output.name = QString::fromUtf8(name);
        self->update();
    }
    static void seatName(void *, wl_seat *, const char *) {}
    static void capabilities(void *data, wl_seat *seat, uint32_t flags) {
        auto *self = static_cast<Connection *>(data);
        if (flags & WL_SEAT_CAPABILITY_POINTER) {
            if (!self->pointer) {
                self->pointer = wl_seat_get_pointer(seat);
                static const wl_pointer_listener listener = {enter, leave, motion, button, axis, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};
                wl_pointer_add_listener(self->pointer, &listener, self);
            }
        } else if (self->pointer) { wl_pointer_destroy(self->pointer); self->pointer = nullptr; self->disposeSurface(); }
        self->update();
    }
    static void enter(void *data, wl_pointer *, uint32_t, wl_surface *surface, wl_fixed_t, wl_fixed_t) {
        auto *self = static_cast<Connection *>(data);
        if (surface != self->surface || !self->active || self->triggered) return;
        self->triggered = true;
        self->setInput(false);
        kde_auto_hide_screen_edge_v1_deactivate(self->edge);
        self->active = false;
        self->flush();
        QTimer::singleShot(0, self->owner, [self] {
            if (self->owner->enabled() && self->triggered) emit self->owner->revealRequested();
        });
    }
    static void leave(void *, wl_pointer *, uint32_t, wl_surface *) {}
    static void motion(void *, wl_pointer *, uint32_t, wl_fixed_t, wl_fixed_t) {}
    static void button(void *, wl_pointer *, uint32_t, uint32_t, uint32_t, uint32_t) {}
    static void axis(void *, wl_pointer *, uint32_t, uint32_t, wl_fixed_t) {}
    static void configure(void *data, zwlr_layer_surface_v1 *layer, uint32_t serial, uint32_t width, uint32_t height) {
        auto *self = static_cast<Connection *>(data);
        zwlr_layer_surface_v1_ack_configure(layer, serial);
        if (width == 0) width = self->owner->width();
        if (height == 0) height = self->owner->height();
        if (!self->makeBuffer(width, height)) { self->fail(); return; }
        wl_surface_attach(self->surface, self->buffer, 0, 0);
        wl_surface_damage(self->surface, 0, 0, width, height);
        wl_surface_commit(self->surface);
        if (!self->edge) self->edge = kde_screen_edge_manager_v1_get_auto_hide_screen_edge(self->manager,
            KDE_SCREEN_EDGE_MANAGER_V1_BORDER_BOTTOM, self->surface);
        self->configured = true;
        self->owner->setAvailable(true);
        self->update();
    }
    static void closed(void *data, zwlr_layer_surface_v1 *) { static_cast<Connection *>(data)->fail(); }
    bool makeBuffer(uint32_t width, uint32_t height) {
        // Bound compositor-controlled allocation; transparent pixels need no HiDPI raster.
        if (width > 16384 || height > 128 || width == 0 || height == 0) return false;
        const size_t size = size_t(width) * height * 4;
        const int fd = memfd_create("punchi-edge", MFD_CLOEXEC);
        if (fd < 0) return false;
        if (ftruncate(fd, size) < 0) { ::close(fd); return false; }
        // A new memfd is zero-filled: ARGB 0 is transparent. No private file is created.
        auto *pool = wl_shm_create_pool(shm, fd, size);
        auto *next = wl_shm_pool_create_buffer(pool, 0, width, height, width * 4, WL_SHM_FORMAT_ARGB8888);
        wl_shm_pool_destroy(pool);
        ::close(fd);
        if (buffer) wl_buffer_destroy(buffer);
        buffer = next;
        return buffer != nullptr;
    }
    void setInput(bool accepts) {
        auto *region = wl_compositor_create_region(compositor);
        if (accepts) wl_region_add(region, 0, 0, owner->width(), owner->height());
        wl_surface_set_input_region(surface, region);
        wl_region_destroy(region);
        wl_surface_commit(surface);
    }
    void update() {
        if (!display || failed || !owner->enabled()) return;
        if (!compositor || !shm || !shell || !manager || !pointer || owner->screenName().isEmpty()) return;
        auto output = std::find_if(outputs.begin(), outputs.end(), [this](const Output &o) { return o.name == owner->screenName(); });
        if (output == outputs.end()) return;
        if (!surface) {
            surface = wl_compositor_create_surface(compositor);
            layer = zwlr_layer_shell_v1_get_layer_surface(shell, surface, output->proxy,
                ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "dock");
            static const zwlr_layer_surface_v1_listener listener = {configure, closed};
            zwlr_layer_surface_v1_add_listener(layer, &listener, this);
            zwlr_layer_surface_v1_set_anchor(layer, ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM);
            zwlr_layer_surface_v1_set_size(layer, owner->width(), owner->height());
            zwlr_layer_surface_v1_set_exclusive_zone(layer, -1);
            zwlr_layer_surface_v1_set_keyboard_interactivity(layer, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);
            setInput(false); // Initial commit has no buffer, as required by layer-shell.
        } else if (configured) {
            const bool wanted = owner->armed() && !triggered;
            if (wanted != active) {
                setInput(wanted);
                if (wanted) kde_auto_hide_screen_edge_v1_activate(edge);
                else kde_auto_hide_screen_edge_v1_deactivate(edge);
                active = wanted;
            }
        }
        flush();
    }
};

AutoHideEdge::AutoHideEdge(QObject *parent) : QObject(parent), m_connection(std::make_unique<Connection>(this)) {}
AutoHideEdge::~AutoHideEdge() = default;
void AutoHideEdge::componentComplete() { m_complete = true; refresh(); }
void AutoHideEdge::setAvailable(bool value) {
    if (m_available == value) return;
    m_available = value; emit availableChanged();
}
void AutoHideEdge::refresh(bool rebuild) {
    if (!m_complete) return;
    if (!m_enabled) { m_connection->close(); return; }
    if (m_width <= 0 || m_width > 16384 || m_height <= 0 || m_height > 128) { m_connection->close(); return; }
    if (!m_connection->display) m_connection->open();
    else if (rebuild) m_connection->disposeSurface();
    m_connection->update();
    // A missing/new output must still flush destruction of the previous sensor.
    m_connection->flush();
}
void AutoHideEdge::setEnabled(bool value) {
    if (m_enabled == value) return;
    m_enabled = value; refresh(); emit enabledChanged();
}
void AutoHideEdge::setArmed(bool value) {
    if (m_armed == value) return;
    m_armed = value;
    if (!value) m_connection->triggered = false;
    refresh(); emit armedChanged();
}
void AutoHideEdge::setWidth(int value) { if (m_width != value) { m_width = value; refresh(true); emit widthChanged(); } }
void AutoHideEdge::setHeight(int value) { if (m_height != value) { m_height = value; refresh(true); emit heightChanged(); } }
void AutoHideEdge::setScreenName(const QString &value) { if (m_screenName != value) { m_screenName = value; refresh(true); emit screenNameChanged(); } }
