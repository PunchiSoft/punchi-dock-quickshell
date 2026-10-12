// SPDX-License-Identifier: GPL-3.0-or-later
#include "runningapplications.h"
#include "desktopentry.h"
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
QString normalized(QString id)
{
    if (id.endsWith(QLatin1String(".desktop"))) id.chop(8);
    return isValidDesktopId(id) ? id : QString();
}
}

RunningApplications::RunningApplications(QObject *parent) : QObject(parent), m_visibility(this)
{
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &RunningApplications::consume);
    connect(&m_process, &QProcess::readyReadStandardError, this, [this]() {
        const QByteArray diagnostic = m_process.readAllStandardError();
        if (!diagnostic.isEmpty()) qWarning().noquote() << "Punchi window backend:" << QString::fromUtf8(diagnostic.left(4096)).trimmed();
    });
    connect(&m_process, &QProcess::finished, this, [this]() { update(false); m_buffer.clear(); });
    connect(&m_process, &QProcess::errorOccurred, this, [this]() { update(false); });
}
RunningApplications::~RunningApplications() { stop(); }
void RunningApplications::setExecutable(const QString &value)
{
    if (value == m_executable) return;
    m_executable = value;
    emit executableChanged();
    if (m_complete) restart();
}
void RunningApplications::setEnabled(bool value)
{
    if (value == m_enabled) return;
    m_enabled = value;
    emit enabledChanged();
    if (m_complete) restart();
}
bool RunningApplications::isRunning(const QString &desktopId) const
{
    return m_available && m_ids.contains(normalized(desktopId));
}
void RunningApplications::update(bool available, const QSet<QString> &ids)
{
    if (!available) m_visibility.clear();
    const QSet<QString> next = available ? ids : QSet<QString>();
    if (available == m_available && next == m_ids) return;
    m_available = available;
    m_ids = next;
    m_revision = m_revision == INT_MAX ? 0 : m_revision + 1;
    emit changed();
}
void RunningApplications::stop()
{
    if (m_stopping) return;
    m_stopping = true;
    if (m_process.state() != QProcess::NotRunning) {
        m_process.closeWriteChannel();
        if (!m_process.waitForFinished(500)) {
            m_process.terminate();
            if (!m_process.waitForFinished(500)) { m_process.kill(); m_process.waitForFinished(500); }
        }
    }
    m_buffer.clear();
    update(false);
    m_stopping = false;
}
void RunningApplications::restart()
{
    stop();
    const QFileInfo file(m_executable);
    if (!m_enabled || !file.isAbsolute() || !file.isFile() || !file.isExecutable()) return;
    m_process.setProgram(file.canonicalFilePath());
    m_process.setArguments({});
    m_process.start();
}
void RunningApplications::consume()
{
    if (m_stopping) { m_process.readAllStandardOutput(); return; }
    m_buffer += m_process.readAllStandardOutput();
    if (m_buffer.size() > 524288) { stop(); return; }
    while (m_buffer.contains('\n')) {
        const int newline = m_buffer.indexOf('\n');
        const QByteArray line = m_buffer.left(newline);
        m_buffer.remove(0, newline + 1);
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(line, &error);
        const auto object = document.object();
        if (error.error != QJsonParseError::NoError || !document.isObject()
            || object.value(QStringLiteral("version")).toInt() != 1
            || !object.value(QStringLiteral("available")).isBool()
            || !object.value(QStringLiteral("desktopIds")).isArray()) { stop(); return; }
        const auto array = object.value(QStringLiteral("desktopIds")).toArray();
        if (array.size() > 1024) { stop(); return; }
        QSet<QString> ids;
        for (const auto value : array) {
            if (!value.isString() || normalized(value.toString()).isEmpty()) { stop(); return; }
            ids.insert(normalized(value.toString()));
        }
        update(object.value(QStringLiteral("available")).toBool(), ids);
        if (m_available) m_visibility.accept(object.value(QStringLiteral("visibility")).toObject());
    }
}
