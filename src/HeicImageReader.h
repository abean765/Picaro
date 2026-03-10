#pragma once

#include <QByteArray>
#include <QImage>
#include <QString>

// Reads HEIC/HEIF images using libheif and returns a QImage.
// Also extracts embedded thumbnails for fast thumbnail generation.

namespace HeicImageReader {

// Decode a full HEIC image
QImage readHeicImage(const QString &filePath);

// Extract the embedded thumbnail (much faster than full decode)
QImage readHeicThumbnail(const QString &filePath);

// Single file open: tries embedded thumbnail first, falls back to
// full decode + scale. Most efficient for thumbnail generation.
QImage readHeicThumbnailOrScaled(const QString &filePath, int maxSize);

// Check if libheif can handle this file
bool isHeicFile(const QString &filePath);

// Extract raw TIFF-format EXIF bytes from a HEIC/HEIF container via libheif.
// The returned bytes are suitable for Exiv2::ExifParser::decode().
// Returns an empty QByteArray if no EXIF metadata is present or libheif is unavailable.
QByteArray readHeicExifBytes(const QString &filePath);

}
