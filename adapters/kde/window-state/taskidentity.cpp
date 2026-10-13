// SPDX-License-Identifier: GPL-3.0-or-later
#include "taskidentity.h"
#include <KShell>
#include <KSycoca>
#include <QCoreApplication>
#include <QFileInfo>
#include <QPointer>

namespace {
QString key(QString value)
{
    if (value.endsWith(QLatin1String(".desktop"), Qt::CaseInsensitive)) value.chop(8);
    return value.trimmed().toCaseFolded();
}

// Resolve aliases once per KDE service-cache revision, not once per window or
// frame. Exact native launcher metadata wins; ambiguous aliases never choose
// an arbitrary installed application.
class IdentityCache : public QObject {
public:
    explicit IdentityCache(QObject *parent) : QObject(parent) {
        connect(KSycoca::self(), &KSycoca::databaseChanged, this, [this] { dirty = true; });
    }
    QString lookup(const QString &value) {
        if (value.isEmpty() || value.size() > 255) return {};
        if (dirty) rebuild();
        const auto needle = key(value);
        for (const auto *map : {&desktopIds, &wmClasses, &executables, &names}) {
            const auto it = map->constFind(needle);
            // An ambiguous match at a stronger level must not fall through.
            if (it != map->cend()) return it.value();
        }
        return {};
    }
private:
    bool dirty = true;
    QHash<QString, QString> desktopIds, wmClasses, executables, names;
    static void add(QHash<QString, QString> &map, const QString &alias, const QString &id) {
        const auto needle = key(alias);
        if (needle.isEmpty() || needle.size() > 255) return;
        if (map.contains(needle) && map.value(needle) != id) map[needle].clear();
        else if (!map.contains(needle)) map.insert(needle, id);
    }
    void rebuild() {
        desktopIds.clear(); wmClasses.clear(); executables.clear(); names.clear();
        for (const auto &service : KService::allServices()) {
            const auto id = normalizedApplicationId(service->storageId());
            if (!service->isApplication() || service->noDisplay() || service->exec().isEmpty() || id.isEmpty()) continue;
            add(desktopIds, service->storageId(), id);
            add(desktopIds, service->desktopEntryName(), id);
            add(desktopIds, service->menuId(), id);
            add(wmClasses, service->property<QString>(QStringLiteral("StartupWMClass")), id);
            add(names, service->name(), id);
            KShell::Errors error = KShell::NoError;
            const auto args = KShell::splitArgs(service->exec(), KShell::AbortOnMeta, &error);
            if (error != KShell::NoError || args.isEmpty()) continue;
            const auto executable = QFileInfo(args.first()).fileName();
            // These are launch wrappers, not application identities. Exported
            // Flatpak/Snap desktop IDs still resolve through native metadata.
            if (QStringList{"env", "flatpak", "snap", "sh", "bash", "python", "python3"}.contains(executable)) continue;
            add(executables, executable, id);
        }
        dirty = false;
    }
};
}

QString resolvedTaskDesktopId(const QString &appId, const QUrl &launcher)
{
    KService::Ptr service;
    if (launcher.scheme() == QLatin1String("applications")) service = KService::serviceByMenuId(launcher.path());
    else if (launcher.isLocalFile() && launcher.fileName().endsWith(QLatin1String(".desktop")))
        service = KService::serviceByDesktopPath(launcher.toLocalFile());
    if (service && service->isApplication() && !service->exec().isEmpty()) {
        const auto id = normalizedApplicationId(service->storageId());
        if (!id.isEmpty()) return id;
    }
    static QPointer<IdentityCache> cache;
    if (!cache) cache = new IdentityCache(QCoreApplication::instance());
    const auto id = cache->lookup(appId);
    if (!id.isEmpty()) return id;
    return launcher.isLocalFile() && !launcher.fileName().endsWith(QLatin1String(".desktop"))
        ? cache->lookup(launcher.fileName()) : QString();
}
