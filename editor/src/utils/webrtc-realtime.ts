import { realtime } from './realtime';
import uuid from './uuid';
import SimplePeer from 'simple-peer';
import { EventEmitter } from 'events';

/** Web RTC utility using Realtime.co to let peers know about each others */
class WebRTCRealtime extends EventEmitter {

    clientId:string = uuid();

    peers:Map<string, SimplePeer.Instance> = new Map();

    connect(room:string) {

        // Connect to the webrtc room
        // (a room is just a concept to tell:
        // multiple peers communicate in the same room)
        realtime.subscribe(room + ':' + this.clientId, (message, id) => {

            // Receive info about other clients
            try {
                let data = JSON.parse(message);

                if (data.type === 'signal') {
                    let remoteClient = data.value.client;
                    let signal = data.value.signal;

                    // Received an updated signal / an offer to connect
                    let p = this.peers.get(room + ':' + remoteClient);
                    if (p != null) {
                        // Update peer signal
                        p.signal(data.value.signal);
                    }
                    else {
                        // Create new peer and set the signal
                        p = new SimplePeer();
                        this.configurePeer(p, room, remoteClient);
                        p.signal(signal);
                    }
                }
            }
            catch (e) {
                console.error(e);
            }

        });
        realtime.subscribe(room, (message, id) => {

            // Receive info about other clients
            try {
                let data = JSON.parse(message);

                if (data.type === 'enter' && !this.peers.has(room + ':' + data.value.client)) {
                    let remoteClient = data.value.client;

                    // Receive a new client's info,
                    // Initiate a new P2P connection
                    let p = new SimplePeer({
                        initiator: true
                    });
                    this.configurePeer(p, room, remoteClient);

                    // Keep peer instance and map it to the couple room + client id
                    this.peers.set(room + ':' + remoteClient, p);
                }
            }
            catch (e) {
                console.error(e);
            }

        });

        // Let others in the room know about us
        realtime.send(room, JSON.stringify({
            type: 'enter',
            value: {
                client: this.clientId
            }
        }));

    } //connect

/// Internal

    private configurePeer(p:SimplePeer.Instance, room:string, remoteClient:string) {

        p.on('signal', (signal) => {
            // Send signaling data to client we want to connect to
            realtime.send(room + ':' + remoteClient, JSON.stringify({
                type: 'signal',
                value: {
                    client: this.clientId,
                    signal: signal
                }
            }));
        });

        p.on('connect', () => {
            // Let locally know about the new connection
            this.emit('connect', room, remoteClient);
        });

        p.on('data', (data) => {
            // Receive data
            this.emit('data', room, remoteClient, data);
        });

    } //configurePeer

} //WebRTCRealtime

export const webrtc = new WebRTCRealtime();
