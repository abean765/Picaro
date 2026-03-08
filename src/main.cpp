#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QDir>
#include <QElapsedTimer>
#include <QQuickStyle>

#include "PhotoDatabase.h"
#include "PhotoModel.h"
#include "PhotoImporter.h"
#include "ThumbnailProvider.h"
#include "AppSettings.h"
#include "StatsProvider.h"

int main(int argc, char *argv[])
{
    QElapsedTimer startupTimer;
    startupTimer.start();

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Picaro"));
    app.setOrganizationName(QStringLiteral("Picaro"));

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // Settings
    AppSettings settings;

    // Database location from settings (default: ~/.local/share/Picaro/picaro.db)
    QString dbPath = settings.databasePath();
    QDir().mkpath(QFileInfo(dbPath).absolutePath());

    // Open database
    PhotoDatabase db;
    if (!db.open(dbPath)) {
        qCritical() << "Failed to open database at" << dbPath;
        return 1;
    }

    // Load photo model from database
    PhotoModel photoModel;
    photoModel.loadFromDatabase(&db);

    // Importer
    PhotoImporter importer(&db);

    // Statistics provider
    StatsProvider statsProvider(&db);

    // QML engine
    QQmlApplicationEngine engine;

    // Register thumbnail image provider (engine takes ownership)
    engine.addImageProvider(QStringLiteral("thumbnail"), new ThumbnailProvider(dbPath));

    // Expose C++ objects to QML
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty(QStringLiteral("photoModel"), &photoModel);
    ctx->setContextProperty(QStringLiteral("photoImporter"), &importer);
    ctx->setContextProperty(QStringLiteral("appSettings"), &settings);
    ctx->setContextProperty(QStringLiteral("statsProvider"), &statsProvider);

    // Reload model and stats after import finishes
    QObject::connect(&importer, &PhotoImporter::importFinished,
                     [&photoModel, &db, &statsProvider](int imported, int /*skipped*/) {
        if (imported > 0) {
            photoModel.loadFromDatabase(&db);
            statsProvider.refresh();
        }
    });

    // Load QML
    engine.loadFromModule("Picaro", "Main");

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load QML";
        return 1;
    }

    qDebug() << "Startup completed in" << startupTimer.elapsed() << "ms";

    return app.exec();
}
