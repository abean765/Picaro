#pragma once

#include <QAbstractListModel>
#include <QVariantList>
#include <QVector>
#include <QString>
#include <QSet>
#include "PhotoDatabase.h"

// The model provides a flat list of "rows" for a ListView.
// Each row is either a MonthHeader or a PhotoRow (containing up to N photo IDs).
// This drastically reduces delegate count: 100k photos / 5 per row = 20k rows.

struct PhotoCell {
    qint64 id = 0;
    MediaType mediaType = MediaType::Photo;
    QString filePath;
    QString liveVideoPath;
};

struct GridRow {
    enum Type { MonthHeader, PhotoRow };

    Type type = PhotoRow;
    QString headerText;          // e.g. "Januar 2024" for headers
    QVector<PhotoCell> cells;    // photo cells for PhotoRow type
};

class PhotoModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int photosPerRow READ photosPerRow WRITE setPhotosPerRow NOTIFY photosPerRowChanged)
    Q_PROPERTY(int totalPhotos READ totalPhotos NOTIFY modelReloaded)
    Q_PROPERTY(QVariantList timelineData READ timelineData NOTIFY modelReloaded)
    Q_PROPERTY(int timelineMaxCount READ timelineMaxCount NOTIFY modelReloaded)
    Q_PROPERTY(int mediaTypeFilter READ mediaTypeFilter WRITE setMediaTypeFilter NOTIFY mediaTypeFilterChanged)
    Q_PROPERTY(bool showDeleted READ showDeleted WRITE setShowDeleted NOTIFY showDeletedChanged)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(QStringList filterSuggestions READ filterSuggestions NOTIFY filterSuggestionsChanged)

public:
    enum Roles {
        RowTypeRole = Qt::UserRole + 1,
        HeaderTextRole,
        CellsRole,        // QVariantList of cell data
        CellCountRole
    };

    explicit PhotoModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void loadFromDatabase(PhotoDatabase *db);
    Q_INVOKABLE void reload();

    int photosPerRow() const { return m_photosPerRow; }
    void setPhotosPerRow(int n);
    int totalPhotos() const { return m_totalPhotos; }
    int mediaTypeFilter() const { return m_mediaTypeFilter; }
    void setMediaTypeFilter(int filter);
    bool showDeleted() const { return m_showDeleted; }
    void setShowDeleted(bool show);
    QString filterText() const { return m_filterText; }
    void setFilterText(const QString &text);
    QStringList filterSuggestions() const { return m_filterSuggestions; }
    Q_INVOKABLE void updateSuggestions(const QString &input);
    Q_INVOKABLE void clearFilter();
    QVariantList timelineData() const { return m_timelineData; }
    int timelineMaxCount() const { return m_timelineMaxCount; }

    Q_INVOKABLE int headerRowIndex(int timelineIndex) const;
    Q_INVOKABLE int timelineIndexForPhotoId(qint64 id) const;

    Q_INVOKABLE QString filePathForId(qint64 id) const;
    Q_INVOKABLE QString monthKeyForId(qint64 id) const;
    Q_INVOKABLE int mediaTypeForId(qint64 id) const;
    Q_INVOKABLE QString liveVideoPathForId(qint64 id) const;
    Q_INVOKABLE QString resolutionForId(qint64 id) const;
    Q_INVOKABLE qint64 nextPhotoId(qint64 currentId) const;
    Q_INVOKABLE qint64 previousPhotoId(qint64 currentId) const;
    Q_INVOKABLE void deletePhoto(qint64 id);
    Q_INVOKABLE void restorePhoto(qint64 id);
    Q_INVOKABLE int ratingForId(qint64 id) const;
    Q_INVOKABLE void setRating(qint64 id, int rating);
    Q_INVOKABLE QVariantList visiblePhotoIds() const;
    Q_INVOKABLE int rowIndexForPhotoId(qint64 id) const;
    Q_INVOKABLE QVariantMap coordinatesForId(qint64 id) const;
    Q_INVOKABLE QVariantList allGeolocatedPhotos() const;

    // Returns all available metadata for a single photo (DB fields + live EXIF).
    Q_INVOKABLE QVariantMap fullMetadataForId(qint64 id) const;

    // Re-reads EXIF from the file, updates m_allPhotos and the DB.
    // Call this before fullMetadataForId when the data might be stale.
    Q_INVOKABLE void refreshExifForId(qint64 id);

signals:
    void photosPerRowChanged();
    void mediaTypeFilterChanged();
    void showDeletedChanged();
    void filterTextChanged();
    void filterSuggestionsChanged();
    void modelReloaded();

private:
    void rebuildGrid();
    void buildTimelineData();

    QVector<PhotoRecord> m_allPhotos;   // flat, sorted by date desc
    QVector<GridRow> m_rows;            // computed grid rows
    QHash<qint64, int> m_idToPhotoIndex; // id -> index in m_allPhotos
    PhotoDatabase *m_db = nullptr;
    int m_photosPerRow = 5;
    int m_totalPhotos = 0;
    int m_mediaTypeFilter = -1;  // -1 = all, 0 = photos only, 1 = videos only
    bool m_showDeleted = false;
    QString m_filterText;
    QSet<qint64> m_filterPhotoIds;  // photo IDs matching the current tag/owner filter
    bool m_filterActive = false;
    QStringList m_filterSuggestions;

    QVariantList m_timelineData;
    QVector<int> m_headerRowIndices;    // row index for each timeline entry
    QHash<QString, int> m_monthKeyToTimelineIndex; // monthKey -> timeline index (O(1) lookup)
    int m_timelineMaxCount = 1;

    // Cached tag list to avoid repeated DB queries during filter/suggestions
    QVector<TagRecord> m_cachedTags;
    bool m_tagsCacheDirty = true;
    void ensureTagsCache();
};
