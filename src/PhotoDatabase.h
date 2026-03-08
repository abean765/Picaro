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
    QString liveVideoPath;
    QString mimeType;
    double duration = 0.0;
    QString monthKey;  // "2024-01"
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

    // Bulk insert for import performance
    bool beginTransaction();
    bool commitTransaction();
    bool rollbackTransaction();

    qint64 insertPhoto(const PhotoRecord &record, const QByteArray &thumbnail);
    bool photoExists(const QString &filePath) const;

    // Load all records sorted by date (no thumbnails - those are loaded on demand)
    QVector<PhotoRecord> loadAllRecords() const;
    int photoCount() const;

    // Thumbnail access for the image provider
    QByteArray loadThumbnail(qint64 photoId) const;

private:
    void createSchema();
    void configurePragmas();

    QSqlDatabase m_db;
    QString m_dbPath;
};
