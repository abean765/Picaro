#pragma once

#include <QAbstractListModel>
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
        PhotoCountRole
    };

    explicit TagModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setDatabase(PhotoDatabase *db);
    int count() const { return m_tags.size(); }

    Q_INVOKABLE void reload();
    Q_INVOKABLE qint64 createTag(const QString &name, const QString &color, const QString &icon);
    Q_INVOKABLE bool updateTag(qint64 tagId, const QString &name, const QString &color, const QString &icon);
    Q_INVOKABLE bool deleteTag(qint64 tagId);

    // Photo-tag association
    Q_INVOKABLE QVariantList tagsForPhoto(qint64 photoId) const;
    Q_INVOKABLE bool addTagToPhoto(qint64 photoId, qint64 tagId);
    Q_INVOKABLE bool removeTagFromPhoto(qint64 photoId, qint64 tagId);

    // Get all photo IDs for a tag (for bulk operations like sending)
    Q_INVOKABLE QVariantList photoIdsForTag(qint64 tagId) const;

    // Lookup helpers for QML
    Q_INVOKABLE QString tagName(qint64 tagId) const;
    Q_INVOKABLE QString tagColor(qint64 tagId) const;
    Q_INVOKABLE QString tagIcon(qint64 tagId) const;

signals:
    void tagsChanged();

private:
    PhotoDatabase *m_db = nullptr;
    QVector<TagRecord> m_tags;
};
