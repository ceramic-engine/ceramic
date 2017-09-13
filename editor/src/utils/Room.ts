import { realtime } from './realtime';
import uuid from './uuid';
import { autobind } from 'utils';
import SimplePeer from 'simple-peer';
import { EventEmitter } from 'events';

/** WebRTC peer */
export interface WebrtcPeer extends SimplePeer.Instance {}

export class Peer extends EventEmitter {

/// Properties

    /** WebRTC peer */
    webrtcPeer:WebrtcPeer = null;

    /** WebRTC ready? */
    webrtcReady:boolean = false;

    /** Remote client id */
    remoteClient:string = null;

    /** Destroyed? */
    destroyed:boolean = false;

    /** Remote peer alive since... */
    remotePeerAliveSince:number = -1;

    /** Room */
    room:Room = null;

    /** On message custom callback */
    onMessage:(message:string) => void = null;

/// Lifecycle

    constructor(room:Room, remoteClient:string) {

        super();

        console.log('%cCREATE PEER ' + remoteClient, 'color: #FF0000');

        this.remoteClient = remoteClient;
        this.room = room;
        this.room.peers.set(remoteClient, this);
        this.remotePeerAliveSince = new Date().getTime();

        // Emit connect event as the peer is now ready to communicate,
        // At least through realtime.co, then Web RTC if possible.
        setImmediate(() => {
            if (this.destroyed) return;
            
            this.room.emit('connect', this, this.remoteClient);
        });

        // Send an `alive` paquet at a regular interval and
        // expect the remote peer to respond to do the same.
        // If one of the peers didn't receive any `alive` paquet
        // After a while, that means the connection is not valid
        // anymore and should be closed.
        let intervalId = setInterval(() => {
            if (this.destroyed) {
                clearInterval(intervalId);
                return;
            }

            // Check if connection is still valid
            let time = new Date().getTime();
            if (time - this.remotePeerAliveSince > 16000) {
                // Connection expired
                console.warn('Connection expired with peer: ' + this.remoteClient);
                this.destroy();
                return;
            }
            
            // Ok, let's continue to `ping` the remote peer
            this.sendInternal({
                type: 'alive',
                value: {
                    client: room.clientId
                }
            });

        }, 5000);

        this.sendInternal({
            type: 'alive',
            value: {
                client: room.clientId
            }
        });

    } //constructor

    destroy() {

        if (this.destroyed) return;
    
        this.destroyed = true;
        this.webrtcReady = false;

        let webrtcPeer = this.webrtcPeer;
        if (webrtcPeer) {
            this.webrtcPeer = null;
            webrtcPeer.destroy();
        }

        if (this.room.peers.get(this.remoteClient) === this) {
            this.room.peers.delete(this.remoteClient);
        }
        
        this.room.emit('close', this.remoteClient);

    } //destroy

/// Public API

    send(message:string) {

        this.sendInternal({
            type: 'message',
            value: {
                client: this.room.clientId,
                message: message
            }
        });

    } //send

    sendInternal(data:{type:string, value?:any}) {

        if (this.destroyed) return;

        let rawData = JSON.stringify(data);

        // If Web RTC is ready, use it to send the message
        if (this.webrtcPeer && this.webrtcReady) {
            console.log('%c-- send via webrtc --', 'color: #666666');
            this.webrtcPeer.send(rawData);
        }
        // Otherwise, fallback to realtime.co messaging
        else {
            console.log('%c-- send via realtime.co --', 'color: #666666');
            realtime.send(this.room.roomId + ':' + this.remoteClient, rawData);
        }

    } //sendRaw

/// Internal API

    configureWebrtcPeer() {

        if (this.destroyed) return;

        let roomId = this.room.roomId;
        let remoteClient = this.remoteClient;
        let webrtcPeer = this.webrtcPeer;
        if (!webrtcPeer) {
            throw 'Cannot configure WebRTC peer if it doesn\' exist';
        }

        webrtcPeer.on('signal', (signal) => {
            // Send signaling data to client we want to connect to
            realtime.send(roomId + ':' + remoteClient, JSON.stringify({
                type: 'signal',
                value: {
                    client: this.room.clientId,
                    signal: signal
                }
            }));
        });

        webrtcPeer.on('connect', () => {
            // Let locally know about the new connection
            this.webrtcReady = true;
            this.emit('webrtc-connect', webrtcPeer, remoteClient);
        });

        webrtcPeer.on('close', () => {
            // Let locally know about the new connection
            this.emit('webrtc-close', webrtcPeer, remoteClient);

            // Unmap
            if (this.webrtcPeer === webrtcPeer) {
                this.webrtcPeer = null;
                this.webrtcReady = false;
            }

            // Destroy
            webrtcPeer.removeAllListeners();
            webrtcPeer.destroy();
        });

        webrtcPeer.on('data', (rawData) => {
            // Receive data
            console.log('%c-- receive via webrtc --', 'color: #666666');
            this.emit('webrtc-data', rawData, webrtcPeer, remoteClient);

            let data = JSON.parse('' + rawData);
            if (data.type === 'message') {
                let message = data.value.message;
                if (this.onMessage) this.onMessage(message);
                this.emit('message', message);
            }
            else if (data.type === 'alive') {
                this.remotePeerAliveSince = new Date().getTime();
            }
        });

    } //configurePeer

    handleRealtimeMessage(message:string) {

        if (this.destroyed) return;
            
        if (this.onMessage) this.onMessage(message);
        this.emit('message', message);

    } //handleRealtimeMessage

    handleRealtimeAlive() {

        if (this.destroyed) return;

        this.remotePeerAliveSince = new Date().getTime();

    } //handleRealtimeAlive

} //Peer

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
    peers:Map<string, Peer> = new Map();

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
                    if (p != null && p.webrtcPeer != null) {
                        // Update peer signal
                        p.webrtcPeer.signal(data.value.signal);
                    }
                    else {
                        // Create (or reuse) peer and set the signal
                        if (p == null) {
                            p = new Peer(this, remoteClient);
                        }

                        // Create WebRTC peer
                        p.webrtcPeer = new SimplePeer({
                            config: this.peerConfig
                        });

                        p.configureWebrtcPeer();
                        p.webrtcPeer.signal(signal);
                    }
                }
                else if (data.type === 'reply') {
                    // A reply to an enter event
                    let remoteClient = data.value.client;
                    if (remoteClient === this.clientId) return; // This is us

                    // Get or create peer
                    let p = this.peers.get(remoteClient);
                    if (p == null) {
                        p = new Peer(this, remoteClient);
                    }

                    // We receive a reply because we should initiate the connection,
                    // But check again before doing so, then do it.
                    let clients = [this.clientId, remoteClient];
                    clients.sort();
                    if (clients[0] === this.clientId) {
                        // Yes, initiate a new P2P connection (if not any yet)
                        if (!p.webrtcPeer) {
                            p.webrtcPeer = new SimplePeer({
                                initiator: true,
                                config: this.peerConfig
                            });
                            p.configureWebrtcPeer();
                        }
                    }
                }
                else if (data.type === 'message') {
                    let remoteClient = data.value.client;
                    let message = data.value.message;

                    let p = this.peers.get(remoteClient);
                    if (p) {
                        p.handleRealtimeMessage(message);
                    }
                    else {
                        console.warn('Received realtime message from unmapped peer: ' + remoteClient);
                    }
                }
                else if (data.type === 'alive') {
                    let remoteClient = data.value.client;

                    let p = this.peers.get(remoteClient);
                    if (p) {
                        p.handleRealtimeAlive();
                    }
                    else {
                        console.warn('Received realtime alive from unmapped peer: ' + remoteClient);
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
                        console.log('%cINITIATE CONNECTION', 'color: #FF00FF');
                        // Yes, initiate a new P2P connection
                        let p = this.peers.get(remoteClient);
                        if (p == null) {
                            p = new Peer(this, remoteClient);
                        }
                        if (!p.webrtcPeer) {
                            p.webrtcPeer = new SimplePeer({
                                initiator: true,
                                config: this.peerConfig
                            });
                            p.configureWebrtcPeer();
                        }
                    }
                    else if (data.type === 'enter') {
                        console.log('%cREPLY', 'color: #FF00FF');
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

} //Room
