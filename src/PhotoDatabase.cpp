#include "PhotoDatabase.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QFileInfo>

PhotoDatabase::PhotoDatabase(QObject *parent)
    : QObject(parent)
{
}

PhotoDatabase::~PhotoDatabase()
{
    close();
}

bool PhotoDatabase::open(const QString &path)
{
    m_dbPath = path;
    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("picaro"));
    m_db.setDatabaseName(path);

    if (!m_db.open()) {
        qWarning() << "Failed to open database:" << m_db.lastError().text();
        return false;
    }

    configurePragmas();
    createSchema();
    migrateSchema();

    qDebug() << "Database opened:" << path;
    return true;
}

void PhotoDatabase::configurePragmas()
{
    QSqlQuery q(m_db);
    q.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    q.exec(QStringLiteral("PRAGMA mmap_size=8589934592"));
    q.exec(QStringLiteral("PRAGMA cache_size=-262144"));
    q.exec(QStringLiteral("PRAGMA synchronous=NORMAL"));
    q.exec(QStringLiteral("PRAGMA page_size=8192"));
    q.exec(QStringLiteral("PRAGMA temp_store=MEMORY"));
}

void PhotoDatabase::createSchema()
{
    QSqlQuery q(m_db);

    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS photos ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  file_path TEXT UNIQUE NOT NULL,"
        "  file_name TEXT NOT NULL,"
        "  date_taken TEXT,"
        "  date_modified TEXT,"
        "  width INTEGER DEFAULT 0,"
        "  height INTEGER DEFAULT 0,"
        "  file_size INTEGER DEFAULT 0,"
        "  media_type INTEGER DEFAULT 0,"
        "  category INTEGER DEFAULT 0,"
        "  live_video_path TEXT,"
        "  mime_type TEXT,"
        "  duration REAL DEFAULT 0,"
        "  month_key TEXT,"
        "  thumbnail BLOB"
        ")"
    ));

    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_photos_date ON photos(date_taken DESC)"
    ));
    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_photos_month ON photos(month_key)"
    ));
    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_photos_path ON photos(file_path)"
    ));
    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_photos_category ON photos(category)"
    ));
}

void PhotoDatabase::migrateSchema()
{
    QSqlQuery q(m_db);
    q.exec(QStringLiteral("PRAGMA table_info(photos)"));
    bool hasCategory = false;
    bool hasDeleted = false;
    while (q.next()) {
        const QString col = q.value(1).toString();
        if (col == QStringLiteral("category")) hasCategory = true;
        if (col == QStringLiteral("deleted")) hasDeleted = true;
    }
    if (!hasCategory) {
        q.exec(QStringLiteral("ALTER TABLE photos ADD COLUMN category INTEGER DEFAULT 0"));
        q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_photos_category ON photos(category)"));
        qDebug() << "Migrated: added category column";
    }
    if (!hasDeleted) {
        q.exec(QStringLiteral("ALTER TABLE photos ADD COLUMN deleted INTEGER DEFAULT 0"));
        qDebug() << "Migrated: added deleted column";
    }
}

void PhotoDatabase::close()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
}

bool PhotoDatabase::isOpen() const
{
    return m_db.isOpen();
}

bool PhotoDatabase::beginTransaction()
{
    return m_db.transaction();
}

bool PhotoDatabase::commitTransaction()
{
    return m_db.commit();
}

bool PhotoDatabase::rollbackTransaction()
{
    return m_db.rollback();
}

qint64 PhotoDatabase::insertPhoto(const PhotoRecord &record, const QByteArray &thumbnail)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO photos "
        "(file_path, file_name, date_taken, date_modified, width, height, "
        " file_size, media_type, category, live_video_path, mime_type, duration, month_key, thumbnail) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ));

    q.addBindValue(record.filePath);
    q.addBindValue(record.fileName);
    q.addBindValue(record.dateTaken.toString(Qt::ISODate));
    q.addBindValue(record.dateModified.toString(Qt::ISODate));
    q.addBindValue(record.width);
    q.addBindValue(record.height);
    q.addBindValue(record.fileSize);
    q.addBindValue(static_cast<int>(record.mediaType));
    q.addBindValue(static_cast<int>(record.category));
    q.addBindValue(record.liveVideoPath);
    q.addBindValue(record.mimeType);
    q.addBindValue(record.duration);
    q.addBindValue(record.monthKey);
    q.addBindValue(thumbnail);

    if (!q.exec()) {
        qWarning() << "Insert failed:" << q.lastError().text();
        return -1;
    }

    return q.lastInsertId().toLongLong();
}

bool PhotoDatabase::photoExists(const QString &filePath) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT 1 FROM photos WHERE file_path = ? LIMIT 1"));
    q.addBindValue(filePath);
    q.exec();
    return q.next();
}

QVector<PhotoRecord> PhotoDatabase::loadAllRecords() const
{
    QVector<PhotoRecord> records;

    QSqlQuery countQuery(m_db);
    countQuery.exec(QStringLiteral("SELECT COUNT(*) FROM photos WHERE deleted = 0"));
    if (countQuery.next()) {
        records.reserve(countQuery.value(0).toInt());
    }

    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "SELECT id, file_path, file_name, date_taken, date_modified, "
        "       width, height, file_size, media_type, category, live_video_path, "
        "       mime_type, duration, month_key "
        "FROM photos WHERE deleted = 0 ORDER BY date_taken DESC"
    ));

    while (q.next()) {
        PhotoRecord r;
        r.id = q.value(0).toLongLong();
        r.filePath = q.value(1).toString();
        r.fileName = q.value(2).toString();
        r.dateTaken = QDateTime::fromString(q.value(3).toString(), Qt::ISODate);
        r.dateModified = QDateTime::fromString(q.value(4).toString(), Qt::ISODate);
        r.width = q.value(5).toInt();
        r.height = q.value(6).toInt();
        r.fileSize = q.value(7).toLongLong();
        r.mediaType = static_cast<MediaType>(q.value(8).toInt());
        r.category = static_cast<PhotoCategory>(q.value(9).toInt());
        r.liveVideoPath = q.value(10).toString();
        r.mimeType = q.value(11).toString();
        r.duration = q.value(12).toDouble();
        r.monthKey = q.value(13).toString();
        records.append(std::move(r));
    }

    return records;
}

int PhotoDatabase::photoCount() const
{
    QSqlQuery q(m_db);
    q.exec(QStringLiteral("SELECT COUNT(*) FROM photos"));
    if (q.next()) {
        return q.value(0).toInt();
    }
    return 0;
}

PhotoStats PhotoDatabase::loadStats() const
{
    PhotoStats stats;

    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "SELECT media_type, category, COUNT(*), COALESCE(SUM(file_size), 0) "
        "FROM photos WHERE deleted = 0 GROUP BY media_type, category"
    ));

    while (q.next()) {
        auto type = static_cast<MediaType>(q.value(0).toInt());
        auto cat = static_cast<PhotoCategory>(q.value(1).toInt());
        int count = q.value(2).toInt();
        qint64 size = q.value(3).toLongLong();

        stats.totalPhotos += count;
        stats.totalSizeBytes += size;

        switch (type) {
        case MediaType::Video:
            stats.videos += count;
            break;
        case MediaType::LivePhoto:
            stats.livePhotos += count;
            break;
        case MediaType::Photo:
            switch (cat) {
            case PhotoCategory::Screenshot:
                stats.screenshots += count;
                break;
            case PhotoCategory::Selfie:
                stats.selfies += count;
                break;
            default:
                stats.normalPhotos += count;
                break;
            }
            break;
        }
    }

    return stats;
}

QByteArray PhotoDatabase::loadThumbnail(qint64 photoId) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT thumbnail FROM photos WHERE id = ?"));
    q.addBindValue(photoId);
    q.exec();
    if (q.next()) {
        return q.value(0).toByteArray();
    }
    return {};
}

QVector<QPair<qint64, QString>> PhotoDatabase::loadVideoFilePaths() const
{
    QVector<QPair<qint64, QString>> result;
    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "SELECT id, file_path FROM photos WHERE media_type = 1"
    ));
    while (q.next()) {
        result.append({q.value(0).toLongLong(), q.value(1).toString()});
    }
    return result;
}

bool PhotoDatabase::updateThumbnail(qint64 photoId, const QByteArray &thumbnail)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE photos SET thumbnail = ? WHERE id = ?"));
    q.addBindValue(thumbnail);
    q.addBindValue(photoId);
    return q.exec();
}

bool PhotoDatabase::markDeleted(qint64 photoId, bool deleted)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE photos SET deleted = ? WHERE id = ?"));
    q.addBindValue(deleted ? 1 : 0);
    q.addBindValue(photoId);
    return q.exec();
}
