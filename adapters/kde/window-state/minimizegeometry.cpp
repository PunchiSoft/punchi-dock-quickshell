// SPDX-License-Identifier: GPL-3.0-or-later
#include "minimizegeometry.h"

#include <QGuiApplication>
#include <QScreen>
#include <QVariantMap>
#include <QtGlobal>

#include <algorithm>
#include <cstring>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <wayland-client.h>

#include "plasma-window-management-client.h"
#include "wlr-layer-shell-unstable-v1-client.h"

namespace {
constexpr int MaximumEntries = 256;

// Output listener: only the connector name is needed; every output event must
// still have a callable member because libwayland dispatches the whole struct.
void outputGeometry(void *, wl_output *, int32_t, int32_t, int32_t, int32_t, int32_t,
    const char *, const char *, int32_t) {}
void outputMode(void *, wl_output *, uint32_t, int32_t, int32_t, int32_t) {}
void outputDone(void *, wl_output *) {}
void outputScale(void *, wl_output *, int32_t) {}
void outputDescription(void *, wl_output *, const char *) {}

// Window listener: the publisher only consumes app id, geometry and unmapped.
void windowTitle(void *, org_kde_plasma_window *, const char *) {}
void windowState(void *, org_kde_plasma_window *, uint32_t) {}
void windowVirtualDesktop(void *, org_kde_plasma_window *, int32_t) {}
void windowThemedIcon(void *, org_kde_plasma_window *, const char *) {}
void windowInitialState(void *, org_kde_plasma_window *) {}
void windowParent(void *, org_kde_plasma_window *, org_kde_plasma_window *) {}
void windowIconChanged(void *, org_kde_plasma_window *) {}
void windowPid(void *, org_kde_plasma_window *, uint32_t) {}
void windowVirtualDesktopEntered(void *, org_kde_plasma_window *, const char *) {}
void windowVirtualDesktopLeft(void *, org_kde_plasma_window *, const char *) {}
void windowApplicationMenu(void *, org_kde_plasma_window *, const char *, const char *) {}
void windowActivityEntered(void *, org_kde_plasma_window *, const char *) {}
void windowActivityLeft(void *, org_kde_plasma_window *, const char *) {}
void windowResourceName(void *, org_kde_plasma_window *, const char *) {}
void windowClientGeometry(void *, org_kde_plasma_window *, int32_t, int32_t, uint32_t,
    uint32_t) {}

void managementShowDesktop(void *, org_kde_plasma_window_management *, uint32_t) {}
void managementStackingOrder(void *, org_kde_plasma_window_management *, wl_array *) {}
void managementStackingUuid(void *, org_kde_plasma_window_management *, const char *) {}
void managementStackingDone(void *, org_kde_plasma_window_management *) {}
}

MinimizeGeometryPublisher::MinimizeGeometryPublisher(QObject *parent)
    : QObject(parent)
{
}

MinimizeGeometryPublisher::~MinimizeGeometryPublisher()
{
    const auto markers = m_markers.values();
    for (auto *marker : markers)
        destroyMarker(marker);
    const auto windows = m_windows;
    for (auto *window : windows)
        removeWindow(window);
    if (m_management)
        org_kde_plasma_window_management_destroy(m_management);
    if (m_registry)
        wl_registry_destroy(m_registry);
}

void MinimizeGeometryPublisher::start(wl_display *display)
{
    if (!display || m_registry)
        return;
    m_display = display;
    m_registry = wl_display_get_registry(display);
    static const wl_registry_listener registryListener = {
        &MinimizeGeometryPublisher::onRegistryGlobal,
        &MinimizeGeometryPublisher::onRegistryGlobalRemove};
    wl_registry_add_listener(m_registry, &registryListener, this);
    wl_display_roundtrip(display);
    wl_display_roundtrip(display);
    rebuildMarkers();
}

void MinimizeGeometryPublisher::rebuildMarkers()
{
    if (!m_compositor || !m_shm || !m_layerShell)
        return;
    for (auto screenIt = m_screens.cbegin(); screenIt != m_screens.cend(); ++screenIt) {
        if (!m_outputs.contains(screenIt.key()))
            continue;
        for (auto entryIt = screenIt->cbegin(); entryIt != screenIt->cend(); ++entryIt) {
            if (entryIt->width() <= 0 || entryIt->height() <= 0)
                continue;
            if (!markerFor(screenIt.key(), entryIt.key()))
                createMarker(screenIt.key(), entryIt.key(), entryIt.value());
        }
    }
}

void MinimizeGeometryPublisher::replaceScreen(const QString &screen, const QVariantList &entries)
{
    if (screen.isEmpty())
        return;
    QHash<QString, QRect> next;
    const int count = int(std::min<qsizetype>(entries.size(), MaximumEntries));
    for (int index = 0; index < count; ++index) {
        const auto entry = entries.at(index).toMap();
        const QString desktopId = entry.value(QStringLiteral("desktopId")).toString();
        if (desktopId.isEmpty())
            continue;
        const QRect rect = normalizedRect(entry);
        if (!rect.isValid())
            continue;
        next.insert(desktopId, rect);
    }
    QList<Marker *> stale;
    for (auto *marker : std::as_const(m_markers)) {
        if (marker->screen == screen && !next.contains(marker->desktopId))
            stale.append(marker);
    }
    for (auto *marker : stale)
        destroyMarker(marker);
    if (next.isEmpty())
        m_screens.remove(screen);
    else
        m_screens.insert(screen, next);
    rebuildMarkers();
    for (auto it = next.cbegin(); it != next.cend(); ++it)
        if (auto *marker = markerFor(screen, it.key()))
            updateMarker(marker, it.value());
    reapply();
}

QRect MinimizeGeometryPublisher::normalizedRect(const QVariantMap &entry)
{
    const int x = entry.value(QStringLiteral("x")).toInt();
    const int y = entry.value(QStringLiteral("y")).toInt();
    const int width = entry.value(QStringLiteral("width")).toInt();
    const int height = entry.value(QStringLiteral("height")).toInt();
    if (width <= 0 || height <= 0 || width > 4096 || height > 4096)
        return {};
    if (x < 0 || y < 0 || x > 100000 || y > 100000)
        return {};
    return QRect(x, y, width, height);
}

MinimizeGeometryPublisher::Marker *MinimizeGeometryPublisher::markerFor(const QString &screen,
    const QString &desktopId) const
{
    return m_markers.value(screen + QLatin1Char('\n') + desktopId, nullptr);
}

MinimizeGeometryPublisher::Marker *MinimizeGeometryPublisher::createMarker(const QString &screen,
    const QString &desktopId, const QRect &rect)
{
    wl_output *output = m_outputs.value(screen, nullptr);
    if (!output || !m_compositor || !m_shm || !m_layerShell)
        return nullptr;
    auto *marker = new Marker;
    marker->owner = this;
    marker->screen = screen;
    marker->desktopId = desktopId;
    marker->rect = rect;
    marker->surface = wl_compositor_create_surface(m_compositor);
    if (!marker->surface) {
        delete marker;
        return nullptr;
    }
    marker->layer = zwlr_layer_shell_v1_get_layer_surface(m_layerShell, marker->surface,
        output, ZWLR_LAYER_SHELL_V1_LAYER_TOP, "punchi-minimize-geometry");
    if (!marker->layer) {
        wl_surface_destroy(marker->surface);
        delete marker;
        return nullptr;
    }
    static const zwlr_layer_surface_v1_listener layerListener = {
        &MinimizeGeometryPublisher::onMarkerConfigure,
        &MinimizeGeometryPublisher::onMarkerClosed};
    zwlr_layer_surface_v1_add_listener(marker->layer, &layerListener, marker);

    const int fd = memfd_create("punchi-minimize", MFD_CLOEXEC);
    if (fd >= 0) {
        if (ftruncate(fd, 4) == 0) {
            void *pixels = mmap(nullptr, 4, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
            if (pixels != MAP_FAILED) {
                std::memset(pixels, 0, 4);
                auto *pool = wl_shm_create_pool(m_shm, fd, 4);
                if (pool) {
                    marker->buffer = wl_shm_pool_create_buffer(pool, 0, 1, 1, 4,
                        WL_SHM_FORMAT_ARGB8888);
                    wl_shm_pool_destroy(pool);
                }
                munmap(pixels, 4);
            }
        }
        close(fd);
    }

    m_markers.insert(marker->screen + QLatin1Char('\n') + marker->desktopId, marker);
    updateMarker(marker, rect);
    return marker;
}

void MinimizeGeometryPublisher::updateMarker(Marker *marker, const QRect &rect)
{
    if (!marker || !marker->layer || !marker->surface)
        return;
    marker->rect = rect;
    zwlr_layer_surface_v1_set_size(marker->layer, uint32_t(rect.width()),
        uint32_t(rect.height()));
    zwlr_layer_surface_v1_set_anchor(marker->layer,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT);
    zwlr_layer_surface_v1_set_margin(marker->layer, uint32_t(rect.y()), 0, 0,
        uint32_t(rect.x()));
    zwlr_layer_surface_v1_set_exclusive_zone(marker->layer, 0);
    zwlr_layer_surface_v1_set_keyboard_interactivity(marker->layer,
        ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);
    wl_surface_commit(marker->surface);
}

void MinimizeGeometryPublisher::attachMarker(Marker *marker)
{
    if (!marker || !marker->surface || !marker->buffer || !m_compositor)
        return;
    wl_surface_attach(marker->surface, marker->buffer, 0, 0);
    wl_surface_damage_buffer(marker->surface, 0, 0, 1, 1);
    wl_region *empty = wl_compositor_create_region(m_compositor);
    if (empty) {
        wl_surface_set_input_region(marker->surface, empty);
        wl_region_destroy(empty);
    }
    wl_surface_commit(marker->surface);
}

void MinimizeGeometryPublisher::destroyMarker(Marker *marker)
{
    if (!marker)
        return;
    m_markers.remove(marker->screen + QLatin1Char('\n') + marker->desktopId);
    if (marker->layer)
        zwlr_layer_surface_v1_destroy(marker->layer);
    if (marker->buffer)
        wl_buffer_destroy(marker->buffer);
    if (marker->surface)
        wl_surface_destroy(marker->surface);
    for (auto *window : std::as_const(m_windows)) {
        if (window->marker == marker)
            window->marker = nullptr;
    }
    delete marker;
}

void MinimizeGeometryPublisher::applyWindow(Window *window)
{
    if (!window || !window->handle)
        return;
    Marker *target = nullptr;
    if (!window->geometry.isEmpty()) {
        for (auto *screen : QGuiApplication::screens()) {
            if (!screen->geometry().contains(window->geometry.center()))
                continue;
            target = markerFor(screen->name(), window->appId);
            break;
        }
    }
    if (target == window->marker) {
        if (target) {
            org_kde_plasma_window_set_minimized_geometry(window->handle, target->surface,
                0, 0, uint32_t(target->rect.width()), uint32_t(target->rect.height()));
        }
        return;
    }
    if (window->marker) {
        org_kde_plasma_window_unset_minimized_geometry(window->handle,
            window->marker->surface);
        window->marker = nullptr;
    }
    if (target) {
        window->marker = target;
        org_kde_plasma_window_set_minimized_geometry(window->handle, target->surface,
            0, 0, uint32_t(target->rect.width()), uint32_t(target->rect.height()));
    }
}

void MinimizeGeometryPublisher::reapply()
{
    for (auto *window : std::as_const(m_windows))
        applyWindow(window);
}

void MinimizeGeometryPublisher::addWindow(org_kde_plasma_window *handle)
{
    if (!handle)
        return;
    auto *window = new Window;
    window->owner = this;
    window->handle = handle;
    m_windows.append(window);
    static const org_kde_plasma_window_listener windowListener = {
        windowTitle, &MinimizeGeometryPublisher::onWindowAppId, windowState,
        windowVirtualDesktop, windowThemedIcon, &MinimizeGeometryPublisher::onWindowUnmapped,
        windowInitialState, windowParent, &MinimizeGeometryPublisher::onWindowGeometry,
        windowIconChanged, windowPid, windowVirtualDesktopEntered, windowVirtualDesktopLeft,
        windowApplicationMenu, windowActivityEntered, windowActivityLeft, windowResourceName,
        windowClientGeometry};
    org_kde_plasma_window_add_listener(handle, &windowListener, window);
}

void MinimizeGeometryPublisher::removeWindow(Window *window)
{
    if (!window)
        return;
    if (window->marker && window->handle)
        org_kde_plasma_window_unset_minimized_geometry(window->handle,
            window->marker->surface);
    m_windows.removeAll(window);
    if (window->handle) {
        org_kde_plasma_window_destroy(window->handle);
        window->handle = nullptr;
    }
    delete window;
}

void MinimizeGeometryPublisher::onRegistryGlobal(void *data, wl_registry *registry,
    uint32_t name, const char *interface, uint32_t version)
{
    auto *self = static_cast<MinimizeGeometryPublisher *>(data);
    if (std::strcmp(interface, wl_compositor_interface.name) == 0) {
        self->m_compositor = static_cast<wl_compositor *>(wl_registry_bind(registry, name,
            &wl_compositor_interface, std::min(version, 4u)));
    } else if (std::strcmp(interface, wl_shm_interface.name) == 0) {
        self->m_shm = static_cast<wl_shm *>(wl_registry_bind(registry, name,
            &wl_shm_interface, 1));
    } else if (std::strcmp(interface, wl_output_interface.name) == 0) {
        auto *output = static_cast<wl_output *>(wl_registry_bind(registry, name,
            &wl_output_interface, std::min(version, 4u)));
        static const wl_output_listener listener = {
            outputGeometry, outputMode, outputDone, outputScale,
            &MinimizeGeometryPublisher::onOutputName, outputDescription};
        wl_output_add_listener(output, &listener, self);
    } else if (std::strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
        self->m_layerShell = static_cast<zwlr_layer_shell_v1 *>(wl_registry_bind(registry,
            name, &zwlr_layer_shell_v1_interface, 1));
    } else if (std::strcmp(interface, org_kde_plasma_window_management_interface.name) == 0) {
        self->m_management = static_cast<org_kde_plasma_window_management *>(
            wl_registry_bind(registry, name, &org_kde_plasma_window_management_interface,
                std::min(version, 18u)));
        static const org_kde_plasma_window_management_listener listener = {
            managementShowDesktop, &MinimizeGeometryPublisher::onManagementWindow,
            managementStackingOrder, managementStackingUuid,
            &MinimizeGeometryPublisher::onManagementWindowWithUuid, managementStackingDone};
        org_kde_plasma_window_management_add_listener(self->m_management, &listener, self);
    }
}

void MinimizeGeometryPublisher::onRegistryGlobalRemove(void *, wl_registry *, uint32_t)
{
}

void MinimizeGeometryPublisher::onOutputName(void *data, wl_output *output, const char *name)
{
    auto *self = static_cast<MinimizeGeometryPublisher *>(data);
    if (!name || !*name)
        return;
    self->m_outputs.insert(QString::fromUtf8(name), output);
    self->rebuildMarkers();
    self->reapply();
}

void MinimizeGeometryPublisher::onManagementWindow(void *data,
    org_kde_plasma_window_management *management, uint32_t id)
{
    auto *self = static_cast<MinimizeGeometryPublisher *>(data);
    self->addWindow(org_kde_plasma_window_management_get_window(management, id));
}

void MinimizeGeometryPublisher::onManagementWindowWithUuid(void *data,
    org_kde_plasma_window_management *management, uint32_t, const char *uuid)
{
    auto *self = static_cast<MinimizeGeometryPublisher *>(data);
    if (!uuid)
        return;
    self->addWindow(org_kde_plasma_window_management_get_window_by_uuid(management, uuid));
}

void MinimizeGeometryPublisher::onWindowAppId(void *data, org_kde_plasma_window *,
    const char *appId)
{
    auto *window = static_cast<Window *>(data);
    window->appId = QString::fromUtf8(appId ? appId : "");
    window->owner->applyWindow(window);
}

void MinimizeGeometryPublisher::onWindowGeometry(void *data, org_kde_plasma_window *,
    int32_t x, int32_t y, uint32_t width, uint32_t height)
{
    auto *window = static_cast<Window *>(data);
    window->geometry = QRect(x, y, int(width), int(height));
    window->owner->applyWindow(window);
}

void MinimizeGeometryPublisher::onWindowUnmapped(void *data, org_kde_plasma_window *)
{
    auto *window = static_cast<Window *>(data);
    window->owner->removeWindow(window);
}

void MinimizeGeometryPublisher::onMarkerConfigure(void *data, zwlr_layer_surface_v1 *layer,
    uint32_t serial, uint32_t, uint32_t)
{
    auto *marker = static_cast<Marker *>(data);
    zwlr_layer_surface_v1_ack_configure(layer, serial);
    if (!marker->configured) {
        marker->configured = true;
        marker->owner->attachMarker(marker);
    }
}

void MinimizeGeometryPublisher::onMarkerClosed(void *data, zwlr_layer_surface_v1 *)
{
    auto *marker = static_cast<Marker *>(data);
    marker->owner->destroyMarker(marker);
}
