#include "PhotoModel.h"
#include <QLocale>
#include <QVariantList>
#include <QVariantMap>
#include <QDebug>
#include <QElapsedTimer>

PhotoModel::PhotoModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PhotoModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_rows.size();
}

QVariant PhotoModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};

    const auto &row = m_rows[index.row()];

    switch (role) {
    case RowTypeRole:
        return row.type == GridRow::MonthHeader
            ? QStringLiteral("header")
            : QStringLiteral("photos");

    case HeaderTextRole:
        return row.headerText;

    case CellsRole: {
        QVariantList list;
        list.reserve(row.cells.size());
        for (const auto &cell : row.cells) {
            QVariantMap m;
            m[QStringLiteral("id")] = cell.id;
            m[QStringLiteral("mediaType")] = static_cast<int>(cell.mediaType);
            m[QStringLiteral("filePath")] = cell.filePath;
            // Look up liveVideoPath from the full record
            auto it = m_idToPhotoIndex.constFind(cell.id);
            if (it != m_idToPhotoIndex.constEnd()) {
                m[QStringLiteral("liveVideoPath")] = m_allPhotos[it.value()].liveVideoPath;
            }
            list.append(m);
        }
        return list;
    }

    case CellCountRole:
        return row.cells.size();

    default:
        return {};
    }
}

QHash<int, QByteArray> PhotoModel::roleNames() const
{
    return {
        { RowTypeRole,    "rowType" },
        { HeaderTextRole, "headerText" },
        { CellsRole,      "cells" },
        { CellCountRole,  "cellCount" }
    };
}

void PhotoModel::loadFromDatabase(PhotoDatabase *db)
{
    m_db = db;

    QElapsedTimer timer;
    timer.start();

    m_allPhotos = db->loadAllRecords();
    m_totalPhotos = m_allPhotos.size();

    // Build id->index lookup
    m_idToPhotoIndex.clear();
    m_idToPhotoIndex.reserve(m_allPhotos.size());
    for (int i = 0; i < m_allPhotos.size(); ++i) {
        m_idToPhotoIndex[m_allPhotos[i].id] = i;
    }

    qDebug() << "Loaded" << m_totalPhotos << "records in" << timer.elapsed() << "ms";

    rebuildGrid();
    buildTimelineData();
    emit modelReloaded();
}

void PhotoModel::reload()
{
    if (m_db) {
        loadFromDatabase(m_db);
    }
}

void PhotoModel::setPhotosPerRow(int n)
{
    if (n == m_photosPerRow || n < 1) return;
    m_photosPerRow = n;
    emit photosPerRowChanged();
    rebuildGrid();
}

void PhotoModel::rebuildGrid()
{
    QElapsedTimer timer;
    timer.start();

    beginResetModel();
    m_rows.clear();

    if (m_allPhotos.isEmpty()) {
        endResetModel();
        return;
    }

    // Estimate row count: photos/perRow + number of months
    m_rows.reserve(m_allPhotos.size() / m_photosPerRow + 100);

    QString currentMonth;
    QVector<PhotoCell> pendingCells;
    pendingCells.reserve(m_photosPerRow);

    auto flushPending = [&]() {
        if (!pendingCells.isEmpty()) {
            GridRow row;
            row.type = GridRow::PhotoRow;
            row.cells = std::move(pendingCells);
            m_rows.append(std::move(row));
            pendingCells.clear();
            pendingCells.reserve(m_photosPerRow);
        }
    };

    QLocale locale(QStringLiteral("de_DE"));

    for (const auto &photo : m_allPhotos) {
        const QString &monthKey = photo.monthKey;

        // New month → flush current row, insert header
        if (monthKey != currentMonth) {
            flushPending();
            currentMonth = monthKey;

            GridRow header;
            header.type = GridRow::MonthHeader;

            // Format "2024-01" → "Januar 2024"
            if (monthKey.length() >= 7) {
                int year = monthKey.left(4).toInt();
                int month = monthKey.mid(5, 2).toInt();
                QDate d(year, month, 1);
                header.headerText = locale.toString(d, QStringLiteral("MMMM yyyy"));
            } else {
                header.headerText = monthKey;
            }

            m_rows.append(std::move(header));
        }

        PhotoCell cell;
        cell.id = photo.id;
        cell.mediaType = photo.mediaType;
        cell.filePath = photo.filePath;
        pendingCells.append(std::move(cell));

        if (pendingCells.size() >= m_photosPerRow) {
            flushPending();
        }
    }

    flushPending();
    endResetModel();

    qDebug() << "Grid built:" << m_rows.size() << "rows in" << timer.elapsed() << "ms";
}

QString PhotoModel::filePathForId(qint64 id) const
{
    auto it = m_idToPhotoIndex.constFind(id);
    if (it != m_idToPhotoIndex.constEnd()) {
        return m_allPhotos[it.value()].filePath;
    }
    return {};
}

int PhotoModel::mediaTypeForId(qint64 id) const
{
    auto it = m_idToPhotoIndex.constFind(id);
    if (it != m_idToPhotoIndex.constEnd()) {
        return static_cast<int>(m_allPhotos[it.value()].mediaType);
    }
    return 0;
}

QString PhotoModel::liveVideoPathForId(qint64 id) const
{
    auto it = m_idToPhotoIndex.constFind(id);
    if (it != m_idToPhotoIndex.constEnd()) {
        return m_allPhotos[it.value()].liveVideoPath;
    }
    return {};
}

void PhotoModel::buildTimelineData()
{
    m_timelineData.clear();
    m_headerRowIndices.clear();
    m_timelineMaxCount = 1;

    QLocale locale(QStringLiteral("de_DE"));

    for (int i = 0; i < m_rows.size(); ++i) {
        const auto &row = m_rows[i];
        if (row.type != GridRow::MonthHeader) continue;

        // Count photos in this month (sum cells in subsequent PhotoRows until next header)
        int count = 0;
        for (int j = i + 1; j < m_rows.size() && m_rows[j].type == GridRow::PhotoRow; ++j) {
            count += m_rows[j].cells.size();
        }

        // Parse monthKey from headerText back, or find it from context
        // We can extract year/month from the header row's photos
        QString monthKey;
        QString shortMonth;
        int year = 0;

        // Find monthKey from the first photo after this header
        for (int j = i + 1; j < m_rows.size() && m_rows[j].type == GridRow::PhotoRow; ++j) {
            if (!m_rows[j].cells.isEmpty()) {
                auto it = m_idToPhotoIndex.constFind(m_rows[j].cells[0].id);
                if (it != m_idToPhotoIndex.constEnd()) {
                    monthKey = m_allPhotos[it.value()].monthKey;
                    if (monthKey.length() >= 7) {
                        year = monthKey.left(4).toInt();
                        int month = monthKey.mid(5, 2).toInt();
                        QDate d(year, month, 1);
                        shortMonth = locale.toString(d, QStringLiteral("MMM"));
                    }
                }
                break;
            }
        }

        QVariantMap entry;
        entry[QStringLiteral("monthKey")] = monthKey;
        entry[QStringLiteral("label")] = shortMonth;
        entry[QStringLiteral("fullLabel")] = row.headerText;
        entry[QStringLiteral("year")] = year;
        entry[QStringLiteral("count")] = count;
        entry[QStringLiteral("rowIndex")] = i;

        m_timelineData.append(entry);
        m_headerRowIndices.append(i);

        if (count > m_timelineMaxCount)
            m_timelineMaxCount = count;
    }
}

int PhotoModel::headerRowIndex(int timelineIndex) const
{
    if (timelineIndex < 0 || timelineIndex >= m_headerRowIndices.size())
        return 0;
    return m_headerRowIndices[timelineIndex];
}
