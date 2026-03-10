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
#include "PhotoImageProvider.h"
#include "AppSettings.h"
#include "StatsProvider.h"
#include "TagModel.h"
#include "NetworkManager.h"
#include "PeerModel.h"
#include "OsmNamFactory.h"

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

    // Tag model
    TagModel tagModel;
    tagModel.setDatabase(&db);

    // Network manager for Local Send
    NetworkManager networkManager(&db);

    // Peer model for QML
    PeerModel peerModel;
    peerModel.setNetworkManager(&networkManager);

    // QML engine
    QQmlApplicationEngine engine;

    // Set a descriptive User-Agent so OSM tile servers do not block us
    OsmNamFactory namFactory;
    engine.setNetworkAccessManagerFactory(&namFactory);

    // Register thumbnail image provider (engine takes ownership)
    engine.addImageProvider(QStringLiteral("thumbnail"), new ThumbnailProvider(dbPath));
    engine.addImageProvider(QStringLiteral("photo"), new PhotoImageProvider(dbPath));

    // Expose C++ objects to QML
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty(QStringLiteral("photoModel"), &photoModel);
    ctx->setContextProperty(QStringLiteral("photoImporter"), &importer);
    ctx->setContextProperty(QStringLiteral("appSettings"), &settings);
    ctx->setContextProperty(QStringLiteral("statsProvider"), &statsProvider);
    ctx->setContextProperty(QStringLiteral("tagModel"), &tagModel);
    ctx->setContextProperty(QStringLiteral("networkManager"), &networkManager);
    ctx->setContextProperty(QStringLiteral("peerModel"), &peerModel);

    // Reload model and stats after import finishes
    QObject::connect(&importer, &PhotoImporter::importFinished,
                     [&photoModel, &db, &statsProvider](int imported, int /*skipped*/) {
        if (imported > 0) {
            photoModel.loadFromDatabase(&db);
            statsProvider.refresh();
        }
    });

    // Load QML
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    engine.loadFromModule("Picaro", "Main");
#else
    const QStringList qmlPaths = {
        QStringLiteral("qrc:/qt/qml/Picaro/qml/Main.qml"),
        QStringLiteral("qrc:/qt/qml/Picaro/Main.qml"),
        QStringLiteral("qrc:/Picaro/qml/Main.qml"),
        QStringLiteral("qrc:/Picaro/Main.qml"),
    };
    for (const auto &path : qmlPaths) {
        engine.load(QUrl(path));
        if (!engine.rootObjects().isEmpty()) break;
    }
#endif

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load QML";
        return 1;
    }

    qDebug() << "Startup completed in" << startupTimer.elapsed() << "ms";

    return app.exec();
}
