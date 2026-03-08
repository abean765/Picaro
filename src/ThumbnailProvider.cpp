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
        QByteArray data = m_db->loadThumbnail(m_photoId);
        if (!data.isEmpty()) {
            QImage img;
            img.loadFromData(data, "JPEG");
            QMetaObject::invokeMethod(m_response, [this, img = std::move(img)]() mutable {
                m_response->setImage(std::move(img));
            });
        } else {
            QMetaObject::invokeMethod(m_response, [this]() {
                m_response->setImage({});
            });
        }
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
    auto *runnable = new ThumbnailRunnable(photoId, db, this);
    pool->start(runnable);
}

void ThumbnailResponse::setImage(QImage image)
{
    m_image = std::move(image);
    emit finished();
}

QQuickTextureFactory *ThumbnailResponse::textureFactory() const
{
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

// -- ThumbnailProvider --

ThumbnailProvider::ThumbnailProvider(PhotoDatabase *db)
    : m_db(db)
{
    // Limit threads to avoid overwhelming SQLite
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
