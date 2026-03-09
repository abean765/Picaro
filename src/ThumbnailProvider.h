#pragma once

#include <QQuickAsyncImageProvider>
#include <QThreadPool>
#include <QMutex>
#include <QHash>
#include <QImage>
#include <QString>
#include <atomic>

// Async image provider that loads thumbnails from SQLite on demand.
// Qt Quick requests "image://thumbnail/<photoId>" and we fetch the JPEG blob.
// Each worker thread gets its own SQLite connection (QSqlDatabase is not thread-safe).
// An in-memory cache avoids reloading thumbnails that were already decoded.

class ThumbnailCache
{
public:
    explicit ThumbnailCache(int maxEntries = 2000);

    bool lookup(qint64 photoId, QImage &out) const;
    void insert(qint64 photoId, const QImage &img);

private:
    mutable QMutex m_mutex;
    QHash<qint64, QImage> m_cache;
    int m_maxEntries;
};

// ThumbnailResponse is both the QQuickImageResponse AND the QRunnable.
// Using the same object eliminates the raw-pointer race where Qt Quick could
// delete the response while a separate runnable was still running.
// setAutoDelete(false) prevents the thread pool from deleting it; Qt Quick
// deletes it after finished() is emitted.
class ThumbnailResponse : public QQuickImageResponse, public QRunnable
{
    Q_OBJECT

public:
    ThumbnailResponse(qint64 photoId, const QString &dbPath, ThumbnailCache *cache);

    // Set a pre-cached image (fast path). Caller must then schedule finished()
    // via QMetaObject::invokeMethod(..., Qt::QueuedConnection).
    void setImage(QImage image);

    // QQuickImageResponse
    QQuickTextureFactory *textureFactory() const override;
    void cancel() override;

    // QRunnable — executed by the thread pool (slow path)
    void run() override;

private:
    qint64 m_photoId;
    QString m_dbPath;
    ThumbnailCache *m_cache;
    QImage m_image;
    mutable QMutex m_mutex;
    std::atomic<bool> m_cancelled{false};
};

class ThumbnailProvider : public QQuickAsyncImageProvider
{
public:
    explicit ThumbnailProvider(const QString &dbPath);

    QQuickImageResponse *requestImageResponse(
        const QString &id, const QSize &requestedSize) override;

private:
    QString m_dbPath;
    // IMPORTANT: m_pool must be declared AFTER m_cache so that it is destroyed
    // FIRST (C++ destroys members in reverse declaration order).
    // m_pool's destructor calls waitForDone(), keeping m_cache alive until all
    // running ThumbnailResponse::run() calls have completed.
    ThumbnailCache m_cache;
    QThreadPool m_pool;
};
