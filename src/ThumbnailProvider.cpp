#include "ThumbnailProvider.h"
#include <QCoreApplication>
#include <QImage>
#include <QMetaObject>
#include <QPointer>
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
        m_cache.clear();
    }
    m_cache.insert(photoId, img);
}

// -- DB access (thread-local connections) --

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
        pragma.exec(QStringLiteral("PRAGMA cache_size=-4096"));
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

// -- ThumbnailResponse --

ThumbnailResponse::ThumbnailResponse(std::shared_ptr<std::atomic<bool>> cancelled)
    : m_cancelled(std::move(cancelled))
{
}

void ThumbnailResponse::setImage(QImage image)
{
    QMutexLocker lock(&m_mutex);
    m_image = std::move(image);
}

void ThumbnailResponse::cancel()
{
    if (m_cancelled) {
        m_cancelled->store(true, std::memory_order_relaxed);
    }
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
    // Never expire idle threads: each thread keeps one SQLite connection open
    // under its address-based name. If threads were recreated with different
    // addresses the old connections would accumulate as unclosed fd leaks.
    m_pool.setExpiryTimeout(-1);
}

QQuickImageResponse *ThumbnailProvider::requestImageResponse(
    const QString &id, const QSize &requestedSize)
{
    Q_UNUSED(requestedSize);

    bool ok = false;
    qint64 photoId = id.toLongLong(&ok);
    if (!ok) photoId = 0;

    auto cancelled = std::make_shared<std::atomic<bool>>(false);
    auto *response = new ThumbnailResponse(cancelled);

    // Fast path: serve from in-memory cache without touching the thread pool.
    QImage cached;
    if (m_cache.lookup(photoId, cached)) {
        response->setImage(std::move(cached));
        // Qt API contract: finished() must not be emitted synchronously from
        // requestImageResponse, so use a queued invocation.
        QMetaObject::invokeMethod(response, &ThumbnailResponse::finished,
                                  Qt::QueuedConnection);
        return response;
    }

    // Slow path: load from DB in background. Use a guarded pointer so we never
    // dereference a ThumbnailResponse after Qt Quick deleted it.
    QPointer<ThumbnailResponse> guardedResponse(response);
    QString dbPath = m_dbPath;
    ThumbnailCache *cache = &m_cache;
    QPointer<QObject> appObject(QCoreApplication::instance());

    m_pool.start([photoId, dbPath, cache, cancelled, guardedResponse, appObject]() {
        // NOTE: Do not read guardedResponse in this worker thread. QObject/QPointer
        // lifetime changes happen on the GUI thread and are handled in the queued
        // continuation below.
        QImage img;
        if (!cancelled->load(std::memory_order_relaxed)) {
            QByteArray data = loadThumbnailFromDb(dbPath, photoId);
            if (!data.isEmpty()) {
                img.loadFromData(data, "JPEG");
                if (!img.isNull()) {
                    cache->insert(photoId, img);
                }
            }
        }

        if (!appObject) {
            return;
        }

        QMetaObject::invokeMethod(
            appObject,
            [guardedResponse, cancelled, img = std::move(img)]() mutable {
                if (!guardedResponse) {
                    return;
                }
                if (!cancelled->load(std::memory_order_relaxed) && !img.isNull()) {
                    guardedResponse->setImage(std::move(img));
                }
                emit guardedResponse->finished();
            },
            Qt::QueuedConnection);
    });

    return response;
}
