#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStandardPaths>
#include <QDir>
#include <QColor>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString databasePath READ databasePath WRITE setDatabasePath NOTIFY databasePathChanged)
    Q_PROPERTY(QString defaultDatabasePath READ defaultDatabasePath CONSTANT)
    Q_PROPERTY(QColor accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)

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

    QColor accentColor() const
    {
        return QColor(m_settings.value(
            QStringLiteral("appearance/accentColor"),
            QStringLiteral("#4a9eff")
        ).toString());
    }

    void setAccentColor(const QColor &color)
    {
        if (color == accentColor()) return;
        m_settings.setValue(QStringLiteral("appearance/accentColor"), color.name());
        m_settings.sync();
        emit accentColorChanged();
    }

    Q_INVOKABLE void resetAccentColor()
    {
        m_settings.remove(QStringLiteral("appearance/accentColor"));
        m_settings.sync();
        emit accentColorChanged();
    }

signals:
    void databasePathChanged();
    void accentColorChanged();

private:
    QSettings m_settings;
};
