#pragma once

#include <QImage>
#include <QString>

// Optional GPU-accelerated HEIC/HEVC thumbnail decoder.
// Uses FFmpeg with hardware acceleration (NVDEC, VAAPI, VideoToolbox)
// to decode HEIC images and scale thumbnails on the GPU.
//
// Falls back gracefully if no GPU or FFmpeg is available.
// Compile with HAVE_FFMPEG_HW to enable.

namespace GpuHeicDecoder {

// Try to decode a HEIC file using GPU-accelerated HEVC decoding
// and scale to maxSize on the GPU. Returns null QImage if unavailable.
QImage decodeThumbnail(const QString &filePath, int maxSize);

// Check if GPU decoding is available on this system
bool isAvailable();

}
