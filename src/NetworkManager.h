#pragma once

#include <QObject>
#include <QUdpSocket>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QHostInfo>
#include <QNetworkInterface>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QImage>

#include "PhotoDatabase.h"

struct PeerInfo {
    QString name;
    QString address;
    quint16 port = 0;
    QDateTime lastSeen;
};

// Incoming transfer request info
struct TransferRequest {
    QString senderName;
    QString senderAddress;
    quint16 senderPort = 0;
    int fileCount = 0;
    qint64 totalSize = 0;
    QTcpSocket *socket = nullptr;
};

class NetworkManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool discoveryActive READ discoveryActive NOTIFY discoveryActiveChanged)
    Q_PROPERTY(bool sending READ sending NOTIFY sendingChanged)
    Q_PROPERTY(int sendProgress READ sendProgress NOTIFY sendProgressChanged)
    Q_PROPERTY(int sendTotal READ sendTotal NOTIFY sendTotalChanged)
    Q_PROPERTY(bool receiving READ receiving NOTIFY receivingChanged)
    Q_PROPERTY(int receiveProgress READ receiveProgress NOTIFY receiveProgressChanged)
    Q_PROPERTY(int receiveTotal READ receiveTotal NOTIFY receiveTotalChanged)
    Q_PROPERTY(QString incomingSender READ incomingSender NOTIFY incomingTransfer)
    Q_PROPERTY(int incomingFileCount READ incomingFileCount NOTIFY incomingTransfer)

public:
    explicit NetworkManager(PhotoDatabase *db, QObject *parent = nullptr);
    ~NetworkManager();

    bool discoveryActive() const { return m_discoveryActive; }
    bool sending() const { return m_sending; }
    int sendProgress() const { return m_sendProgress; }
    int sendTotal() const { return m_sendTotal; }
    bool receiving() const { return m_receiving; }
    int receiveProgress() const { return m_receiveProgress; }
    int receiveTotal() const { return m_receiveTotal; }
    QString incomingSender() const { return m_incomingSender; }
    int incomingFileCount() const { return m_incomingFileCount; }

    Q_INVOKABLE void startDiscovery(const QString &computerName);
    Q_INVOKABLE void stopDiscovery();

    // Get current list of discovered peers
    Q_INVOKABLE QVariantList peers() const;

    // Send photos to a peer
    Q_INVOKABLE void sendPhotos(const QString &peerAddress, quint16 peerPort,
                                const QVariantList &photoIds, const QString &senderName);

    // Accept/reject incoming transfer
    Q_INVOKABLE void acceptTransfer(const QString &receiveFolder);
    Q_INVOKABLE void rejectTransfer();

    void setReceiveFolder(const QString &folder) { m_receiveFolder = folder; }

signals:
    void discoveryActiveChanged();
    void peersChanged();
    void sendingChanged();
    void sendProgressChanged();
    void sendTotalChanged();
    void sendFinished(bool success, const QString &message);
    void receivingChanged();
    void receiveProgressChanged();
    void receiveTotalChanged();
    void incomingTransfer(const QString &senderName, int fileCount, qint64 totalSize);
    void receiveFinished(bool success, int count, const QString &message);
    void errorOccurred(const QString &message);

private slots:
    void onBroadcastTimer();
    void onReadUdp();
    void onNewConnection();
    void onPeerTimeout();

private:
    void cleanupStalePeers();
    void handleIncomingData(QTcpSocket *socket);
    void processTransferRequest(QTcpSocket *socket, const QJsonObject &header);
    void receiveFiles(QTcpSocket *socket);

    static constexpr quint16 DISCOVERY_PORT = 45678;
    static constexpr int BROADCAST_INTERVAL_MS = 2000;
    static constexpr int PEER_TIMEOUT_MS = 8000;

    PhotoDatabase *m_db;
    QUdpSocket *m_udpSocket = nullptr;
    QTcpServer *m_tcpServer = nullptr;
    QTimer *m_broadcastTimer = nullptr;
    QTimer *m_peerCleanupTimer = nullptr;

    QString m_computerName;
    bool m_discoveryActive = false;

    QMap<QString, PeerInfo> m_peers;  // keyed by address:port

    // Sending state
    bool m_sending = false;
    int m_sendProgress = 0;
    int m_sendTotal = 0;

    // Receiving state
    bool m_receiving = false;
    int m_receiveProgress = 0;
    int m_receiveTotal = 0;
    QString m_receiveFolder;

    // Incoming transfer request
    QString m_incomingSender;
    int m_incomingFileCount = 0;
    qint64 m_incomingTotalSize = 0;
    QTcpSocket *m_pendingTransferSocket = nullptr;
};
