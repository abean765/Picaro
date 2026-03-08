#include "VideoFrameExtractor.h"

#include <QMediaPlayer>
#include <QVideoSink>
#include <QVideoFrame>
#include <QEventLoop>
#include <QTimer>
#include <QUrl>
#include <QDebug>

class VideoFrameExtractorWorker : public QObject
{
    Q_OBJECT
public:
    explicit VideoFrameExtractorWorker(QObject *parent = nullptr) : QObject(parent) {}

public slots:
    void extract(const QString &filePath, int maxSize)
    {
        QImage result;
        QMediaPlayer player;
        QVideoSink sink;
        player.setVideoSink(&sink);

        QEventLoop loop;
        bool gotFrame = false;

        QObject::connect(&sink, &QVideoSink::videoFrameChanged, &loop,
            [&](const QVideoFrame &frame) {
                if (gotFrame) return;
                QVideoFrame f = frame;
                if (f.isValid() && f.map(QVideoFrame::ReadOnly)) {
                    result = f.toImage();
                    f.unmap();
                    if (!result.isNull()) {
                        gotFrame = true;
                        loop.quit();
                    }
                }
            });

        QObject::connect(&player, &QMediaPlayer::errorOccurred, &loop,
            [&](QMediaPlayer::Error, const QString &msg) {
                qDebug() << "VideoFrameExtractor error:" << msg;
                loop.quit();
            });

        // Timeout after 5 seconds
        QTimer::singleShot(5000, &loop, &QEventLoop::quit);

        player.setSource(QUrl::fromLocalFile(filePath));
        player.play();
        loop.exec();
        player.stop();

        if (!result.isNull() && (result.width() > maxSize || result.height() > maxSize)) {
            result = result.scaled(maxSize, maxSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }

        emit frameCaptured(result);
    }

signals:
    void frameCaptured(const QImage &image);
};

VideoFrameExtractor::VideoFrameExtractor(QObject *parent)
    : QObject(parent)
{
    m_worker = new VideoFrameExtractorWorker();
    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    m_thread.start();
}

VideoFrameExtractor::~VideoFrameExtractor()
{
    m_thread.quit();
    m_thread.wait();
}

QImage VideoFrameExtractor::grabFrame(const QString &filePath, int maxSize)
{
    QImage result;
    QEventLoop loop;

    connect(m_worker, &VideoFrameExtractorWorker::frameCaptured, &loop,
        [&](const QImage &img) {
            result = img;
            loop.quit();
        });

    QMetaObject::invokeMethod(m_worker, "extract", Qt::QueuedConnection,
                              Q_ARG(QString, filePath), Q_ARG(int, maxSize));

    // Timeout safety: 6 seconds (worker has 5s internal timeout)
    QTimer::singleShot(6000, &loop, &QEventLoop::quit);
    loop.exec();

    return result;
}

#include "VideoFrameExtractor.moc"
