#pragma once
#include <QQmlNetworkAccessManagerFactory>

// Produces QNetworkAccessManagers that set a descriptive User-Agent on every
// request so that OpenStreetMap tile servers can identify this application and
// do not block it for sending a generic "Qt/<version>" agent string.
class OsmNamFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override;
};
