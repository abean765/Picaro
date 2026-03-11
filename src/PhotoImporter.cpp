#include "PhotoImporter.h"
#include "HeicImageReader.h"

#include <QDir>
#include <QDirIterator>
#include <QSet>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QBuffer>
#include <QMimeDatabase>
#include <QDebug>
#include <QElapsedTimer>
#include <QThreadPool>
#include <QtConcurrent>

#ifdef HAVE_EXIV2
#include <exiv2/exiv2.hpp>
#endif

#ifdef Q_OS_LINUX
#include <sys/resource.h>
#include <dirent.h>
#endif

// Returns the number of FDs still available, or -1 if unknown.
static int availableFds()
{
#ifdef Q_OS_LINUX
    struct rlimit rl;
    if (getrlimit(RLIMIT_NOFILE, &rl) != 0)
        return -1;
    // Count open FDs by scanning /proc/self/fd
    int openCount = 0;
    if (DIR *dir = opendir("/proc/self/fd")) {
        while (readdir(dir))
            ++openCount;
        closedir(dir);
        openCount -= 2; // subtract . and ..
    }
    return static_cast<int>(rl.rlim_cur) - openCount;
#else
    return -1;
#endif
}

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

void PhotoImporter::importDirectory(const QString &path, const QString &owner,
                                    const QVariantList &tagIds, const QString &copyToFolder)
{
    if (m_running) return;

    m_running = true;
    m_cancelled = false;
    m_progress = 0;
    m_currentDirectory = QFileInfo(path).fileName();
    emit runningChanged();
    emit currentDirectoryChanged();

    QVector<qint64> tagIdVec;
    for (const auto &v : tagIds)
        tagIdVec.append(v.toLongLong());

    Q_UNUSED(QtConcurrent::run([this, path, owner, tagIdVec, copyToFolder]() {
        doImport(path, owner, tagIdVec, copyToFolder);
    }));
}

void PhotoImporter::cancel()
{
    m_cancelled = true;
}

QStringList PhotoImporter::scanDirectory(const QString &path) const
{
    QStringList files;
    QDirIterator it(path, QDir::Files, QDirIterator::Subdirectories);

    // Use QSet for O(1) extension lookup instead of QStringList O(n)
    static const QSet<QString> allExtensions = []() {
        QSet<QString> s;
        for (const auto &ext : s_photoExtensions) s.insert(ext);
        for (const auto &ext : s_videoExtensions) s.insert(ext);
        return s;
    }();

    while (it.hasNext()) {
        it.next();
        QString suffix = it.fileInfo().suffix().toLower();
        if (allExtensions.contains(suffix)) {
            files.append(it.filePath());
        }
    }

    return files;
}

void PhotoImporter::doImport(const QString &path, const QString &owner,
                             const QVector<qint64> &tagIds, const QString &copyToFolder)
{
    QElapsedTimer timer;
    timer.start();

    // Helper: copy a file into copyToFolder if set, avoiding overwrites.
    // Returns the destination path, or an empty string if no copy was made.
    auto copyToPhotoFolder = [&copyToFolder](const QString &srcPath, const QString &fileName) -> QString {
        if (copyToFolder.isEmpty()) return {};
        QDir().mkpath(copyToFolder);
        QString destPath = copyToFolder + QStringLiteral("/") + fileName;
        if (QFile::exists(destPath)) {
            QFileInfo fi(destPath);
            QString base = fi.completeBaseName();
            QString ext = fi.suffix();
            int n = 1;
            while (QFile::exists(destPath)) {
                destPath = copyToFolder + QStringLiteral("/") + base
                           + QStringLiteral("_%1.").arg(n) + ext;
                ++n;
            }
        }
        QFile::copy(srcPath, destPath);
        return destPath;
    };

    qDebug() << "Scanning directory:" << path;
    QMetaObject::invokeMethod(this, [this, path]() {
        emit logMessage(QStringLiteral("Scanne Verzeichnis: %1").arg(path));
    });

    QStringList files = scanDirectory(path);
    m_totalFiles = files.size();
    QMetaObject::invokeMethod(this, [this]() { emit totalFilesChanged(); });

    qDebug() << "Found" << m_totalFiles << "media files in" << timer.elapsed() << "ms";

    // Phase 1: Filter out existing files (fast DB lookups)
    QStringList photoFiles;
    QStringList videoFiles;
    int skipped = 0;

    // Build a set of HEIC/HEIF file keys (dir + basename) to detect live photo companions.
    // A MOV/MP4 with the same basename in the same directory is a live video, not a standalone video.
    static const QSet<QString> heicSuffixes = {
        QStringLiteral("heic"), QStringLiteral("heif"), QStringLiteral("hif")
    };
    static const QSet<QString> liveVideoSuffixes = {
        QStringLiteral("mov"), QStringLiteral("mp4")
    };
    QSet<QString> heicKeys;
    for (const QString &filePath : files) {
        QFileInfo fi(filePath);
        if (heicSuffixes.contains(fi.suffix().toLower()))
            heicKeys.insert(fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName().toLower());
    }

    for (const QString &filePath : files) {
        if (m_cancelled) break;
        if (m_db->photoExists(filePath)) {
            ++skipped;
        } else if (classifyFile(filePath) == MediaType::Video) {
            // Skip MOV/MP4 files that serve as live video companions for HEIC live photos,
            // either in this batch or already imported in a previous session.
            QFileInfo fi(filePath);
            if (liveVideoSuffixes.contains(fi.suffix().toLower())) {
                QString key = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName().toLower();
                if (heicKeys.contains(key) || m_db->liveVideoExists(filePath)) {
                    ++skipped;
                    continue;
                }
            }
            videoFiles.append(filePath);
        } else {
            photoFiles.append(filePath);
        }
    }

    QMetaObject::invokeMethod(this, [this, total = m_totalFiles, skipped,
                                     photos = photoFiles.size(), videos = videoFiles.size()]() {
        emit logMessage(QStringLiteral("%1 Dateien gefunden  •  %2 neu (%3 Fotos, %4 Videos)  •  %5 bereits vorhanden")
            .arg(total).arg(photos + videos).arg(photos).arg(videos).arg(skipped));
    });

    int imported = 0;
    const int batchSize = 500;
    int withExif = 0;
    int withGps = 0;

    // Phase 2: Import photos in parallel (HEIC decode is CPU-bound)
    if (!photoFiles.isEmpty() && !m_cancelled) {
        QMetaObject::invokeMethod(this, [this, n = photoFiles.size()]() {
            emit logMessage(QStringLiteral("Importiere %1 Fotos...").arg(n));
        });

        QThreadPool pool;
        const int threadCount = qMin(4, QThread::idealThreadCount());
        pool.setMaxThreadCount(threadCount);

        // Maximum tasks queued ahead of the consumer — keeps FD usage bounded.
        // Each worker may open ~4 FDs (mime, exiv2, thumbnail reader, heif/ffmpeg).
        const int maxInFlight = threadCount * 8;

        m_submittedCount = 0;
        m_resultQueue.clear();

        int submitted = 0;
        int photoRemaining = 0;
        m_db->beginTransaction();

        for (int fileIdx = 0; fileIdx < photoFiles.size(); ++fileIdx) {
            if (m_cancelled) break;

            // Throttle: wait until the queue has room before submitting more
            {
                QMutexLocker lock(&m_queueMutex);
                while (submitted - (imported + m_resultQueue.size()) >= maxInFlight
                       && !m_cancelled) {
                    // Drain available results while we wait
                    while (!m_resultQueue.isEmpty()) {
                        ImportResult result = m_resultQueue.dequeue();
                        lock.unlock();

                        if (!result.record.exifError.isEmpty()) {
                            QMetaObject::invokeMethod(this, [this, name = result.record.fileName, err = result.record.exifError]() {
                                emit logMessage(QStringLiteral("[EXIF-Fehler] %1: %2").arg(name, err));
                            });
                        }
                        if (result.record.hasExif) ++withExif;
                        if (result.record.hasGeolocation) ++withGps;
                        if (!owner.isEmpty())
                            result.record.owner = owner;
                        QString copiedPath = copyToPhotoFolder(result.record.filePath, result.record.fileName);
                        if (!copiedPath.isEmpty()) {
                            result.record.filePath = copiedPath;
                            result.record.fileName = QFileInfo(copiedPath).fileName();
                        }
                        qint64 insertedId = m_db->insertPhoto(result.record, result.thumbnail);
                        if (insertedId < 0) {
                            QMetaObject::invokeMethod(this, [this, name = result.record.fileName]() {
                                emit logMessage(QStringLiteral("[DB-Fehler] Konnte Foto nicht speichern: %1").arg(name));
                            });
                        } else {
                            for (qint64 tagId : tagIds)
                                m_db->addTagToPhoto(insertedId, tagId);
                        }
                        ++imported;
                        --photoRemaining;

                        if (imported % batchSize == 0) {
                            m_db->commitTransaction();
                            m_db->beginTransaction();
                        }
                        m_progress = skipped + imported;
                        QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); });

                        lock.relock();
                    }
                    if (submitted - (imported + m_resultQueue.size()) >= maxInFlight
                        && !m_cancelled) {
                        m_queueCondition.wait(&m_queueMutex, 50);
                    }
                }
            }

            if (m_cancelled) break;

            // Periodic FD safety check (every 200 files)
            if (fileIdx % 200 == 0) {
                int fdAvail = availableFds();
                if (fdAvail >= 0 && fdAvail < 100) {
                    qWarning() << "Import aborted: only" << fdAvail
                               << "file descriptors remaining";
                    QMetaObject::invokeMethod(this, [this, fdAvail]() {
                        QString msg = tr("Import abgebrochen: zu wenige freie Datei-Deskriptoren. "
                                         "Bitte 'ulimit -n 65536' setzen und erneut versuchen.");
                        emit logMessage(QStringLiteral("[Fehler] %1 (noch %2 FDs frei)").arg(msg).arg(fdAvail));
                        emit errorOccurred(msg);
                    });
                    m_cancelled = true;
                    break;
                }
            }

            const QString &filePath = photoFiles[fileIdx];
            ++submitted;
            ++photoRemaining;
            QtConcurrent::run(&pool, [this, filePath]() {
                if (m_cancelled) return;
                ImportResult result;
                result.record = extractMetadata(filePath);
                result.thumbnail = generateThumbnail(filePath, result.record.mediaType);

                // Compute perceptual hash for duplicate detection (photos only)
                if (result.record.mediaType != MediaType::Video) {
                    QImageReader hashReader(filePath);
                    hashReader.setAutoTransform(true);
                    QSize origSize = hashReader.size();
                    if (origSize.isValid()) {
                        // Read at reduced size for speed
                        hashReader.setScaledSize(origSize.scaled(64, 64, Qt::KeepAspectRatio));
                    }
                    QImage hashImg = hashReader.read();
                    result.record.phash = computeDHash(hashImg);
                }

                QMutexLocker lock(&m_queueMutex);
                m_resultQueue.enqueue(std::move(result));
                m_queueCondition.wakeOne();
            });
        }

        // Drain remaining results
        while (photoRemaining > 0 && !m_cancelled) {
            QMutexLocker lock(&m_queueMutex);
            while (m_resultQueue.isEmpty()) {
                m_queueCondition.wait(&m_queueMutex, 100);
                if (m_cancelled && m_resultQueue.isEmpty()) break;
            }

            while (!m_resultQueue.isEmpty()) {
                ImportResult result = m_resultQueue.dequeue();
                lock.unlock();

                if (result.record.hasExif) ++withExif;
                if (result.record.hasGeolocation) ++withGps;
                if (!owner.isEmpty())
                    result.record.owner = owner;
                QString copiedPath2 = copyToPhotoFolder(result.record.filePath, result.record.fileName);
                if (!copiedPath2.isEmpty()) {
                    result.record.filePath = copiedPath2;
                    result.record.fileName = QFileInfo(copiedPath2).fileName();
                }
                qint64 insertedId2 = m_db->insertPhoto(result.record, result.thumbnail);
                if (insertedId2 > 0) {
                    for (qint64 tagId : tagIds)
                        m_db->addTagToPhoto(insertedId2, tagId);
                }
                ++imported;
                --photoRemaining;

                if (imported % batchSize == 0) {
                    m_db->commitTransaction();
                    m_db->beginTransaction();
                }

                m_progress = skipped + imported;
                QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); });

                lock.relock();
            }

            if (m_cancelled) break;
        }

        m_db->commitTransaction();

        // Wait for any remaining workers to finish
        pool.waitForDone();

        // Drain any leftovers added after cancellation
        QMutexLocker lock(&m_queueMutex);
        m_resultQueue.clear();
    }

    // Phase 3: Import videos sequentially (VideoFrameExtractor not thread-safe)
    if (!videoFiles.isEmpty() && !m_cancelled) {
        QMetaObject::invokeMethod(this, [this, n = videoFiles.size()]() {
            emit logMessage(QStringLiteral("Importiere %1 Videos...").arg(n));
        });

        m_db->beginTransaction();

        for (int i = 0; i < videoFiles.size(); ++i) {
            if (m_cancelled) break;

            const QString &filePath = videoFiles[i];
            PhotoRecord record = extractMetadata(filePath);
            if (!record.exifError.isEmpty()) {
                QMetaObject::invokeMethod(this, [this, name = record.fileName, err = record.exifError]() {
                    emit logMessage(QStringLiteral("[EXIF-Fehler] %1: %2").arg(name, err));
                });
            }
            if (record.hasExif) ++withExif;
            if (record.hasGeolocation) ++withGps;
            if (!owner.isEmpty())
                record.owner = owner;
            QByteArray thumbnail = generateThumbnail(filePath, record.mediaType);
            QString copiedVideoPath = copyToPhotoFolder(filePath, record.fileName);
            if (!copiedVideoPath.isEmpty()) {
                record.filePath = copiedVideoPath;
                record.fileName = QFileInfo(copiedVideoPath).fileName();
            }
            qint64 vidId = m_db->insertPhoto(record, thumbnail);
            if (vidId < 0) {
                QMetaObject::invokeMethod(this, [this, name = record.fileName]() {
                    emit logMessage(QStringLiteral("[DB-Fehler] Konnte Video nicht speichern: %1").arg(name));
                });
            } else {
                for (qint64 tagId : tagIds)
                    m_db->addTagToPhoto(vidId, tagId);
            }
            ++imported;

            if (imported % batchSize == 0) {
                m_db->commitTransaction();
                m_db->beginTransaction();
            }

            m_progress = skipped + imported;
            QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); });
        }

        m_db->commitTransaction();
    }

    m_progress = skipped + imported;
    m_running = false;
    int noExif = imported - withExif;
    qDebug() << "Import finished:" << imported << "imported," << skipped
             << "skipped in" << timer.elapsed() << "ms";

    QMetaObject::invokeMethod(this, [this, imported, skipped, withExif, withGps, noExif,
                                     elapsed = (int)timer.elapsed()]() {
        emit logMessage(QStringLiteral(
            "Fertig: %1 importiert  •  %2 mit EXIF  •  %3 mit GPS  •  %4 ohne EXIF  •  %5 übersprungen  (%6 ms)")
            .arg(imported).arg(withExif).arg(withGps).arg(noExif).arg(skipped).arg(elapsed));
        emit runningChanged();
        emit importFinished(imported, skipped);
    });
}

void PhotoImporter::regenerateVideoThumbnails()
{
    if (m_running) return;

    m_running = true;
    m_cancelled = false;
    m_progress = 0;
    emit runningChanged();

    Q_UNUSED(QtConcurrent::run([this]() {
        QElapsedTimer timer;
        timer.start();

        auto videos = m_db->loadVideoFilePaths();
        m_totalFiles = videos.size();
        QMetaObject::invokeMethod(this, [this]() { emit totalFilesChanged(); });

        qDebug() << "Regenerating thumbnails for" << m_totalFiles << "videos";

        int updated = 0;

        for (int i = 0; i < videos.size(); ++i) {
            if (m_cancelled) break;

            const auto &[id, filePath] = videos[i];
            QImage frame = m_frameExtractor.grabFrame(filePath, 320);
            if (!frame.isNull()) {
                QByteArray blob = imageToJpegBlob(frame);
                if (!blob.isEmpty()) {
                    m_db->updateThumbnail(id, blob);
                    ++updated;
                }
            }

            m_progress = i + 1;
            if (m_progress % 10 == 0 || m_progress == m_totalFiles) {
                QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); });
            }
        }

        m_running = false;
        qDebug() << "Thumbnail regeneration finished:" << updated << "of"
                 << videos.size() << "updated in" << timer.elapsed() << "ms";

        QMetaObject::invokeMethod(this, [this, updated, total = videos.size()]() {
            emit runningChanged();
            emit importFinished(updated, static_cast<int>(total) - updated);
        });
    }));
}

void PhotoImporter::rereadMetadata()
{
    if (m_running) return;

    m_running = true;
    m_cancelled = false;
    m_progress = 0;
    emit runningChanged();

    Q_UNUSED(QtConcurrent::run([this]() {
        QElapsedTimer timer;
        timer.start();

        auto allFiles = m_db->loadAllFilePaths();
        m_totalFiles = allFiles.size();
        QMetaObject::invokeMethod(this, [this]() { emit totalFilesChanged(); });

        QMetaObject::invokeMethod(this, [this, n = m_totalFiles]() {
            emit logMessage(QStringLiteral("Starte Metadaten-Neueinlesung für %1 Einträge...").arg(n));
        });

        int updated = 0;
        int notFound = 0;
        int withExif = 0;
        int withGps = 0;

        m_db->beginTransaction();

        for (int i = 0; i < allFiles.size(); ++i) {
            if (m_cancelled) break;

            const auto &[id, filePath] = allFiles[i];

            if (!QFileInfo::exists(filePath)) {
                ++notFound;
                QMetaObject::invokeMethod(this, [this, filePath]() {
                    emit logMessage(QStringLiteral("[Nicht gefunden] %1").arg(filePath));
                });
                m_progress = i + 1;
                QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); });
                continue;
            }

            PhotoRecord record = extractMetadata(filePath);
            record.id = id;

            // Compute perceptual hash if not yet set (photos only)
            if (record.mediaType != MediaType::Video) {
                QImageReader hashReader(filePath);
                hashReader.setAutoTransform(true);
                QSize origSize = hashReader.size();
                if (origSize.isValid())
                    hashReader.setScaledSize(origSize.scaled(64, 64, Qt::KeepAspectRatio));
                record.phash = computeDHash(hashReader.read());
            }

            if (!record.exifError.isEmpty()) {
                QMetaObject::invokeMethod(this, [this, name = record.fileName, err = record.exifError]() {
                    emit logMessage(QStringLiteral("[EXIF-Fehler] %1: %2").arg(name, err));
                });
            }

            if (record.hasExif) ++withExif;
            if (record.hasGeolocation) ++withGps;

            if (!m_db->updateMetadata(id, record)) {
                QMetaObject::invokeMethod(this, [this, name = record.fileName]() {
                    emit logMessage(QStringLiteral("[DB-Fehler] Konnte Metadaten nicht schreiben: %1").arg(name));
                });
            }
            ++updated;

            m_progress = i + 1;
            if (m_progress % 50 == 0 || m_progress == m_totalFiles)
                QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); });

            if ((i + 1) % 500 == 0) {
                QMetaObject::invokeMethod(this, [this, cur = i + 1, total = m_totalFiles]() {
                    emit logMessage(QStringLiteral("Fortschritt: %1 / %2 ...").arg(cur).arg(total));
                });
            }
        }

        m_db->commitTransaction();
        m_running = false;

        int elapsed = static_cast<int>(timer.elapsed());
        QMetaObject::invokeMethod(this, [this, updated, notFound, withExif, withGps, elapsed]() {
            emit logMessage(QStringLiteral(
                "Fertig: %1 aktualisiert  •  %2 mit EXIF  •  %3 mit GPS  •  %4 nicht gefunden  (%5 ms)")
                .arg(updated).arg(withExif).arg(withGps).arg(notFound).arg(elapsed));
            emit runningChanged();
            emit importFinished(updated, 0);
        });
    }));
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
    static thread_local QMimeDatabase mimeDb;
    record.mimeType = mimeDb.mimeTypeForFile(filePath).name();

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
    // Load EXIF: HEIC files require extraction via libheif because exiv2 cannot
    // open the HEIF container directly. All other formats use exiv2 as usual.
    Exiv2::ExifData exifData;

    if (HeicImageReader::isHeicFile(filePath)) {
        QByteArray rawExif = HeicImageReader::readHeicExifBytes(filePath);
        if (!rawExif.isEmpty()) {
            try {
                Exiv2::ExifParser::decode(
                    exifData,
                    reinterpret_cast<const Exiv2::byte *>(rawExif.constData()),
                    static_cast<size_t>(rawExif.size()));
            } catch (const Exiv2::Error &e) {
                record.exifError = QString::fromStdString(e.what());
            }
        }
    } else {
        try {
            auto image = Exiv2::ImageFactory::open(filePath.toStdString());
            if (image.get()) {
                image->readMetadata();
                exifData = image->exifData();
            }
        } catch (const Exiv2::Error &e) {
            // Best-effort; videos and unsupported formats will throw here.
            record.exifError = QString::fromStdString(e.what());
        }
    }

    if (!exifData.empty()) {
        record.hasExif = true;

        auto it = exifData.findKey(Exiv2::ExifKey("Exif.Photo.DateTimeOriginal"));
        if (it == exifData.end())
            it = exifData.findKey(Exiv2::ExifKey("Exif.Image.DateTime"));
        if (it != exifData.end()) {
            QString dateStr = QString::fromStdString(it->toString());
            QDateTime dt = QDateTime::fromString(dateStr, QStringLiteral("yyyy:MM:dd HH:mm:ss"));
            if (dt.isValid())
                record.dateTaken = dt;
        }

        auto wIt = exifData.findKey(Exiv2::ExifKey("Exif.Photo.PixelXDimension"));
        auto hIt = exifData.findKey(Exiv2::ExifKey("Exif.Photo.PixelYDimension"));
        if (wIt != exifData.end()) record.width = static_cast<int>(wIt->toLong());
        if (hIt != exifData.end()) record.height = static_cast<int>(hIt->toLong());

        auto latIt    = exifData.findKey(Exiv2::ExifKey("Exif.GPSInfo.GPSLatitude"));
        auto latRefIt = exifData.findKey(Exiv2::ExifKey("Exif.GPSInfo.GPSLatitudeRef"));
        auto lonIt    = exifData.findKey(Exiv2::ExifKey("Exif.GPSInfo.GPSLongitude"));
        auto lonRefIt = exifData.findKey(Exiv2::ExifKey("Exif.GPSInfo.GPSLongitudeRef"));
        if (latIt != exifData.end() && lonIt != exifData.end()) {
            record.hasGeolocation = true;

            auto dmsToDecimal = [](const Exiv2::Value &val) -> double {
                double result = 0.0;
                if (val.count() >= 1) {
                    auto r = val.toRational(0);
                    if (r.second != 0) result += static_cast<double>(r.first) / r.second;
                }
                if (val.count() >= 2) {
                    auto r = val.toRational(1);
                    if (r.second != 0) result += static_cast<double>(r.first) / r.second / 60.0;
                }
                if (val.count() >= 3) {
                    auto r = val.toRational(2);
                    if (r.second != 0) result += static_cast<double>(r.first) / r.second / 3600.0;
                }
                return result;
            };

            record.latitude  = dmsToDecimal(latIt->value());
            record.longitude = dmsToDecimal(lonIt->value());

            if (latRefIt != exifData.end() && latRefIt->toString() == "S")
                record.latitude = -record.latitude;
            if (lonRefIt != exifData.end() && lonRefIt->toString() == "W")
                record.longitude = -record.longitude;
        }
    }
#endif

    // Generate month key for grouping
    record.monthKey = record.dateTaken.toString(QStringLiteral("yyyy-MM"));

    // Classify category (screenshot, selfie, or normal)
    record.category = classifyCategory(record);

    return record;
}

QByteArray PhotoImporter::generateThumbnail(const QString &filePath, MediaType type)
{
    QImage thumb;
    const int thumbSize = 320;

    if (type == MediaType::Video) {
        thumb = m_frameExtractor.grabFrame(filePath, thumbSize);
        if (thumb.isNull()) {
            // Fallback: gray placeholder if frame extraction fails
            thumb = QImage(thumbSize, thumbSize, QImage::Format_RGB32);
            thumb.fill(QColor(60, 60, 60));
        }
    } else if (HeicImageReader::isHeicFile(filePath)) {
        thumb = HeicImageReader::readHeicThumbnailOrScaled(filePath, thumbSize);
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

QString PhotoImporter::computeDHash(const QImage &img)
{
    if (img.isNull())
        return {};

    // Difference Hash: resize to 9x8 grayscale, compare adjacent horizontal pixels
    QImage small = img.scaled(9, 8, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                      .convertToFormat(QImage::Format_Grayscale8);

    quint64 hash = 0;
    int bit = 0;
    for (int y = 0; y < 8; ++y) {
        const uchar *row = small.constScanLine(y);
        for (int x = 0; x < 8; ++x) {
            if (row[x] < row[x + 1]) {
                hash |= (static_cast<quint64>(1) << bit);
            }
            ++bit;
        }
    }

    return QStringLiteral("%1").arg(hash, 16, 16, QLatin1Char('0'));
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
