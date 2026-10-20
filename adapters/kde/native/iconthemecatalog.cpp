// SPDX-License-Identifier: GPL-3.0-or-later
#include "iconthemecatalog.h"
#include <KConfigGroup>
#include <KSharedConfig>
#include <QCollator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QMutex>
#include <QMutexLocker>
#include <QSaveFile>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QVector>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>
#include <cstdio>

namespace {
// A theme can ship several thousand files; stop before an unusual package
// makes the picker allocate without bound.
constexpr int maximumIcons = 20000;
const QStringList iconSuffixes = {QStringLiteral("png"), QStringLiteral("svg"),
    QStringLiteral("svgz"), QStringLiteral("xpm")};

QStringList iconSearchPaths()
{
    QStringList paths = QIcon::themeSearchPaths();
    for (const auto &location : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
        paths.append(location + QStringLiteral("/icons"));
    paths.append(QStringLiteral("/usr/share/icons"));
    paths.removeDuplicates();
    paths.removeAll(QString());
    return paths;
}

QString configuredThemeName()
{
    const QString fallback = QIcon::themeName().isEmpty() ? QStringLiteral("breeze") : QIcon::themeName();
    const KConfigGroup icons = KSharedConfig::openConfig()->group(QStringLiteral("Icons"));
    const QString theme = icons.readEntry("Theme", fallback).trimmed();
    return theme.isEmpty() ? fallback : theme;
}

// The scan cache is keyed by the theme contents instead of a timeout: a theme
// that changes name, inherits differently or gains a directory is rescanned.
constexpr int cacheVersion = 1;

struct ThemeEntry {
    QString directory;
    QString context;
};

struct ThemeRoot {
    QString root;
    QStringList inherited;
    QVector<ThemeEntry> entries;
};

// Reads one theme and keeps the directories the picker scans. Only the smaller
// renditions are kept: every size repeats the same names.
bool readThemeRoot(const QString &theme, const QStringList &searchPaths, ThemeRoot &root)
{
    for (const auto &path : searchPaths) {
        const QString candidate = path + QLatin1Char('/') + theme;
        const QString indexFile = candidate + QStringLiteral("/index.theme");
        if (!QFileInfo::exists(indexFile)) continue;
        root.root = candidate;
        // index.theme is an INI file, but it may contain locale keys and repeated
        // sections that QSettings tolerates and a manual parser would not.
        QSettings index(indexFile, QSettings::IniFormat);
        index.beginGroup(QStringLiteral("Icon Theme"));
        const QStringList directories = index.value(QStringLiteral("Directories")).toStringList()
            + index.value(QStringLiteral("ScaledDirectories")).toStringList();
        root.inherited = index.value(QStringLiteral("Inherits")).toStringList();
        index.endGroup();
        for (const auto &entry : directories) {
            // Directory keys are theme-relative and never leave the theme root.
            if (entry.isEmpty() || entry.contains(QStringLiteral(".."))) continue;
            // The section names the context the picker groups the icons by.
            index.beginGroup(entry);
            const QString context
                = index.value(QStringLiteral("Context"), QStringLiteral("Other")).toString();
            const int size = index.value(QStringLiteral("Size"), 0).toInt();
            const QString type = index.value(QStringLiteral("Type")).toString();
            index.endGroup();
            if (type != QStringLiteral("Scalable") && size > 48) continue;
            root.entries.append({candidate + QLatin1Char('/') + entry, context});
        }
        return true;
    }
    return false;
}

void resolveThemeChain(const QString &theme, const QStringList &searchPaths, QSet<QString> &visited,
    int depth, QVector<ThemeRoot> &roots)
{
    if (theme.isEmpty() || visited.contains(theme) || depth > 4 || roots.size() >= 32) return;
    ThemeRoot root;
    if (!readThemeRoot(theme, searchPaths, root)) return;
    visited.insert(theme);
    const QStringList inherited = root.inherited;
    roots.append(root);
    for (const auto &parent : inherited)
        resolveThemeChain(parent.trimmed(), searchPaths, visited, depth + 1, roots);
}

// Cheap fingerprint of everything the scan reads. A directory's modification
// time covers added and removed files; its entry count covers file systems with
// a coarse timestamp.
QString themeStamp(const QString &theme, const QVector<ThemeRoot> &roots)
{
    QStringList parts;
    parts.append(theme);
    for (const auto &root : roots) {
        const QFileInfo index(root.root + QStringLiteral("/index.theme"));
        parts.append(root.root + QLatin1Char(':')
            + QString::number(index.lastModified().toMSecsSinceEpoch()) + QLatin1Char(':')
            + QString::number(index.size()));
        for (const auto &entry : root.entries) {
            const QFileInfo directory(entry.directory);
            parts.append(entry.directory + QLatin1Char(':')
                + QString::number(directory.lastModified().toMSecsSinceEpoch()) + QLatin1Char(':')
                + QString::number(directory.size()));
        }
    }
    return QString::number(static_cast<qulonglong>(qHash(parts.join(QLatin1Char('\n')), 0)), 16);
}

QString cacheFilePath(const QString &theme)
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    if (base.isEmpty() || theme.isEmpty()) return {};
    QString safe = theme.left(64);
    for (auto &character : safe)
        if (!character.isLetterOrNumber() && character != QLatin1Char('.')
            && character != QLatin1Char('-') && character != QLatin1Char('_'))
            character = QLatin1Char('_');
    return base + QStringLiteral("/punchi-dock-quickshell/icon-theme-") + safe + QLatin1Char('-')
        + QString::number(static_cast<qulonglong>(qHash(theme, 0)), 16) + QStringLiteral(".json");
}

bool readCache(const QString &theme, const QString &stamp, IconThemeCatalog::Snapshot &snapshot)
{
    const QString path = cacheFilePath(theme);
    if (path.isEmpty()) return false;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return false;
    // A damaged or truncated entry must never become the picker contents, so
    // every field is validated before it is used.
    const QJsonObject object = QJsonDocument::fromJson(file.readAll()).object();
    if (object.value(QStringLiteral("version")).toInt() != cacheVersion) return false;
    if (object.value(QStringLiteral("theme")).toString() != theme) return false;
    if (object.value(QStringLiteral("stamp")).toString() != stamp) return false;
    const QJsonArray names = object.value(QStringLiteral("names")).toArray();
    const QJsonArray contexts = object.value(QStringLiteral("rowContexts")).toArray();
    if (names.isEmpty() || names.size() != contexts.size() || names.size() > maximumIcons)
        return false;
    snapshot.theme = theme;
    snapshot.cached = true;
    snapshot.names.reserve(names.size());
    snapshot.rowContexts.reserve(contexts.size());
    for (int index = 0; index < names.size(); ++index) {
        snapshot.names.append(names.at(index).toString());
        snapshot.rowContexts.append(contexts.at(index).toString());
    }
    for (const auto &value : object.value(QStringLiteral("contexts")).toArray())
        snapshot.contextNames.append(value.toString());
    return true;
}

void writeCache(const QString &theme, const QString &stamp,
    const IconThemeCatalog::Snapshot &snapshot)
{
    const QString path = cacheFilePath(theme);
    if (path.isEmpty() || snapshot.names.isEmpty()) return;
    const QFileInfo target(path);
    // The cache only speeds up the next run, so a missing or read-only cache
    // location must not affect the picker.
    if (!QDir().mkpath(target.absolutePath())) return;
    QJsonArray names;
    QJsonArray contexts;
    for (int index = 0; index < snapshot.names.size(); ++index) {
        names.append(snapshot.names.at(index));
        contexts.append(snapshot.rowContexts.value(index));
    }
    const QJsonObject object{{QStringLiteral("version"), cacheVersion},
        {QStringLiteral("theme"), theme}, {QStringLiteral("stamp"), stamp},
        {QStringLiteral("contexts"), QJsonArray::fromStringList(snapshot.contextNames)},
        {QStringLiteral("names"), names}, {QStringLiteral("rowContexts"), contexts}};
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) return;
    file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    file.commit();
}

void collectEntry(const ThemeEntry &entry, QMap<QString, QString> &names)
{
    const QDir directory(entry.directory);
    const auto files = directory.entryInfoList(QDir::Files | QDir::Readable, QDir::Name);
    for (const auto &file : files) {
        if (names.size() >= maximumIcons) return;
        if (!iconSuffixes.contains(file.suffix(), Qt::CaseInsensitive)) continue;
        const QString name = file.completeBaseName();
        if (name.isEmpty() || name.size() > 200 || name.contains(QLatin1Char(' '))
            || name.contains(QLatin1Char('/')))
            continue;
        // A name present in several contexts keeps the first one listed.
        if (!names.contains(name)) names.insert(name, entry.context);
    }
}

// Qt reports an unparsable SVG asset once for every paint, so one broken icon in
// a theme would flood the session log while the picker scrolls. Repeated warnings
// are counted instead of printed; the first report of each distinct warning and
// the final count keep the diagnosis available. Every other message is forwarded
// untouched.
QMutex &svgWarningMutex()
{
    static QMutex mutex;
    return mutex;
}

QSet<QString> &reportedSvgWarnings()
{
    static QSet<QString> reported;
    return reported;
}

int &svgWarningUsers()
{
    static int users = 0;
    return users;
}

int &suppressedSvgWarnings()
{
    static int suppressed = 0;
    return suppressed;
}

QtMessageHandler &previousMessageHandler()
{
    static QtMessageHandler previous = nullptr;
    return previous;
}

bool isSvgWarning(const QMessageLogContext &context)
{
    const QByteArray category = context.category ? QByteArray(context.category) : QByteArray();
    return category.startsWith("qt.svg");
}

void relayMessage(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    const QtMessageHandler previous = previousMessageHandler();
    if (type == QtWarningMsg && isSvgWarning(context)) {
        const QString key = QString::fromUtf8(context.category ? context.category : "")
            + QLatin1Char('\x1f') + message;
        QMutexLocker locker(&svgWarningMutex());
        if (reportedSvgWarnings().contains(key)) {
            ++suppressedSvgWarnings();
            return;
        }
        reportedSvgWarnings().insert(key);
    }
    if (previous) {
        previous(type, context, message);
        return;
    }
    // No earlier handler means Qt's default one is in charge; format the message
    // the same way so a fallback does not change the log layout.
    const QByteArray line = qFormatLogMessage(type, context, message).toLocal8Bit();
    std::fwrite(line.constData(), 1, size_t(line.size()), stderr);
    std::fputc('\n', stderr);
    std::fflush(stderr);
    if (type == QtFatalMsg) std::abort();
}

void acquireSvgWarningRelay()
{
    QMutexLocker locker(&svgWarningMutex());
    if (svgWarningUsers()++ == 0)
        previousMessageHandler() = qInstallMessageHandler(&relayMessage);
}

void releaseSvgWarningRelay()
{
    QMutexLocker locker(&svgWarningMutex());
    if (--svgWarningUsers() > 0) return;
    const int suppressed = suppressedSvgWarnings();
    // Leave a handler that someone installed after this relay untouched.
    const QtMessageHandler current = qInstallMessageHandler(nullptr);
    qInstallMessageHandler(current == &relayMessage ? previousMessageHandler() : current);
    previousMessageHandler() = nullptr;
    reportedSvgWarnings().clear();
    suppressedSvgWarnings() = 0;
    locker.unlock();
    if (suppressed > 0)
        qWarning("Punchi icon picker: %d repeated icon warnings suppressed.", suppressed);
}
}

// The active theme holds thousands of files. Enumerate it when the picker is
// first opened instead of while the settings page is being built.
IconThemeCatalog::IconThemeCatalog(QObject *parent) : QAbstractListModel(parent)
{
    acquireSvgWarningRelay();
}

IconThemeCatalog::~IconThemeCatalog()
{
    releaseSvgWarningRelay();
}

QHash<int, QByteArray> IconThemeCatalog::roleNames() const
{
    return {{IconName, "iconName"}, {IconContext, "iconContext"}};
}

int IconThemeCatalog::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_names.size();
}

QVariant IconThemeCatalog::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_names.size()) return {};
    if (role == IconName || role == Qt::DisplayRole) return m_names.at(index.row());
    if (role == IconContext) return m_rowContexts.value(index.row());
    return {};
}

void IconThemeCatalog::reload()
{
    load();
}

void IconThemeCatalog::load()
{
    if (m_loading) return;
    m_loading = true;
    emit changed();
    const QString theme = configuredThemeName();
    const QStringList searchPaths = iconSearchPaths();
    auto *watcher = new QFutureWatcher<Snapshot>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher] {
        const Snapshot snapshot = watcher->result();
        watcher->deleteLater();
        apply(snapshot);
    });
    watcher->setFuture(QtConcurrent::run([theme, searchPaths] {
        return IconThemeCatalog::buildSnapshot(theme, searchPaths);
    }));
}

void IconThemeCatalog::apply(const Snapshot &snapshot)
{
    m_loading = false;
    m_cached = snapshot.cached;
    m_loaded = true;
    if (snapshot.names == m_names && snapshot.theme == m_themeName) {
        emit changed();
        return;
    }
    beginResetModel();
    m_names = snapshot.names;
    m_rowContexts = snapshot.rowContexts;
    m_contextNames = snapshot.contextNames;
    m_themeName = snapshot.theme;
    endResetModel();
    emit changed();
}

IconThemeCatalog::Snapshot IconThemeCatalog::buildSnapshot(const QString &theme,
    const QStringList &searchPaths)
{
    Snapshot snapshot;
    snapshot.theme = theme;
    QSet<QString> visited;
    QVector<ThemeRoot> roots;
    resolveThemeChain(theme, searchPaths, visited, 0, roots);
    // hicolor holds the theme-independent names every icon theme falls back to.
    if (theme != QStringLiteral("hicolor"))
        resolveThemeChain(QStringLiteral("hicolor"), searchPaths, visited, 1, roots);
    if (roots.isEmpty()) return snapshot;
    // A second picker opening reuses the previous scan; only a changed theme
    // pays for enumerating its directories again.
    const QString stamp = themeStamp(theme, roots);
    if (readCache(theme, stamp, snapshot)) return snapshot;
    snapshot.theme = theme;
    QMap<QString, QString> collected;
    for (const auto &root : roots)
        for (const auto &entry : root.entries)
            collectEntry(entry, collected);
    for (auto it = collected.cbegin(); it != collected.cend(); ++it) {
        snapshot.names.append(it.key());
        snapshot.rowContexts.append(it.value());
    }
    // The picker lists each category once; well-known categories come first so
    // the selector keeps a familiar order.
    static const QStringList preferred = {
        QStringLiteral("Applications"), QStringLiteral("Actions"), QStringLiteral("Devices"),
        QStringLiteral("Places"), QStringLiteral("Status"), QStringLiteral("MimeTypes"),
        QStringLiteral("Emblems"), QStringLiteral("Filesystems"), QStringLiteral("International"),
        QStringLiteral("Animations"), QStringLiteral("Categories"), QStringLiteral("Emotes")};
    QStringList unique = snapshot.rowContexts;
    unique.removeDuplicates();
    std::sort(unique.begin(), unique.end());
    for (const auto &name : preferred)
        if (unique.contains(name)) snapshot.contextNames.append(name);
    for (const auto &name : unique)
        if (!snapshot.contextNames.contains(name)) snapshot.contextNames.append(name);
    writeCache(theme, stamp, snapshot);
    return snapshot;
}

IconThemeSearchModel::IconThemeSearchModel(QObject *parent) : QSortFilterProxyModel(parent)
{
    setSortRole(IconThemeCatalog::IconName);
    setSortCaseSensitivity(Qt::CaseInsensitive);
    sort(0);
    connect(this, &QAbstractItemModel::rowsInserted, this, &IconThemeSearchModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &IconThemeSearchModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &IconThemeSearchModel::countChanged);
}

void IconThemeSearchModel::setContext(const QString &context)
{
    if (context == m_context) return;
#if QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)
    beginFilterChange();
    m_context = context;
    endFilterChange(Direction::Rows);
#else
    m_context = context;
    invalidateFilter();
#endif
    emit contextChanged();
    emit countChanged();
}

void IconThemeSearchModel::setQuery(const QString &query)
{
    const QString bounded = query.left(128).trimmed();
    if (bounded == m_query) return;
#if QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)
    beginFilterChange();
    m_query = bounded;
    endFilterChange(Direction::Rows);
#else
    m_query = bounded;
    invalidateFilter();
#endif
    emit queryChanged();
    emit countChanged();
}

bool IconThemeSearchModel::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const auto item = sourceModel()->index(row, 0, parent);
    if (!m_context.isEmpty() && item.data(IconThemeCatalog::IconContext).toString() != m_context)
        return false;
    if (m_query.isEmpty()) return true;
    return item.data(IconThemeCatalog::IconName).toString().contains(m_query, Qt::CaseInsensitive);
}
