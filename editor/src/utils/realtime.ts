import uuid from './uuid';
import { EventEmitter } from 'events';

class Realtime extends EventEmitter {

    active:boolean = false;

    apiKey:string = null;

    private onConnectedCallbacks:Array<() => void> = [];

    private ortcClient:any = null;

    private subscriberIds:Map<string,string> = new Map();

    constructor() {

        super();

    } //constructor

    connect(apiKey:string, token:string = '_') {

        if (this.ortcClient != null) {
            this.disconnect(true);
        }

        this.apiKey = apiKey;

        this.ortcClient = (window as any).RealtimeMessaging.createClient();
        this.ortcClient.setClusterUrl('https://ortc-europe.realtime.co/server/ssl/2.1');
        this.ortcClient.connect(apiKey, token);

        this.ortcClient.onConnected = () => {
            this.active = true;
            let callbacks = this.onConnectedCallbacks;
            this.onConnectedCallbacks = [];
            for (let cb of callbacks) {
                cb();
            }

            setImmediate(() => {
                this.emit('connect');
            });
        };

        this.ortcClient.onDisconnected = () => {
            this.active = false;

            this.emit('disconnect');
        };

        this.ortcClient.onReconnected = () => {
            this.active = true;
            let callbacks = this.onConnectedCallbacks;
            this.onConnectedCallbacks = [];
            for (let cb of callbacks) {
                cb();
            }

            this.emit('reconnect');
        };

    } //connect

    disconnect(force:boolean = false) {

        if (!this.active && !force) {
            this.onConnectedCallbacks.push(() => {
                this.disconnect();
            });
            return;
        }

        if (this.ortcClient) {
            this.ortcClient.disconnect();
            this.ortcClient = null;
        }

    } //disconnect

    subscribe(channel:string, callback:(message:string, id:string) => void) {

        if (!this.active) {
            this.onConnectedCallbacks.push(() => {
                this.subscribe(channel, callback);
            });
            return;
        }

        let subId = this.subscriberIds.get(channel);
        if (!subId) {
            subId = uuid();
            this.subscriberIds.set(channel, subId);
        }
        this.ortcClient.subscribeWithBuffer(channel, subId, (ortc:any, channel:string, seqId:string, message:string) => {
            callback(message, seqId);
        });

    } //subscribe

    unsubscribe(channel:string) {

        if (!this.active) {
            this.onConnectedCallbacks.push(() => {
                this.unsubscribe(channel);
            });
            return;
        }

        this.ortcClient.unsubscribe(channel);

    } //unsubscribe

    send(channel:string, message:string) {

        if (!this.active) {
            this.onConnectedCallbacks.push(() => {
                this.send(channel, message);
            });
            return;
        }

        this.ortcClient.publish(channel, message, 120, (err:any, seqId:string) => {
            if (err) {
                console.error(err);
            }
        });

    } //send

}

export const realtime = new Realtime();
