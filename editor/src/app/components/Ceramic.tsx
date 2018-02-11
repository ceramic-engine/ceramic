import * as React from 'react';
import { observer, observe, autorun, uuid, autobind, ceramic, history, serializeModel } from 'utils';
import { context } from 'app/context';
import { project, FragmentItem } from 'app/model';
import { IReactionDisposer } from 'mobx';
import { join } from 'path';
import { readFileSync, existsSync } from 'fs';

export interface Message {

    type:string;

    value?:any;

} //Message

@observer class Ceramic extends React.Component {

    @observe ready:boolean = false;

    elementId:string = 'ceramic-' + uuid();

    mounted:boolean = false;

    private responseHandlers:Map<string, (message:Message) => void> = new Map();

    private messageListeners:Map<string, Array<(message:Message) => void>> = new Map();

/// Lifecycle

    componentDidMount() {

        // Flag as mounted
        this.mounted = true;
        ceramic.component = this;

        // Load script when server port is ready
        let unbind = autorun(() => {

            if (context.serverPort != null) {

                (window as any)._ceramicBaseUrl = "http://localhost:" + context.serverPort;

                const script = document.createElement("script");
                let url = "http://localhost:" + context.serverPort + "/ceramic/FragmentEditor.js";
                if (project.absolutePreviewPath != null) {
                    let indexPath = join(project.absolutePreviewPath, 'index.html');
                    if (existsSync(indexPath)) {
                        let data = '' + readFileSync(indexPath);
                        let m = data.match(/<script[^>]+src="([^"]+)"/);
                        url = "http://localhost:" + context.serverPort + '/' + join("ceramic", m[1]);
                    }
                }
                script.src = url;
                script.async = true;

                document.body.appendChild(script);

                setImmediate(() => unbind());

                let usedPreviewPath = project.absolutePreviewPath;
                autorun(() => {

                    if (project.absolutePreviewPath !== usedPreviewPath && !project.ui.editSettings) {
                        window.location.reload();
                    }

                });
            }

        });

        // Add listener to receive message
        (window as any)._ceramicComponentSend = this.receiveRawMessage;

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

        return (
            <div
                id="ceramic-editor-view"
                style={{
                    width: '100%',
                    height: '100%',
                    border: 'none',
                    visibility: this.ready && !context.needsReload ? 'visible' : 'hidden'
                }}
            />
        );

    } //render

/// Messages

    @autobind receiveRawMessage(event:any) {

        /*// Check origin
        if (event.origin !== "http://localhost:" + context.serverPort) {
            console.error('wrong origin');
            return;
        }

        // Check iframe
        const iframe = document.getElementById(this.elementId) as HTMLIFrameElement;
        if (event.source !== iframe.contentWindow) {
            console.error('Received message from invalid window');
            return;
        }*/

        // Decode message
        try {
            const message = JSON.parse(event.data) as Message;

            // Ready?
            if (message.type === 'pong') {
                if (!this.ready) {
                    this.ready = true;
                    context.ceramicReady = true;
                    console.log('%cMessaging with ' + this.elementId + ' is ready', 'color: #0000FF');

                    this.handleReady();
                }
                return;
            }
            if (!this.ready) return;

            // Handle with respond handler (if any)
            let handler = this.responseHandlers.get(message.type);
            if (handler) {
                this.responseHandlers.delete(message.type);
                handler(message);
            }

            // Notify listeners
            var keys = [message.type];
            var parts = message.type.split('/');
            for (let i = parts.length - 1; i >= 0; i--) {
                parts[i] = '*';
                if (i < parts.length - 1) {
                    parts.pop();
                }
                keys.push(parts.join('/'));
            }
            for (let pattern of keys) {
                let listeners = this.messageListeners.get(pattern);
                if (listeners != null) {
                    for (let listener of listeners) {
                        listener(message);
                    }
                }
            }
 
        } catch (e) {
            console.error(e);
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
        /*const iframe = document.getElementById(this.elementId) as HTMLIFrameElement;
        iframe.contentWindow.postMessage(
            JSON.stringify(message),
            "http://localhost:" + context.serverPort
        );*/
        let ceramicEditor = (window as any)._ceramicEditor;
        if (ceramicEditor != null && ceramicEditor.send != null) {
            ceramicEditor.send({
                data: JSON.stringify(message),
                origin: "http://localhost:" + context.serverPort,
                source: window
            });
        }

    } //send

    handleReady() {

        // Run ready callbacks
        let callbacks = ceramic.onReadyCallbacks;
        ceramic.onReadyCallbacks = [];
        for (let cb of callbacks) {
            cb();
        }

        // Start history
        history.start();

        // Watch fragment && items
        let fragmentInCeramic:string = null;
        let itemsInCeramic = new Map<FragmentItem, IReactionDisposer>();
        autorun(() => {

            let fragment = project.ui.selectedFragment;

            // Don't load any fragment if project is not ready
            let projectReady = project.ready;
            if (!projectReady) {
                fragment = null;
            }

            if (fragment != null) {
                fragmentInCeramic = fragment.id;
                this.send({
                    type: 'fragment/put',
                    value: fragment.serializeForCeramic()
                });
            }
            else {
                if (fragmentInCeramic != null) {
                    this.send({
                        type: 'fragment/delete',
                        value: {
                            id: fragmentInCeramic,
                        }
                    });
                    fragmentInCeramic = null;
                }
            }
        });
        autorun(() => {

            let fragment = project.ui.selectedFragment;

            // Don't load any fragment if project is not ready
            let projectReady = project.ready;
            if (!projectReady) {
                fragment = null;
            }

            if (fragment != null) {
                if (!fragmentInCeramic) {
                    fragmentInCeramic = fragment.id;
                    this.send({
                        type: 'fragment/put',
                        value: fragment.serializeForCeramic()
                    });
                }

                let itemsToKeep = new Map<FragmentItem, boolean>();
                for (let item of fragment.items) {
                    itemsToKeep.set(item, true);

                    if (!itemsInCeramic.has(item)) {

                        // Add item and watch for changes
                        itemsInCeramic.set(item, autorun(() => {
                            this.send({
                                type: 'fragment-item/put',
                                value: item.serializeForCeramic()
                            });
                        }));
                    }
                }

                itemsInCeramic.forEach((_, item) => {

                    if (!itemsToKeep.has(item)) {
                        // Stop watching item
                        itemsInCeramic.get(item)();
                        // Remove item
                        itemsInCeramic.delete(item);
                        this.send({
                            type: 'fragment-item/delete',
                            value: {
                                id: item.id
                            }
                        });
                    }

                });

            }

        });

        // Selected item
        autorun(() => {

            if (project.ui.selectedItem != null) {
                // Select item
                this.send({
                    type: 'fragment-item/select',
                    value: {
                        id: project.ui.selectedItem.id
                    }
                });
            }
            else {
                // Deselect
                this.send({
                    type: 'fragment-item/select',
                    value: null
                });
            }

        });

    } //handleReady

    listen(typePattern:string, listener?:(message:Message) => void) {

        let listeners:Array<(message:Message) => void> = this.messageListeners.get(typePattern);
        if (listeners == null) {
            listeners = [];
            this.messageListeners.set(typePattern, listeners);
        }

        listeners.push(listener);

    } //listen

    removeListener(typePattern:string, listener?:(message:Message) => void) {

        let listeners:Array<(message:Message) => void> = this.messageListeners.get(typePattern);
        if (listeners != null) {
            let index = listeners.indexOf(listener);
            if (index !== -1) {
                if (listeners.length === 1) {
                    this.messageListeners.delete(typePattern);
                } else {
                    listeners.splice(index, 1);
                }
            }
        }

    } //removeListener
    
}

export default Ceramic;
