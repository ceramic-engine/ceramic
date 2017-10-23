import { spawn } from 'child_process';
import { join, normalize } from 'path';
import * as fs from 'fs';
import * as electron from 'electron';
const electronApp = electron.remote.require('./app.js');

interface Message {

    type:string;

    value?:any;

} //Message

/** Utility taking advantage of shared Ceramic component to send/receive messages. */
class CeramicProxy {

    component:any;

    onReadyCallbacks:Array<() => void> = [];

    private ceramicRunning:boolean = false;

    send(message:Message, responseHandler?:(message:Message) => void) {

        if (this.component && this.component.ready) {
            this.component.send(message, responseHandler);
        }
        else {
            // If component is not ready, wait
            setTimeout(() => {
                this.send(message, responseHandler);
            }, 100);
        }

    } //send

    /** Listen to the given message type pattern. Returns an unbind function. */
    listen(typePattern:string, listener?:(message:Message) => void):() => void {

        if (this.component && this.component.ready) {
            this.component.listen(typePattern, listener);
        }
        else {
            // If component is not ready, wait until ready
            this.onReadyCallbacks.push(() => {
                this.listen(typePattern, listener);
            });
        }

        let removeListener = () => {
            if (this.component && this.component.ready) {
                this.component.removeListener(typePattern, listener);
            }
            else {
                // If component is not ready, wait until ready
                this.onReadyCallbacks.push(() => {
                    removeListener();
                });
            }
        };

        return removeListener;

    } //listen

    /** Run a ceramic CLI instance with the given args and cwd */
    run(args:Array<string>, cwd:string, done:(code:number, out:string, err:string)=>void):void {

        if (this.ceramicRunning) {
            setTimeout(() => {
                this.run(args, cwd, done);
            }, 100);
            return;
        }
        this.ceramicRunning = true;

        if (args == null) args = [];
        else args = [].concat(args);
        if (cwd == null) throw 'cwd is required';

        let cmd = 'ceramic';

        if (process.platform === 'darwin') {
            if (electronApp.electronDev) {
                let electronPath = join(process.cwd(), 'node_modules/.bin/electron');
                cmd = electronPath;
                args.unshift('ceramic');
                args.unshift('.');
            } else {
                let macElectronPath = join(__dirname, '../../MacOS/Ceramic');
                if (fs.existsSync(macElectronPath)) {
                    cmd = macElectronPath;
                    args.unshift('ceramic');
                }
                else {
                    let macGlobalPath = '/usr/local/bin/ceramic';
                    if (fs.existsSync(macGlobalPath)) {
                        cmd = macGlobalPath;
                    }
                }
            }
        }
        else if (process.platform === 'win32') {
            // TODO handle packaged windows app
            if (electronApp.electronDev) {
                let electronPath = join(process.cwd(), 'node_modules/.bin/electron');
                cmd = electronPath;
                args.unshift('ceramic');
                args.unshift('.');
            } else {
                let linkedCeramic = normalize('C:/HaxeToolkit/haxe/ceramic.bat');
                if (fs.existsSync(linkedCeramic)) {
                    cmd = linkedCeramic;
                }
                /*else {
                    cmd = 'cmd';
                    args = ['/c', 'ceramic'].concat(args);
                }*/
            }
        }

        let proc = spawn(cmd, args, { cwd: cwd } );
        
        var out = '';
        var err = '';

        proc.stdout.on('data', (data) => {
            out += data;
        });

        proc.stderr.on('data', (data) => {
            err += data;
        });

        proc.on('error', (err) => {
            console.error('Error when running ceramic command: ' + err);
        });

        proc.on('close', (code) => {
            if (code !== 0) {
                if (err.trim().length > 0) {
                    console.warn(err);
                }
                console.error('Finished ceramic command with code: ' + code);
            }
            if (out.trim().length > 0) {
                console.log(out);
            }
            this.ceramicRunning = false;
            done(code, out, err);
        });

    } //run

}

export const ceramic = new CeramicProxy();
