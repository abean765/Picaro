#include "PhotoModel.h"
#include <QLocale>
#include <QVariantList>
#include <QVariantMap>
#include <QDebug>
#include <QSqlQuery>
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
            m[QStringLiteral("liveVideoPath")] = cell.liveVideoPath;
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

    m_allPhotos = m_showDeleted ? db->loadDeletedRecords() : db->loadAllRecords();

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
        m_tagsCacheDirty = true;
        loadFromDatabase(m_db);
    }
}

void PhotoModel::setPhotosPerRow(int n)
{
    if (n == m_photosPerRow || n < 1) return;
    m_photosPerRow = n;
    emit photosPerRowChanged();
    rebuildGrid();
    buildTimelineData();
    emit modelReloaded();
}

void PhotoModel::setMediaTypeFilter(int filter)
{
    if (filter == m_mediaTypeFilter) return;
    m_mediaTypeFilter = filter;
    emit mediaTypeFilterChanged();
    rebuildGrid();
    buildTimelineData();
    emit modelReloaded();
}

void PhotoModel::setShowDeleted(bool show)
{
    if (show == m_showDeleted) return;
    m_showDeleted = show;
    emit showDeletedChanged();
    if (m_db) {
        loadFromDatabase(m_db);
    }
}

void PhotoModel::setFilterText(const QString &text)
{
    if (text == m_filterText) return;
    m_filterText = text;
    emit filterTextChanged();

    // Build the set of matching photo IDs
    m_filterPhotoIds.clear();
    m_filterActive = !text.isEmpty();

    if (m_filterActive && m_db) {
        QString lower = text.toLower();

        // Match by tag name: find tags whose name matches, then get their photo IDs
        ensureTagsCache();
        for (const auto &tag : m_cachedTags) {
            if (tag.name.toLower() == lower) {
                auto ids = m_db->photoIdsForTag(tag.id);
                for (qint64 id : ids) {
                    m_filterPhotoIds.insert(id);
                }
            }
        }

        // Match by owner: find photos whose owner matches
        for (const auto &photo : m_allPhotos) {
            if (!photo.owner.isEmpty() && photo.owner.toLower() == lower) {
                m_filterPhotoIds.insert(photo.id);
            }
        }
    }

    rebuildGrid();
    buildTimelineData();
    emit modelReloaded();
}

void PhotoModel::updateSuggestions(const QString &input)
{
    m_filterSuggestions.clear();

    if (input.isEmpty() || !m_db) {
        emit filterSuggestionsChanged();
        return;
    }

    QString lower = input.toLower();

    // Collect tag names
    ensureTagsCache();
    for (const auto &tag : m_cachedTags) {
        if (tag.name.toLower().startsWith(lower) || tag.name.toLower().contains(lower)) {
            QString entry = QStringLiteral("Tag: ") + tag.name;
            if (!m_filterSuggestions.contains(entry))
                m_filterSuggestions.append(entry);
        }
    }

    // Collect unique owners
    QSet<QString> seenOwners;
    for (const auto &photo : m_allPhotos) {
        if (!photo.owner.isEmpty() && !seenOwners.contains(photo.owner)) {
            seenOwners.insert(photo.owner);
            if (photo.owner.toLower().startsWith(lower) || photo.owner.toLower().contains(lower)) {
                QString entry = QStringLiteral("Sender: ") + photo.owner;
                if (!m_filterSuggestions.contains(entry))
                    m_filterSuggestions.append(entry);
            }
        }
    }

    emit filterSuggestionsChanged();
}

void PhotoModel::clearFilter()
{
    setFilterText(QString());
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

    int filteredCount = 0;

    for (const auto &photo : m_allPhotos) {
        // Apply media type filter
        if (m_mediaTypeFilter >= 0 && static_cast<int>(photo.mediaType) != m_mediaTypeFilter)
            continue;

        // Apply text filter (tag/owner)
        if (m_filterActive && !m_filterPhotoIds.contains(photo.id))
            continue;

        ++filteredCount;
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
        cell.liveVideoPath = photo.liveVideoPath;
        pendingCells.append(std::move(cell));

        if (pendingCells.size() >= m_photosPerRow) {
            flushPending();
        }
    }

    flushPending();
    m_totalPhotos = filteredCount;
    endResetModel();

    qDebug() << "Grid built:" << m_rows.size() << "rows (" << filteredCount << "photos) in" << timer.elapsed() << "ms";
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

QString PhotoModel::resolutionForId(qint64 id) const
{
    auto it = m_idToPhotoIndex.constFind(id);
    if (it != m_idToPhotoIndex.constEnd()) {
        const auto &rec = m_allPhotos[it.value()];
        if (rec.width > 0 && rec.height > 0)
            return QString::number(rec.width) + QStringLiteral(" × ") + QString::number(rec.height);
    }
    return {};
}

qint64 PhotoModel::nextPhotoId(qint64 currentId) const
{
    auto it = m_idToPhotoIndex.constFind(currentId);
    if (it == m_idToPhotoIndex.constEnd()) return -1;
    for (int idx = it.value() + 1; idx < m_allPhotos.size(); ++idx) {
        const auto &photo = m_allPhotos[idx];
        if (m_mediaTypeFilter >= 0 && static_cast<int>(photo.mediaType) != m_mediaTypeFilter)
            continue;
        if (m_filterActive && !m_filterPhotoIds.contains(photo.id))
            continue;
        return photo.id;
    }
    return -1;
}

qint64 PhotoModel::previousPhotoId(qint64 currentId) const
{
    auto it = m_idToPhotoIndex.constFind(currentId);
    if (it == m_idToPhotoIndex.constEnd()) return -1;
    for (int idx = it.value() - 1; idx >= 0; --idx) {
        const auto &photo = m_allPhotos[idx];
        if (m_mediaTypeFilter >= 0 && static_cast<int>(photo.mediaType) != m_mediaTypeFilter)
            continue;
        if (m_filterActive && !m_filterPhotoIds.contains(photo.id))
            continue;
        return photo.id;
    }
    return -1;
}

void PhotoModel::deletePhoto(qint64 id)
{
    if (!m_db) return;
    if (!m_db->markDeleted(id)) return;

    auto it = m_idToPhotoIndex.constFind(id);
    if (it != m_idToPhotoIndex.constEnd()) {
        int idx = it.value();
        m_allPhotos.removeAt(idx);
        m_idToPhotoIndex.remove(id);

        // Update only shifted indices (those after the removed element)
        for (auto jt = m_idToPhotoIndex.begin(); jt != m_idToPhotoIndex.end(); ++jt) {
            if (jt.value() > idx)
                jt.value()--;
        }

        rebuildGrid();
        buildTimelineData();
        emit modelReloaded();
    }
}

void PhotoModel::restorePhoto(qint64 id)
{
    if (!m_db) return;
    if (!m_db->markDeleted(id, false)) return;

    auto it = m_idToPhotoIndex.constFind(id);
    if (it != m_idToPhotoIndex.constEnd()) {
        int idx = it.value();
        m_allPhotos.removeAt(idx);
        m_idToPhotoIndex.remove(id);

        for (auto jt = m_idToPhotoIndex.begin(); jt != m_idToPhotoIndex.end(); ++jt) {
            if (jt.value() > idx)
                jt.value()--;
        }

        rebuildGrid();
        buildTimelineData();
        emit modelReloaded();
    }
}

int PhotoModel::ratingForId(qint64 id) const
{
    if (!m_db) return 0;
    return m_db->getRating(id);
}

void PhotoModel::setRating(qint64 id, int rating)
{
    if (!m_db) return;
    m_db->setRating(id, rating);
}

void PhotoModel::ensureTagsCache()
{
    if (!m_tagsCacheDirty || !m_db) return;
    m_cachedTags = m_db->loadAllTags();
    m_tagsCacheDirty = false;
}

QVariantList PhotoModel::visiblePhotoIds() const
{
    QVariantList ids;
    for (const auto &row : m_rows) {
        if (row.type == GridRow::PhotoRow) {
            for (const auto &cell : row.cells) {
                if (cell.id > 0)
                    ids.append(cell.id);
            }
        }
    }
    return ids;
}

void PhotoModel::buildTimelineData()
{
    m_timelineData.clear();
    m_headerRowIndices.clear();
    m_monthKeyToTimelineIndex.clear();
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
        if (!monthKey.isEmpty())
            m_monthKeyToTimelineIndex[monthKey] = m_timelineData.size() - 1;

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

int PhotoModel::timelineIndexForPhotoId(qint64 id) const
{
    auto it = m_idToPhotoIndex.constFind(id);
    if (it == m_idToPhotoIndex.constEnd()) return -1;

    const QString &monthKey = m_allPhotos[it.value()].monthKey;
    return m_monthKeyToTimelineIndex.value(monthKey, -1);
}
