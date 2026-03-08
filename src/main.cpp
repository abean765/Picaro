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

int main(int argc, char *argv[])
{
    QElapsedTimer startupTimer;
    startupTimer.start();

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Picaro"));
    app.setOrganizationName(QStringLiteral("Picaro"));

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // Database location: ~/.local/share/Picaro/picaro.db
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);
    QString dbPath = dataDir + QStringLiteral("/picaro.db");

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

    // QML engine
    QQmlApplicationEngine engine;

    // Register thumbnail image provider (engine takes ownership)
    engine.addImageProvider(QStringLiteral("thumbnail"), new ThumbnailProvider(&db));

    // Expose C++ objects to QML
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty(QStringLiteral("photoModel"), &photoModel);
    ctx->setContextProperty(QStringLiteral("photoImporter"), &importer);

    // Add reload method to photoModel for QML access
    // (We connect import finish to model reload)
    QObject::connect(&importer, &PhotoImporter::importFinished,
                     [&photoModel, &db](int imported, int /*skipped*/) {
        if (imported > 0) {
            photoModel.loadFromDatabase(&db);
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
