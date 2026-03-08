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

    qDebug() << "Database opened:" << path;
    return true;
}

void PhotoDatabase::configurePragmas()
{
    QSqlQuery q(m_db);

    // WAL mode for concurrent reads during import
    q.exec(QStringLiteral("PRAGMA journal_mode=WAL"));

    // Memory-map up to 8 GB for near-instant access from SSD
    q.exec(QStringLiteral("PRAGMA mmap_size=8589934592"));

    // Larger cache: 256 MB worth of pages (64k pages × 4KB)
    q.exec(QStringLiteral("PRAGMA cache_size=-262144"));

    // We trust the SSD + filesystem for durability on import
    q.exec(QStringLiteral("PRAGMA synchronous=NORMAL"));

    // Larger page size for blob-heavy workloads (thumbnails)
    // Only effective on new databases
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
        " file_size, media_type, live_video_path, mime_type, duration, month_key, thumbnail) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ));

    q.addBindValue(record.filePath);
    q.addBindValue(record.fileName);
    q.addBindValue(record.dateTaken.toString(Qt::ISODate));
    q.addBindValue(record.dateModified.toString(Qt::ISODate));
    q.addBindValue(record.width);
    q.addBindValue(record.height);
    q.addBindValue(record.fileSize);
    q.addBindValue(static_cast<int>(record.mediaType));
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
    countQuery.exec(QStringLiteral("SELECT COUNT(*) FROM photos"));
    if (countQuery.next()) {
        records.reserve(countQuery.value(0).toInt());
    }

    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "SELECT id, file_path, file_name, date_taken, date_modified, "
        "       width, height, file_size, media_type, live_video_path, "
        "       mime_type, duration, month_key "
        "FROM photos ORDER BY date_taken DESC"
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
        r.liveVideoPath = q.value(9).toString();
        r.mimeType = q.value(10).toString();
        r.duration = q.value(11).toDouble();
        r.monthKey = q.value(12).toString();
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
