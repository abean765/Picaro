#pragma once

#include <QQuickAsyncImageProvider>
#include <QThreadPool>
#include <QMutex>
#include "PhotoDatabase.h"

// Async image provider that loads thumbnails from SQLite on demand.
// Qt Quick requests "image://thumbnail/<photoId>" and we fetch the JPEG blob.

class ThumbnailResponse : public QQuickImageResponse
{
    Q_OBJECT

public:
    ThumbnailResponse(qint64 photoId, const QSize &requestedSize, PhotoDatabase *db, QThreadPool *pool);

    QQuickTextureFactory *textureFactory() const override;

    // Thread-safe: called from worker thread
    void handleResult(QImage image);

private:
    QImage m_image;
    QMutex m_mutex;
};

class ThumbnailProvider : public QQuickAsyncImageProvider
{
public:
    explicit ThumbnailProvider(PhotoDatabase *db);

    QQuickImageResponse *requestImageResponse(
        const QString &id, const QSize &requestedSize) override;

private:
    PhotoDatabase *m_db;
    QThreadPool m_pool;
};
