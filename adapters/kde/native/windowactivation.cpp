// SPDX-License-Identifier: GPL-3.0-or-later
#include "windowactivation.h"
#include "../window-state/taskidentity.h"
#include <QJsonDocument>
#include <climits>
#include <cmath>

WindowActivation::WindowActivation(QProcess *process, QObject *parent)
    : QObject(parent), m_process(process) {}

void WindowActivation::setAvailable(bool value)
{
    if (!value) {
        const auto requests = m_pending.keys();
        for (int id : requests) complete(id, QStringLiteral("unavailable"));
    }
    if (m_available == value) return;
    m_available = value;
    emit changed();
}

int WindowActivation::requestActivate(const QString &desktopId)
{
    return request(desktopId, QStringLiteral("activate"));
}

int WindowActivation::requestNewInstance(const QString &desktopId)
{
    return request(desktopId, QStringLiteral("new-instance"));
}

int WindowActivation::request(const QString &desktopId, const QString &type)
{
    const QString id = normalizedApplicationId(desktopId);
    if (!m_available || id.isEmpty() || m_process->state() != QProcess::Running
        || m_pending.size() >= 64 || m_process->bytesToWrite() > 16384) return 0;
    do { m_nextId = m_nextId == INT_MAX ? 1 : m_nextId + 1; } while (m_pending.contains(m_nextId));
    const auto request = QJsonDocument(QJsonObject{{QStringLiteral("version"), 1},
        {QStringLiteral("type"), type}, {QStringLiteral("requestId"), m_nextId},
        {QStringLiteral("desktopId"), id}}).toJson(QJsonDocument::Compact) + '\n';
    if (m_process->write(request) != request.size()) return 0;
    auto *timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(3000);
    const int requestId = m_nextId;
    connect(timer, &QTimer::timeout, this, [this, requestId]() { complete(requestId, QStringLiteral("unavailable")); });
    m_pending.insert(requestId, {id, timer});
    timer->start();
    return requestId;
}

void WindowActivation::complete(int requestId, const QString &status)
{
    if (!m_pending.contains(requestId)) return;
    const auto request = m_pending.take(requestId);
    request.timer->stop(); request.timer->deleteLater();
    // Always asynchronous, including transport loss; QML can register the ID.
    QTimer::singleShot(0, this, [this, requestId, request, status]() {
        emit finished(requestId, request.desktopId, status);
    });
}

bool WindowActivation::acceptResult(const QJsonObject &object)
{
    const auto numberValue = object.value(QStringLiteral("requestId"));
    const double number = numberValue.toDouble();
    const QString desktopId = object.value(QStringLiteral("desktopId")).toString();
    const QString status = object.value(QStringLiteral("status")).toString();
    if (object.value(QStringLiteral("version")).toInt() != 1
        || object.value(QStringLiteral("type")).toString() != QLatin1String("activation-result")
        || !numberValue.isDouble() || !std::isfinite(number) || number < 1 || number > INT_MAX
        || std::floor(number) != number || normalizedApplicationId(desktopId) != desktopId || desktopId.isEmpty()
        || (status != QLatin1String("activated") && status != QLatin1String("minimized") && status != QLatin1String("not-found")
            && status != QLatin1String("starting") && status != QLatin1String("new-instance")
            && status != QLatin1String("unavailable") && status != QLatin1String("rejected"))) return false;
    const int requestId = int(number);
    // Late responses to expired requests are harmless; never launch from them.
    if (!m_pending.contains(requestId)) return true;
    if (m_pending.value(requestId).desktopId != desktopId) return false;
    complete(requestId, status);
    return true;
}
