#include "TagModel.h"

TagModel::TagModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int TagModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_tags.size();
}

QVariant TagModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_tags.size())
        return {};

    const auto &tag = m_tags[index.row()];
    switch (role) {
    case IdRole:         return tag.id;
    case NameRole:       return tag.name;
    case ColorRole:      return tag.color;
    case IconRole:       return tag.icon;
    case PhotoCountRole: return tag.photoCount;
    case ParentIdRole:   return tag.parentId;
    case DepthRole:      return tag.depth;
    }
    return {};
}

QHash<int, QByteArray> TagModel::roleNames() const
{
    return {
        { IdRole,         "tagId" },
        { NameRole,       "name" },
        { ColorRole,      "tagColor" },
        { IconRole,       "tagIcon" },
        { PhotoCountRole, "photoCount" },
        { ParentIdRole,   "parentId" },
        { DepthRole,      "depth" }
    };
}

void TagModel::setDatabase(PhotoDatabase *db)
{
    m_db = db;
    reload();
}

void TagModel::reload()
{
    if (!m_db) return;
    beginResetModel();
    m_tags = m_db->loadAllTags();
    rebuildIndex();
    endResetModel();
    emit tagsChanged();
}

void TagModel::rebuildIndex()
{
    m_tagIndex.clear();
    m_tagIndex.reserve(m_tags.size());
    for (int i = 0; i < m_tags.size(); ++i) {
        m_tagIndex[m_tags[i].id] = i;
    }
}

qint64 TagModel::createTag(const QString &name, const QString &color, const QString &icon, qint64 parentId)
{
    if (!m_db) return -1;
    qint64 id = m_db->createTag(name, color, icon, parentId);
    if (id > 0) reload();
    return id;
}

bool TagModel::updateTag(qint64 tagId, const QString &name, const QString &color, const QString &icon, qint64 parentId)
{
    if (!m_db) return false;
    bool ok = m_db->updateTag(tagId, name, color, icon, parentId);
    if (ok) reload();
    return ok;
}

bool TagModel::deleteTag(qint64 tagId)
{
    if (!m_db) return false;
    bool ok = m_db->deleteTag(tagId);
    if (ok) reload();
    return ok;
}

QVariantList TagModel::tagsForPhoto(qint64 photoId) const
{
    if (!m_db) return {};
    QVariantList result;
    for (qint64 id : m_db->tagsForPhoto(photoId)) {
        result.append(id);
    }
    return result;
}

bool TagModel::addTagToPhoto(qint64 photoId, qint64 tagId)
{
    if (!m_db) return false;
    bool ok = m_db->addTagToPhoto(photoId, tagId);
    if (ok) reload();
    return ok;
}

bool TagModel::batchAddTagToPhotos(const QVariantList &photoIds, qint64 tagId)
{
    if (!m_db) return false;
    bool ok = true;
    for (const QVariant &v : photoIds)
        ok = m_db->addTagToPhoto(v.toLongLong(), tagId) && ok;
    reload();
    return ok;
}

bool TagModel::removeTagFromPhoto(qint64 photoId, qint64 tagId)
{
    if (!m_db) return false;
    bool ok = m_db->removeTagFromPhoto(photoId, tagId);
    if (ok) reload();
    return ok;
}

bool TagModel::batchRemoveTagFromPhotos(const QVariantList &photoIds, qint64 tagId)
{
    if (!m_db) return false;
    bool ok = true;
    for (const QVariant &v : photoIds)
        ok = m_db->removeTagFromPhoto(v.toLongLong(), tagId) && ok;
    reload();
    return ok;
}

QString TagModel::tagName(qint64 tagId) const
{
    auto it = m_tagIndex.constFind(tagId);
    if (it != m_tagIndex.constEnd()) return m_tags[it.value()].name;
    return {};
}

QString TagModel::tagColor(qint64 tagId) const
{
    auto it = m_tagIndex.constFind(tagId);
    if (it != m_tagIndex.constEnd()) return m_tags[it.value()].color;
    return QStringLiteral("#888888");
}

QString TagModel::tagIcon(qint64 tagId) const
{
    auto it = m_tagIndex.constFind(tagId);
    if (it != m_tagIndex.constEnd()) return m_tags[it.value()].icon;
    return {};
}

qint64 TagModel::tagParentId(qint64 tagId) const
{
    auto it = m_tagIndex.constFind(tagId);
    if (it != m_tagIndex.constEnd()) return m_tags[it.value()].parentId;
    return -1;
}

QVariantList TagModel::allTagsFlat() const
{
    QVariantList result;
    result.reserve(m_tags.size());
    for (const auto &t : m_tags) {
        QVariantMap m;
        m[QStringLiteral("id")]         = t.id;
        m[QStringLiteral("name")]       = t.name;
        m[QStringLiteral("color")]      = t.color;
        m[QStringLiteral("icon")]       = t.icon;
        m[QStringLiteral("depth")]      = t.depth;
        m[QStringLiteral("photoCount")] = t.photoCount;
        result.append(m);
    }
    return result;
}

QVariantList TagModel::photoIdsForTag(qint64 tagId) const
{
    QVariantList result;
    if (!m_db) return result;

    const auto ids = m_db->photoIdsForTag(tagId);
    for (qint64 id : ids) {
        result.append(id);
    }
    return result;
}

bool TagModel::saveTagPhotoOrder(qint64 tagId, const QVariantList &photoIds)
{
    if (!m_db) return false;
    QVector<qint64> ids;
    ids.reserve(photoIds.size());
    for (const QVariant &v : photoIds)
        ids.append(v.toLongLong());
    return m_db->saveTagPhotoOrder(tagId, ids);
}
