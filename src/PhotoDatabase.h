#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVector>
#include <QDateTime>
#include <QByteArray>
#include <optional>

enum class MediaType : int {
    Photo = 0,
    Video = 1,
    LivePhoto = 2
};

enum class PhotoCategory : int {
    Normal = 0,
    Screenshot = 1,
    Selfie = 2
};

struct PhotoRecord {
    qint64 id = 0;
    QString filePath;
    QString fileName;
    QDateTime dateTaken;
    QDateTime dateModified;
    int width = 0;
    int height = 0;
    qint64 fileSize = 0;
    MediaType mediaType = MediaType::Photo;
    PhotoCategory category = PhotoCategory::Normal;
    QString liveVideoPath;
    QString mimeType;
    double duration = 0.0;
    QString monthKey;  // "2024-01"
    bool hasExif = false;
    bool hasGeolocation = false;
    double latitude = 0.0;   // decimal degrees, only valid if hasGeolocation
    double longitude = 0.0;  // decimal degrees, only valid if hasGeolocation
    QString owner;  // empty = own photo, otherwise sender name
    QString phash;  // perceptual hash (dHash, 16 hex chars = 64 bits)
    QString exifError; // non-empty if EXIF parsing threw an exception (not persisted)
};

struct PhotoStats {
    int totalPhotos = 0;
    int normalPhotos = 0;
    int videos = 0;
    int livePhotos = 0;
    int screenshots = 0;
    int selfies = 0;
    qint64 totalSizeBytes = 0;
    int withExif = 0;
    int withGeolocation = 0;
};

struct TagRecord {
    qint64 id = 0;
    QString name;
    QString color;    // hex color e.g. "#ff5555"
    QString icon;     // emoji or short text
    int photoCount = 0;
};

class PhotoDatabase : public QObject
{
    Q_OBJECT

public:
    explicit PhotoDatabase(QObject *parent = nullptr);
    ~PhotoDatabase();

    bool open(const QString &path);
    void close();
    bool isOpen() const;
    QString databasePath() const { return m_dbPath; }

    // Bulk insert for import performance
    bool beginTransaction();
    bool commitTransaction();
    bool rollbackTransaction();

    qint64 insertPhoto(const PhotoRecord &record, const QByteArray &thumbnail);
    bool photoExists(const QString &filePath) const;

    // Load records sorted by date (no thumbnails - those are loaded on demand)
    QVector<PhotoRecord> loadAllRecords() const;
    QVector<PhotoRecord> loadDeletedRecords() const;
    int photoCount() const;

    // Statistics
    PhotoStats loadStats() const;

    // Thumbnail access for the image provider
    QByteArray loadThumbnail(qint64 photoId) const;

    // Video thumbnail regeneration
    QVector<QPair<qint64, QString>> loadVideoFilePaths() const;
    bool updateThumbnail(qint64 photoId, const QByteArray &thumbnail);

    // Metadata re-read
    QVector<QPair<qint64, QString>> loadAllFilePaths() const;
    bool updateMetadata(qint64 photoId, const PhotoRecord &record);

    // Load a single photo record by ID
    std::optional<PhotoRecord> loadRecord(qint64 photoId) const;

    // Soft-delete: mark photo as deleted (hidden from UI, kept in DB)
    bool markDeleted(qint64 photoId, bool deleted = true);

    // Rating (0 = unrated, 1-5 = hearts)
    int getRating(qint64 photoId) const;
    bool setRating(qint64 photoId, int rating);

    // Tags
    qint64 createTag(const QString &name, const QString &color, const QString &icon);
    bool updateTag(qint64 tagId, const QString &name, const QString &color, const QString &icon);
    bool deleteTag(qint64 tagId);
    QVector<TagRecord> loadAllTags() const;
    QVector<qint64> tagsForPhoto(qint64 photoId) const;
    bool addTagToPhoto(qint64 photoId, qint64 tagId);
    bool removeTagFromPhoto(qint64 photoId, qint64 tagId);

    // Perceptual hashing for duplicate detection
    QStringList loadAllHashes() const;
    // Returns groups of photo IDs that share an identical phash
    QVector<QVector<qint64>> findDuplicateGroups() const;

    QVector<qint64> photoIdsForTag(qint64 tagId) const;

private:
    void createSchema();
    void migrateSchema();
    void configurePragmas();

    QSqlDatabase m_db;
    QString m_dbPath;
};
