#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QVector>
#include "PhotoDatabase.h"

class TagModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY tagsChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ColorRole,
        IconRole,
        PhotoCountRole,
        ParentIdRole,
        DepthRole
    };

    explicit TagModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setDatabase(PhotoDatabase *db);
    int count() const { return m_tags.size(); }

    Q_INVOKABLE void reload();
    Q_INVOKABLE qint64 createTag(const QString &name, const QString &color, const QString &icon, qint64 parentId = -1);
    Q_INVOKABLE bool updateTag(qint64 tagId, const QString &name, const QString &color, const QString &icon, qint64 parentId = -1);
    Q_INVOKABLE bool deleteTag(qint64 tagId);

    // Photo-tag association
    Q_INVOKABLE QVariantList tagsForPhoto(qint64 photoId) const;
    Q_INVOKABLE bool addTagToPhoto(qint64 photoId, qint64 tagId);
    Q_INVOKABLE bool removeTagFromPhoto(qint64 photoId, qint64 tagId);

    // Get all photo IDs for a tag (for bulk operations like sending)
    Q_INVOKABLE QVariantList photoIdsForTag(qint64 tagId) const;

    // Persist the custom sort order for a tag's photos
    Q_INVOKABLE bool saveTagPhotoOrder(qint64 tagId, const QVariantList &photoIds);

    // Lookup helpers for QML
    Q_INVOKABLE QString tagName(qint64 tagId) const;
    Q_INVOKABLE QString tagColor(qint64 tagId) const;
    Q_INVOKABLE QString tagIcon(qint64 tagId) const;
    Q_INVOKABLE qint64 tagParentId(qint64 tagId) const;

    // Returns all tags as a flat JS-friendly list [{id, name, color, icon, depth}, ...]
    Q_INVOKABLE QVariantList allTagsFlat() const;

signals:
    void tagsChanged();

private:
    void rebuildIndex();

    PhotoDatabase *m_db = nullptr;
    QVector<TagRecord> m_tags;
    QHash<qint64, int> m_tagIndex;  // tagId -> index in m_tags for O(1) lookup
};
