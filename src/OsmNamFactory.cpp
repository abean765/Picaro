#include "OsmNamFactory.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>

static const QByteArray kUserAgent =
    "Picaro/1.0 (photo organiser; https://github.com/abean765/Picaro)";

class PicaroNam : public QNetworkAccessManager
{
    using QNetworkAccessManager::QNetworkAccessManager;

protected:
    QNetworkReply *createRequest(Operation op,
                                 const QNetworkRequest &req,
                                 QIODevice *data) override
    {
        QNetworkRequest r = req;
        r.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
        return QNetworkAccessManager::createRequest(op, r, data);
    }
};

QNetworkAccessManager *OsmNamFactory::create(QObject *parent)
{
    return new PicaroNam(parent);
}
