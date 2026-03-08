#include "ThumbnailProvider.h"
#include <QImage>
#include <QRunnable>
#include <QBuffer>

class ThumbnailRunnable : public QRunnable
{
public:
    ThumbnailRunnable(qint64 photoId, PhotoDatabase *db, ThumbnailResponse *response)
        : m_photoId(photoId), m_db(db), m_response(response)
    {
        setAutoDelete(true);
    }

    void run() override
    {
        QImage img;
        QByteArray data = m_db->loadThumbnail(m_photoId);
        if (!data.isEmpty()) {
            img.loadFromData(data, "JPEG");
        }
        // Thread-safe: mutex protects m_image, emit finished() is safe from any thread
        m_response->handleResult(std::move(img));
    }

private:
    qint64 m_photoId;
    PhotoDatabase *m_db;
    ThumbnailResponse *m_response;
};

// -- ThumbnailResponse --

ThumbnailResponse::ThumbnailResponse(qint64 photoId, const QSize &requestedSize,
                                     PhotoDatabase *db, QThreadPool *pool)
{
    Q_UNUSED(requestedSize);
    auto *runnable = new ThumbnailRunnable(photoId, db, this);
    pool->start(runnable);
}

void ThumbnailResponse::handleResult(QImage image)
{
    {
        QMutexLocker lock(&m_mutex);
        m_image = std::move(image);
    }
    emit finished();
}

QQuickTextureFactory *ThumbnailResponse::textureFactory() const
{
    QMutexLocker lock(&m_mutex);
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

// -- ThumbnailProvider --

ThumbnailProvider::ThumbnailProvider(PhotoDatabase *db)
    : m_db(db)
{
    m_pool.setMaxThreadCount(4);
}

QQuickImageResponse *ThumbnailProvider::requestImageResponse(
    const QString &id, const QSize &requestedSize)
{
    bool ok = false;
    qint64 photoId = id.toLongLong(&ok);
    if (!ok) photoId = 0;

    return new ThumbnailResponse(photoId, requestedSize, m_db, &m_pool);
}
