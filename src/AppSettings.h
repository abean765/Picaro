#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStandardPaths>
#include <QDir>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString databasePath READ databasePath WRITE setDatabasePath NOTIFY databasePathChanged)
    Q_PROPERTY(QString defaultDatabasePath READ defaultDatabasePath CONSTANT)

public:
    explicit AppSettings(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    QString databasePath() const
    {
        return m_settings.value(
            QStringLiteral("database/path"),
            defaultDatabasePath()
        ).toString();
    }

    void setDatabasePath(const QString &path)
    {
        if (path == databasePath()) return;
        m_settings.setValue(QStringLiteral("database/path"), path);
        m_settings.sync();
        emit databasePathChanged();
    }

    QString defaultDatabasePath() const
    {
        QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        return dataDir + QStringLiteral("/picaro.db");
    }

    Q_INVOKABLE void resetDatabasePath()
    {
        m_settings.remove(QStringLiteral("database/path"));
        m_settings.sync();
        emit databasePathChanged();
    }

signals:
    void databasePathChanged();

private:
    QSettings m_settings;
};
