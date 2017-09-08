import uuid from './uuid';

class Realtime {

    active:boolean = false;

    private onConnectedCallbacks:Array<() => void> = [];

    private ortcClient:any = null;

    private subscriberIds:Map<string,string> = new Map();

    constructor() {

    } //constructor

    connect(apiKey:string, token:string = '_') {

        if (this.ortcClient != null) {
            this.disconnect();
        }

        this.ortcClient = (window as any).RealtimeMessaging.createClient();
        this.ortcClient.setClusterUrl('https://ortc-developers.realtime.co/server/ssl/2.1/');
        this.ortcClient.connect(apiKey, token);

        this.ortcClient.onConnected = () => {
            this.active = true;
            let callbacks = this.onConnectedCallbacks;
            this.onConnectedCallbacks = [];
            for (let cb of callbacks) {
                cb();
            }
        };

    } //connect

    disconnect() {

        if (!this.active) {
            this.onConnectedCallbacks.push(() => {
                this.disconnect();
            });
            return;
        }

        this.ortcClient.disconnect();
        this.ortcClient = null;

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
