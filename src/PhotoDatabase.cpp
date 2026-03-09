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

    // Tags tables
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS tags ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name TEXT NOT NULL,"
        "  color TEXT DEFAULT '#888888',"
        "  icon TEXT DEFAULT ''"
        ")"
    ));

    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS photo_tags ("
        "  photo_id INTEGER NOT NULL,"
        "  tag_id INTEGER NOT NULL,"
        "  PRIMARY KEY (photo_id, tag_id),"
        "  FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE,"
        "  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE"
        ")"
    ));

    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_photo_tags_photo ON photo_tags(photo_id)"
    ));
    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_photo_tags_tag ON photo_tags(tag_id)"
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

    // Check for rating column
    q.exec(QStringLiteral("PRAGMA table_info(photos)"));
    bool hasRating = false;
    while (q.next()) {
        if (q.value(1).toString() == QStringLiteral("rating")) hasRating = true;
    }
    if (!hasRating) {
        q.exec(QStringLiteral("ALTER TABLE photos ADD COLUMN rating INTEGER DEFAULT 0"));
        qDebug() << "Migrated: added rating column";
    }

    // Check for has_exif and has_geolocation columns
    q.exec(QStringLiteral("PRAGMA table_info(photos)"));
    bool hasExifCol = false;
    bool hasGeoCol = false;
    while (q.next()) {
        const QString col = q.value(1).toString();
        if (col == QStringLiteral("has_exif")) hasExifCol = true;
        if (col == QStringLiteral("has_geolocation")) hasGeoCol = true;
    }
    if (!hasExifCol) {
        q.exec(QStringLiteral("ALTER TABLE photos ADD COLUMN has_exif INTEGER DEFAULT 0"));
        qDebug() << "Migrated: added has_exif column";
    }
    if (!hasGeoCol) {
        q.exec(QStringLiteral("ALTER TABLE photos ADD COLUMN has_geolocation INTEGER DEFAULT 0"));
        qDebug() << "Migrated: added has_geolocation column";
    }

    // Check for owner column
    q.exec(QStringLiteral("PRAGMA table_info(photos)"));
    bool hasOwner = false;
    while (q.next()) {
        if (q.value(1).toString() == QStringLiteral("owner")) hasOwner = true;
    }
    if (!hasOwner) {
        q.exec(QStringLiteral("ALTER TABLE photos ADD COLUMN owner TEXT DEFAULT ''"));
        qDebug() << "Migrated: added owner column";
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
        " file_size, media_type, category, live_video_path, mime_type, duration, month_key, thumbnail, "
        " has_exif, has_geolocation, owner) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
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
    q.addBindValue(record.hasExif ? 1 : 0);
    q.addBindValue(record.hasGeolocation ? 1 : 0);
    q.addBindValue(record.owner);

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

std::optional<PhotoRecord> PhotoDatabase::loadRecord(qint64 photoId) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT id, file_path, file_name, date_taken, date_modified, "
        "       width, height, file_size, media_type, category, live_video_path, "
        "       mime_type, duration, month_key "
        "FROM photos WHERE id = ?"
    ));
    q.addBindValue(photoId);

    if (!q.exec() || !q.next())
        return std::nullopt;

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
    return r;
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

QVector<PhotoRecord> PhotoDatabase::loadDeletedRecords() const
{
    QVector<PhotoRecord> records;

    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "SELECT id, file_path, file_name, date_taken, date_modified, "
        "       width, height, file_size, media_type, category, live_video_path, "
        "       mime_type, duration, month_key "
        "FROM photos WHERE deleted = 1 ORDER BY date_taken DESC"
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

    // Count photos with EXIF metadata
    q.exec(QStringLiteral(
        "SELECT COUNT(*) FROM photos WHERE deleted = 0 AND has_exif = 1"
    ));
    if (q.next()) stats.withExif = q.value(0).toInt();

    // Count photos with geolocation
    q.exec(QStringLiteral(
        "SELECT COUNT(*) FROM photos WHERE deleted = 0 AND has_geolocation = 1"
    ));
    if (q.next()) stats.withGeolocation = q.value(0).toInt();

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

int PhotoDatabase::getRating(qint64 photoId) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT rating FROM photos WHERE id = ?"));
    q.addBindValue(photoId);
    if (q.exec() && q.next())
        return q.value(0).toInt();
    return 0;
}

bool PhotoDatabase::setRating(qint64 photoId, int rating)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE photos SET rating = ? WHERE id = ?"));
    q.addBindValue(qBound(0, rating, 5));
    q.addBindValue(photoId);
    return q.exec();
}

qint64 PhotoDatabase::createTag(const QString &name, const QString &color, const QString &icon)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO tags (name, color, icon) VALUES (?, ?, ?)"));
    q.addBindValue(name);
    q.addBindValue(color);
    q.addBindValue(icon);
    if (!q.exec()) return -1;
    return q.lastInsertId().toLongLong();
}

bool PhotoDatabase::updateTag(qint64 tagId, const QString &name, const QString &color, const QString &icon)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE tags SET name = ?, color = ?, icon = ? WHERE id = ?"));
    q.addBindValue(name);
    q.addBindValue(color);
    q.addBindValue(icon);
    q.addBindValue(tagId);
    return q.exec();
}

bool PhotoDatabase::deleteTag(qint64 tagId)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM photo_tags WHERE tag_id = ?"));
    q.addBindValue(tagId);
    q.exec();

    q.prepare(QStringLiteral("DELETE FROM tags WHERE id = ?"));
    q.addBindValue(tagId);
    return q.exec();
}

QVector<TagRecord> PhotoDatabase::loadAllTags() const
{
    QVector<TagRecord> tags;
    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "SELECT t.id, t.name, t.color, t.icon, "
        "  (SELECT COUNT(*) FROM photo_tags pt WHERE pt.tag_id = t.id) "
        "FROM tags t ORDER BY t.name"
    ));
    while (q.next()) {
        TagRecord t;
        t.id = q.value(0).toLongLong();
        t.name = q.value(1).toString();
        t.color = q.value(2).toString();
        t.icon = q.value(3).toString();
        t.photoCount = q.value(4).toInt();
        tags.append(std::move(t));
    }
    return tags;
}

QVector<qint64> PhotoDatabase::tagsForPhoto(qint64 photoId) const
{
    QVector<qint64> ids;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT tag_id FROM photo_tags WHERE photo_id = ?"));
    q.addBindValue(photoId);
    q.exec();
    while (q.next()) {
        ids.append(q.value(0).toLongLong());
    }
    return ids;
}

bool PhotoDatabase::addTagToPhoto(qint64 photoId, qint64 tagId)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR IGNORE INTO photo_tags (photo_id, tag_id) VALUES (?, ?)"));
    q.addBindValue(photoId);
    q.addBindValue(tagId);
    return q.exec();
}

bool PhotoDatabase::removeTagFromPhoto(qint64 photoId, qint64 tagId)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM photo_tags WHERE photo_id = ? AND tag_id = ?"));
    q.addBindValue(photoId);
    q.addBindValue(tagId);
    return q.exec();
}
