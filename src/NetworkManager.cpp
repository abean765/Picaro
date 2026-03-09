#include "NetworkManager.h"

#include <QDataStream>
#include <QImageReader>
#include <QBuffer>

NetworkManager::NetworkManager(PhotoDatabase *db, QObject *parent)
    : QObject(parent)
    , m_db(db)
{
}

NetworkManager::~NetworkManager()
{
    stopDiscovery();
}

void NetworkManager::startDiscovery(const QString &computerName)
{
    if (m_discoveryActive)
        return;

    m_computerName = computerName;

    // UDP socket for discovery broadcasts
    m_udpSocket = new QUdpSocket(this);
    if (!m_udpSocket->bind(QHostAddress::AnyIPv4, DISCOVERY_PORT,
                           QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) {
        qWarning() << "Failed to bind UDP socket on port" << DISCOVERY_PORT;
        delete m_udpSocket;
        m_udpSocket = nullptr;
        emit errorOccurred(QStringLiteral("UDP-Port %1 konnte nicht geöffnet werden").arg(DISCOVERY_PORT));
        return;
    }
    connect(m_udpSocket, &QUdpSocket::readyRead, this, &NetworkManager::onReadUdp);

    // TCP server for file transfers
    m_tcpServer = new QTcpServer(this);
    if (!m_tcpServer->listen(QHostAddress::AnyIPv4, 0)) {
        qWarning() << "Failed to start TCP server";
        delete m_udpSocket;
        m_udpSocket = nullptr;
        delete m_tcpServer;
        m_tcpServer = nullptr;
        emit errorOccurred(QStringLiteral("TCP-Server konnte nicht gestartet werden"));
        return;
    }
    connect(m_tcpServer, &QTcpServer::newConnection, this, &NetworkManager::onNewConnection);

    qDebug() << "Local Send: TCP server on port" << m_tcpServer->serverPort();

    // Broadcast timer
    m_broadcastTimer = new QTimer(this);
    connect(m_broadcastTimer, &QTimer::timeout, this, &NetworkManager::onBroadcastTimer);
    m_broadcastTimer->start(BROADCAST_INTERVAL_MS);

    // Peer cleanup timer
    m_peerCleanupTimer = new QTimer(this);
    connect(m_peerCleanupTimer, &QTimer::timeout, this, &NetworkManager::onPeerTimeout);
    m_peerCleanupTimer->start(PEER_TIMEOUT_MS / 2);

    // Send initial broadcast
    onBroadcastTimer();

    m_discoveryActive = true;
    emit discoveryActiveChanged();
}

void NetworkManager::stopDiscovery()
{
    if (!m_discoveryActive)
        return;

    if (m_broadcastTimer) {
        m_broadcastTimer->stop();
        delete m_broadcastTimer;
        m_broadcastTimer = nullptr;
    }
    if (m_peerCleanupTimer) {
        m_peerCleanupTimer->stop();
        delete m_peerCleanupTimer;
        m_peerCleanupTimer = nullptr;
    }
    if (m_udpSocket) {
        m_udpSocket->close();
        delete m_udpSocket;
        m_udpSocket = nullptr;
    }
    if (m_tcpServer) {
        m_tcpServer->close();
        delete m_tcpServer;
        m_tcpServer = nullptr;
    }

    m_peers.clear();
    m_discoveryActive = false;
    emit discoveryActiveChanged();
    emit peersChanged();
}

void NetworkManager::onBroadcastTimer()
{
    if (!m_udpSocket || !m_tcpServer)
        return;

    QJsonObject announce;
    announce[QStringLiteral("type")] = QStringLiteral("picaro_announce");
    announce[QStringLiteral("name")] = m_computerName;
    announce[QStringLiteral("port")] = m_tcpServer->serverPort();

    QByteArray data = QJsonDocument(announce).toJson(QJsonDocument::Compact);

    // Broadcast on all interfaces
    const auto addresses = QNetworkInterface::allAddresses();
    for (const auto &iface : QNetworkInterface::allInterfaces()) {
        if (iface.flags().testFlag(QNetworkInterface::IsLoopBack))
            continue;
        if (!iface.flags().testFlag(QNetworkInterface::IsUp))
            continue;
        if (!iface.flags().testFlag(QNetworkInterface::IsRunning))
            continue;

        for (const auto &entry : iface.addressEntries()) {
            if (entry.ip().protocol() != QAbstractSocket::IPv4Protocol)
                continue;
            auto broadcast = entry.broadcast();
            if (!broadcast.isNull()) {
                m_udpSocket->writeDatagram(data, broadcast, DISCOVERY_PORT);
            }
        }
    }
}

void NetworkManager::onReadUdp()
{
    while (m_udpSocket && m_udpSocket->hasPendingDatagrams()) {
        QByteArray data;
        data.resize(static_cast<int>(m_udpSocket->pendingDatagramSize()));
        QHostAddress sender;
        quint16 senderPort;
        m_udpSocket->readDatagram(data.data(), data.size(), &sender, &senderPort);

        // Skip our own broadcasts
        bool isOwn = false;
        for (const auto &addr : QNetworkInterface::allAddresses()) {
            if (addr == sender) {
                isOwn = true;
                break;
            }
        }
        if (isOwn)
            continue;

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (doc.isNull() || !doc.isObject())
            continue;

        QJsonObject obj = doc.object();
        if (obj.value(QStringLiteral("type")).toString() != QStringLiteral("picaro_announce"))
            continue;

        QString peerName = obj.value(QStringLiteral("name")).toString();
        quint16 peerTcpPort = static_cast<quint16>(obj.value(QStringLiteral("port")).toInt());

        if (peerName.isEmpty())
            continue;

        QString key = sender.toString() + QStringLiteral(":") + QString::number(peerTcpPort);

        bool isNew = !m_peers.contains(key);

        PeerInfo &peer = m_peers[key];
        peer.name = peerName;
        peer.address = sender.toString();
        peer.port = peerTcpPort;
        peer.lastSeen = QDateTime::currentDateTime();

        if (isNew) {
            qDebug() << "Discovered peer:" << peerName << "at" << sender.toString() << ":" << peerTcpPort;
            emit peersChanged();
        }
    }
}

void NetworkManager::onPeerTimeout()
{
    cleanupStalePeers();
}

void NetworkManager::cleanupStalePeers()
{
    QDateTime cutoff = QDateTime::currentDateTime().addMSecs(-PEER_TIMEOUT_MS);
    bool changed = false;

    auto it = m_peers.begin();
    while (it != m_peers.end()) {
        if (it->lastSeen < cutoff) {
            qDebug() << "Peer timed out:" << it->name;
            it = m_peers.erase(it);
            changed = true;
        } else {
            ++it;
        }
    }

    if (changed)
        emit peersChanged();
}

QVariantList NetworkManager::peers() const
{
    QVariantList result;
    for (auto it = m_peers.constBegin(); it != m_peers.constEnd(); ++it) {
        QVariantMap peer;
        peer[QStringLiteral("name")] = it->name;
        peer[QStringLiteral("address")] = it->address;
        peer[QStringLiteral("port")] = it->port;
        result.append(peer);
    }
    return result;
}

// --- Sending ---

void NetworkManager::sendPhotos(const QString &peerAddress, quint16 peerPort,
                                const QVariantList &photoIds, const QString &senderName)
{
    if (m_sending)
        return;

    m_sending = true;
    m_sendProgress = 0;
    m_sendTotal = photoIds.size();
    emit sendingChanged();
    emit sendTotalChanged();
    emit sendProgressChanged();

    auto *socket = new QTcpSocket(this);

    connect(socket, &QTcpSocket::connected, this, [=]() {
        // Send transfer request header
        QJsonObject header;
        header[QStringLiteral("type")] = QStringLiteral("transfer_request");
        header[QStringLiteral("sender")] = senderName;
        header[QStringLiteral("fileCount")] = static_cast<int>(photoIds.size());

        // Gather file info via loadRecord
        qint64 totalSz = 0;
        struct FileEntry { QString path; QString name; qint64 size; };
        QVector<FileEntry> entries;

        for (const auto &idVar : photoIds) {
            qint64 id = idVar.toLongLong();
            auto rec = m_db->loadRecord(id);
            if (rec) {
                FileEntry e;
                e.path = rec->filePath;
                e.name = rec->fileName;
                e.size = rec->fileSize;
                totalSz += e.size;
                entries.append(e);
            }
        }

        header[QStringLiteral("totalSize")] = totalSz;
        QByteArray headerData = QJsonDocument(header).toJson(QJsonDocument::Compact);

        // Write: [4 bytes header length][header json]
        QDataStream stream(socket);
        stream.setByteOrder(QDataStream::BigEndian);
        stream << static_cast<quint32>(headerData.size());
        socket->write(headerData);
        socket->flush();

        // Wait for accept/reject response
        connect(socket, &QTcpSocket::readyRead, this, [=, entries = std::move(entries)]() mutable {
            if (socket->bytesAvailable() < 4)
                return;

            // Read response
            QByteArray allData = socket->readAll();
            QJsonDocument respDoc = QJsonDocument::fromJson(allData.mid(4));
            if (respDoc.isNull()) {
                // Try without length prefix
                respDoc = QJsonDocument::fromJson(allData);
            }

            if (respDoc.isNull() || !respDoc.isObject()) {
                m_sending = false;
                emit sendingChanged();
                emit sendFinished(false, QStringLiteral("Ungültige Antwort vom Empfänger"));
                socket->deleteLater();
                return;
            }

            QJsonObject resp = respDoc.object();
            QString respType = resp.value(QStringLiteral("type")).toString();

            if (respType == QStringLiteral("reject")) {
                m_sending = false;
                emit sendingChanged();
                emit sendFinished(false, QStringLiteral("Übertragung wurde abgelehnt"));
                socket->deleteLater();
                return;
            }

            if (respType != QStringLiteral("accept")) {
                m_sending = false;
                emit sendingChanged();
                emit sendFinished(false, QStringLiteral("Unerwartete Antwort"));
                socket->deleteLater();
                return;
            }

            // Disconnect readyRead to avoid re-entry
            disconnect(socket, &QTcpSocket::readyRead, this, nullptr);

            // Send files one by one
            int sent = 0;
            for (const auto &entry : entries) {
                QFile file(entry.path);
                if (!file.open(QIODevice::ReadOnly)) {
                    qWarning() << "Cannot open file for sending:" << entry.path;
                    continue;
                }

                // File header: [4 bytes json length][json with name, size]
                QJsonObject fh;
                fh[QStringLiteral("name")] = entry.name;
                fh[QStringLiteral("size")] = entry.size;
                QByteArray fhData = QJsonDocument(fh).toJson(QJsonDocument::Compact);

                QDataStream fs(socket);
                fs.setByteOrder(QDataStream::BigEndian);
                fs << static_cast<quint32>(fhData.size());
                socket->write(fhData);

                // Send file data in chunks
                while (!file.atEnd()) {
                    QByteArray chunk = file.read(64 * 1024);
                    socket->write(chunk);
                    socket->waitForBytesWritten(5000);
                }
                file.close();

                sent++;
                m_sendProgress = sent;
                emit sendProgressChanged();
            }

            socket->flush();
            socket->waitForBytesWritten(5000);

            m_sending = false;
            emit sendingChanged();
            emit sendFinished(true, QStringLiteral("%1 Dateien gesendet").arg(sent));
            socket->disconnectFromHost();
            socket->deleteLater();
        });
    });

    connect(socket, &QTcpSocket::errorOccurred, this, [=](QAbstractSocket::SocketError) {
        m_sending = false;
        emit sendingChanged();
        emit sendFinished(false, QStringLiteral("Verbindungsfehler: %1").arg(socket->errorString()));
        socket->deleteLater();
    });

    socket->connectToHost(peerAddress, peerPort);
}

// --- Receiving ---

void NetworkManager::onNewConnection()
{
    while (m_tcpServer && m_tcpServer->hasPendingConnections()) {
        QTcpSocket *socket = m_tcpServer->nextPendingConnection();
        handleIncomingData(socket);
    }
}

void NetworkManager::handleIncomingData(QTcpSocket *socket)
{
    // Wait for enough data to read the header
    connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
        if (socket->bytesAvailable() < 4)
            return;

        // Disconnect to avoid re-entry
        disconnect(socket, &QTcpSocket::readyRead, this, nullptr);

        // Read header length
        QByteArray lenBuf = socket->read(4);
        QDataStream lenStream(lenBuf);
        lenStream.setByteOrder(QDataStream::BigEndian);
        quint32 headerLen;
        lenStream >> headerLen;

        if (headerLen > 1024 * 1024) { // Sanity check: 1MB max header
            socket->disconnectFromHost();
            socket->deleteLater();
            return;
        }

        // Read rest of header (may need to wait)
        QByteArray headerData;
        while (static_cast<quint32>(headerData.size()) < headerLen) {
            if (socket->bytesAvailable() == 0 && !socket->waitForReadyRead(5000))
                break;
            headerData.append(socket->read(static_cast<qint64>(headerLen) - headerData.size()));
        }

        QJsonDocument doc = QJsonDocument::fromJson(headerData);
        if (doc.isNull() || !doc.isObject()) {
            socket->disconnectFromHost();
            socket->deleteLater();
            return;
        }

        QJsonObject header = doc.object();
        QString type = header.value(QStringLiteral("type")).toString();

        if (type == QStringLiteral("transfer_request")) {
            processTransferRequest(socket, header);
        } else {
            socket->disconnectFromHost();
            socket->deleteLater();
        }
    });
}

void NetworkManager::processTransferRequest(QTcpSocket *socket, const QJsonObject &header)
{
    m_incomingSender = header.value(QStringLiteral("sender")).toString();
    m_incomingFileCount = header.value(QStringLiteral("fileCount")).toInt();
    m_incomingTotalSize = header.value(QStringLiteral("totalSize")).toVariant().toLongLong();
    m_pendingTransferSocket = socket;

    qDebug() << "Transfer request from" << m_incomingSender
             << ":" << m_incomingFileCount << "files," << m_incomingTotalSize << "bytes";

    emit incomingTransfer(m_incomingSender, m_incomingFileCount, m_incomingTotalSize);
}

void NetworkManager::acceptTransfer(const QString &receiveFolder)
{
    if (!m_pendingTransferSocket)
        return;

    // Send accept response
    QJsonObject resp;
    resp[QStringLiteral("type")] = QStringLiteral("accept");
    QByteArray respData = QJsonDocument(resp).toJson(QJsonDocument::Compact);

    QDataStream stream(m_pendingTransferSocket);
    stream.setByteOrder(QDataStream::BigEndian);
    stream << static_cast<quint32>(respData.size());
    m_pendingTransferSocket->write(respData);
    m_pendingTransferSocket->flush();

    m_receiveFolder = receiveFolder;

    // Ensure receive folder exists
    QDir().mkpath(m_receiveFolder);

    m_receiving = true;
    m_receiveProgress = 0;
    m_receiveTotal = m_incomingFileCount;
    emit receivingChanged();
    emit receiveTotalChanged();
    emit receiveProgressChanged();

    // Now receive files
    receiveFiles(m_pendingTransferSocket);
}

void NetworkManager::rejectTransfer()
{
    if (!m_pendingTransferSocket)
        return;

    QJsonObject resp;
    resp[QStringLiteral("type")] = QStringLiteral("reject");
    QByteArray respData = QJsonDocument(resp).toJson(QJsonDocument::Compact);

    QDataStream stream(m_pendingTransferSocket);
    stream.setByteOrder(QDataStream::BigEndian);
    stream << static_cast<quint32>(respData.size());
    m_pendingTransferSocket->write(respData);
    m_pendingTransferSocket->flush();

    m_pendingTransferSocket->disconnectFromHost();
    m_pendingTransferSocket->deleteLater();
    m_pendingTransferSocket = nullptr;
}

void NetworkManager::receiveFiles(QTcpSocket *socket)
{
    QString senderName = m_incomingSender;
    int totalFiles = m_incomingFileCount;
    int received = 0;

    // Use a sequential read approach
    auto readExact = [socket](qint64 bytes) -> QByteArray {
        QByteArray result;
        while (result.size() < bytes) {
            if (socket->bytesAvailable() == 0 && !socket->waitForReadyRead(10000))
                break;
            result.append(socket->read(bytes - result.size()));
        }
        return result;
    };

    for (int i = 0; i < totalFiles; ++i) {
        // Read file header length (4 bytes)
        QByteArray lenBuf = readExact(4);
        if (lenBuf.size() < 4)
            break;

        QDataStream lenStream(lenBuf);
        lenStream.setByteOrder(QDataStream::BigEndian);
        quint32 fhLen;
        lenStream >> fhLen;

        if (fhLen > 1024 * 1024)
            break;

        // Read file header JSON
        QByteArray fhData = readExact(fhLen);
        QJsonDocument fhDoc = QJsonDocument::fromJson(fhData);
        if (fhDoc.isNull())
            break;

        QJsonObject fh = fhDoc.object();
        QString fileName = fh.value(QStringLiteral("name")).toString();
        qint64 fileSize = fh.value(QStringLiteral("size")).toVariant().toLongLong();

        // Avoid overwriting: add suffix if file exists
        QString destPath = m_receiveFolder + QStringLiteral("/") + fileName;
        if (QFile::exists(destPath)) {
            QFileInfo fi(destPath);
            QString base = fi.completeBaseName();
            QString ext = fi.suffix();
            int n = 1;
            while (QFile::exists(destPath)) {
                destPath = m_receiveFolder + QStringLiteral("/") + base
                           + QStringLiteral("_%1.").arg(n) + ext;
                n++;
            }
        }

        // Read file data and write to disk
        QFile outFile(destPath);
        if (!outFile.open(QIODevice::WriteOnly)) {
            qWarning() << "Cannot write to" << destPath;
            // Still consume the data
            readExact(fileSize);
            continue;
        }

        qint64 remaining = fileSize;
        while (remaining > 0) {
            qint64 chunkSize = qMin(remaining, static_cast<qint64>(64 * 1024));
            QByteArray chunk = readExact(chunkSize);
            if (chunk.isEmpty())
                break;
            outFile.write(chunk);
            remaining -= chunk.size();
        }
        outFile.close();

        // Create a PhotoRecord and insert into DB
        QFileInfo destInfo(destPath);
        PhotoRecord record;
        record.filePath = destPath;
        record.fileName = destInfo.fileName();
        record.dateTaken = QDateTime::currentDateTime();
        record.dateModified = QDateTime::currentDateTime();
        record.fileSize = destInfo.size();
        record.monthKey = record.dateTaken.toString(QStringLiteral("yyyy-MM"));
        record.owner = senderName;

        // Detect media type from extension
        QString ext = destInfo.suffix().toLower();
        static const QStringList videoExts = {
            QStringLiteral("mp4"), QStringLiteral("mov"), QStringLiteral("avi"),
            QStringLiteral("mkv"), QStringLiteral("m4v"), QStringLiteral("webm")
        };
        if (videoExts.contains(ext)) {
            record.mediaType = MediaType::Video;
        } else {
            record.mediaType = MediaType::Photo;
        }

        // Detect MIME type
        static const QMap<QString, QString> mimeMap = {
            {QStringLiteral("jpg"), QStringLiteral("image/jpeg")},
            {QStringLiteral("jpeg"), QStringLiteral("image/jpeg")},
            {QStringLiteral("png"), QStringLiteral("image/png")},
            {QStringLiteral("heic"), QStringLiteral("image/heic")},
            {QStringLiteral("webp"), QStringLiteral("image/webp")},
            {QStringLiteral("mp4"), QStringLiteral("video/mp4")},
            {QStringLiteral("mov"), QStringLiteral("video/quicktime")},
        };
        record.mimeType = mimeMap.value(ext, QStringLiteral("application/octet-stream"));

        // Generate a simple thumbnail for images
        QByteArray thumbnail;
        if (record.mediaType == MediaType::Photo) {
            QImageReader reader(destPath);
            reader.setAutoTransform(true);
            QSize origSize = reader.size();
            if (origSize.isValid()) {
                record.width = origSize.width();
                record.height = origSize.height();
                int thumbSize = 320;
                QSize scaled = origSize.scaled(thumbSize, thumbSize, Qt::KeepAspectRatio);
                reader.setScaledSize(scaled);
            }
            QImage img = reader.read();
            if (!img.isNull()) {
                QBuffer buf(&thumbnail);
                buf.open(QIODevice::WriteOnly);
                img.save(&buf, "JPEG", 75);
            }
        }

        m_db->insertPhoto(record, thumbnail);

        received++;
        m_receiveProgress = received;
        emit receiveProgressChanged();
    }

    m_receiving = false;
    emit receivingChanged();
    emit receiveFinished(received > 0, received,
                         QStringLiteral("%1 Dateien von %2 empfangen").arg(received).arg(senderName));

    socket->disconnectFromHost();
    socket->deleteLater();
    m_pendingTransferSocket = nullptr;
}
