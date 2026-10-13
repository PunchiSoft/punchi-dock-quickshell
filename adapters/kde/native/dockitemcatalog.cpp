// SPDX-License-Identifier: GPL-3.0-or-later
#include "dockitemcatalog.h"
#include "applicationcatalog.h"

DockItemCatalog::DockItemCatalog(QObject *parent) : QConcatenateTablesProxyModel(parent) {
    const QHash<int,QByteArray> roles{{ApplicationCatalog::AppId,"appId"},{ApplicationCatalog::DesktopId,"desktopId"},
        {ApplicationCatalog::Title,"title"},{ApplicationCatalog::Icon,"iconName"},{ApplicationCatalog::Name,"name"},
        {ApplicationCatalog::Description,"description"},{ApplicationCatalog::Installed,"installed"},
        {ApplicationCatalog::ApplicationIcon,"appIconName"}};
    m_specials.setItemRoleNames(roles);
    auto *trash = new QStandardItem;
    trash->setData(QStringLiteral("item:trash"), ApplicationCatalog::AppId);
    trash->setData(QString(), ApplicationCatalog::DesktopId);
    // Consumers can observe the row before QML applies translated title
    // bindings. Publish typed fields immediately, never invalid QVariants.
    trash->setData(QString(), ApplicationCatalog::Title);
    trash->setData(QString(), ApplicationCatalog::Name);
    trash->setData(QString(), ApplicationCatalog::Description);
    trash->setData(false, ApplicationCatalog::Installed); // Not an application-picker result.
    trash->setData(QStringLiteral("user-trash"), ApplicationCatalog::Icon);
    trash->setData(QStringLiteral("user-trash"), ApplicationCatalog::ApplicationIcon);
    m_specials.appendRow(trash);
    addSourceModel(&m_specials);
    connect(this, &QAbstractItemModel::rowsInserted, this, &DockItemCatalog::notifyChange);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &DockItemCatalog::notifyChange);
    connect(this, &QAbstractItemModel::modelReset, this, &DockItemCatalog::notifyChange);
    connect(this, &QAbstractItemModel::dataChanged, this, &DockItemCatalog::notifyChange);
}
void DockItemCatalog::notifyChange() { ++m_revision; emit changed(); }
void DockItemCatalog::setApplications(QAbstractItemModel *model) {
    if (m_applications == model) return;
    if (m_applications) removeSourceModel(m_applications);
    m_applications = model;
    if (model) addSourceModel(model);
    emit applicationsChanged();
}
QString DockItemCatalog::trashTitle() const { return m_specials.index(0,0).data(ApplicationCatalog::Title).toString(); }
void DockItemCatalog::setTrashTitle(const QString &value) {
    if (trashTitle() == value) return;
    m_specials.setData(m_specials.index(0,0), value, ApplicationCatalog::Title);
    m_specials.setData(m_specials.index(0,0), value, ApplicationCatalog::Name);
    emit trashChanged();
}
QString DockItemCatalog::trashIconName() const { return m_specials.index(0,0).data(ApplicationCatalog::Icon).toString(); }
void DockItemCatalog::setTrashIconName(const QString &value) {
    if (trashIconName() == value) return;
    m_specials.setData(m_specials.index(0,0), value, ApplicationCatalog::Icon);
    emit trashChanged();
}
QVariantMap DockItemCatalog::get(int row) const {
    QVariantMap result;
    if (row < 0 || row >= rowCount()) return result;
    const auto roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        result.insert(QString::fromUtf8(it.value()), index(row,0).data(it.key()));
    return result;
}
QVariantMap DockItemCatalog::application(const QString &appId) const {
    if (appId.startsWith(QLatin1String("item:"))) return {};
    for (int row = 0; row < rowCount(); ++row) {
        const auto entry = get(row);
        if (entry.value(QStringLiteral("appId")) == appId) return entry;
    }
    return {};
}
