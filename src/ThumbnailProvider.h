#pragma once

#include <QQuickAsyncImageProvider>
#include <QThreadPool>
#include <QMutex>
#include <QString>

// Async image provider that loads thumbnails from SQLite on demand.
// Qt Quick requests "image://thumbnail/<photoId>" and we fetch the JPEG blob.
// Each worker thread gets its own SQLite connection (QSqlDatabase is not thread-safe).

class ThumbnailResponse : public QQuickImageResponse
{
    Q_OBJECT

public:
    ThumbnailResponse(qint64 photoId, const QSize &requestedSize,
                      const QString &dbPath, QThreadPool *pool);

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
};
