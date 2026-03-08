#include "PhotoImporter.h"
#include "HeicImageReader.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QBuffer>
#include <QMimeDatabase>
#include <QDebug>
#include <QElapsedTimer>
#include <QtConcurrent>

#ifdef HAVE_EXIV2
#include <exiv2/exiv2.hpp>
#endif

const QStringList PhotoImporter::s_photoExtensions = {
    QStringLiteral("jpg"), QStringLiteral("jpeg"), QStringLiteral("png"),
    QStringLiteral("heic"), QStringLiteral("heif"), QStringLiteral("hif"),
    QStringLiteral("webp"), QStringLiteral("bmp"), QStringLiteral("tiff"),
    QStringLiteral("tif"), QStringLiteral("gif")
};

const QStringList PhotoImporter::s_videoExtensions = {
    QStringLiteral("mp4"), QStringLiteral("mov"), QStringLiteral("avi"),
    QStringLiteral("mkv"), QStringLiteral("m4v"), QStringLiteral("wmv"),
    QStringLiteral("webm"), QStringLiteral("3gp")
};

PhotoImporter::PhotoImporter(PhotoDatabase *db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

void PhotoImporter::importDirectory(const QString &path)
{
    if (m_running) return;

    m_running = true;
    m_cancelled = false;
    m_progress = 0;
    emit runningChanged();

    QtConcurrent::run([this, path]() {
        doImport(path);
    });
}

void PhotoImporter::cancel()
{
    m_cancelled = true;
}

QStringList PhotoImporter::scanDirectory(const QString &path) const
{
    QStringList files;
    QDirIterator it(path, QDir::Files, QDirIterator::Subdirectories);

    QStringList allExtensions = s_photoExtensions + s_videoExtensions;

    while (it.hasNext()) {
        it.next();
        QString suffix = it.fileInfo().suffix().toLower();
        if (allExtensions.contains(suffix)) {
            files.append(it.filePath());
        }
    }

    return files;
}

void PhotoImporter::doImport(const QString &path)
{
    QElapsedTimer timer;
    timer.start();

    qDebug() << "Scanning directory:" << path;

    QStringList files = scanDirectory(path);
    m_totalFiles = files.size();
    QMetaObject::invokeMethod(this, [this]() { emit totalFilesChanged(); });

    qDebug() << "Found" << m_totalFiles << "media files in" << timer.elapsed() << "ms";

    int imported = 0;
    int skipped = 0;
    const int batchSize = 500;

    m_db->beginTransaction();

    for (int i = 0; i < files.size(); ++i) {
        if (m_cancelled) break;

        const QString &filePath = files[i];

        if (m_db->photoExists(filePath)) {
            ++skipped;
        } else {
            PhotoRecord record = extractMetadata(filePath);
            QByteArray thumbnail = generateThumbnail(filePath, record.mediaType);
            m_db->insertPhoto(record, thumbnail);
            ++imported;
        }

        if ((i + 1) % batchSize == 0) {
            m_db->commitTransaction();
            m_db->beginTransaction();
        }

        m_progress = i + 1;
        if (m_progress % 100 == 0 || m_progress == m_totalFiles) {
            QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); });
        }
    }

    m_db->commitTransaction();

    m_running = false;
    qDebug() << "Import finished:" << imported << "imported," << skipped
             << "skipped in" << timer.elapsed() << "ms";

    QMetaObject::invokeMethod(this, [this, imported, skipped]() {
        emit runningChanged();
        emit importFinished(imported, skipped);
    });
}

PhotoRecord PhotoImporter::extractMetadata(const QString &filePath) const
{
    QFileInfo fi(filePath);
    PhotoRecord record;
    record.filePath = filePath;
    record.fileName = fi.fileName();
    record.fileSize = fi.size();
    record.dateModified = fi.lastModified();
    record.mediaType = classifyFile(filePath);
    record.mimeType = QMimeDatabase().mimeTypeForFile(filePath).name();

    // Try to find live video for HEIC files (iPhone Live Photos)
    if (record.mediaType == MediaType::Photo && HeicImageReader::isHeicFile(filePath)) {
        QString liveVideo = findLiveVideo(filePath);
        if (!liveVideo.isEmpty()) {
            record.mediaType = MediaType::LivePhoto;
            record.liveVideoPath = liveVideo;
        }
    }

    // Default date to file modification time
    record.dateTaken = record.dateModified;

#ifdef HAVE_EXIV2
    // Try EXIF data for actual date taken
    try {
        auto image = Exiv2::ImageFactory::open(filePath.toStdString());
        if (image) {
            image->readMetadata();
            const auto &exifData = image->exifData();

            auto it = exifData.findKey(Exiv2::ExifKey("Exif.Photo.DateTimeOriginal"));
            if (it == exifData.end()) {
                it = exifData.findKey(Exiv2::ExifKey("Exif.Image.DateTime"));
            }
            if (it != exifData.end()) {
                QString dateStr = QString::fromStdString(it->toString());
                QDateTime dt = QDateTime::fromString(dateStr, QStringLiteral("yyyy:MM:dd HH:mm:ss"));
                if (dt.isValid()) {
                    record.dateTaken = dt;
                }
            }

            auto wIt = exifData.findKey(Exiv2::ExifKey("Exif.Photo.PixelXDimension"));
            auto hIt = exifData.findKey(Exiv2::ExifKey("Exif.Photo.PixelYDimension"));
            if (wIt != exifData.end()) record.width = wIt->toInt64();
            if (hIt != exifData.end()) record.height = hIt->toInt64();
        }
    } catch (const Exiv2::Error &) {
        // EXIF extraction is best-effort; videos won't have EXIF
    }
#endif

    // Generate month key for grouping
    record.monthKey = record.dateTaken.toString(QStringLiteral("yyyy-MM"));

    // Classify category (screenshot, selfie, or normal)
    record.category = classifyCategory(record);

    return record;
}

QByteArray PhotoImporter::generateThumbnail(const QString &filePath, MediaType type) const
{
    QImage thumb;
    const int thumbSize = 320;

    if (type == MediaType::Video) {
        thumb = QImage(thumbSize, thumbSize, QImage::Format_RGB32);
        thumb.fill(QColor(60, 60, 60));
    } else if (HeicImageReader::isHeicFile(filePath)) {
        thumb = HeicImageReader::readHeicThumbnail(filePath);
        if (thumb.isNull()) {
            thumb = HeicImageReader::readHeicImage(filePath);
        }
        if (!thumb.isNull() && (thumb.width() > thumbSize || thumb.height() > thumbSize)) {
            thumb = thumb.scaled(thumbSize, thumbSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }
    } else {
        QImageReader reader(filePath);
        reader.setAutoTransform(true);

        QSize originalSize = reader.size();
        if (originalSize.isValid() && (originalSize.width() > thumbSize || originalSize.height() > thumbSize)) {
            QSize scaled = originalSize.scaled(thumbSize, thumbSize, Qt::KeepAspectRatio);
            reader.setScaledSize(scaled);
        }

        thumb = reader.read();
    }

    if (thumb.isNull()) {
        return {};
    }

    return imageToJpegBlob(thumb);
}

QByteArray PhotoImporter::imageToJpegBlob(const QImage &img) const
{
    QByteArray data;
    QBuffer buffer(&data);
    buffer.open(QIODevice::WriteOnly);
    img.save(&buffer, "JPEG", 80);
    return data;
}

MediaType PhotoImporter::classifyFile(const QString &filePath) const
{
    QString suffix = QFileInfo(filePath).suffix().toLower();
    if (s_videoExtensions.contains(suffix)) {
        return MediaType::Video;
    }
    return MediaType::Photo;
}

PhotoCategory PhotoImporter::classifyCategory(const PhotoRecord &record) const
{
    if (record.mediaType == MediaType::Video) {
        return PhotoCategory::Normal;
    }

    QString nameLower = record.fileName.toLower();
    QString pathLower = record.filePath.toLower();

    // Screenshot detection:
    // - Filename patterns: "screenshot", "bildschirmfoto", "captura"
    // - Path contains "screenshots" folder
    // - Common Android pattern: "Screenshot_2024..."
    if (nameLower.contains(QStringLiteral("screenshot"))
        || nameLower.contains(QStringLiteral("bildschirmfoto"))
        || nameLower.contains(QStringLiteral("captura"))
        || nameLower.startsWith(QStringLiteral("screen_"))
        || pathLower.contains(QStringLiteral("/screenshots/"))
        || pathLower.contains(QStringLiteral("\\screenshots\\"))) {
        return PhotoCategory::Screenshot;
    }

    // Selfie detection:
    // - Path contains "selfie" or "front camera"
    // - iPhone naming: files from front camera often in specific folders
    if (nameLower.contains(QStringLiteral("selfie"))
        || pathLower.contains(QStringLiteral("/selfies/"))
        || pathLower.contains(QStringLiteral("\\selfies\\"))
        || pathLower.contains(QStringLiteral("/front camera/"))
        || pathLower.contains(QStringLiteral("\\front camera\\"))) {
        return PhotoCategory::Selfie;
    }

    return PhotoCategory::Normal;
}

QString PhotoImporter::findLiveVideo(const QString &photoPath) const
{
    QFileInfo fi(photoPath);
    QString baseName = fi.completeBaseName();
    QString dir = fi.absolutePath();

    for (const auto &ext : { QStringLiteral("mov"), QStringLiteral("MOV"),
                              QStringLiteral("mp4"), QStringLiteral("MP4") }) {
        QString videoPath = dir + QStringLiteral("/") + baseName + QStringLiteral(".") + ext;
        if (QFileInfo::exists(videoPath)) {
            return videoPath;
        }
    }

    return {};
}
