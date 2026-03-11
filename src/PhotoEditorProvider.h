#pragma once

#include <QQuickAsyncImageProvider>
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QImage>
#include <QRunnable>
#include <QThreadPool>
#include <QMutex>
#include <atomic>

// All edit parameters passed from QML to the provider / saver.
struct EditParams {
    // ── Licht ─────────────────────────────────────────────────────────────────
    float brightness = 0.f;  // -1 … +1  (additive exposure shift)
    float contrast   = 0.f;  // -1 … +1
    float highlights = 0.f;  // -1 … +1  (bright-tone adjustment)
    float shadows    = 0.f;  // -1 … +1  (dark-tone adjustment)
    float blacks     = 0.f;  // -1 … +1  (black-point)
    float whites     = 0.f;  // -1 … +1  (white-point, complement to blacks)
    // ── Farbe ─────────────────────────────────────────────────────────────────
    float saturation = 0.f;  // -1 … +1  (multiplicative delta on HSL saturation)
    float vibrance   = 0.f;  // -1 … +1  (smart saturation, less on already-saturated)
    float warmth     = 0.f;  // -1 … +1  (colour temperature, blue↔warm)
    float tint       = 0.f;  // -1 … +1  (green↔magenta perpendicular to temperature)
    // ── Details ───────────────────────────────────────────────────────────────
    float clarity    = 0.f;  // -1 … +1  (midtone local contrast)
    float sharpness  = 0.f;  // 0 … 1    (unsharp-mask strength)
    float noiseReduction = 0.f; // 0 … 1 (smoothing / noise reduction)
    // ── Effekte ───────────────────────────────────────────────────────────────
    float vignette   = 0.f;  // -1 … +1  (negative = darken edges, positive = lighten)
    // ── Geometrie ─────────────────────────────────────────────────────────────
    int   rotation   = 0;    // 0 / 90 / 180 / 270
    bool  flipH      = false;

    static EditParams fromQuery(const QString &queryStr);
    static EditParams fromMap(const QVariantMap &m);
};

// Applies all edits to src.
// If targetSize is non-empty and smaller than src the image is scaled first
// (for fast previews).  Pass an empty QSize for full-resolution saving.
QImage applyEdits(const QImage &src, const EditParams &p,
                  const QSize &targetSize = QSize());

// ──────────────────────────────────────────────────────────────────────────────
// Async image provider  –  URL:  image://editor/<photoId>_v<ver>?b=…&c=……
// ──────────────────────────────────────────────────────────────────────────────

class PhotoEditorResponse : public QQuickImageResponse, public QRunnable
{
    Q_OBJECT
public:
    PhotoEditorResponse(qint64 photoId, const EditParams &params,
                        const QString &dbPath, const QSize &requestedSize);

    QQuickTextureFactory *textureFactory() const override;
    void cancel() override;
    void run() override;

private:
    qint64      m_photoId;
    EditParams  m_params;
    QString     m_dbPath;
    QSize       m_requestedSize;
    QImage      m_image;
    mutable QMutex m_mutex;
    std::atomic<bool> m_cancelled{false};
};

class PhotoEditorProvider : public QQuickAsyncImageProvider
{
public:
    explicit PhotoEditorProvider(const QString &dbPath);

    QQuickImageResponse *requestImageResponse(
        const QString &id, const QSize &requestedSize) override;

private:
    QString     m_dbPath;
    QThreadPool m_pool;
};

// ──────────────────────────────────────────────────────────────────────────────
// QObject exposed to QML as "photoEditor" – handles saving edits to disk.
// ──────────────────────────────────────────────────────────────────────────────

class PhotoEditor : public QObject
{
    Q_OBJECT
public:
    explicit PhotoEditor(const QString &dbPath, QObject *parent = nullptr);

    // Called from QML; runs in a background thread and emits editsSaved /
    // editFailed when done.
    Q_INVOKABLE void saveEdits(int photoId, const QVariantMap &params);

signals:
    void editsSaved(int photoId);
    void editFailed(int photoId, const QString &error);

private:
    QString m_dbPath;
};
