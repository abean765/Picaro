#include "PhotoImageProvider.h"
#include "HeicImageReader.h"

#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QThread>

static const int kMaxPhotoSize = 2048;

static QString loadFilePathFromDb(const QString &dbPath, qint64 photoId)
{
    // Thread-local SQLite connections (address-based name, same pattern as ThumbnailProvider).
    QString connName = QStringLiteral("photo_") +
        QString::number(reinterpret_cast<quintptr>(QThread::currentThread()), 16);

    if (!QSqlDatabase::contains(connName)) {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        if (!db.open())
            return {};
        QSqlQuery pragma(db);
        pragma.exec(QStringLiteral("PRAGMA cache_size=-2048"));
    }

    QSqlDatabase db = QSqlDatabase::database(connName, false);
    if (!db.isOpen())
        return {};

    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT file_path FROM photos WHERE id = ?"));
    q.addBindValue(photoId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return {};
}

// -- PhotoImageResponse --

PhotoImageResponse::PhotoImageResponse(qint64 photoId, const QString &dbPath)
    : m_photoId(photoId), m_dbPath(dbPath)
{
    setAutoDelete(false);
}

void PhotoImageResponse::cancel()
{
    m_cancelled.store(true, std::memory_order_relaxed);
}

void PhotoImageResponse::run()
{
    if (!m_cancelled.load(std::memory_order_relaxed)) {
        QString filePath = loadFilePathFromDb(m_dbPath, m_photoId);
        if (!filePath.isEmpty()) {
            QString suffix = QFileInfo(filePath).suffix().toLower();
            QImage img;

            if (suffix == QLatin1String("heic") || suffix == QLatin1String("heif")
                    || suffix == QLatin1String("hif")) {
                img = HeicImageReader::readHeicThumbnailOrScaled(filePath, kMaxPhotoSize);
            } else {
                QImageReader reader(filePath);
                reader.setAutoTransform(true);
                QSize origSize = reader.size();
                if (origSize.isValid()
                        && (origSize.width() > kMaxPhotoSize || origSize.height() > kMaxPhotoSize)) {
                    reader.setScaledSize(
                        origSize.scaled(kMaxPhotoSize, kMaxPhotoSize, Qt::KeepAspectRatio));
                }
                img = reader.read();
            }

            if (!img.isNull()) {
                QMutexLocker lock(&m_mutex);
                m_image = std::move(img);
            }
        }
    }
    emit finished();
}

QQuickTextureFactory *PhotoImageResponse::textureFactory() const
{
    QMutexLocker lock(&m_mutex);
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

// -- PhotoImageProvider --

PhotoImageProvider::PhotoImageProvider(const QString &dbPath)
    : m_dbPath(dbPath)
{
    m_pool.setMaxThreadCount(2);
    m_pool.setExpiryTimeout(-1);
}

QQuickImageResponse *PhotoImageProvider::requestImageResponse(
    const QString &id, const QSize &requestedSize)
{
    Q_UNUSED(requestedSize);

    bool ok = false;
    qint64 photoId = id.toLongLong(&ok);
    if (!ok) photoId = 0;

    auto *response = new PhotoImageResponse(photoId, m_dbPath);
    m_pool.start(response);
    return response;
}
