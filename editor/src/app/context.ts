import { observe, ceramic, action, serialize, uuid } from 'utils';
import * as electron from 'electron';
import shortcuts from './shortcuts';
import { spawn } from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import { join } from 'path';
const electronApp = electron.remote.require('./app.js');

/** Track app info such as fullscreen, width, height, project path.. */
export class Context {

/// Properties

    @observe fullscreen:boolean = false;

    @observe width:number = 0;

    @observe height:number = 0;

    @observe serverPort:number = null;

    @observe ceramicReady:boolean = false;

    @observe draggingOver:boolean = false;

    @observe machineId:string = null;

    @observe connectionStatus:'pending'|'online'|'offline' = 'pending';

/// External commands versions

    @observe haxeVersion?:string;

    @observe gitVersion?:string;

/// Constructor

    constructor() {

        // Get electron window
        let appWindow = electron.remote.getCurrentWindow();

        // Get current state
        this.fullscreen = appWindow.isFullScreen();
        this.width = window.innerWidth;
        this.height = window.innerHeight;

        // Listen state changes
        const handleFullScreen = () => {
            this.fullscreen = appWindow.isFullScreen();
        };
        appWindow.addListener('enter-full-screen', handleFullScreen);
        appWindow.addListener('leave-full-screen', handleFullScreen);
        const handleClose = () => {
            appWindow.removeListener('enter-full-screen', handleClose);
            appWindow.removeListener('leave-full-screen', handleClose);
            appWindow.removeListener('close', handleClose);
        };
        appWindow.addListener('close', handleClose);
        let sizeTimeout:any = null;
        const handleResize = () => {
            if (sizeTimeout != null) clearTimeout(sizeTimeout);
            sizeTimeout = setTimeout(() => {
                sizeTimeout = null;
                this.width = window.innerWidth;
                this.height = window.innerHeight;
            }, 100);
        };
        window.addEventListener('resize', handleResize);
        window.addEventListener('orientationchange', handleResize);

        // Get server port
        const checkServerPort = () => {
            this.serverPort = electronApp.serverPort;
            if (this.serverPort == null) {
                setTimeout(checkServerPort, 100);
            }
        };
        checkServerPort();

        // Get machine identifier
        var dotCeramicDir = join(os.homedir(), '.ceramic');
        if (!fs.existsSync(dotCeramicDir)) {
            fs.mkdirSync(dotCeramicDir);
        }
        var idFilePath = join(dotCeramicDir, '.machine');
        if (!fs.existsSync(idFilePath)) {
            this.machineId = uuid();
            fs.writeFileSync(idFilePath, this.machineId);
        } else {
            this.machineId = ('' + fs.readFileSync(idFilePath)).trim();
        }
        
        // Default ceramic state is false
        this.ceramicReady = false;

        // Create menu/shortcuts
        shortcuts.initialize();

        // Check external commands status
        this.checkHaxeVersion();
        this.checkGitVersion();

        // Connection status
        setInterval(() => {
            if (navigator.onLine) {
                this.connectionStatus = 'online';
            }
            else {
                this.connectionStatus = 'offline';
            }
        }, 250);

    } //constructor

/// Commands version

    @action checkHaxeVersion() {

        // Check haxe
        var proc = spawn('haxe', ['-version']);
        proc.on('error', (error) => {
            console.error('Haxe command failed: ' + error);
        });
        var out = '';
        proc.stdout.on('data', (data) => {
            out += data;
        });
        proc.stderr.on('data', (data) => {
            out += data;
        });
        proc.on('close', (code) => {
            if (code === 0) {
                this.haxeVersion = out.trim();
            }
            else {
                this.haxeVersion = null;
            }
        });

    } //checkHaxeVersion
    
    @action checkGitVersion() {

        // Check git
        var proc = spawn('git', ['--version']);
        proc.on('error', (error) => {
            console.error('Git command failed: ' + error);
        });
        var out = '';
        proc.stdout.on('data', (data) => {
            out += data;
        });
        proc.stderr.on('data', (data) => {
            out += data;
        });
        proc.on('close', (code) => {
            if (code === 0) {
                this.gitVersion = out.trim().split('git version ').join('');
            }
            else {
                this.gitVersion = null;
            }
        });

    } //checkGitVersion

} //Context

export const context = new Context();
