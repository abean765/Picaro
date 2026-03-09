#pragma once

#include <QAbstractListModel>
#include "NetworkManager.h"

class PeerModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY peersChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        AddressRole,
        PortRole
    };

    explicit PeerModel(QObject *parent = nullptr)
        : QAbstractListModel(parent)
    {
    }

    void setNetworkManager(NetworkManager *mgr)
    {
        m_mgr = mgr;
        connect(m_mgr, &NetworkManager::peersChanged, this, &PeerModel::refresh);
        refresh();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        Q_UNUSED(parent);
        return m_peers.size();
    }

    int count() const { return m_peers.size(); }

    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override
    {
        if (!index.isValid() || index.row() >= m_peers.size())
            return {};

        const auto &peer = m_peers.at(index.row());
        switch (role) {
        case NameRole: return peer.toMap().value(QStringLiteral("name"));
        case AddressRole: return peer.toMap().value(QStringLiteral("address"));
        case PortRole: return peer.toMap().value(QStringLiteral("port"));
        default: return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {NameRole, "peerName"},
            {AddressRole, "peerAddress"},
            {PortRole, "peerPort"}
        };
    }

signals:
    void peersChanged();

private slots:
    void refresh()
    {
        beginResetModel();
        m_peers = m_mgr ? m_mgr->peers() : QVariantList{};
        endResetModel();
        emit peersChanged();
    }

private:
    NetworkManager *m_mgr = nullptr;
    QVariantList m_peers;
};
