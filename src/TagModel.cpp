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
    }
    return {};
}

QHash<int, QByteArray> TagModel::roleNames() const
{
    return {
        { IdRole, "tagId" },
        { NameRole, "name" },
        { ColorRole, "tagColor" },
        { IconRole, "tagIcon" },
        { PhotoCountRole, "photoCount" }
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
    endResetModel();
    emit tagsChanged();
}

qint64 TagModel::createTag(const QString &name, const QString &color, const QString &icon)
{
    if (!m_db) return -1;
    qint64 id = m_db->createTag(name, color, icon);
    if (id > 0) reload();
    return id;
}

bool TagModel::updateTag(qint64 tagId, const QString &name, const QString &color, const QString &icon)
{
    if (!m_db) return false;
    bool ok = m_db->updateTag(tagId, name, color, icon);
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

bool TagModel::removeTagFromPhoto(qint64 photoId, qint64 tagId)
{
    if (!m_db) return false;
    bool ok = m_db->removeTagFromPhoto(photoId, tagId);
    if (ok) reload();
    return ok;
}

QString TagModel::tagName(qint64 tagId) const
{
    for (const auto &t : m_tags) {
        if (t.id == tagId) return t.name;
    }
    return {};
}

QString TagModel::tagColor(qint64 tagId) const
{
    for (const auto &t : m_tags) {
        if (t.id == tagId) return t.color;
    }
    return QStringLiteral("#888888");
}

QString TagModel::tagIcon(qint64 tagId) const
{
    for (const auto &t : m_tags) {
        if (t.id == tagId) return t.icon;
    }
    return {};
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
