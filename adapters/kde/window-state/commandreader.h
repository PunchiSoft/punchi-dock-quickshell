// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QCoreApplication>
#include <QSocketNotifier>
#include <QJsonDocument>
#include <QJsonObject>
#include <functional>
#include <cerrno>
#include <unistd.h>

// Owned process pipe only. One bounded read per readiness event; EOF ends life.
class WindowCommandReader : public QObject
{
public:
    explicit WindowCommandReader(std::function<void(const QJsonObject &)> dispatch, QObject *parent)
        : QObject(parent), m_notifier(STDIN_FILENO, QSocketNotifier::Read, this), m_dispatch(std::move(dispatch))
    {
        connect(&m_notifier, &QSocketNotifier::activated, this, [this]() { read(); });
    }
private:
    void read() {
        char bytes[4096];
        const auto count = ::read(STDIN_FILENO, bytes, sizeof(bytes));
        if (count == 0) { m_notifier.setEnabled(false); QCoreApplication::quit(); return; }
        if (count < 0) { if (errno != EINTR && errno != EAGAIN) QCoreApplication::exit(2); return; }
        m_buffer.append(bytes, count);
        if (m_buffer.size() > 65536) { QCoreApplication::exit(2); return; }
        while (m_buffer.contains('\n')) {
            const int end = m_buffer.indexOf('\n');
            if (end > 2048) { QCoreApplication::exit(2); return; }
            const auto line = m_buffer.left(end);
            m_buffer.remove(0, end + 1);
            QJsonParseError error;
            const auto document = QJsonDocument::fromJson(line, &error);
            if (error.error != QJsonParseError::NoError || !document.isObject()) { QCoreApplication::exit(2); return; }
            m_dispatch(document.object());
        }
        if (m_buffer.size() > 2048) QCoreApplication::exit(2);
    }
    QSocketNotifier m_notifier;
    QByteArray m_buffer;
    std::function<void(const QJsonObject &)> m_dispatch;
};
