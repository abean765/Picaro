#include "HeicImageReader.h"
#include "GpuHeicDecoder.h"
#include <QFileInfo>
#include <QDebug>
#include <vector>

#ifdef HAVE_LIBHEIF
#include <libheif/heif.h>
#endif

namespace HeicImageReader {

#ifdef HAVE_LIBHEIF

static QImage decodeHandle(heif_image_handle *handle)
{
    heif_image *img = nullptr;
    heif_error err = heif_decode_image(handle, &img,
                                        heif_colorspace_RGB,
                                        heif_chroma_interleaved_RGBA,
                                        nullptr);
    if (err.code != heif_error_Ok) {
        qWarning() << "HEIC decode error:" << err.message;
        return {};
    }

    int stride = 0;
    const uint8_t *data = heif_image_get_plane_readonly(img, heif_channel_interleaved, &stride);
    int w = heif_image_get_width(img, heif_channel_interleaved);
    int h = heif_image_get_height(img, heif_channel_interleaved);

    QImage result(w, h, QImage::Format_RGBA8888);
    for (int y = 0; y < h; ++y) {
        memcpy(result.scanLine(y), data + y * stride, w * 4);
    }

    heif_image_release(img);
    return result;
}

QImage readHeicImage(const QString &filePath)
{
    heif_context *ctx = heif_context_alloc();
    heif_error err = heif_context_read_from_file(ctx, filePath.toUtf8().constData(), nullptr);
    if (err.code != heif_error_Ok) {
        qWarning() << "HEIC open error:" << err.message;
        heif_context_free(ctx);
        return {};
    }

    heif_image_handle *handle = nullptr;
    err = heif_context_get_primary_image_handle(ctx, &handle);
    if (err.code != heif_error_Ok) {
        heif_context_free(ctx);
        return {};
    }

    QImage result = decodeHandle(handle);
    heif_image_handle_release(handle);
    heif_context_free(ctx);
    return result;
}

QImage readHeicThumbnail(const QString &filePath)
{
    heif_context *ctx = heif_context_alloc();
    heif_error err = heif_context_read_from_file(ctx, filePath.toUtf8().constData(), nullptr);
    if (err.code != heif_error_Ok) {
        heif_context_free(ctx);
        return {};
    }

    heif_image_handle *handle = nullptr;
    err = heif_context_get_primary_image_handle(ctx, &handle);
    if (err.code != heif_error_Ok) {
        heif_context_free(ctx);
        return {};
    }

    heif_item_id thumbIds[1];
    int nThumbs = heif_image_handle_get_list_of_thumbnail_IDs(handle, thumbIds, 1);

    QImage result;
    if (nThumbs > 0) {
        heif_image_handle *thumbHandle = nullptr;
        err = heif_image_handle_get_thumbnail(handle, thumbIds[0], &thumbHandle);
        if (err.code == heif_error_Ok) {
            result = decodeHandle(thumbHandle);
            heif_image_handle_release(thumbHandle);
        }
    }

    if (result.isNull()) {
        result = decodeHandle(handle);
        if (!result.isNull()) {
            result = result.scaled(320, 320, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }
    }

    heif_image_handle_release(handle);
    heif_context_free(ctx);
    return result;
}

QImage readHeicThumbnailOrScaled(const QString &filePath, int maxSize)
{
    // Try GPU-accelerated decode first (NVDEC / VAAPI / VideoToolbox)
    QImage gpuResult = GpuHeicDecoder::decodeThumbnail(filePath, maxSize);
    if (!gpuResult.isNull())
        return gpuResult;

    // CPU fallback via libheif
    heif_context *ctx = heif_context_alloc();
    heif_error err = heif_context_read_from_file(ctx, filePath.toUtf8().constData(), nullptr);
    if (err.code != heif_error_Ok) {
        qWarning() << "HEIC open error:" << err.message;
        heif_context_free(ctx);
        return {};
    }

    heif_image_handle *handle = nullptr;
    err = heif_context_get_primary_image_handle(ctx, &handle);
    if (err.code != heif_error_Ok) {
        heif_context_free(ctx);
        return {};
    }

    QImage result;

    // Try embedded thumbnail first
    heif_item_id thumbIds[1];
    int nThumbs = heif_image_handle_get_list_of_thumbnail_IDs(handle, thumbIds, 1);
    if (nThumbs > 0) {
        heif_image_handle *thumbHandle = nullptr;
        err = heif_image_handle_get_thumbnail(handle, thumbIds[0], &thumbHandle);
        if (err.code == heif_error_Ok) {
            result = decodeHandle(thumbHandle);
            heif_image_handle_release(thumbHandle);
        }
    }

    // Fallback: decode full image
    if (result.isNull()) {
        result = decodeHandle(handle);
    }

    heif_image_handle_release(handle);
    heif_context_free(ctx);

    // Scale down if needed
    if (!result.isNull() && (result.width() > maxSize || result.height() > maxSize)) {
        result = result.scaled(maxSize, maxSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    }

    return result;
}

QByteArray readHeicExifBytes(const QString &filePath)
{
    heif_context *ctx = heif_context_alloc();
    heif_error err = heif_context_read_from_file(ctx, filePath.toUtf8().constData(), nullptr);
    if (err.code != heif_error_Ok) {
        heif_context_free(ctx);
        return {};
    }

    heif_image_handle *handle = nullptr;
    err = heif_context_get_primary_image_handle(ctx, &handle);
    if (err.code != heif_error_Ok) {
        heif_context_free(ctx);
        return {};
    }

    heif_item_id exifIds[4];
    int nExif = heif_image_handle_get_list_of_metadata_block_IDs(handle, "Exif", exifIds, 4);

    QByteArray result;
    if (nExif > 0) {
        size_t dataSize = heif_image_handle_get_metadata_size(handle, exifIds[0]);
        if (dataSize > 4) {
            std::vector<uint8_t> buf(dataSize);
            err = heif_image_handle_get_metadata(handle, exifIds[0], buf.data());
            if (err.code == heif_error_Ok) {
                // The HEIF spec stores a 4-byte big-endian offset at the start.
                // The actual EXIF data begins at byte (4 + offset). For iPhone
                // photos this offset is almost always 0.
                uint32_t skip = (uint32_t(buf[0]) << 24) | (uint32_t(buf[1]) << 16)
                              | (uint32_t(buf[2]) << 8)  | uint32_t(buf[3]);
                size_t dataStart = 4 + skip;
                if (dataStart < dataSize) {
                    const uint8_t *p = buf.data() + dataStart;
                    size_t remaining = dataSize - dataStart;
                    // Some implementations prepend "Exif\0\0"; strip it so that
                    // only the raw TIFF data (starting with "II" or "MM") remains.
                    if (remaining >= 6 && p[0]=='E' && p[1]=='x' && p[2]=='i'
                            && p[3]=='f' && p[4]=='\0' && p[5]=='\0') {
                        p += 6;
                        remaining -= 6;
                    }
                    result = QByteArray(reinterpret_cast<const char *>(p),
                                        static_cast<int>(remaining));
                }
            }
        }
    }

    heif_image_handle_release(handle);
    heif_context_free(ctx);
    return result;
}

#else // !HAVE_LIBHEIF

QImage readHeicImage(const QString &filePath)
{
    Q_UNUSED(filePath);
    qWarning() << "HEIC support not available (libheif not found)";
    return {};
}

QImage readHeicThumbnail(const QString &filePath)
{
    Q_UNUSED(filePath);
    return {};
}

QImage readHeicThumbnailOrScaled(const QString &filePath, int maxSize)
{
    // Even without libheif, try GPU path (FFmpeg can handle HEIF container)
    return GpuHeicDecoder::decodeThumbnail(filePath, maxSize);
}

QByteArray readHeicExifBytes(const QString &filePath)
{
    Q_UNUSED(filePath);
    return {};
}

#endif // HAVE_LIBHEIF

bool isHeicFile(const QString &filePath)
{
    QString suffix = QFileInfo(filePath).suffix().toLower();
    return suffix == QStringLiteral("heic")
        || suffix == QStringLiteral("heif")
        || suffix == QStringLiteral("hif");
}

}
