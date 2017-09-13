import { realtime } from './realtime';
import uuid from './uuid';
import { autobind } from 'utils';
import SimplePeer from 'simple-peer';
import { EventEmitter } from 'events';

export interface Peer extends SimplePeer.Instance {}

/** Utility built with realtime.co + webrtc to let peers
    communicate with each others inside a common `room` */
export class Room extends EventEmitter {

/// Public properties

    /** The value that identifies us as a client */
    clientId:string = uuid();

    /** The shared room identifier. If multiple clients use the same room id,
        they will be able to communicate with each others. */
    roomId:string = null;

/// Internal properties

    /** Mapping of (webrtc) peers by client id. */
    private peers:Map<string, Peer> = new Map();

    /** Simple-peer (webrtc) config used internally */
    private peerConfig = {
        iceServers: [
            {
                url: 'stun:stun.l.google.com:19302'
            }
        ]
    };

/// Lifecycle

    constructor(roomId:string, clientId?:string) {

        super();

        // Setup room id
        this.roomId = roomId;

        // Setup client id
        if (clientId) {
            this.clientId = clientId;
        }
        else {
            this.clientId = uuid();
        }

        console.log('%cREALTIME subscribe ' + roomId + ':' + this.clientId, 'color: #0000FF');
        console.log('%cREALTIME subscribe ' + roomId, 'color: #0000FF');

        // Add listener to re-send `enter` event in case we were disconnected
        realtime.addListener('reconnect', this.onRealtimeReconnect);

        // Use realtime as a signaling server to let clients know about each others
        realtime.subscribe(roomId + ':' + this.clientId, (message, id) => {

            // Receive info about other clients
            try {
                let data = JSON.parse(message);

                if (data.type === 'signal') {
                    let remoteClient = data.value.client;
                    let signal = data.value.signal;

                    if (remoteClient === this.clientId) return; // This is us

                    // Received an updated signal / an offer to connect
                    let p = this.peers.get(remoteClient);
                    if (p != null) {
                        // Update peer signal
                        p.signal(data.value.signal);
                    }
                    else {
                        // Create new peer and set the signal
                        p = new SimplePeer({
                            config: this.peerConfig
                        });

                        // Keep peer instance and map it to the couple roomId + client id
                        this.peers.set(remoteClient, p);

                        this.configurePeer(p, remoteClient);
                        p.signal(signal);
                    }
                }
                else if (data.type === 'reply') {
                    // A reply to an enter event
                    let remoteClient = data.value.client;
                    if (remoteClient === this.clientId) return; // This is us

                    // We receive a reply because we should initiate the connection,
                    // But check again before doing so, then do it.
                    let clients = [this.clientId, remoteClient];
                    clients.sort();
                    if (clients[0] === this.clientId) {
                        // Yes, initiate a new P2P connection
                        let p = new SimplePeer({
                            initiator: true,
                            config: this.peerConfig
                        });
                        this.configurePeer(p, remoteClient);
                    }
                }
            }
            catch (e) {
                console.error(e);
            }

        });
        realtime.subscribe(roomId, (message, id) => {

            // Receive info about other clients
            try {
                let data = JSON.parse(message);

                if ((data.type === 'enter' || data.type === 'reply') && !this.peers.has(data.value.client)) {
                    let remoteClient = data.value.client;
                    if (remoteClient === this.clientId) return; // This is us

                    console.log('%cRECEIVE ' + data.type + ' EVENT', 'color: #FF00FF');

                    // Should we initiate this connection?
                    let clients = [this.clientId, remoteClient];
                    clients.sort();
                    if (clients[0] === this.clientId) {
                        // Yes, initiate a new P2P connection
                        let p = new SimplePeer({
                            initiator: true,
                            config: this.peerConfig
                        });
                        this.configurePeer(p, remoteClient);
                    }
                    else if (data.type === 'enter') {
                        // No, then just reply to this client
                        // to let it initiate the connection
                        realtime.send(roomId + ':' + remoteClient, JSON.stringify({
                            type: 'reply',
                            value: {
                                client: this.clientId
                            }
                        }));
                    }
                }
            }
            catch (e) {
                console.error(e);
            }

        });

        // Let others in the roomId know about us
        realtime.send(roomId, JSON.stringify({
            type: 'enter',
            value: {
                client: this.clientId
            }
        }));

    } //constructor

    destroy() {

        // Unsubscribe from realtime
        realtime.unsubscribe(this.roomId);
        realtime.unsubscribe(this.roomId + ':' + this.clientId);
        realtime.removeListener('reconnect', this.onRealtimeReconnect);

        // Close all peers
        let allPeers = [];
        for (let remoteClient in this.peers.keys()) {
            let peer = this.peers.get(remoteClient);
            allPeers.push(peer);
        }
        this.peers = new Map();
        for (let peer of allPeers) {
            peer.destroy();
        }

        // Remove events
        this.removeAllListeners();

    } //destroy

/// Internal

    @autobind private onRealtimeReconnect() {

        // Let others in the roomId know about us,
        // again as we just reconnected
        realtime.send(this.roomId, JSON.stringify({
            type: 'enter',
            value: {
                client: this.clientId
            }
        }));

    } //onRealtimeReconnect

    private configurePeer(p:Peer, remoteClient:string) {

        // Map
        this.peers.set(remoteClient, p);

        p.on('signal', (signal) => {
            // Send signaling data to client we want to connect to
            realtime.send(this.roomId + ':' + remoteClient, JSON.stringify({
                type: 'signal',
                value: {
                    client: this.clientId,
                    signal: signal
                }
            }));
        });

        p.on('connect', () => {
            // Let locally know about the new connection
            this.emit('connect', p, remoteClient);
        });

        p.on('close', () => {
            // Let locally know about the new connection
            this.emit('close', p, remoteClient);

            // Unmap
            if (this.peers.get(remoteClient) === p) {
                this.peers.delete(remoteClient);
            }

            // Destroy
            p.removeAllListeners();
            p.destroy();
        });

        p.on('data', (data) => {
            // Receive data
            this.emit('data', data, p, remoteClient);
        });

    } //configurePeer

} //Room
