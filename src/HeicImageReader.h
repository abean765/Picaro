#pragma once

#include <QImage>
#include <QString>

// Reads HEIC/HEIF images using libheif and returns a QImage.
// Also extracts embedded thumbnails for fast thumbnail generation.

namespace HeicImageReader {

// Decode a full HEIC image
QImage readHeicImage(const QString &filePath);

// Extract the embedded thumbnail (much faster than full decode)
QImage readHeicThumbnail(const QString &filePath);

// Check if libheif can handle this file
bool isHeicFile(const QString &filePath);

}
