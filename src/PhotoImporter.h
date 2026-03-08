#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include "PhotoDatabase.h"
#include "VideoFrameExtractor.h"

// Async photo importer that scans a directory, reads metadata,
// generates thumbnails, and inserts into the database.
// Runs on a worker thread via QtConcurrent.

class PhotoImporter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY totalFilesChanged)

public:
    explicit PhotoImporter(PhotoDatabase *db, QObject *parent = nullptr);

    bool isRunning() const { return m_running; }
    int progress() const { return m_progress; }
    int totalFiles() const { return m_totalFiles; }

    Q_INVOKABLE void importDirectory(const QString &path);
    Q_INVOKABLE void cancel();

signals:
    void runningChanged();
    void progressChanged();
    void totalFilesChanged();
    void importFinished(int imported, int skipped);
    void errorOccurred(const QString &message);

private:
    void doImport(const QString &path);
    PhotoRecord extractMetadata(const QString &filePath) const;
    QByteArray generateThumbnail(const QString &filePath, MediaType type);
    QByteArray imageToJpegBlob(const QImage &img) const;
    MediaType classifyFile(const QString &filePath) const;
    PhotoCategory classifyCategory(const PhotoRecord &record) const;
    QString findLiveVideo(const QString &photoPath) const;
    QStringList scanDirectory(const QString &path) const;

    PhotoDatabase *m_db;
    VideoFrameExtractor m_frameExtractor;
    bool m_running = false;
    bool m_cancelled = false;
    int m_progress = 0;
    int m_totalFiles = 0;

    static const QStringList s_photoExtensions;
    static const QStringList s_videoExtensions;
};
