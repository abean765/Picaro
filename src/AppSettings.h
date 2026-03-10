#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStandardPaths>
#include <QDir>
#include <QColor>
#include <QVariantMap>
#include <QTemporaryDir>
#include <QFile>
#include <QtMath>
#include <QHostInfo>
#include "GpuHeicDecoder.h"

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString databasePath READ databasePath WRITE setDatabasePath NOTIFY databasePathChanged)
    Q_PROPERTY(QString defaultDatabasePath READ defaultDatabasePath CONSTANT)
    Q_PROPERTY(QColor accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(QString computerName READ computerName WRITE setComputerName NOTIFY computerNameChanged)
    Q_PROPERTY(bool networkVisible READ networkVisible WRITE setNetworkVisible NOTIFY networkVisibleChanged)
    Q_PROPERTY(QString receiveFolder READ receiveFolder WRITE setReceiveFolder NOTIFY receiveFolderChanged)
    Q_PROPERTY(QString importDirectory READ importDirectory WRITE setImportDirectory NOTIFY importDirectoryChanged)
    Q_PROPERTY(QString importOwner READ importOwner WRITE setImportOwner NOTIFY importOwnerChanged)
    Q_PROPERTY(QString photoFolder READ photoFolder WRITE setPhotoFolder NOTIFY photoFolderChanged)

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

    // --- Local Send settings ---

    QString computerName() const
    {
        return m_settings.value(
            QStringLiteral("localsend/computerName"),
            QHostInfo::localHostName()
        ).toString();
    }

    void setComputerName(const QString &name)
    {
        if (name == computerName()) return;
        m_settings.setValue(QStringLiteral("localsend/computerName"), name);
        m_settings.sync();
        emit computerNameChanged();
    }

    bool networkVisible() const
    {
        return m_settings.value(QStringLiteral("localsend/networkVisible"), false).toBool();
    }

    void setNetworkVisible(bool visible)
    {
        if (visible == networkVisible()) return;
        m_settings.setValue(QStringLiteral("localsend/networkVisible"), visible);
        m_settings.sync();
        emit networkVisibleChanged();
    }

    QString receiveFolder() const
    {
        return m_settings.value(
            QStringLiteral("localsend/receiveFolder"),
            defaultReceiveFolder()
        ).toString();
    }

    void setReceiveFolder(const QString &folder)
    {
        if (folder == receiveFolder()) return;
        m_settings.setValue(QStringLiteral("localsend/receiveFolder"), folder);
        m_settings.sync();
        emit receiveFolderChanged();
    }

    QString defaultReceiveFolder() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)
               + QStringLiteral("/Picaro Empfangen");
    }

    Q_INVOKABLE void resetComputerName()
    {
        m_settings.remove(QStringLiteral("localsend/computerName"));
        m_settings.sync();
        emit computerNameChanged();
    }

    Q_INVOKABLE void resetReceiveFolder()
    {
        m_settings.remove(QStringLiteral("localsend/receiveFolder"));
        m_settings.sync();
        emit receiveFolderChanged();
    }

    // --- Import settings ---

    QString importDirectory() const
    {
        return m_settings.value(
            QStringLiteral("import/directory"),
            QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)
        ).toString();
    }

    void setImportDirectory(const QString &dir)
    {
        if (dir == importDirectory()) return;
        m_settings.setValue(QStringLiteral("import/directory"), dir);
        m_settings.sync();
        emit importDirectoryChanged();
    }

    QString importOwner() const
    {
        return m_settings.value(QStringLiteral("import/owner"), QString()).toString();
    }

    void setImportOwner(const QString &owner)
    {
        if (owner == importOwner()) return;
        m_settings.setValue(QStringLiteral("import/owner"), owner);
        m_settings.sync();
        emit importOwnerChanged();
    }

    QString photoFolder() const
    {
        return m_settings.value(
            QStringLiteral("storage/photoFolder"),
            QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)
                + QStringLiteral("/Picaro")
        ).toString();
    }

    void setPhotoFolder(const QString &folder)
    {
        if (folder == photoFolder()) return;
        m_settings.setValue(QStringLiteral("storage/photoFolder"), folder);
        m_settings.sync();
        emit photoFolderChanged();
    }

    Q_INVOKABLE void resetPhotoFolder()
    {
        m_settings.remove(QStringLiteral("storage/photoFolder"));
        m_settings.sync();
        emit photoFolderChanged();
    }

    Q_INVOKABLE QString generateTestTone()
    {
        if (!m_tempDir.isValid())
            return {};
        QString path = m_tempDir.path() + QStringLiteral("/test_tone.wav");
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly))
            return {};

        const int sampleRate = 44100;
        const int channels = 1;
        const int bitsPerSample = 16;
        const double duration = 0.5;
        const double freq = 440.0;
        const int numSamples = static_cast<int>(sampleRate * duration);
        const int dataSize = numSamples * channels * (bitsPerSample / 8);

        // WAV header
        auto writeU32 = [&](quint32 v) { f.write(reinterpret_cast<const char*>(&v), 4); };
        auto writeU16 = [&](quint16 v) { f.write(reinterpret_cast<const char*>(&v), 2); };

        f.write("RIFF", 4);
        writeU32(36 + dataSize);
        f.write("WAVE", 4);
        f.write("fmt ", 4);
        writeU32(16);
        writeU16(1); // PCM
        writeU16(channels);
        writeU32(sampleRate);
        writeU32(sampleRate * channels * bitsPerSample / 8);
        writeU16(channels * bitsPerSample / 8);
        writeU16(bitsPerSample);
        f.write("data", 4);
        writeU32(dataSize);

        // Sine wave samples with fade in/out
        const int fadeLen = sampleRate / 20; // 50ms fade
        for (int i = 0; i < numSamples; ++i) {
            double t = static_cast<double>(i) / sampleRate;
            double sample = qSin(2.0 * M_PI * freq * t);
            // Fade envelope
            double env = 1.0;
            if (i < fadeLen)
                env = static_cast<double>(i) / fadeLen;
            else if (i > numSamples - fadeLen)
                env = static_cast<double>(numSamples - i) / fadeLen;
            qint16 val = static_cast<qint16>(sample * env * 32000);
            f.write(reinterpret_cast<const char*>(&val), 2);
        }

        f.close();
        return path;
    }

    Q_INVOKABLE QVariantMap testGpuHeicDecode()
    {
        QVariantMap result;
        result[QStringLiteral("available")] = GpuHeicDecoder::isAvailable();

#ifdef HAVE_FFMPEG_HW
        result[QStringLiteral("compiled")] = true;
#else
        result[QStringLiteral("compiled")] = false;
#endif

        return result;
    }

signals:
    void databasePathChanged();
    void accentColorChanged();
    void computerNameChanged();
    void networkVisibleChanged();
    void receiveFolderChanged();
    void importDirectoryChanged();
    void importOwnerChanged();
    void photoFolderChanged();

private:
    QSettings m_settings;
    QTemporaryDir m_tempDir;
};
