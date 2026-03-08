#pragma once

#include <QQuickAsyncImageProvider>
#include <QThreadPool>
#include <QMutex>
#include <QHash>
#include <QImage>
#include <QString>

// Async image provider that loads thumbnails from SQLite on demand.
// Qt Quick requests "image://thumbnail/<photoId>" and we fetch the JPEG blob.
// Each worker thread gets its own SQLite connection (QSqlDatabase is not thread-safe).
// An in-memory LRU cache avoids reloading thumbnails that were already decoded.

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

class ThumbnailResponse : public QQuickImageResponse
{
    Q_OBJECT

public:
    ThumbnailResponse(qint64 photoId, const QSize &requestedSize,
                      const QString &dbPath, QThreadPool *pool,
                      ThumbnailCache *cache);

    QQuickTextureFactory *textureFactory() const override;

    // Thread-safe: called from worker thread
    void handleResult(QImage image);

private:
    QImage m_image;
    mutable QMutex m_mutex;
};

class ThumbnailProvider : public QQuickAsyncImageProvider
{
public:
    explicit ThumbnailProvider(const QString &dbPath);

    QQuickImageResponse *requestImageResponse(
        const QString &id, const QSize &requestedSize) override;

private:
    QString m_dbPath;
    QThreadPool m_pool;
    ThumbnailCache m_cache;
};
