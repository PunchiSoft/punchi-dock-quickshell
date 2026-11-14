// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QHash>
#include <QObject>
#include <QRect>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

struct wl_display;
struct wl_registry;
struct wl_compositor;
struct wl_shm;
struct wl_output;
struct wl_surface;
struct wl_buffer;
struct zwlr_layer_shell_v1;
struct zwlr_layer_surface_v1;
struct org_kde_plasma_window_management;
struct org_kde_plasma_window;

// Publishes the dock icon rectangle to KWin through
// org_kde_plasma_window_management.set_minimized_geometry. KWin's minimize
// effects animate a window to that rectangle.
//
// The helper cannot pass the dock's own wl_surface (Wayland objects never cross
// client connections), so it creates one transparent layer-shell marker per
// dock icon and publishes the icon corner as (0, 0) relative to that marker.
class MinimizeGeometryPublisher : public QObject
{
    Q_OBJECT
public:
    explicit MinimizeGeometryPublisher(QObject *parent = nullptr);
    ~MinimizeGeometryPublisher() override;

    void start(wl_display *display);
    void replaceScreen(const QString &screen, const QVariantList &entries);

private:
    struct Marker {
        QString screen;
        QString desktopId;
        MinimizeGeometryPublisher *owner = nullptr;
        wl_surface *surface = nullptr;
        wl_buffer *buffer = nullptr;
        zwlr_layer_surface_v1 *layer = nullptr;
        QRect rect;
        bool configured = false;
    };
    struct Window {
        MinimizeGeometryPublisher *owner = nullptr;
        org_kde_plasma_window *handle = nullptr;
        QString appId;
        QRect geometry;
        Marker *marker = nullptr;
    };

    static void onRegistryGlobal(void *data, wl_registry *registry, uint32_t name,
        const char *interface, uint32_t version);
    static void onRegistryGlobalRemove(void *data, wl_registry *registry, uint32_t name);
    static void onOutputName(void *data, wl_output *output, const char *name);
    static void onManagementWindow(void *data, org_kde_plasma_window_management *management,
        uint32_t id);
    static void onManagementWindowWithUuid(void *data,
        org_kde_plasma_window_management *management, uint32_t id, const char *uuid);
    static void onWindowAppId(void *data, org_kde_plasma_window *window, const char *appId);
    static void onWindowGeometry(void *data, org_kde_plasma_window *window, int32_t x,
        int32_t y, uint32_t width, uint32_t height);
    static void onWindowUnmapped(void *data, org_kde_plasma_window *window);
    static void onMarkerConfigure(void *data, zwlr_layer_surface_v1 *layer,
        uint32_t serial, uint32_t width, uint32_t height);
    static void onMarkerClosed(void *data, zwlr_layer_surface_v1 *layer);

    void addWindow(org_kde_plasma_window *window);
    void removeWindow(Window *window);
    Marker *markerFor(const QString &screen, const QString &desktopId) const;
    Marker *createMarker(const QString &screen, const QString &desktopId, const QRect &rect);
    void updateMarker(Marker *marker, const QRect &rect);
    void destroyMarker(Marker *marker);
    void attachMarker(Marker *marker);
    void rebuildMarkers();
    void reapply();
    void applyWindow(Window *window);
    static QRect normalizedRect(const QVariantMap &entry);

    wl_display *m_display = nullptr;
    wl_registry *m_registry = nullptr;
    wl_compositor *m_compositor = nullptr;
    wl_shm *m_shm = nullptr;
    zwlr_layer_shell_v1 *m_layerShell = nullptr;
    org_kde_plasma_window_management *m_management = nullptr;
    QHash<QString, wl_output *> m_outputs;
    QHash<QString, Marker *> m_markers;
    QHash<QString, QHash<QString, QRect>> m_screens;
    QList<Window *> m_windows;
};
