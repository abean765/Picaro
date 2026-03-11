#include "PhotoEditorProvider.h"

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QThread>
#include <QBuffer>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>
#include <cmath>

// ─── EditParams ──────────────────────────────────────────────────────────────

EditParams EditParams::fromQuery(const QString &qs)
{
    EditParams p;
    const QStringList parts = qs.split(QLatin1Char('&'));
    for (const QString &part : parts) {
        const int eq = part.indexOf(QLatin1Char('='));
        if (eq < 0) continue;
        const QString key = part.left(eq);
        const float   val = part.mid(eq + 1).toFloat();
        if      (key == QLatin1String("b"))  p.brightness = val;
        else if (key == QLatin1String("c"))  p.contrast   = val;
        else if (key == QLatin1String("s"))  p.saturation = val;
        else if (key == QLatin1String("w"))  p.warmth     = val;
        else if (key == QLatin1String("hl")) p.highlights = val;
        else if (key == QLatin1String("sh")) p.shadows    = val;
        else if (key == QLatin1String("bl")) p.blacks     = val;
        else if (key == QLatin1String("sp")) p.sharpness  = val;
        else if (key == QLatin1String("r"))  p.rotation   = static_cast<int>(val);
        else if (key == QLatin1String("fh")) p.flipH      = static_cast<int>(val) != 0;
    }
    return p;
}

EditParams EditParams::fromMap(const QVariantMap &m)
{
    EditParams p;
    p.brightness = m.value(QStringLiteral("brightness"), 0.0).toFloat();
    p.contrast   = m.value(QStringLiteral("contrast"),   0.0).toFloat();
    p.saturation = m.value(QStringLiteral("saturation"), 0.0).toFloat();
    p.warmth     = m.value(QStringLiteral("warmth"),     0.0).toFloat();
    p.highlights = m.value(QStringLiteral("highlights"), 0.0).toFloat();
    p.shadows    = m.value(QStringLiteral("shadows"),    0.0).toFloat();
    p.blacks     = m.value(QStringLiteral("blacks"),     0.0).toFloat();
    p.sharpness  = m.value(QStringLiteral("sharpness"),  0.0).toFloat();
    p.rotation   = m.value(QStringLiteral("rotation"),   0).toInt();
    p.flipH      = m.value(QStringLiteral("flipH"),   false).toBool();
    return p;
}

// ─── Colour-math helpers ──────────────────────────────────────────────────────

static inline float clamp01(float x)
{
    return x < 0.f ? 0.f : (x > 1.f ? 1.f : x);
}

static void rgb2hsl(float r, float g, float b,
                    float &h, float &s, float &l)
{
    float mx = std::max({r, g, b});
    float mn = std::min({r, g, b});
    l = (mx + mn) * 0.5f;
    float d = mx - mn;
    if (d < 1e-6f) { h = s = 0.f; return; }
    s = l > 0.5f ? d / (2.f - mx - mn) : d / (mx + mn);
    if      (mx == r) h = (g - b) / d + (g < b ? 6.f : 0.f);
    else if (mx == g) h = (b - r) / d + 2.f;
    else              h = (r - g) / d + 4.f;
    h /= 6.f;
}

static float hue2rgb(float p, float q, float t)
{
    if (t < 0.f) t += 1.f;
    if (t > 1.f) t -= 1.f;
    if (t < 1.f/6.f) return p + (q - p) * 6.f * t;
    if (t < 0.5f)    return q;
    if (t < 2.f/3.f) return p + (q - p) * (2.f/3.f - t) * 6.f;
    return p;
}

static void hsl2rgb(float h, float s, float l,
                    float &r, float &g, float &b)
{
    if (s < 1e-6f) { r = g = b = l; return; }
    float q = l < 0.5f ? l * (1.f + s) : l + s - l * s;
    float p = 2.f * l - q;
    r = hue2rgb(p, q, h + 1.f/3.f);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1.f/3.f);
}

// ─── applyColorAdjustments ───────────────────────────────────────────────────

static QImage applyColorAdjustments(QImage img, const EditParams &p)
{
    img = img.convertToFormat(QImage::Format_RGBA8888);
    const int W = img.width();
    const int H = img.height();

    for (int y = 0; y < H; ++y) {
        uchar *line = img.scanLine(y);
        for (int x = 0; x < W; ++x) {
            float r = line[x*4+0] / 255.f;
            float g = line[x*4+1] / 255.f;
            float b = line[x*4+2] / 255.f;

            // 1. Brightness (additive exposure shift)
            r += p.brightness * 0.5f;
            g += p.brightness * 0.5f;
            b += p.brightness * 0.5f;

            // 2. Contrast (pivot around 0.5)
            float cf = 1.f + p.contrast;
            r = (r - 0.5f) * cf + 0.5f;
            g = (g - 0.5f) * cf + 0.5f;
            b = (b - 0.5f) * cf + 0.5f;

            // 3. Warmth (colour temperature shift)
            r += p.warmth * 0.12f;
            b -= p.warmth * 0.12f;

            // Clamp before luminance-based ops
            r = clamp01(r); g = clamp01(g); b = clamp01(b);

            // 4. Highlights / Shadows (luminance-based)
            float lum = 0.2126f*r + 0.7152f*g + 0.0722f*b;

            if (p.highlights != 0.f && lum > 0.5f) {
                float t = (lum - 0.5f) * 2.f;   // 0 … 1 in bright range
                float delta = p.highlights * t * 0.4f;
                r += delta; g += delta; b += delta;
            }
            if (p.shadows != 0.f && lum < 0.5f) {
                float t = (0.5f - lum) * 2.f;    // 0 … 1 in dark range
                float delta = p.shadows * t * 0.4f;
                r += delta; g += delta; b += delta;
            }

            // 5. Blacks (lift/crush the very darkest tones)
            if (p.blacks != 0.f) {
                float t = std::max(0.f, 1.f - lum * 3.f); // strongest effect near 0
                float delta = -p.blacks * t * 0.25f;
                r += delta; g += delta; b += delta;
            }

            // 6. Saturation (via HSL)
            r = clamp01(r); g = clamp01(g); b = clamp01(b);
            float h, s, l;
            rgb2hsl(r, g, b, h, s, l);
            s = clamp01(s * (1.f + p.saturation));
            hsl2rgb(h, s, l, r, g, b);

            line[x*4+0] = static_cast<uchar>(clamp01(r) * 255.f + 0.5f);
            line[x*4+1] = static_cast<uchar>(clamp01(g) * 255.f + 0.5f);
            line[x*4+2] = static_cast<uchar>(clamp01(b) * 255.f + 0.5f);
            // Alpha unchanged (line[x*4+3])
        }
    }
    return img;
}

// ─── applySharpen (unsharp-mask style) ───────────────────────────────────────

static QImage applySharpen(QImage img, float strength)
{
    if (strength < 0.01f) return img;
    img = img.convertToFormat(QImage::Format_RGBA8888);
    const QImage src = img.copy();
    const int W = src.width();
    const int H = src.height();

    for (int y = 1; y < H - 1; ++y) {
        uchar       *dst = img.scanLine(y);
        const uchar *s0  = src.constScanLine(y - 1);
        const uchar *s1  = src.constScanLine(y);
        const uchar *s2  = src.constScanLine(y + 1);
        for (int x = 1; x < W - 1; ++x) {
            for (int c = 0; c < 3; ++c) {
                // Laplacian-of-Gaussian approximation (8-neighbour)
                int center = s1[x*4+c];
                int lap = center * 8
                    - s0[(x-1)*4+c] - s0[x*4+c] - s0[(x+1)*4+c]
                    -  s1[(x-1)*4+c]             -  s1[(x+1)*4+c]
                    - s2[(x-1)*4+c] - s2[x*4+c] - s2[(x+1)*4+c];
                int v = center + static_cast<int>(strength * lap * 0.18f);
                dst[x*4+c] = static_cast<uchar>(std::clamp(v, 0, 255));
            }
        }
    }
    return img;
}

// ─── applyEdits (public, used by provider + save path) ───────────────────────

QImage applyEdits(const QImage &src, const EditParams &p, const QSize &targetSize)
{
    if (src.isNull()) return {};

    // Scale down for preview speed
    QImage img = src;
    if (!targetSize.isEmpty() &&
        (src.width() > targetSize.width() || src.height() > targetSize.height())) {
        img = src.scaled(targetSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    // Geometric transforms
    if (p.rotation != 0) {
        QTransform t;
        t.rotate(p.rotation);
        img = img.transformed(t, Qt::SmoothTransformation);
    }
    if (p.flipH) {
        img = img.mirrored(true, false);
    }

    // Skip colour pass if all params are zero
    bool anyColour = (p.brightness != 0.f || p.contrast   != 0.f ||
                      p.saturation != 0.f || p.warmth     != 0.f ||
                      p.highlights != 0.f || p.shadows    != 0.f ||
                      p.blacks     != 0.f);
    if (anyColour) {
        img = applyColorAdjustments(std::move(img), p);
    }
    if (p.sharpness > 0.01f) {
        img = applySharpen(std::move(img), p.sharpness);
    }
    return img;
}

// ─── Thread-local DB helper ───────────────────────────────────────────────────

static QString loadFilePathFromDb(const QString &dbPath, qint64 photoId)
{
    const QString connName = QStringLiteral("editor_") +
        QString::number(reinterpret_cast<quintptr>(QThread::currentThread()), 16);

    if (!QSqlDatabase::contains(connName)) {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        if (!db.open()) return {};
    }

    QSqlDatabase db = QSqlDatabase::database(connName, false);
    if (!db.isOpen()) return {};

    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT file_path FROM photos WHERE id = ?"));
    q.addBindValue(photoId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return {};
}

// ─── PhotoEditorResponse ─────────────────────────────────────────────────────

PhotoEditorResponse::PhotoEditorResponse(qint64 photoId, const EditParams &params,
                                         const QString &dbPath,
                                         const QSize &requestedSize)
    : m_photoId(photoId)
    , m_params(params)
    , m_dbPath(dbPath)
    , m_requestedSize(requestedSize)
{
    setAutoDelete(false);
}

void PhotoEditorResponse::cancel()
{
    m_cancelled.store(true, std::memory_order_relaxed);
}

void PhotoEditorResponse::run()
{
    if (!m_cancelled.load(std::memory_order_relaxed)) {
        const QString fp = loadFilePathFromDb(m_dbPath, m_photoId);
        if (!fp.isEmpty()) {
            QImage src;
            if (src.load(fp)) {
                // For preview cap the long edge at 1800 px for speed.
                QSize previewSize = m_requestedSize;
                if (previewSize.isEmpty()) {
                    int maxEdge = 1800;
                    if (src.width() > maxEdge || src.height() > maxEdge)
                        previewSize = QSize(maxEdge, maxEdge);
                }
                QImage result = applyEdits(src, m_params, previewSize);
                if (!result.isNull()) {
                    QMutexLocker lk(&m_mutex);
                    m_image = std::move(result);
                }
            }
        }
    }
    emit finished();
}

QQuickTextureFactory *PhotoEditorResponse::textureFactory() const
{
    QMutexLocker lk(&m_mutex);
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

// ─── PhotoEditorProvider ─────────────────────────────────────────────────────

PhotoEditorProvider::PhotoEditorProvider(const QString &dbPath)
    : m_dbPath(dbPath)
{
    m_pool.setMaxThreadCount(2);
    m_pool.setExpiryTimeout(-1);
}

QQuickImageResponse *PhotoEditorProvider::requestImageResponse(
    const QString &id, const QSize &requestedSize)
{
    // id  =  "<photoId>_v<version>?b=…&c=…&…"
    const int qmark   = id.indexOf(QLatin1Char('?'));
    const QString idPart    = qmark >= 0 ? id.left(qmark)    : id;
    const QString queryPart = qmark >= 0 ? id.mid(qmark + 1) : QString();

    // Extract numeric photoId (everything before the first '_')
    const int uscore  = idPart.indexOf(QLatin1Char('_'));
    const qint64 photoId = (uscore >= 0 ? idPart.left(uscore) : idPart).toLongLong();

    const EditParams params = EditParams::fromQuery(queryPart);
    auto *response = new PhotoEditorResponse(photoId, params, m_dbPath, requestedSize);
    m_pool.start(response);
    return response;
}

// ─── PhotoEditor (save path) ──────────────────────────────────────────────────

PhotoEditor::PhotoEditor(const QString &dbPath, QObject *parent)
    : QObject(parent)
    , m_dbPath(dbPath)
{
}

void PhotoEditor::saveEdits(int photoId, const QVariantMap &params)
{
    const QString dbPath  = m_dbPath;
    const EditParams ep   = EditParams::fromMap(params);
    const int pid         = photoId;

    // Run in a background thread; emit signal on the GUI thread when done.
    QtConcurrent::run([this, pid, ep, dbPath]() {
        // ── 1. Load file path ────────────────────────────────────────────────
        const QString connName = QStringLiteral("editor_save_") +
            QString::number(reinterpret_cast<quintptr>(QThread::currentThread()), 16);
        if (!QSqlDatabase::contains(connName)) {
            QSqlDatabase db2 = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
            db2.setDatabaseName(dbPath);
            if (!db2.open()) {
                emit editFailed(pid, QStringLiteral("DB öffnen fehlgeschlagen"));
                return;
            }
        }
        QSqlDatabase db = QSqlDatabase::database(connName, false);

        QString filePath;
        {
            QSqlQuery q(db);
            q.prepare(QStringLiteral("SELECT file_path FROM photos WHERE id = ?"));
            q.addBindValue(pid);
            if (!q.exec() || !q.next()) {
                emit editFailed(pid, QStringLiteral("Foto nicht gefunden"));
                return;
            }
            filePath = q.value(0).toString();
        }

        // ── 2. Load full-resolution image ────────────────────────────────────
        QImage src;
        if (!src.load(filePath)) {
            emit editFailed(pid, QStringLiteral("Bild konnte nicht geladen werden"));
            return;
        }

        // ── 3. Apply edits at full resolution ────────────────────────────────
        QImage result = applyEdits(src, ep, QSize());
        if (result.isNull()) {
            emit editFailed(pid, QStringLiteral("Bildbearbeitung fehlgeschlagen"));
            return;
        }

        // ── 4. Save back to disk (keep original format for JPEG; PNG otherwise)
        const QString lower = filePath.toLower();
        int  quality = -1;
        const char *fmt = nullptr;
        if (lower.endsWith(QLatin1String(".jpg")) ||
            lower.endsWith(QLatin1String(".jpeg"))) {
            fmt = "JPEG"; quality = 95;
        } else if (lower.endsWith(QLatin1String(".png"))) {
            fmt = "PNG";
        } else if (lower.endsWith(QLatin1String(".webp"))) {
            fmt = "WEBP"; quality = 92;
        } else {
            // Default: save as JPEG
            fmt = "JPEG"; quality = 95;
        }
        if (!result.save(filePath, fmt, quality)) {
            emit editFailed(pid, QStringLiteral("Datei konnte nicht gespeichert werden"));
            return;
        }

        // ── 5. Re-generate thumbnail (max 512×512) and store in DB ────────────
        QImage thumb = result.scaled(512, 512, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        QByteArray thumbData;
        {
            QBuffer buf(&thumbData);
            buf.open(QIODevice::WriteOnly);
            thumb.save(&buf, "JPEG", 80);
        }

        {
            QSqlQuery q(db);
            q.prepare(QStringLiteral(
                "UPDATE photos SET thumbnail = ?, date_modified = datetime('now') WHERE id = ?"));
            q.addBindValue(thumbData);
            q.addBindValue(pid);
            q.exec();
        }

        emit editsSaved(pid);
    });
}
