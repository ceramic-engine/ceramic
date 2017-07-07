import { observe } from 'utils';
import * as electron from 'electron';

/** Track app info such as fullscreen, width, height.. */
export class Context {

/// Properties

    @observe fullscreen:boolean;

    @observe width:number;

    @observe height:number;

    @observe serverPort:number;

/// Constructor

    constructor() {

        // Get electron window
        let appWindow = electron.remote.getCurrentWindow();

        // Get current state
        this.fullscreen = appWindow.isFullScreen();
        this.width = window.innerWidth;
        this.height = window.innerHeight;

        // Listen state changes
        appWindow.on('enter-full-screen', () => {
            this.fullscreen = appWindow.isFullScreen();
        });
        appWindow.on('leave-full-screen', () => {
            this.fullscreen = appWindow.isFullScreen();
        });
        window.addEventListener('resize', () => {
            this.width = window.innerWidth;
            this.height = window.innerHeight;
        });
        window.addEventListener('orientationchange', () => {
            this.width = window.innerWidth;
            this.height = window.innerHeight;
        });

        // Get server port
        let electronApp = electron.remote.require('./ElectronApp');
        const checkServerPort = () => {
            this.serverPort = electronApp.serverPort;
            if (this.serverPort == null) {
                setTimeout(checkServerPort, 500);
            }
        };
        checkServerPort();

    } //constructor

} //Context

export const context = new Context();
