#pragma once

#include <QObject>
#include "PhotoDatabase.h"

class StatsProvider : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int totalPhotos READ totalPhotos NOTIFY statsChanged)
    Q_PROPERTY(int normalPhotos READ normalPhotos NOTIFY statsChanged)
    Q_PROPERTY(int videos READ videos NOTIFY statsChanged)
    Q_PROPERTY(int livePhotos READ livePhotos NOTIFY statsChanged)
    Q_PROPERTY(int screenshots READ screenshots NOTIFY statsChanged)
    Q_PROPERTY(int selfies READ selfies NOTIFY statsChanged)
    Q_PROPERTY(QString totalSize READ totalSize NOTIFY statsChanged)

public:
    explicit StatsProvider(PhotoDatabase *db, QObject *parent = nullptr)
        : QObject(parent), m_db(db)
    {
    }

    int totalPhotos() const { return m_stats.totalPhotos; }
    int normalPhotos() const { return m_stats.normalPhotos; }
    int videos() const { return m_stats.videos; }
    int livePhotos() const { return m_stats.livePhotos; }
    int screenshots() const { return m_stats.screenshots; }
    int selfies() const { return m_stats.selfies; }

    QString totalSize() const
    {
        double bytes = m_stats.totalSizeBytes;
        if (bytes < 1024.0) return QString::number(bytes, 'f', 0) + QStringLiteral(" B");
        bytes /= 1024.0;
        if (bytes < 1024.0) return QString::number(bytes, 'f', 1) + QStringLiteral(" KB");
        bytes /= 1024.0;
        if (bytes < 1024.0) return QString::number(bytes, 'f', 1) + QStringLiteral(" MB");
        bytes /= 1024.0;
        return QString::number(bytes, 'f', 2) + QStringLiteral(" GB");
    }

    Q_INVOKABLE void refresh()
    {
        m_stats = m_db->loadStats();
        emit statsChanged();
    }

signals:
    void statsChanged();

private:
    PhotoDatabase *m_db;
    PhotoStats m_stats;
};
