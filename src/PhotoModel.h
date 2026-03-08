#pragma once

#include <QAbstractListModel>
#include <QVariantList>
#include <QVector>
#include <QString>
#include "PhotoDatabase.h"

// The model provides a flat list of "rows" for a ListView.
// Each row is either a MonthHeader or a PhotoRow (containing up to N photo IDs).
// This drastically reduces delegate count: 100k photos / 5 per row = 20k rows.

struct PhotoCell {
    qint64 id = 0;
    MediaType mediaType = MediaType::Photo;
    QString filePath;
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
    QVariantList timelineData() const { return m_timelineData; }
    int timelineMaxCount() const { return m_timelineMaxCount; }

    Q_INVOKABLE int headerRowIndex(int timelineIndex) const;

    Q_INVOKABLE QString filePathForId(qint64 id) const;
    Q_INVOKABLE int mediaTypeForId(qint64 id) const;
    Q_INVOKABLE QString liveVideoPathForId(qint64 id) const;
    Q_INVOKABLE qint64 nextPhotoId(qint64 currentId) const;
    Q_INVOKABLE qint64 previousPhotoId(qint64 currentId) const;

signals:
    void photosPerRowChanged();
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

    QVariantList m_timelineData;
    QVector<int> m_headerRowIndices;    // row index for each timeline entry
    int m_timelineMaxCount = 1;
};
