#pragma once

#include <QQuickAsyncImageProvider>
#include <QThreadPool>
#include <QMutex>
#include <QString>
#include <atomic>

// Async image provider that loads full-size photos from disk on demand.
// Handles HEIC/HEIF via HeicImageReader; all other formats via QImageReader.
// Registered as "image://photo/<photoId>".

class PhotoImageResponse : public QQuickImageResponse, public QRunnable
{
    Q_OBJECT

public:
    PhotoImageResponse(qint64 photoId, const QString &dbPath);

    QQuickTextureFactory *textureFactory() const override;
    void cancel() override;
    void run() override;

private:
    qint64 m_photoId;
    QString m_dbPath;
    QImage m_image;
    mutable QMutex m_mutex;
    std::atomic<bool> m_cancelled{false};
};

class PhotoImageProvider : public QQuickAsyncImageProvider
{
public:
    explicit PhotoImageProvider(const QString &dbPath);

    QQuickImageResponse *requestImageResponse(
        const QString &id, const QSize &requestedSize) override;

private:
    QString m_dbPath;
    // m_pool must be declared after m_dbPath and destroyed before it.
    QThreadPool m_pool;
};
