import * as React from 'react';
import { observer, uuid, autobind } from 'utils';
import { context } from 'app/context';

interface Message {

    type:string;

    value?:any;

} //Message

@observer class Ceramic extends React.Component {

    elementId:string = 'ceramic-' + uuid();

    ready:boolean = false;

    mounted:boolean = false;

/// Lifecycle

    componentDidMount() {

        // Flag as mounted
        this.mounted = true;

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
                    style={{ width: '100%', height: '100%', border: 'none' }}
                />
            );
        }

    } //render

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
                    console.debug('Messaging with ' + this.elementId + ' is ready');

                    this.sendDummyData(); // TODO remove
                }
                return;
            }
            if (!this.ready) return;

            // Handle message

        } catch (e) {
            console.error('Failed to decode ' + this.elementId + ' message: ' + event.data);
            return;
        }

    } //receiveMessage

    send(message:Message) {

        // Send message to frame
        const iframe = document.getElementById(this.elementId) as HTMLIFrameElement;
        iframe.contentWindow.postMessage(
            JSON.stringify(message),
            "http://localhost:" + context.serverPort
        );

    } //send

    sendDummyData() {

        this.send({
            type: 'scene/put',
            value: {
                name: 'myscene',
                data: {},
                width: 320,
                height: 568,
                x: 800 / 2,
                y: 600 / 2,
                anchorX: 0.5,
                anchorY: 0.5,
                items: [
                    {
                        name: 'quad1',
                        entity: 'ceramic.Quad',
                        props: {
                            width: 120,
                            height: 50,
                            x: 150,
                            y: 150,
                            anchorX: 0.5,
                            anchorY: 0.5,
                            color: 0xFF0000,
                            skewX: 25
                        }
                    }
                ]
            }
        });

    } //sendDummyData
    
}

export default Ceramic;
