// SPDX-License-Identifier: GPL-3.0-or-later
#include "profilefile.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QStringConverter>
#include <QStringDecoder>

ProfileFile::ProfileFile(QObject *parent) : QObject(parent) {}

QVariantMap ProfileFile::failure(const QString &error)
{
    return {{QStringLiteral("ok"), false}, {QStringLiteral("error"), error}};
}

QVariantMap ProfileFile::read(const QUrl &url, int maximumBytes) const
{
    if (!url.isLocalFile()) return failure(QStringLiteral("not-local"));
    return readLocalPath(url.toLocalFile(), maximumBytes);
}

QVariantMap ProfileFile::readPath(const QString &path, int maximumBytes) const
{
    if (!QDir::isAbsolutePath(path)) return failure(QStringLiteral("not-local"));
    return readLocalPath(path, maximumBytes);
}

QVariantMap ProfileFile::readLocalPath(const QString &path, int maximumBytes) const
{
    if (maximumBytes <= 0) return failure(QStringLiteral("too-large"));
    if (path.isEmpty()) return failure(QStringLiteral("not-local"));

    const QFileInfo info(path);
    if (!info.exists()) return failure(QStringLiteral("missing"));
    // isFile() follows a symlink but rejects directories, FIFOs and devices,
    // so opening the path cannot block on a pipe chosen by mistake.
    if (!info.isFile()) return failure(QStringLiteral("not-regular"));
    if (info.size() < 0 || info.size() > maximumBytes)
        return failure(QStringLiteral("too-large"));

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return failure(QStringLiteral("read-failed"));
    QByteArray data = file.read(static_cast<qint64>(maximumBytes) + 1);
    // The file can grow between the size check and the read.
    if (data.size() > maximumBytes) return failure(QStringLiteral("too-large"));
    if (data.startsWith("\xEF\xBB\xBF")) data.remove(0, 3);

    QStringDecoder decoder(QStringConverter::Utf8);
    const QString text = decoder.decode(data);
    if (decoder.hasError()) return failure(QStringLiteral("invalid-encoding"));
    return {{QStringLiteral("ok"), true}, {QStringLiteral("text"), text}};
}

QVariantMap ProfileFile::write(const QUrl &url, const QString &text, int maximumBytes) const
{
    if (!url.isLocalFile()) return failure(QStringLiteral("not-local"));
    if (maximumBytes <= 0) return failure(QStringLiteral("too-large"));
    const QString path = url.toLocalFile();
    if (path.isEmpty()) return failure(QStringLiteral("not-local"));

    const QFileInfo info(path);
    if (info.exists()) {
        // Replacing a symlink would make the written path depend on a link the
        // user did not create in the dialog. Refuse instead.
        if (info.isSymLink()) return failure(QStringLiteral("symlink"));
        if (!info.isFile()) return failure(QStringLiteral("not-regular"));
    }

    const QByteArray data = text.toUtf8();
    if (data.size() > maximumBytes) return failure(QStringLiteral("too-large"));

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) return failure(QStringLiteral("write-failed"));
    if (file.write(data) != data.size()) {
        file.cancelWriting();
        return failure(QStringLiteral("write-failed"));
    }
    // The profile can name folders and applications. Keep it readable by its
    // owner only, even when the previous file had broader permissions.
    if (!file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner)) {
        file.cancelWriting();
        return failure(QStringLiteral("write-failed"));
    }
    if (!file.commit()) return failure(QStringLiteral("write-failed"));
    return {{QStringLiteral("ok"), true}};
}
