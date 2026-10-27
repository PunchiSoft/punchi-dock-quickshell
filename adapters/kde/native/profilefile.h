// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <qqmlintegration.h>

// Bounded, data-only file access for the profile exchange. Reads accept a
// regular file only, so a FIFO or a device cannot stall the shell, and writes
// replace the destination atomically without following a symbolic link.
class ProfileFile : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit ProfileFile(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap read(const QUrl &url, int maximumBytes) const;
    // Absolute paths come from the settings store, which already owns the
    // profile location and does not need a URL round trip.
    Q_INVOKABLE QVariantMap readPath(const QString &path, int maximumBytes) const;
    Q_INVOKABLE QVariantMap write(const QUrl &url, const QString &text, int maximumBytes) const;

private:
    QVariantMap readLocalPath(const QString &path, int maximumBytes) const;
    static QVariantMap failure(const QString &error);
};
