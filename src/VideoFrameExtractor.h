#pragma once

#include <QImage>
#include <QString>
#include <QThread>
#include <QObject>

// Extracts the first video frame using QMediaPlayer + QVideoSink.
// Runs its own event loop thread since QMediaPlayer requires one.

class VideoFrameExtractorWorker;

class VideoFrameExtractor : public QObject
{
    Q_OBJECT
public:
    explicit VideoFrameExtractor(QObject *parent = nullptr);
    ~VideoFrameExtractor();

    // Thread-safe, blocking call. Returns first frame scaled to fit maxSize.
    QImage grabFrame(const QString &filePath, int maxSize = 320);

private:
    QThread m_thread;
    VideoFrameExtractorWorker *m_worker = nullptr;
};
