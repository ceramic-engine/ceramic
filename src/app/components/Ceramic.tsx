import * as React from 'react';
import { observer, observe, autorun, uuid, autobind, ceramic, serializeModel } from 'utils';
import { context } from 'app/context';
import { project } from 'app/model';

export interface Message {

    type:string;

    value?:any;

} //Message

@observer class Ceramic extends React.Component {

    @observe ready:boolean = false;

    elementId:string = 'ceramic-' + uuid();

    mounted:boolean = false;

    private responseHandlers:Map<String, (message:Message) => void> = new Map();

/// Lifecycle

    componentDidMount() {

        // Flag as mounted
        this.mounted = true;
        ceramic.component = this;

        // Add listener to receive message
        window.addEventListener('message', this.receiveRawMessage);

        const emitPing = () => {

            // Don't do anything until a server port is defined
            if (context.serverPort == null) return;

            // Ready? No need to ping anymore
            if (this.ready) return;

            // Unmounted? Nothing to do either
            if (!this.mounted) return;

            // Send ping
            this.send({type: 'ping'});

            // Check/try again in 0.5s
            setTimeout(emitPing, 500);
        };

        // Try to reach iframe window
        setTimeout(emitPing, 500);

    } //componentDidMount

    componentWillUnmount() {

        // Flag as unmounted
        this.mounted = false;
        if (ceramic.component === this) {
            delete ceramic.component;
            context.ceramicReady = false;
        }

        // Remove message listener
        window.removeEventListener('message', this.receiveRawMessage);

    } //componentWillUnmount

    render() {

        if (context.serverPort == null) {
            return null;
        }
        else {
            return (
                <iframe
                    id={this.elementId}
                    src={"http://localhost:" + context.serverPort + "/ceramic"}
                    frameBorder={0}
                    scrolling="no"
                    sandbox="allow-scripts allow-popups allow-same-origin"
                    style={{
                        width: '100%',
                        height: '100%',
                        border: 'none',
                        visibility: this.ready ? 'visible' : 'hidden'
                    }}
                />
            );
        }

    } //render

/// Messages

    @autobind receiveRawMessage(event:any) {

        // Check origin
        if (event.origin !== "http://localhost:" + context.serverPort) {
            console.error('wrong origin');
            return;
        }

        // Check iframe
        const iframe = document.getElementById(this.elementId) as HTMLIFrameElement;
        if (event.source !== iframe.contentWindow) {
            console.error('Received message from invalid window');
            return;
        }

        // Decode message
        try {
            const message = JSON.parse(event.data) as Message;

            // Ready?
            if (message.type === 'pong') {
                if (!this.ready) {
                    this.ready = true;
                    context.ceramicReady = true;
                    console.debug('Messaging with ' + this.elementId + ' is ready');

                    this.handleReady();
                }
                return;
            }
            if (!this.ready) return;

            // Handle message
            let handler = this.responseHandlers.get(message.type);
            if (handler) {
                this.responseHandlers.delete(message.type);
                handler(message);
            }
 
        } catch (e) {
            console.error('Failed to decode ' + this.elementId + ' message: ' + event.data);
            return;
        }

    } //receiveMessage

    send(message:Message, responseHandler?:(message:Message) => void) {

        // Add handler, if any
        if (responseHandler) {
            this.responseHandlers.set(message.type, responseHandler);
        }

        // Send message to frame
        const iframe = document.getElementById(this.elementId) as HTMLIFrameElement;
        iframe.contentWindow.postMessage(
            JSON.stringify(message),
            "http://localhost:" + context.serverPort
        );

    } //send

    handleReady() {

        autorun(() => {

            if (project.scene != null) {
                this.send({
                    type: 'scene/put',
                    value: serializeModel(project.scene)
                });
            }
            else {
                this.send({
                    type: 'scene/delete',
                    value: {
                        name: 'scene',
                    }
                });
            }

        });

    } //handleReady

    sendDummyData() {

        this.send({
            type: 'scene/put',
            value: {
                name: 'scene',
                data: {},
                width: 320,
                height: 568,
                x: 640 / 2,
                y: 480 / 2,
                anchorX: 0.5,
                anchorY: 0.5,
                items: [
                    {
                        name: 'quad1',
                        entity: 'ceramic.Quad',
                        props: {
                            width: 120,
                            height: 50,
                            x: 320 / 2,
                            y: 568 / 2,
                            anchorX: 0.5,
                            anchorY: 0.5,
                            color: 0x2798EB,
                            skewX: 25
                        }
                    }
                ]
            }
        });

    } //sendDummyData
    
}

export default Ceramic;
