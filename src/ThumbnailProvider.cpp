#include "ThumbnailProvider.h"
#include <QImage>
#include <QRunnable>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QThread>

// -- ThumbnailCache --

ThumbnailCache::ThumbnailCache(int maxEntries)
    : m_maxEntries(maxEntries)
{
}

bool ThumbnailCache::lookup(qint64 photoId, QImage &out) const
{
    QMutexLocker lock(&m_mutex);
    auto it = m_cache.constFind(photoId);
    if (it != m_cache.constEnd()) {
        out = it.value();
        return true;
    }
    return false;
}

void ThumbnailCache::insert(qint64 photoId, const QImage &img)
{
    QMutexLocker lock(&m_mutex);
    if (m_cache.size() >= m_maxEntries) {
        // Simple eviction: clear half the cache when full
        m_cache.clear();
    }
    m_cache.insert(photoId, img);
}

// -- DB access (thread-local connections) --

// Each thread gets its own SQLite connection, cached via thread-local connection name.
static QByteArray loadThumbnailFromDb(const QString &dbPath, qint64 photoId)
{
    QString connName = QStringLiteral("thumb_") +
        QString::number(reinterpret_cast<quintptr>(QThread::currentThread()), 16);

    if (!QSqlDatabase::contains(connName)) {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        if (!db.open()) {
            return {};
        }
        QSqlQuery pragma(db);
        pragma.exec(QStringLiteral("PRAGMA mmap_size=8589934592"));
        pragma.exec(QStringLiteral("PRAGMA cache_size=-65536"));
    }

    QSqlDatabase db = QSqlDatabase::database(connName, false);
    if (!db.isOpen()) {
        return {};
    }

    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT thumbnail FROM photos WHERE id = ?"));
    q.addBindValue(photoId);
    if (q.exec() && q.next()) {
        return q.value(0).toByteArray();
    }
    return {};
}

// -- ThumbnailRunnable --

class ThumbnailRunnable : public QRunnable
{
public:
    ThumbnailRunnable(qint64 photoId, const QString &dbPath,
                      ThumbnailResponse *response, ThumbnailCache *cache)
        : m_photoId(photoId), m_dbPath(dbPath), m_response(response), m_cache(cache)
    {
        setAutoDelete(true);
    }

    void run() override
    {
        QImage img;
        QByteArray data = loadThumbnailFromDb(m_dbPath, m_photoId);
        if (!data.isEmpty()) {
            img.loadFromData(data, "JPEG");
            m_cache->insert(m_photoId, img);
        }
        m_response->handleResult(std::move(img));
    }

private:
    qint64 m_photoId;
    QString m_dbPath;
    ThumbnailResponse *m_response;
    ThumbnailCache *m_cache;
};

// -- ThumbnailResponse --

ThumbnailResponse::ThumbnailResponse(qint64 photoId, const QSize &requestedSize,
                                     const QString &dbPath, QThreadPool *pool,
                                     ThumbnailCache *cache)
{
    Q_UNUSED(requestedSize);

    // Fast path: serve from in-memory cache (no thread pool needed)
    QImage cached;
    if (cache->lookup(photoId, cached)) {
        m_image = std::move(cached);
        // Emit finished on next event loop iteration (required by Qt API contract)
        QMetaObject::invokeMethod(this, &ThumbnailResponse::finished, Qt::QueuedConnection);
        return;
    }

    // Slow path: load from DB in background
    auto *runnable = new ThumbnailRunnable(photoId, dbPath, this, cache);
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

ThumbnailProvider::ThumbnailProvider(const QString &dbPath)
    : m_dbPath(dbPath), m_cache(2000)
{
    m_pool.setMaxThreadCount(4);
}

QQuickImageResponse *ThumbnailProvider::requestImageResponse(
    const QString &id, const QSize &requestedSize)
{
    bool ok = false;
    qint64 photoId = id.toLongLong(&ok);
    if (!ok) photoId = 0;

    return new ThumbnailResponse(photoId, requestedSize, m_dbPath, &m_pool, &m_cache);
}
