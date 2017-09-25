import { serialize, observe, action, compute, files, autorun, ceramic, keypath, history, uuid, db, git, realtime, serializeModel, Model, Room, Peer } from 'utils';
import Scene from './Scene';
import SceneItem from './SceneItem';
import UiState from './UiState';
import * as fs from 'fs';
import * as electron from 'electron';
import * as os from 'os';
import shortcuts from 'app/shortcuts';
import { join, normalize, dirname, relative, basename, isAbsolute } from 'path';
import { context } from 'app/context';
import { user } from './index';
import { spawn } from 'child_process';
import { createHash } from 'crypto';
import { ncp } from 'ncp';
import rimraf from 'rimraf';
import dateformat from 'dateformat';

export interface SyncWithGithubOptions {

    auto?:boolean;

    directions:'auto'|'remoteToLocal'|'localToRemote';

    targetCommit?:string;

    filesOnly?:boolean;

    syncDirNames?:Array<string>;

    branch?:string;

} //SyncWithGithubOptions

interface PeerMessage {

    /** The (unique) index of this message. Allows clients to keep strict message orders. */
    index:number;

    /** Message type */
    type:string;

    /** Message data */
    data?:any;

} //PeerMessage

interface PendingPeerMessage {

    /** The message itself */
    message:PeerMessage;

    /** Time when the message was sent */
    time:number;

    /** Number of attempts. When this number gets too high,
        we discard the message (all messages for this client)
        and mark the client as `expired`. In case the client reconnects later,
        He will have to make itself `up to date` before exchanging changesets. */
    attempts:number;

} //PendingPeerMessage

interface PeerMessageReceipt {

    /** Always to `true`, to identify receipt kinds */
    receipt:true;

    /** The message index we want to confirm its reception. */
    index:number;

} //PeerMessageReceipt

interface PendingChangeset {

    /** Changeset index (per client) */
    index:number;

    /** Related data */
    data:any;

    /** Target client id */
    targetClient:string;

    /** Redoing? */
    redoing?:{ owner:string, index:number, syncTimestamp:number };

    /** Undoing? */
    undoing?:{ owner:string, index:number, syncTimestamp:number };

} //PendingChangeset

class Project extends Model {

/// Properties

    /** Project hash (unique identifier) */
    @observe @serialize uuid:string;

    /** Project save timestamp */
    @observe @serialize saveTimestamp:number;

    /** Project scenes */
    @observe @serialize(Scene) scenes:Array<Scene> = [];

    /** Default scene bundle (name) */
    @observe @serialize defaultSceneBundle:string = null;

    /** Custom scene bundles (name) */
    @observe @serialize sceneBundles:Array<string> = [];

    /** Project error */
    @observe error?:string;

    /** Project name */
    @observe @serialize name?:string;

    /** Project footprint.
        The footprint is computed from local project's path and host machine identifier. */
    @observe @serialize footprint:string;

/// Editor canvas

    /** Project custom editor canvas path */
    @observe @serialize editorPath?:string;

    /** Identify the custom editor preview version with a hash */
    @observe @serialize editorHash?:string;

/// Git (Github) repository

    /** Whether the editor is currently syncing with Github repository (manual sync). */
    @observe manualSyncingWithGithub:boolean = false;

    /** Whether the editor is currently syncing with Github repository (auto sync). */
    @observe autoSyncingWithGithub:boolean = false;

    /** Whether the editor is currently syncing with Github repository. */
    @observe @serialize lastGithubSyncStatus:'success'|'failure' = null;

    /** Git repository (https) URL */
    @observe @serialize gitRepository?:string;

    /** Keep the (unix) timestamp of when this project was last synced with Github. */
    @observe @serialize lastGitSyncTimestamp?:number;

    /** Keep the git commit hash of when this project was last synced with Github. */
    @observe @serialize lastGitSyncCommitHash?:string;

    /** Keep last git sync footprint. */
    @observe @serialize lastGitSyncProjectFootprint?:string;

/// Realtime / Online

    @observe @serialize onlineEnabled:boolean = false;

    /** Last online project sync timestamp. Helps to know if we are up to date or not. */
    @observe lastOnlineSyncTimestamp:number = null;

    /** A flag that marks realtime as broken */
    @observe realtimeBroken:boolean = false;

    /** Our own client id. Generated at app startup. */
    @observe clientId:string = uuid();

    /** The room where every client/peer is connecting to. It's id is the same as the project's uuid. */
    @observe room:Room = null;

    /** List of connected peers (`us` is not included in this list) */
    @observe peers:Array<Peer> = [];

    /** Client ids that are confirmed to be up to date as far as we know.
        Only a peer which have its client id in this list can be considered master. */
    @observe upToDateClientIds:Map<string,boolean> = new Map();

    /** Is `true` if current project data is considered up to date.
        Project must be up to date before sending data to other peers. */
    @observe isUpToDate:boolean = false;

    /** Expired client ids. At this stage, we don't interact with them,
        unless we get them up to date again. */
    @observe expiredClientIds:Map<string,boolean> = new Map();

    /** Whether the realtime (realtime.co) connection itself is ready. */
    @observe realtimeConnected:boolean = false;

    /** Track the last index of message processed for each peer (client id) */
    @observe lastProcessedIndexByClientId:Map<string,number> = new Map();

    /** Keep received messages for each peer (client id) until they are processed */
    @observe receivedMessagesByClientId:Map<string,Map<number,PeerMessage>> = new Map();

    /** Track the last index of message sent to each peer (client id) */
    @observe lastSentIndexByClientId:Map<string,number> = new Map();

    /** Keep sent messages for each peer (client id) until we get a receipt from remote peer */
    @observe pendingMessagesByClientId:Map<string,Map<number,PendingPeerMessage>> = new Map();

    /** Changesets waiting to be validated by master */
    @observe pendingLocalChangesets:Array<PendingChangeset> = [];

    /** Next local changeset index */
    @observe nextLocalChangesetIndex:number = 0;

    /** Keep track of the master changeset index. We don't want to miss any */
    @observe lastProcessedChangesetIndexByClientId:Map<string,number> = new Map();

    /** Remote changesets waiting to be processed locally */
    @observe pendingRemoteChangesetsByClientId:Map<string, Map<number,PendingChangeset>> = new Map();

    /** When consuming a master changeset, this flag is set to `true`
        to prevent the changeset from being re-sent again in loop forever. */
    @observe processingMasterChangeset:boolean = false;

    /** When history is locked, no change will be added or removed automatically in it.
        Project data itself can still be changed. */
    @observe historyLocked:boolean = false;

    /** Currently consumed changeset index by master */
    @observe consumedChangesetIndexByMaster:number = null;

    /** Currently consumed client by master */
    @observe consumedClientByMaster:string = null;

    /** Index consumed by remote peers (client id) */
    @observe remoteConsumedChangesetByClientId:Map<string,number> = new Map();
    
/// UI State

    @observe @serialize ui:UiState;

/// Assets

    /** Assets path */
    @observe @serialize assetsPath?:string;

    /** Updating this value will force refresh of assets list */
    @observe assetsUpdatedAt:number;

    /** Sometimes, we want to lock assets lists, like when loading a project to prevent
        it from processing in-between values that don't make any sense. */
    @observe assetsLocked:boolean = false;

    /** All assets */
    @observe allAssets?:Array<string>;

    /** All asset directories */
    @observe allAssetDirs?:Array<string>;

    /** All assets by name */
    @observe allAssetsByName?:Map<string, Array<string>>;

    /** All asset directories */
    @observe allAssetDirsByName?:Map<string, Array<string>>;

    /** All assets paths as key with last modified date as value */
    @observe allAssetPathsLastModified?:Map<string, number>;

    /** Image assets */
    @observe imageAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

    /** Text assets */
    @observe textAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

    /** Sound assets */
    @observe soundAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

    /** Font assets */
    @observe fontAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

/// Raw files directory

    /** Raw files path */
    @observe @serialize rawFilesPath?:string;

/// Computed

    @compute get path():string {
        
        return user.projectPath;

    } //path

    @compute get initialized():boolean {
        
        return !!this.name;

    } //initialized

    @compute get absoluteAssetsPath():string {

        let path = this.assetsPath;

        if (!path) return null;

        if (isAbsolute(path)) return path;

        if (!this.path) {
            return null;
        }
        else {
            return normalize(join(dirname(this.path), path));
        }

    } //absoluteAssetsPath

    @compute get absoluteRawFilesPath():string {

        let path = this.rawFilesPath;

        if (!path) return null;

        if (isAbsolute(path)) return path;

        if (!this.path) {
            return null;
        }
        else {
            return normalize(join(dirname(this.path), path));
        }

    } //absoluteRawFilesPath
    
    @compute get absoluteEditorPath():string {

        let path = this.editorPath;

        if (!path) return null;

        if (isAbsolute(path)) return path;

        if (!this.path) {
            return null;
        }
        else {
            return normalize(join(dirname(this.path), path));
        }

    } //absoluteEditorPath
    
    @compute get hasValidEditorPath():boolean {

        let path = this.absoluteEditorPath;

        // TODO

        return false;

    } //hasValidEditorPath

    @compute get cwd():string {

        if (this.path) return dirname(this.path);
        return null;

    } //cwd

/// Lifecycle

    constructor(id?:string) {

        super(id);

        // Set db changes listener
        db.changesListener = this;

        // Bind realtime features
        this.bindRealtime();

        // Update status bar text
        //
        autorun(() => {

            if (!this.ui) return;

            let CtlrOrCmd = process.platform === 'darwin' ? 'Cmd' : 'Ctrl';
            
            if (this.gitRepository) {
                if (!user.githubToken) {
                    this.ui.statusBarTextKind = 'warning';
                    this.ui.statusBarText = '⚠ Set your Github Personal Access Token in settings';
                }
                else if (this.manualSyncingWithGithub || this.autoSyncingWithGithub) {
                    this.ui.statusBarTextKind = 'default';
                    this.ui.statusBarText = 'Synchronizing with Github repository \u2026';
                }
                else if (this.lastGithubSyncStatus === 'failure') {
                    this.ui.statusBarTextKind = 'failure';
                    this.ui.statusBarText = '✗ Failed to synchronize with Github';
                }
                else if (this.lastGithubSyncStatus === 'success') {
                    this.ui.statusBarTextKind = 'success';
                    this.ui.statusBarText = '✔ Synchronized with Github on ' + dateformat(this.lastGitSyncTimestamp * 1000);
                }
                else if (user.manualGithubProjectDirty) {
                    this.ui.statusBarTextKind = 'default';
                    this.ui.statusBarText = 'Press ' + CtlrOrCmd + '+Alt+S to synchronize with Github';
                }
                else {
                    this.ui.statusBarTextKind = 'default';
                    this.ui.statusBarText = '';
                }
            }
            else {
                this.ui.statusBarTextKind = 'default';
                this.ui.statusBarText = '';
            }
            
            if (this.onlineEnabled) {
                if (!user.realtimeApiKey) {
                    this.ui.statusBarBisTextKind = 'warning';
                    this.ui.statusBarBisText = '⚠ Set your Realtime token in settings';
                }
                else if (this.realtimeBroken) {
                    this.ui.statusBarBisTextKind = 'failure';
                    this.ui.statusBarBisText = '✗ Failed to connect to Realtime';
                }
                else if (!this.isUpToDate && !this.ui.editSettings) {
                    this.ui.statusBarBisTextKind = 'default';
                    this.ui.statusBarBisText = 'Updating\u2026';
                    this.ui.statusBarTextKind = 'default';
                    this.ui.statusBarText = '';
                }
                else if (this.realtimeConnected) {
                    this.ui.statusBarBisTextKind = 'success';
                    this.ui.statusBarBisText = '✔ Connected to Realtime messaging';
                }
                else {
                    this.ui.statusBarBisTextKind = 'default';
                    this.ui.statusBarBisText = '';
                }
            }
            else {
                this.ui.statusBarBisTextKind = 'default';
                this.ui.statusBarBisText = '';
            }

        });

        // Generate project footprint
        //
        autorun(() => {

            let projectPath = this.path;
            let machineId = context.machineId;

            if (!projectPath) return;
            if (!machineId) return;

            let hash = createHash('md5').update(projectPath + ' ~! ' + machineId).digest('hex');
            this.footprint = hash;

        });

        // Update asset info from assets path
        //
        autorun(() => {

            let updatedAt = this.assetsUpdatedAt;
            let electronApp = electron.remote.require('./app.js');

            if (this.assetsLocked) {
                electronApp.processingAssets = true;
                return;
            }

            electronApp.sourceAssetsPath = this.absoluteAssetsPath;
            electronApp.assetsPath = null;

            if (this.absoluteAssetsPath != null) {
                electronApp.processingAssets = true;
                let processedAssetsPath = join(os.tmpdir(), 'ceramic', this.id);
                let proc = ceramic.run([
                    'luxe', 'assets', 'web',
                    '--from', this.absoluteAssetsPath,
                    '--to', processedAssetsPath
                ], process.cwd(), (code, out, err) => {
                    if (code !== 0) {
                        console.error('Failed to process assets from ' + this.absoluteAssetsPath + ' to ' + processedAssetsPath + ' : ' + err);
                    }
                    else {
                        electronApp.assetsPath = processedAssetsPath;
                        electronApp.processingAssets = false;
                        console.log('assets path: ' + electronApp.assetsPath);
                    }
                });
            }

            if (!this.absoluteAssetsPath || !fs.existsSync(this.absoluteAssetsPath) || !fs.statSync(this.absoluteAssetsPath).isDirectory()) {
                this.imageAssets = null;
                this.textAssets = null;
                this.soundAssets = null;
                this.fontAssets = null;
                this.allAssets = null;
                this.allAssetDirs = null;
                this.allAssetsByName = null;
                this.allAssetDirsByName = null;
                return;
            }

            if (!context.ceramicReady) {
                this.imageAssets = [];
                this.textAssets = [];
                this.soundAssets = [];
                this.fontAssets = [];
                this.allAssets = [];
                this.allAssetDirs = [];
                this.allAssetsByName = new Map();
                this.allAssetDirsByName = new Map();
                return;
            }

            let rawList = files.getFlatDirectory(this.absoluteAssetsPath);

            ceramic.send({
                type: 'assets/lists',
                value: {
                    list: rawList
                }
            }, (message) => {
                
                this.imageAssets = message.value.images;
                this.textAssets = message.value.texts;
                this.soundAssets = message.value.sounds;
                this.fontAssets = message.value.fonts;

                this.allAssets = message.value.all;
                this.allAssetDirs = message.value.allDirs;

                this.allAssetsByName = new Map();
                for (let key in message.value.allByName) {
                    if (message.value.allByName.hasOwnProperty(key)) {
                        this.allAssetsByName.set(key, message.value.allByName[key]);
                    }
                }

                this.allAssetDirsByName = new Map();
                for (let key in message.value.allDirsByName) {
                    if (message.value.allDirsByName.hasOwnProperty(key)) {
                        this.allAssetDirsByName.set(key, message.value.allDirsByName[key]);
                    }
                }

                let prevAllAssetsLastModified:Map<string,number> = null;
                if (this.allAssetPathsLastModified != null) {
                    this.allAssetPathsLastModified.forEach((val, key) => {
                        prevAllAssetsLastModified.set(key, val);
                    });
                }

                // Compute all asset paths with last modified date
                let allAssetsLastModified = new Map();
                for (let assetsGroup of [
                    this.imageAssets,
                    this.textAssets,
                    this.soundAssets,
                    this.fontAssets
                ]) {
                    for (let entry of assetsGroup) {
                        for (let path of entry.paths) {
                            if (!allAssetsLastModified.has(path)) {
                                try {
                                    let lastModified = fs.statSync(join(this.absoluteAssetsPath, path)).mtime;
                                    allAssetsLastModified.set(path, lastModified);
                                }
                                catch (e) {
                                    console.error('Failed to get last modified date of path ' + path + ': ' + e);
                                }
                            }
                        }
                    }
                }
                this.allAssetPathsLastModified = allAssetsLastModified;

                // If we had a previous assets last modified list,
                // check if it is different than the new one.
                // If so, and if online is enabled, we
                // should sync them with other peers through git
                if (prevAllAssetsLastModified != null) {
                    let hasChanged = false;
                    this.allAssetPathsLastModified.forEach((val, key) => {
                        if (hasChanged) return;
                        if (prevAllAssetsLastModified.get(key) !== val) {
                            hasChanged = true;
                        }
                    });
                    if (!hasChanged) {
                        prevAllAssetsLastModified.forEach((val, key) => {
                            if (hasChanged) return;
                            if (this.allAssetPathsLastModified.get(key) !== val) {
                                hasChanged = true;
                            }
                        });
                    }

                    if (hasChanged) {

                        // Assets have changed.
                        // Let's refresh the window for now
                        // (later we may try to find a less agressive solution)
                        window.location.reload();

                    }
                }

            });

        });

        // Deselect item when changing scene tab
        autorun(() => {

            if (this.ui == null) return;
            if (this.ui.editor !== 'scene') return;
            if (this.ui.sceneTab !== 'visuals') {
                ceramic.send({
                    type: 'scene-item/select',
                    value: null
                });
            }

        });

        // Update editor preview
        autorun(() => {

            // Do it everytime the footprint changes
            if (this.footprint != null) {
                // Check that we can do it
                if (this.absoluteEditorPath && this.onlineEnabled && this.gitRepository && user.githubToken) {

                    // Seems ok, check if we should fetch editor
                    let projectEditorHash = this.editorHash;
                    if (projectEditorHash == null) {
                        // No editor hash, nothing to fetch
                        return;
                    }

                    // Get current actual editor hash
                    let actualEditorHash = null;
                    if (fs.existsSync(join(this.absoluteEditorPath, 'SceneEditor.js'))) {
                        let data = fs.readFileSync(join(this.absoluteEditorPath, 'SceneEditor.js'));
                        actualEditorHash = createHash('md5').update(data).digest('hex');
                    }

                    if (actualEditorHash !== projectEditorHash) {
                        // Fetch editor
                        this.syncEditorPreview(true);
                    }
                }
            }

        });

        // Update data from ceramic (haxe)
        ceramic.listen('set/*', (message) => {

            let [, key] = message.type.split('/');

            // Change UI
            if (key.startsWith('ui.')) {
                keypath.set(this.ui, key.substr(3), message.value);
            }
            // Change Scene Item
            else if (key.startsWith('scene.item.')) {
                if (this.ui.selectedScene == null || this.ui.selectedScene.items == null) return;

                let itemId = key.substr(11);
                let item = this.ui.selectedScene.itemsById.get(itemId);

                if (item != null) {
                    for (let k in message.value) {
                        if (message.value.hasOwnProperty(k)) {
                            keypath.set(item, k, message.value[k]);
                        }
                    }
                }
            }

        });

    } //constructor

/// Public API

    @action createNew() {

        // Set name
        this.name = null;

        // Set unique identifier
        this.uuid = uuid();

        // Reset assets path
        this.assetsPath = null;

        // Reset raw files path
        this.rawFilesPath = null;

        // Reset project path
        user.projectPath = null;

        // Reset editor path
        this.editorPath = null;

        // Reset git stuff
        this.gitRepository = null;
        this.lastGitSyncProjectFootprint = null;
        this.lastGitSyncTimestamp = null;
        this.lastGithubSyncStatus = null;

        // Save timestamp
        this.saveTimestamp = null;

        // Scene bundles
        this.defaultSceneBundle = null;
        this.sceneBundles = [];

        // Set scene
        this.scenes = [];

        // Set UI state
        this.ui = new UiState('ui');

    } //createNew

    @action chooseAssetsPath() {

        let path = files.chooseDirectory('Assets Directory');
        if (path != null) {
            this.setAssetsPath(path);
        }

    } //chooseAssetsPath

    @action setAssetsPath(path:string) {

        let projectDir = this.path ? normalize(dirname(this.path)) : null;
        let assetsDir = normalize(path);
        
        if (projectDir === assetsDir) {
            this.assetsPath = '.';
        }
        else if (projectDir) {
            let res = relative(projectDir, assetsDir);
            if (!res.startsWith('.')) res = './' + res;
            this.assetsPath = res;
        }
        else {
            this.assetsPath = path;
        }

        this.assetsUpdatedAt = new Date().getTime();

    }

    @action chooseRawFilesPath() {

        let path = files.chooseDirectory('Raw Files Directory');
        if (path != null) {
            this.setRawFilesPath(path);
        }

    } //chooseRawFilesPath

    @action setRawFilesPath(path:string) {

        let projectDir = this.path ? normalize(dirname(this.path)) : null;
        let rawFilesDir = normalize(path);
        
        if (projectDir === rawFilesDir) {
            this.rawFilesPath = '.';
        }
        else if (projectDir) {
            let res = relative(projectDir, rawFilesDir);
            if (!res.startsWith('.')) res = './' + res;
            this.rawFilesPath = res;
        }
        else {
            this.rawFilesPath = path;
        }

    } //setRawFilesPath

    @action chooseEditorPath() {

        let path = files.chooseDirectory('Editor Preview Directory');
        if (path != null) {
            this.setEditorPath(path);
        }

    } //chooseEditorPath

    @action setEditorPath(path:string) {
        
        if (path) {

            // Set project dir
            //
            let projectDir = normalize(dirname(this.path));
            let editorDir = normalize(path);
            
            if (projectDir === editorDir) {
                this.editorPath = '.';
            } else {
                let res = relative(projectDir, editorDir);
                if (!res.startsWith('.')) res = './' + res;
                this.editorPath = res;
            }
            
        }
        else {
            this.editorPath = null;
        }

    } //chooseAssetsPath

    @action createScene() {

        let scene = new Scene();
        scene.name = 'Scene ' + (this.scenes.length + 1);

        this.scenes.push(scene);
        this.ui.selectedSceneId = scene.id;

    } //createScene

    @action removeCurrentSceneItem() {

        let itemId = this.ui.selectedItemId;
        if (!itemId) return;

        let item = this.ui.selectedScene.itemsById.get(itemId);

        if (item != null) {

            if (this.ui.selectedItemId === itemId) {
                this.ui.selectedItemId = null;
            }

            this.ui.selectedScene.items.splice(
                this.ui.selectedScene.items.indexOf(item),
                1
            );
            item = null;
        }

    } //removeCurrentSceneItem

    @action removeCurrentScene() {

        let sceneId = this.ui.selectedSceneId;

        if (!sceneId) return;

        let index = -1;
        let i = 0;
        for (let scene of this.scenes) {
            if (scene.id === sceneId) {
                index = i;
                break;
            }
            i++;
        }

        if (index !== -1) {
            this.ui.selectedSceneId = null;
            this.scenes.splice(index, 1);
        }

    } //removeCurrentScene

/// Save/Open

    open():void {

        let path = files.chooseFile(
            'Open project',
            [
                {
                    name: 'Ceramic Project File',
                    extensions: ['ceramic']
                }
            ]
        );

        if (!path) return;

        this.openFile(path);

    } //open

    openFile(path:string):void {

        console.log('open project: ' + path);

        // Lock assets
        this.assetsLocked = true;

        try {
            let data = JSON.parse(''+fs.readFileSync(path));
            
            let serialized = data.project;

            // Remove footprint (we will compute ours)
            delete serialized.footprint;

            // Reset sync timestamp & footprint if not provided
            if (!serialized.lastGitSyncProjectFootprint) {
                serialized.lastGitSyncProjectFootprint = null;
            }
            if (!serialized.lastGitSyncTimestamp) {
                serialized.lastGitSyncTimestamp = null;
            }

            // Update db from project data
            for (let serializedItem of data.entries) {
                db.putSerialized(serializedItem, false);
            }
            for (let serializedItem of data.entries) {
                db.putSerialized(serializedItem, true);
            }

            // Put project (and trigger its update)
            db.putSerialized(serialized);

            // Update project path
            user.projectPath = path;

            // Unlock and force assets to reload
            this.assetsUpdatedAt = new Date().getTime();
            this.assetsLocked = false;

            // Mark project as clean
            user.markProjectAsClean();

        }
        catch (e) {
            alert('Failed to open project: ' + e);

            // Unlock assets
            this.assetsLocked = false;
        }
    }

    save(saveAutoGit:boolean = false):void {

        if (!this.path || !fs.existsSync(dirname(this.path))) {
            this.saveAs();
            return;
        }

        // Update save timestamp
        this.saveTimestamp = Math.round(new Date().getTime() / 1000.0);

        // Serialize
        let options = { entries: {}, recursive: true };
        let serialized = serializeModel(this, options);

        // Keep the stuff we want
        //
        let entries:Array<any> = [];
        for (let key in options.entries) {
            if (options.entries.hasOwnProperty(key)) {
                entries.push(options.entries[key].serialized);
            }
        }
        
        let data = JSON.stringify({
            project: serialized,
            entries: entries
        }, null, 2);

        // Save data
        fs.writeFileSync(this.path, data);
        console.log('saved project: ' + this.path);

        // Mark project as `clean`
        user.markProjectAsClean();

        // If we should auto sync with github, do sync
        if (saveAutoGit) {

            // Not online, no auto github save
            if (!this.onlineEnabled) return;

            // Don't save if internet is down or realtime broken
            if (this.realtimeBroken || context.connectionStatus !== 'online') return;

            // Don't save if not up to date
            if (!this.isUpToDate) return;

            // Don't save if project hasn't changed
            if (!user.autoGithubProjectDirty) return;

            // Only master peer is responsible to save
            if (this.isMaster) {
                // We are master, do it
                this.syncWithGithub({
                    auto: true,
                    directions: 'localToRemote'
                }, () => {
                    // Done
                });
            }
            else if (this.masterPeer != null) {
                // We are not master, tell master to save
                this.sendPeerMessage(this.masterPeer, 'save', {
                    lastSyncTimestamp: this.lastOnlineSyncTimestamp
                });
            }
        }

    } //save

    saveAs():void {

        let path = files.chooseSaveAs(
            'Save project',
            [
                {
                    name: 'Ceramic Project File',
                    extensions: ['ceramic']
                }
            ],
            this.path ? this.path : undefined
        );

        if (path) {

            // Keep current absolute assets path
            let assetsPath = this.absoluteAssetsPath;

            // Keep current absolute raw files path
            let rawFilesPath = this.absoluteRawFilesPath;

            // Keep current absolute editor path
            let editorPath = this.absoluteEditorPath;

            // Update project path
            user.projectPath = path;

            // Update assets path (make it relative to new project path)
            if (assetsPath) {
                this.setAssetsPath(assetsPath);
            }

            // Update raw files path (make it relative to new project path)
            if (rawFilesPath) {
                this.setRawFilesPath(rawFilesPath);
            }

            // Update editor path as well
            if (editorPath) {
                this.setEditorPath(editorPath);
            }

            // Set project name from file path
            this.name = basename(path).split('.')[0];

            // Set project default scene bundle from project name
            this.defaultSceneBundle = this.name.split(' ').join('_');

            // Save
            this.save();
        }

    } //saveAs

/// Clipboard

    copySelectedSceneItem(cut:boolean = false):string {

        let scene = this.ui.selectedScene;
        if (!scene) return null;

        // Get scene item
        let item = this.ui.selectedItem;
        if (!item) return null;

        // Duplicate serialized data
        let data = JSON.parse(JSON.stringify(db.getSerialized(item.id)));

        // Cut?
        if (cut) {
            let index = scene.items.indexOf(item);
            if (index !== -1) {
                scene.items.splice(index, 1);
            }
        }

        return JSON.stringify(data);

    } //copySelectedItem

    pasteSceneItem(strData:string) {

        let scene = this.ui.selectedScene;
        if (!scene) return;

        // Parse data
        let data = JSON.parse(strData);

        // Create a new id
        data.id = uuid();

        // Set it to maximum depth (will be normalized right after)
        data.depth = 9999999999;

        // Update name
        if (data.name != null) {
            if (data.name.endsWith(' (copy)')) {
                let i = 2;
                let baseName = data.name.substr(0, data.name.length - 7);
                let itemExistsWithName = false;
                do {
                    let composedName = baseName + ' (copy ' + i + ')';
                    itemExistsWithName = false;
                    for (let item of scene.items.slice()) {
                        if (item.name != null && item.name === composedName) {
                            itemExistsWithName = true;
                            break;
                        }
                    }
                    i++;
                } while (itemExistsWithName);
                data.name = baseName + ' (copy ' + i + ')';
            }
            else {
                data.name += ' (copy)';
            }
        }

        // Put item in db
        db.putSerialized(data);

        // Create instance
        let item = db.getOrCreate(Model, data.id) as SceneItem;

        // Add item
        scene.items.push(item);

        // Normalize item depths
        let visuals = scene.visualItemsSorted.slice();
        let depth = 1;
        for (let i = visuals.length -1; i >= 0; i--) {
            visuals[i].depth = depth++;
        }

        // Select item
        this.ui.selectedItemId = item.id;

    } //copySelectedItem

/// Drag & Drop files

    dropFile(path:string):void {

        if (path.endsWith('.ceramic')) {
            this.openFile(path);
        }

    } //dropFile

/// Build

    /** Build/Export scene files */
    build():void {

        if (!this.absoluteAssetsPath) {
            alert('You choose an asset directory before building.');
            return;
        }

        if (!fs.existsSync(this.absoluteAssetsPath)) {
            alert('Current assets directory doesn\'t exist');
            return;
        }

        let perBundle:Map<string,any> = new Map();

        // Serialize each scene
        for (let scene of this.scenes) {

            let sceneData = scene.serializeForCeramic();

            // Include scene items
            sceneData.items = [];
            for (let item of scene.items) {
                let serialized = item.serializeForCeramic();
                sceneData.items.push(serialized);
            }

            let bundleName = scene.bundle ? scene.bundle : this.defaultSceneBundle;
            if (bundleName) {
                let bundleData:any = perBundle.get(bundleName);
                if (bundleData == null) {
                    bundleData = {};
                    perBundle.set(bundleName, bundleData);
                }
                bundleData[scene.id] = sceneData;
            }
            else {
                alert('Save project before building it.');
                return;
            }

        }

        perBundle.forEach((val, key) => {

            let scenesPath = join(this.absoluteAssetsPath, key + '.scenes');
            let scenesData = JSON.stringify(val, null, 2);
            
            console.log('Export: ' + scenesPath);

            fs.writeFileSync(scenesPath, scenesData);

        });

    } //build

/// Sync editor preview

    syncEditorPreview(auto:boolean = false):void {

        // Get previous editor hash
        let prevEditorHash:string = null;
        if (fs.existsSync(join(this.absoluteEditorPath, 'SceneEditor.js'))) {
            let data = fs.readFileSync(join(this.absoluteEditorPath, 'SceneEditor.js'));
            prevEditorHash = createHash('md5').update(data).digest('hex');
        }

        this.syncWithGithub({
            auto: true,
            branch: 'editor',
            directions: 'remoteToLocal',
            filesOnly: true,
            syncDirNames: ['editor']
        }, (err) => {

            if (err) {
                if (auto) alert(err);
                return;
            }

            // Update editor hash
            let actualEditorHash = null;
            if (fs.existsSync(join(this.absoluteEditorPath, 'SceneEditor.js'))) {
                let data = fs.readFileSync(join(this.absoluteEditorPath, 'SceneEditor.js'));
                actualEditorHash = createHash('md5').update(data).digest('hex');
            }

            // Reload new editor
            if (prevEditorHash !== actualEditorHash) {
                if (actualEditorHash) {
                    this.editorHash = actualEditorHash;
                }
                this.reloadEditorPreview();
            }

        });

    } //syncEditorPreview

    reloadEditorPreview() {

        // TODO

    } //reloadEditorPreview

/// Remote save

    syncWithGithub(options:SyncWithGithubOptions, done?:(err?:string) => void):void {

        let directions = options.directions;
        let auto = options.auto;
        let filesOnly = options.filesOnly;
        let targetCommit = options.targetCommit;
        let syncDirNames = options.syncDirNames ? options.syncDirNames : ['assets', 'files'];
        let branch = options.branch ? options.branch : (auto ? 'auto' : 'master');

        let resetToGithub = directions === 'remoteToLocal';

        if (!context.gitVersion) {
            let err = 'Git is required to save remotely to Github.';
            if (!auto) alert(err);
            if (done) done(err);
            return;
        }

        if (!user.githubToken) {
            let err = 'You need to set a Github Personal Access Token.';
            if (!auto) alert(err);
            if (done) done(err);
            return;
        }

        // Compute 'tokenized' git url
        if (!this.gitRepository || !this.gitRepository.startsWith('https://')) {
            let err = 'Invalid git repository URL.';
            if (!auto) alert(err);
            if (done) done(err);
            return;
        }

        // Prevent parallel syncs
        if (!auto) {
            if (this.manualSyncingWithGithub) {
                if (done) done('Already syncing.');
                return;
            }
            else if (this.autoSyncingWithGithub) {
                console.log('Plan manual sync, but wait for auto sync to finish\u2026');
                this.manualSyncingWithGithub = true;
                this.ui.loadingMessage = 'Waiting for end of auto sync \u2026';
                let intervalId = setInterval(() => {
                    if (!this.autoSyncingWithGithub) {
                        clearInterval(intervalId);
                        this.manualSyncingWithGithub = false;
                        this.syncWithGithub(options, done);
                    }
                }, 250);
                return;
            }
        }
        if (auto) {
            if (this.autoSyncingWithGithub) {
                if (done) done('Already syncing.');
                return;
            }
            else if (this.manualSyncingWithGithub) {
                console.log('Plan auto sync, but wait for manual sync to finish\u2026');
                this.autoSyncingWithGithub = true;
                let intervalId = setInterval(() => {
                    if (!this.manualSyncingWithGithub) {
                        clearInterval(intervalId);
                        this.autoSyncingWithGithub = false;
                        this.syncWithGithub(options, done);
                    }
                }, 250);
                return;
            }
        }

        // Save local version before sync
        this.save();

        // Check that project is saved to disk and has local path
        if (!this.path) {
            let err = 'Cannot synchronize project with Github if it\'s not saved to disk first';
            if (!auto) alert(err);
            if (done) done(err);
            return;
        }

        if (!auto) this.manualSyncingWithGithub = true;
        if (auto) this.autoSyncingWithGithub = true;
        if (!auto) this.ui.loadingMessage = 'Fetching remote repository \u2026';

        // Serialize
        let opt = { entries: {}, recursive: true };
        let serialized = serializeModel(this, opt);

        // Remove things we don't want to save remotely
        delete serialized.lastGitSyncTimestamp;
        delete serialized.lastGithubSyncStatus;
        delete serialized.lastGitSyncProjectFootprint;

        // Keep the stuff we want
        //
        let entries:Array<any> = [];
        for (let key in opt.entries) {
            if (opt.entries.hasOwnProperty(key)) {
                entries.push(opt.entries[key].serialized);
            }
        }
        
        let data = JSON.stringify({
            project: serialized,
            entries: entries
        }, null, 2);

        // Clone repository
        //
        let gitDir = join(os.homedir(), '.ceramic/git');
        if (!fs.existsSync(gitDir)) {
            if (!fs.existsSync(dirname(gitDir))) {
                fs.mkdirSync(dirname(gitDir));
            }
            fs.mkdirSync(gitDir);
        }

        let authenticatedUrl = 'https://' + user.githubToken + '@' + this.gitRepository.substr('https://'.length);

        let repoHash = createHash('md5').update(this.footprint + ' ~? ' + authenticatedUrl).digest('hex');
        let repoDirName = repoHash + '-' + branch;
        let repoDir = join(gitDir, repoDirName);
        let localAssetsPath = this.absoluteAssetsPath;
        let localRawFilesPath = this.absoluteRawFilesPath;
        let localEditorPath = this.absoluteEditorPath;
        
        this.cloneOrPullGitRepository(gitDir, repoDirName, authenticatedUrl, branch, targetCommit, (code, out, err) => {
            
            if (code !== 0) {
                if (!auto) this.manualSyncingWithGithub = false;
                if (auto) this.autoSyncingWithGithub = false;
                this.lastGithubSyncStatus = 'failure';
                this.ui.loadingMessage = null;
                let error = 'Failed to get latest commit: ' + (''+err).split(user.githubToken + '@').join('');
                if (!auto) alert(error);
                if (done) done(error);
                return;
            }

            // Get commit hash
            git.run(['rev-parse', 'HEAD'], repoDir, (code, out, err) => {
                if (code !== 0) {
                    if (!auto) this.manualSyncingWithGithub = false;
                    if (auto) this.autoSyncingWithGithub = false;
                    this.lastGithubSyncStatus = 'failure';
                    this.ui.loadingMessage = null;
                    let error = 'Failed to get latest commit hash: ' + (''+err).split(user.githubToken + '@').join('');
                    if (!auto) alert(error);
                    if (done) done(error);
                    return;
                }

                let commitHash = out.trim();
            
                // Get latest commit timestamp
                git.run(['log', '-1', '--pretty=format:%ct'], repoDir, (code, out, err) => {
                    if (code !== 0) {
                        if (!auto) this.manualSyncingWithGithub = false;
                        if (auto) this.autoSyncingWithGithub = false;
                        this.lastGithubSyncStatus = 'failure';
                        this.ui.loadingMessage = null;
                        let error = 'Failed to get latest commit timestamp: ' + (''+err).split(user.githubToken + '@').join('');
                        if (!auto) alert(error);
                        if (done) done(error);
                        return;
                    }

                    let commitTimestamp = parseInt(out, 10);
                    let hasProjectInRepo = fs.existsSync(join(repoDir, 'project.ceramic'));
                    this.ui.loadingMessage = null;

                    if (resetToGithub || (hasProjectInRepo && (this.footprint !== this.lastGitSyncProjectFootprint || !this.lastGitSyncTimestamp))) {
                        // Apply remote version
                        this.applyRemoteGitToLocal(repoDir, commitTimestamp, commitHash, auto, filesOnly, done);
                    }
                    else if (hasProjectInRepo && (commitTimestamp > this.lastGitSyncTimestamp || directions === 'remoteToLocal')) {

                        if (auto || directions === 'remoteToLocal') {
                            // Always get most recent changes in automatic mode
                            this.applyRemoteGitToLocal(repoDir, commitTimestamp, commitHash, auto, filesOnly, done);
                        }
                        else if (directions === 'localToRemote') {
                            // Apply local version
                            this.applyLocalToRemoteGit(repoDir, data, localAssetsPath, localRawFilesPath, localEditorPath, auto, filesOnly, syncDirNames, done);
                        }
                        else {
                            // There are more recent commits from remote.
                            // Prompt user to know which version he wants to keep (local or remote)
                            this.promptChoice({
                                    title: "Resolve conflict",
                                    message: "Remote project has new changes.\nWhich version do you want to keep?",
                                    choices: [
                                        "Local",
                                        "Remote"
                                    ]
                                },
                                (result) => {
                                    
                                    if (result === 0) {
                                        // Apply local version
                                        this.applyLocalToRemoteGit(repoDir, data, localAssetsPath, localRawFilesPath, localEditorPath, auto, filesOnly, syncDirNames, done);
                                    }
                                    else if (result === 1) {
                                        // Apply remote version
                                        this.applyRemoteGitToLocal(repoDir, commitTimestamp, commitHash, auto, filesOnly, done);
                                    }
                                }
                            );
                        }
                    }
                    else {
                        // Apply local version
                        this.applyLocalToRemoteGit(repoDir, data, localAssetsPath, localRawFilesPath, localEditorPath, auto, filesOnly, syncDirNames, done);
                    }

                });
            });
            
        });

    } //syncWithGithub

    cloneOrPullGitRepository(gitDir:string, repoDirName:string, authenticatedUrl:string, branch:string, targetCommit:string, callback:(code:number, stdout:string, stderr:string) => void) {

        let repoDir = join(gitDir, repoDirName);
        let shouldClone = !fs.existsSync(join(repoDir, '.git'));

        if (shouldClone) {

            // Clone
            git.run(['clone', '--branch', branch, '--single-branch', authenticatedUrl, repoDirName], gitDir, (code, out, err) => {
                if (code !== 0) {
                    callback(code, out, err);
                    return;
                }

                if (targetCommit) {
                    this.checkoutGitCommit(gitDir, targetCommit, (code, out, err) => {
                        callback(code, out, err);
                    });
                }
                else {
                    callback(code, out, err);
                }
            });
        }
        else {

            // Cleanup repo (just to be sure, remove local changes)
            git.run(['reset', '--hard', 'HEAD'], repoDir, (code, out, err) => {
                if (code !== 0) {
                    callback(code, out, err);
                    return;
                }

                // Remove untracked files and directories
                git.run(['clean', '-df'], repoDir, (code, out, err) => {
                    if (code !== 0) {
                        callback(code, out, err);
                        return;
                    }

                    // Then pull
                    git.run(['pull'], repoDir, (code, out, err) => {

                        if (targetCommit) {
                            this.checkoutGitCommit(repoDir, targetCommit, (code, out, err) => {
                                callback(code, out, err);
                            });
                        }
                        else {
                            callback(code, out, err);
                        }
                    });
                });
            });
        }

    } //cloneOrPullGitRepository

    checkoutGitCommit(repoDir:string, targetCommit:string, callback:(code:number, stdout:string, stderr:string) => void) {

        // Assume git repo is up to date, checkout target commit/revision
        git.run(['reset', '--hard', targetCommit], repoDir, (code, out, err) => {

            if (code !== 0) {
                callback(code, out, err);
                return;
            }

            // Clean again
            git.run(['clean', '-df'], repoDir, (code, out, err) => {

                callback(code, out, err);

            });
            
        });

    } //checkoutGitCommit

    applyLocalToRemoteGit(repoDir:string, data:string, localAssetsPath:string, localRawFilesPath:string, localEditorPath:string, autoSave:boolean, filesOnly:boolean, syncDirNames:Array<string>, done?:(err?:string) => void, commitMessage?:string) {

        if (autoSave && !commitMessage) {
            commitMessage = 'Auto-save on ' + dateformat(new Date().getTime());
        }

        if (!commitMessage) {
            this.promptText({
                title: 'Commit message',
                message: 'Please describe your changes:',
                placeholder: 'Enter a message\u2026',
                validate: 'Commit',
                cancel: 'Cancel'
            },
            (result) => {
                if (result == null) {
                    // Canceled
                    if (!autoSave) this.manualSyncingWithGithub = false;
                    if (autoSave) this.autoSyncingWithGithub = false;
                    this.lastGithubSyncStatus = null;
                    this.ui.loadingMessage = null;
                    return;
                }

                this.applyLocalToRemoteGit(repoDir, data, localAssetsPath, localRawFilesPath, localEditorPath, autoSave, filesOnly, syncDirNames, done, result);
            });

            return;
        }

        if (!autoSave) this.ui.loadingMessage = 'Pushing changes \u2026';

        let syncFilesDirectory = (localPath:string, pathName:string, next:() => void) => {

            // Sync files
            if (localPath && syncDirNames.indexOf(pathName) !== -1) {
                let repoFilesDir = join(repoDir, pathName);

                // Copy local files to repo files
                if (fs.existsSync(repoFilesDir)) {
                    rimraf.sync(repoFilesDir);
                }
                fs.mkdirSync(repoFilesDir);
                ncp(localPath, repoFilesDir, (err) => {
                    if (err) {
                        if (!autoSave) this.manualSyncingWithGithub = false;
                        if (autoSave) this.autoSyncingWithGithub = false;
                        this.lastGithubSyncStatus = 'failure';
                        this.ui.loadingMessage = null;
                        let error = 'Failed to copy asset: ' + err;
                        if (!autoSave) alert(error);
                        if (done) done(error);
                        return;
                    }

                    next();
                });
            }
            else {
                next();
            }

        };

        // Set .gitignore
        let gitIgnorePath = join(repoDir, '.gitignore');
        if (!fs.existsSync(gitIgnorePath)) {
            fs.writeFileSync(gitIgnorePath, [
                '.DS_Store',
                '__MACOSX',
                'thumbs.db'
            ].join(os.EOL));
        }

        // Sync project file
        let syncProjectFileAndPush = () => {

            // Don't save project if we only are syncing files
            let repoProjectFile = join(repoDir, 'project.ceramic');
            if (!filesOnly) {
                fs.writeFileSync(repoProjectFile, data);
            }

            // Stage files
            git.run(['add', '-A'], repoDir, (code, out, err) => {
                if (code !== 0) {
                    if (!autoSave) this.manualSyncingWithGithub = false;
                    if (autoSave) this.autoSyncingWithGithub = false;
                    this.lastGithubSyncStatus = 'failure';
                    this.ui.loadingMessage = null;
                    let error = 'Failed to stage modified files: ' + (''+err).split(user.githubToken + '@').join('');
                    if (!autoSave) alert(error);
                    if (done) done(error);
                    return;
                }

                // Commit
                git.run(['commit', '-m', commitMessage], repoDir, (code, out, err) => {
                    if (code !== 0) {
                        if (!autoSave) this.manualSyncingWithGithub = false;
                        if (autoSave) this.autoSyncingWithGithub = false;
                        this.lastGithubSyncStatus = 'failure';
                        this.ui.loadingMessage = null;
                        let error = 'Failed commit changes: ' + (''+err).split(user.githubToken + '@').join('');
                        if (!autoSave) alert(error);
                        if (done) done(error);
                        return;
                    }

                    // Get commit timestamp
                    git.run(['log', '-1', '--pretty=format:%ct'], repoDir, (code, out, err) => {
                        if (code !== 0) {
                            if (!autoSave) this.manualSyncingWithGithub = false;
                            if (autoSave) this.autoSyncingWithGithub = false;
                            this.lastGithubSyncStatus = 'failure';
                            this.ui.loadingMessage = null;
                            let error = 'Failed to get new commit timestamp: ' + (''+err).split(user.githubToken + '@').join('');
                            if (!autoSave) alert(error);
                            if (done) done(error);
                            return;
                        }

                        // Keep timestamp
                        let commitTimestamp = parseInt(out, 10);

                        // Get commit hash
                        git.run(['rev-parse', 'HEAD'], repoDir, (code, out, err) => {
                            if (code !== 0) {
                                if (!autoSave) this.manualSyncingWithGithub = false;
                                if (autoSave) this.autoSyncingWithGithub = false;
                                this.lastGithubSyncStatus = 'failure';
                                this.ui.loadingMessage = null;
                                let error = 'Failed to get new commit hash: ' + (''+err).split(user.githubToken + '@').join('');
                                if (!autoSave) alert(error);
                                if (done) done(error);
                                return;
                            }

                            let commitHash = out.trim();

                            // Push
                            git.run(['push'], repoDir, (code, out, err) => {
                                if (code !== 0) {
                                    if (!autoSave) this.manualSyncingWithGithub = false;
                                    if (autoSave) this.autoSyncingWithGithub = false;
                                    this.lastGithubSyncStatus = 'failure';
                                    this.ui.loadingMessage = null;
                                    let error = 'Failed to push to remote repository: ' + (''+err).split(user.githubToken + '@').join('');
                                    if (!autoSave) alert(error);
                                    if (done) done(error);
                                    return;
                                }

                                // Save project with new timestamp and footprint
                                this.lastGitSyncTimestamp = commitTimestamp;
                                this.lastGitSyncCommitHash = commitHash;
                                this.lastGitSyncProjectFootprint = this.footprint;
                                this.save();
                                
                                // Finish
                                if (!autoSave) this.manualSyncingWithGithub = false;
                                if (autoSave) this.autoSyncingWithGithub = false;
                                this.lastGithubSyncStatus = 'success';
                                this.ui.loadingMessage = null;
                                if (!autoSave) user.markManualGithubProjectAsClean();
                                if (autoSave) user.markAutoGithubProjectAsClean();

                                if (done) done();
                            });
                        });
                    });
                });
            });
        };

        // Sync files
        syncFilesDirectory(this.absoluteAssetsPath, 'assets', () => {
            syncFilesDirectory(this.absoluteRawFilesPath, 'files', () => {
                syncFilesDirectory(this.absoluteEditorPath, 'editor', () => {

                    syncProjectFileAndPush();

                });
            });
        });

    } //applyLocalToRemoteGit

    applyRemoteGitToLocal(repoDir:string, commitTimestamp:number, commitHash:string, autoLoad:boolean, filesOnly:boolean, done?:(err?:string) => void) {

        if (!autoLoad) this.ui.loadingMessage = 'Updating local files \u2026';

        // Lock assets
        this.assetsLocked = true;

        // Get remote project data
        let repoProjectFile = join(repoDir, 'project.ceramic');
        let data = JSON.parse('' + fs.readFileSync(repoProjectFile));

        // If we only want to update files, no need to update project data
        if (!filesOnly) {

            // Assign new data
            let serialized = data.project;

            // Remove footprint (we will compute ours)
            delete serialized.footprint;

            // Update db from project data
            for (let serializedItem of data.entries) {
                db.putSerialized(serializedItem, false);
            }
            for (let serializedItem of data.entries) {
                db.putSerialized(serializedItem, true);
            }

            // Put project (and trigger its update)
            db.putSerialized(serialized);
        }

        let syncFilesDirectory = (localPath:string, pathName:string, next:() => void) => {

            // Sync assets
            if (localPath) {
                let repoFilesDir = join(repoDir, pathName);

                try {
                    // Copy local files path to repo files path
                    if (fs.existsSync(localPath)) {
                        rimraf.sync(localPath);
                    }
                    fs.mkdirSync(localPath);
                } catch (e) {
                    if (!autoLoad) this.manualSyncingWithGithub = false;
                    if (autoLoad) this.autoSyncingWithGithub = false;
                    this.lastGithubSyncStatus = 'failure';
                    this.ui.loadingMessage = null;

                    // Unlock assets
                    this.assetsLocked = true;

                    console.error(e);
                    let error = 'Failed to update ' + pathName + ' directory: ' + e;
                    if (!autoLoad) alert(error);
                    if (done) done(error);
                    return;
                }
                if (fs.existsSync(repoFilesDir)) {
                    ncp(repoFilesDir, localPath, (err) => {
                        if (err) {
                            if (!autoLoad) this.manualSyncingWithGithub = false;
                            if (autoLoad) this.autoSyncingWithGithub = false;
                            this.lastGithubSyncStatus = 'failure';
                            this.ui.loadingMessage = null;

                            // Unlock assets
                            this.assetsLocked = true;

                            let error = 'Failed to copy file of ' + pathName + ' directory: ' + err;
                            if (!autoLoad) alert(error);
                            if (done) done(error);
                            return;
                        }

                        next();
                    });
                } else {
                    next();
                }
            }
            else {
                next();
            }
        };

        // That's it
        let finish = () => {

            // Save project with changed data and new timestamp and footprint
            this.lastGitSyncTimestamp = commitTimestamp;
            this.lastGitSyncCommitHash = commitHash;
            this.lastGitSyncProjectFootprint = this.footprint;
            this.save();

            if (!autoLoad) this.manualSyncingWithGithub = false;
            if (autoLoad) this.autoSyncingWithGithub = false;
            this.lastGithubSyncStatus = 'success';
            this.ui.loadingMessage = null;
            if (!autoLoad) user.markManualGithubProjectAsClean();
            if (autoLoad) user.markAutoGithubProjectAsClean();
            
            // Unlock and force assets list to update
            this.assetsUpdatedAt = new Date().getTime();
            this.assetsLocked = false;

            if (done) done();
        };

        // Sync files
        syncFilesDirectory(this.absoluteAssetsPath, 'assets', () => {
            syncFilesDirectory(this.absoluteRawFilesPath, 'files', () => {
                syncFilesDirectory(this.absoluteEditorPath, 'editor', () => {

                    finish();

                });
            });
        });

    } //applyRemoteGitToLocal

/// Prompt

    promptChoice(options:{title:string, message:string, choices:Array<string>}, callback:(result:number) => void) {

        this.ui.promptChoiceResult = null;

        let release:any = null;
        release = autorun(() => {
            if (this.ui.promptChoiceResult == null) return;
            release();
            let result = this.ui.promptChoiceResult;
            this.ui.promptChoiceResult = null;
            callback(result);
        });

        this.ui.promptChoice = options;

    } //promptChoice

    promptText(options:{title:string, message:string, placeholder:string, validate:string, cancel?:string}, callback:(result:string) => void) {

        this.ui.promptTextResult = null;
        this.ui.promptTextCanceled = false;

        let release:any = null;
        release = autorun(() => {
            if (this.ui.promptTextCanceled) {
                release();
                callback(null);
                return;
            }
            if (this.ui.promptTextResult == null) return;
            release();
            let result = this.ui.promptTextResult;
            this.ui.promptTextResult = null;
            callback(result);
        });

        this.ui.promptText = options;

    } //promptText

/// Realtime

    @compute get shouldSendToMaster():boolean {

        return this.hasRemotePeers && !this.isMaster && this.isUpToDate;

    } //shouldSendToMaster

    @compute get hasRemotePeers():boolean {

        return this.peers != null && this.peers.length > 0;

    } //hasRemotePeers

    @compute get isMaster():boolean {

        return !this.hasRemotePeers || (this.masterPeer == null && this.isUpToDate);

    } //isMaster

    @compute get isUncheckedMaster():boolean {

        return !this.hasRemotePeers || this.uncheckedMasterPeer == null;

    } //isUncheckedMaster

    @compute get masterPeer():Peer {

        if (!this.hasRemotePeers) {
            return null;
        }
        else {
            let ids = [];
            if (this.isUpToDate) {
                ids.push(this.clientId);
            }
            for (let peer of this.peers) {
                if (this.upToDateClientIds.has(peer.remoteClient)) {
                    // Only add `up to date` peers
                    ids.push(peer.remoteClient);
                }
            }
            ids.sort();
            if (ids[0] === this.clientId) {
                return null;
            }
            else {
                for (let peer of this.peers) {
                    if (ids[0] === peer.remoteClient) {
                        return peer;
                    }
                }
                return null;
            }
        }

    } //masterPeer

    @compute get uncheckedMasterPeer():Peer {

        if (!this.hasRemotePeers) {
            return null;
        }
        else {
            let ids = [];
            ids.push(this.clientId);
            for (let peer of this.peers) {
                ids.push(peer.remoteClient);
            }
            ids.sort();
            if (ids[0] === this.clientId) {
                return null;
            }
            else {
                for (let peer of this.peers) {
                    if (ids[0] === peer.remoteClient) {
                        return peer;
                    }
                }
                return null;
            }
        }

    } //uncheckedMasterPeer

    bindRealtime() {

        // Check realtime connection status
        let cyclesBroken = 0;
        let lastRealtimeToken = user.realtimeApiKey;
        setInterval(() => {

            // Wait until we close settings before deciding something is broken or not
            if (this.ui.editSettings) return;

            if (lastRealtimeToken !== user.realtimeApiKey) {
                lastRealtimeToken = user.realtimeApiKey;
                this.realtimeBroken = false;
                cyclesBroken = 0;
            }
            else if (this.onlineEnabled && !this.realtimeConnected) {
                cyclesBroken++;

                if (cyclesBroken >= 10) this.realtimeBroken = true;
            }
            else {
                cyclesBroken = 0;
                this.realtimeBroken = false;
            }

        }, 1000);

        // Manage realtime.co connection
        //
        let realtimeActive = false;

        // Bind events
        realtime.on('connect', () => {
            console.log('%cREALTIME READY', 'color: #00FF00');
            this.realtimeConnected = true;
        });
        realtime.on('disconnect', () => {
            console.log('%cREALTIME DISCONNECTED', 'color: #FF0000');
            this.realtimeConnected = false;
        });
        realtime.on('reconnect', () => {
            console.log('%cREALTIME RECONNECTED', 'color: #00FF00');
            this.realtimeConnected = true;
        });

        autorun(() => {

            if (!this.ui || this.ui.editSettings) return;

            if (realtime.apiKey !== user.realtimeApiKey || (!realtimeActive && this.onlineEnabled)
            ) {
                if (user.realtimeApiKey && this.onlineEnabled) {
                    if (!realtimeActive) console.log('%cREALTIME CONNECT', 'color: #FF00FF');
                    realtimeActive = true;
                    realtime.connect(user.realtimeApiKey);
                }
                else {
                    if (realtimeActive) console.log('%cREALTIME DISCONNECT', 'color: #FF00FF');
                    realtimeActive = false;
                    realtime.disconnect(true);
                }
            }
            else if (realtimeActive && !this.onlineEnabled) {
                if (realtimeActive) console.log('%cREALTIME DISCONNECT', 'color: #FF00FF');
                realtimeActive = false;
                realtime.disconnect(true);
            }

        });

        // Manage realtime messaging room
        //
        autorun(() => {

            if (!this.onlineEnabled) return;

            if (!this.uuid) {
                // Destroy existing room, if any
                if (this.room) {
                    this.room.destroy();
                    this.room = null;
                    this.peers.splice(0, this.peers.length);
                }
            }
            else {
                // Destroy existing room, if any
                if (this.room && this.room.roomId !== this.uuid) {
                    this.room.destroy();
                    this.room = null;
                }

                if (!this.room) {
                    // Create up to date room
                    this.room = new Room(this.uuid, this.clientId);

                    // Bind events
                    //
                    this.room.on('peer-connect', (p:Peer, remoteClient:string) => {

                        console.log('%cPEER CONNECTED: ' + remoteClient, 'color: #0000FF');

                        this.bindPeer(p);

                    });
                    this.room.on('peer-close', (p:Peer, remoteClient:string) => {

                        console.log('%cPEER DISCONNECTED: ' + remoteClient, 'color: #FFBB00');

                        this.unbindPeer(p);

                    });
                }
            }

        });

        // Manage auto-save
        //
        let lastTimeSinceAutoSave = new Date().getTime();
        setInterval(() => {

            if (!this.onlineEnabled) return;

            // Don't save if internet is down or realtime broken
            if (this.realtimeBroken || context.connectionStatus !== 'online') return;

            // Only master peer is responsible to save
            if (!this.isMaster) return;

            // Don't save if not up to date
            if (!this.isUpToDate) return;

            // Don't save if project hasn't changed
            if (!user.autoGithubProjectDirty) return;

            // Don't save more than once every minute
            if (new Date().getTime() - 60000 <= lastTimeSinceAutoSave) return;

            // Save
            lastTimeSinceAutoSave = new Date().getTime();
            this.syncWithGithub({
                auto: true,
                directions: 'localToRemote'
            }, (err?:string) => {

                // If err
                if (err) {
                    console.error(err);
                    return;
                }

            });

        }, 10000);

        // Make project up to date in a way or another
        let sessionStatusInterval:any = null;
        autorun(() => {

            if (!this.onlineEnabled) return;

            // Make this autorun depend on these values
            let apiKey = user.realtimeApiKey;
            let connected = this.realtimeConnected;

            // Connection status changed, clear previous timeout
            if (sessionStatusInterval != null) clearInterval(sessionStatusInterval);

            // Start a new timeout
            sessionStatusInterval = setInterval(() => {

                console.log('%cMASTER='+this.isMaster+' UNCHECKED_MASTER='+this.isUncheckedMaster+' MASTER_PEER=' + (this.masterPeer ? 'exists' : 'null'), 'color: #FBAC02');

                // Now, decide whether we are master or not
                //
                if (!this.isUpToDate && this.realtimeConnected) {
                    // Project still not up to date, update from git
                    // if we are alone, or if we are the `unchecked master peer`
                    if (this.isUncheckedMaster || !this.hasRemotePeers) {

                        // Sync
                        this.syncWithGithub({
                            auto: true,
                            directions: 'remoteToLocal'
                        }, (err?:string) => {

                            // If err
                            if (err) {
                                console.error(err);
                                return;
                            }

                            // Fine? Then update timestamp and mark project as up to date
                            this.lastOnlineSyncTimestamp = this.lastGitSyncTimestamp;
                            this.isUpToDate = true;

                            // Send our state to everyone else (if any)
                            this.sendMasterProjectToEveryone();

                        });
                    }
                }

            }, 10000);

        });

        // Automatically re-send messages for which we didn't
        // receive any confirmation receipt from remote user
        setInterval(() => {

            // Online disabled? Nothing to do
            if (!this.onlineEnabled) return;

            // No peers? Nothing to do
            if (!this.hasRemotePeers || !this.realtimeConnected) return;

            // Get current time
            let time = new Date().getTime();

            // Iterate over pending messages
            this.pendingMessagesByClientId.forEach((pendingMessages, remoteClient) => {

                // Find peer for remote client
                let p:Peer = null;
                for (let peer of this.peers) {
                    if (!peer.destroyed && peer.remoteClient === remoteClient) {
                        p = peer;
                        break;
                    }
                }

                // Then iterate over each pending message of this client
                // To check if we should still try to send messages
                let maxAttempts = 0;
                pendingMessages.forEach((pending, index) => {

                    // Increment attempts and keep max value
                    if (time - 5000 >= pending.time) {
                        maxAttempts = Math.max(pending.attempts, maxAttempts);
                        pending.attempts++;
                    }

                });
                
                // If max attempts > 12 (1 min), mark this client as expired
                if (maxAttempts > 12) {
                    this.pendingMessagesByClientId.delete(remoteClient);
                    this.expiredClientIds.set(remoteClient, true);
                }
                else if (p != null) {
                    // Otherwise, try to send each message again
                    pendingMessages.forEach((pending, index) => {

                        // Send message again
                        if (time - 5000 >= pending.time) {

                            console.log('(RE) SEND PEER MESSAGE ' + remoteClient + ' ' + pending.message.type);
                            console.log(pending.message.data);

                            p.send(JSON.stringify(pending.message));
                        }

                    });
                }

            });

        }, 2500);

        // Re-send pending changes if needed
        //
        setInterval(() => {

            // Online disabled? Nothing to do
            if (!this.onlineEnabled) return;

            // No peers? Nothing to do
            if (!this.hasRemotePeers || !this.realtimeConnected) return;

            // Check pending local changes
            if (!this.isMaster && this.masterPeer != null) {

                // Re-send changesets that where not send to this client id
                // (in case master peer changed)
                let changesetsToSend:Array<PendingChangeset> = [];
                for (let changeset of this.pendingLocalChangesets) {
                    if (changeset.targetClient !== this.masterPeer.remoteClient) {
                        changeset.targetClient = this.masterPeer.remoteClient;
                        changesetsToSend.push(changeset);
                    }
                }

                // Then send a message that includes all pending changesets
                if (changesetsToSend.length > 0) {
                    this.sendPeerMessage(this.masterPeer, 'change', {
                        master: false,
                        lastSyncTimestamp: this.lastOnlineSyncTimestamp,
                        changesets: changesetsToSend
                    });
                }

            }

        }, 5000);

    } //bindRealtime

    bindPeer(p:Peer) {

        // Keep remote client id
        let remoteClient = p.remoteClient;

        // Update peer list
        if (this.peers.indexOf(p) === -1) {
            this.peers.push(p);
        }

        // Listen to remote peer incoming messages
        this.listenToPeerMessages(p, (type:string, data?:any) => {
            
            if (type === 'sync') {
                let status:'update'|'reset'|'expired'|'verify' = data.status;

                if (status === 'update') {
                    console.log('%cRECEIVE UPDATE', 'color: red');
                    // A peer requests to sync and get updated. In that case, master peer sends its latest data
                    // to everybody and update the sync timestamp. If nobody replies,
                    // That means we are alone and we should just use git data.
                    // TODO check isUpToDate for every case
                    if (((this.isMaster && this.isUpToDate) || (!this.masterPeer && this.isUncheckedMaster))) {
                        // That's us! Reply!
                        this.sendMasterProjectToEveryone();
                    }
                }
                else if (status === 'reset') {

                    // We received a reset. Process it.

                    db.silentChanges = true;

                    // Update local data accordingly
                    this.lastProcessedChangesetIndexByClientId = new Map();
                    this.lastProcessedIndexByClientId = new Map();
                    this.nextLocalChangesetIndex = 0;
                    this.pendingRemoteChangesetsByClientId = new Map();
                    let i = 0;
                    for (let changeset of this.pendingLocalChangesets) {
                        changeset.index = i++;
                        changeset.targetClient = null;
                    }

                    // Update expired/up to date lists
                    for (let clientId of data.clients) {
                        if (clientId !== this.clientId) {
                            this.expiredClientIds.delete(clientId);
                            this.upToDateClientIds.set(clientId, true);
                        }
                    }

                    // Load master's project
                    this.loadMasterProject(data.project);

                    // Mark project as up to date
                    this.isUpToDate = true;
                    this.lastOnlineSyncTimestamp = data.timestamp;
                    user.markProjectAsClean();

                    db.silentChanges = false;

                }
                else if (status === 'verify') {
                    // We received a verify request.
                    // Let's check if we should verify
                    if (this.isMaster) {

                        // Compare peer sync time with ours
                        if (this.lastOnlineSyncTimestamp !== data.timestamp) {
                            // And tell remote peer it is expired
                            this.sendPeerMessage(p, 'sync', {
                                status: 'expired',
                                master: true,
                                newTimestamp: this.lastOnlineSyncTimestamp,
                                expiredTimestamp: data.timestamp
                            });
                        }
                    }
                }
                else if (status === 'expired') {

                    // Received expired from master peer?
                    if (data.master) {
                        this.upToDateClientIds.set(remoteClient, true);
                        this.expiredClientIds.delete(remoteClient);
                    }

                    // Peer told us we are expired, let's get updated
                    // Well, only if master peer told us so. Others is noise.
                    if (this.masterPeer != null && this.masterPeer.remoteClient === remoteClient && data.newTimestamp !== this.lastOnlineSyncTimestamp) {

                        // Mark us as expired
                        this.isUpToDate = false;

                        // Request master to be synchronized
                        this.sendPeerMessage(p, 'sync', {
                            status: 'update'
                        });
                    }
                }
            }
            // Handle other kind of message only if the client is up to date
            // Ignore expired peers at this point. Life is hard.
            else if (type === 'change') {

                console.log('%cRECEIVE CHANGE', 'color: #FF00FF');
                
                if (data.lastSyncTimestamp !== this.lastOnlineSyncTimestamp) {

                    console.log('%c  BUT SYNC MISMATCH input=' + data.lastSyncTimestamp + ' ours=' + this.lastOnlineSyncTimestamp+'', 'color: #FF00FF');
                    // Ignore changesets from peers that don't match sync timestamp
                    // Situation should resolve itself when peer verify each other
                    return;
                }
                else {
                    if (data.master && this.masterPeer != null && remoteClient === this.masterPeer.remoteClient) {

                        console.log('%c  OK, MASTER SENT IT, LETS HANDLE IT', 'color: #FF00FF');

                        history.pause();

                        // Not master, got data from master
                        //
                        let pendingChangesets = this.pendingRemoteChangesetsByClientId.get(remoteClient);
                        if (pendingChangesets == null) {
                            pendingChangesets = new Map();
                            this.pendingRemoteChangesetsByClientId.set(remoteClient, pendingChangesets);
                        }
                        for (let changeset of data.changesets) {
                            pendingChangesets.set(changeset.index, changeset);
                        }

                        let lastConsumedByMaster = this.remoteConsumedChangesetByClientId.get(remoteClient);
                        if (lastConsumedByMaster == null) lastConsumedByMaster = -1;

                        // Apply changesets
                        //
                        // Setting this flag will prevent history from being modified automatically
                        // and also prevent the applied changes to be re-sent again in loop
                        this.processingMasterChangeset = true;
                        db.silentChanges = true;

                        // Before applying master changesets, get
                        // every item we need to re-apply after master changes
                        let itemsToReApply = [];
                        let itemIndex = history.index;
                        let item = history.items[itemIndex];
                        while (
                            item != null &&
                            item.meta.syncTimestamp === this.lastGitSyncTimestamp &&
                            item.meta.owner === this.clientId &&
                            !(
                                item.meta.consumedClient === this.clientId &&
                                item.meta.consumedIndex === lastConsumedByMaster
                            )) {

                            itemsToReApply.unshift(item);

                            item = history.items[--itemIndex];
                        }

                        // Insert new master changes in history
                        let lastProcessed = -1;
                        if (this.lastProcessedChangesetIndexByClientId.has(remoteClient)) {
                            lastProcessed = this.lastProcessedChangesetIndexByClientId.get(remoteClient);
                        }
                        while (pendingChangesets.has(lastProcessed + 1)) {

                            lastProcessed++;
                            let changeset = pendingChangesets.get(lastProcessed);
                            this.lastProcessedChangesetIndexByClientId.set(remoteClient, lastProcessed);

                            let serialized = changeset.data;
                            for (let key in serialized) {
                                if (serialized.hasOwnProperty(key)) {
                                    db.putSerialized(serialized[key], false);
                                }
                            }
                            for (let key in serialized) {
                                if (serialized.hasOwnProperty(key)) {
                                    db.putSerialized(serialized[key], true);
                                }
                            }
                        }

                        // Re-apply local changes
                        for (let item of itemsToReApply) {
                            let doData:{ [key: string]: any } = item.do;
                            for (let key in doData) {
                                if (doData.hasOwnProperty(key)) {
                                    db.putSerialized(doData[key], false);
                                }
                            }
                            for (let key in doData) {
                                if (doData.hasOwnProperty(key)) {
                                    db.putSerialized(doData[key], true);
                                }
                            }
                        }

                        // Unlock history/changeset messaging
                        this.processingMasterChangeset = false;
                        db.silentChanges = false;

                        // Cleanup
                        let toRemove:Array<number> = [];
                        pendingChangesets.forEach((val, key) => {
                            if (key <= lastProcessed) {
                                toRemove.push(key);
                            }
                        });
                        for (let key of toRemove) {
                            pendingChangesets.delete(key);
                        }

                        history.resume();

                        // Notify peer about where we are
                        this.sendPeerMessage(p, 'consumed', {
                            lastIndex: lastProcessed,
                            master: false,
                            lastSyncTimestamp: this.lastOnlineSyncTimestamp
                        });
                        
                    }
                    else if (this.isMaster && !data.master) {

                        console.log('%c  OK, WE ARE MASTER, LETS HANDLE THAT', 'color: #FF00FF');

                        history.pause();

                        // We are master,
                        // Got data from other peer
                        //
                        let pendingChangesets = this.pendingRemoteChangesetsByClientId.get(remoteClient);
                        if (pendingChangesets == null) {
                            pendingChangesets = new Map();
                            this.pendingRemoteChangesetsByClientId.set(remoteClient, pendingChangesets);
                        }
                        for (let changeset of data.changesets) {
                            pendingChangesets.set(changeset.index, changeset);
                        }

                        // Process every changeset we can in strict order
                        let lastProcessed = -1;
                        if (this.lastProcessedChangesetIndexByClientId.has(remoteClient)) {
                            lastProcessed = this.lastProcessedChangesetIndexByClientId.get(remoteClient);
                        }
                        while (pendingChangesets.has(lastProcessed + 1)) {

                            lastProcessed++;
                            let changeset = pendingChangesets.get(lastProcessed);
                            this.lastProcessedChangesetIndexByClientId.set(remoteClient, lastProcessed);

                            this.consumedChangesetIndexByMaster = lastProcessed;
                            this.consumedClientByMaster = remoteClient;

                            // Applying changeset should trigger a response changeset
                            // that include info about original changeset
                            let serialized = changeset.data;
                            for (let key in serialized) {
                                if (serialized.hasOwnProperty(key)) {
                                    db.putSerialized(serialized[key], false);
                                }
                            }
                            for (let key in serialized) {
                                if (serialized.hasOwnProperty(key)) {
                                    db.putSerialized(serialized[key], true);
                                }
                            }

                            this.consumedChangesetIndexByMaster = null;
                            this.consumedClientByMaster = null;
                        }

                        // Cleanup
                        let toRemove:Array<number> = [];
                        pendingChangesets.forEach((val, key) => {
                            if (key <= lastProcessed) {
                                toRemove.push(key);
                            }
                        });
                        for (let key of toRemove) {
                            pendingChangesets.delete(key);
                        }

                        history.resume();

                        // Notify peer about where we are
                        this.sendPeerMessage(p, 'consumed', {
                            lastIndex: lastProcessed,
                            master: true,
                            lastSyncTimestamp: this.lastOnlineSyncTimestamp
                        });

                    }
                }
            }
            else if (type === 'consumed') {
                
                if (data.lastSyncTimestamp !== this.lastOnlineSyncTimestamp) {
                    // Ignore consumed message from out of sync peers
                    return;
                }
                else {
                    this.remoteConsumedChangesetByClientId.set(remoteClient, data.lastIndex);
                }
            }
            else if (type === 'save') {
                
                if (data.lastSyncTimestamp !== this.lastOnlineSyncTimestamp) {
                    // Ignore consumed message from out of sync peers
                    return;
                }
                else {
                    // Only master can be requested to save and auto git-sync
                    if (this.isMaster) {
                        // Save project (and auto git-sync) as requested by peer
                        this.save(true);
                    }
                }
            }
            else if (type === 'files') {
                
                if (data.lastSyncTimestamp !== this.lastOnlineSyncTimestamp) {
                    // Ignore consumed message from out of sync peers
                    return;
                }
                else {
                    // Get files from target commit
                    this.syncWithGithub({
                        auto: true,
                        directions: 'remoteToLocal',
                        filesOnly: true
                    }, (err) => {
                        // Done
                    });
                }
            }

        });
        
        // If we need to get updated, ask peer his last save time
        if (!this.isUpToDate) {
            this.sendPeerMessage(p, 'sync', {
                status: 'update'
            });
        }
        else {
            // Verify continuously that we are still up to date
            this.sendPeerMessage(p, 'sync', {
                status: 'verify',
                timestamp: this.lastOnlineSyncTimestamp
            });
        }

        let intervalId = setInterval(() => {
            if (p.destroyed) {
                clearInterval(intervalId);
                return;
            }

            if (!this.isUpToDate) {
            this.sendPeerMessage(p, 'sync', {
                status: 'update'
            });
            }
            else {
                this.sendPeerMessage(p, 'sync', {
                    status: 'verify',
                    timestamp: this.lastOnlineSyncTimestamp
                });
            }

        }, 10000);

    } //binPeer

    unbindPeer(p:Peer) {
                        
        // Update peer list
        let peerIndex = this.peers.indexOf(p);
        if (peerIndex !== -1) {
            this.peers.splice(peerIndex, 1);
        }

    } //unbindPeer

    listenToPeerMessages(p:Peer, onMessage:(type:string, data?:any) => void) {

        let remoteClient = p.remoteClient;

        // Create required mappings if needed
        //
        if (!this.pendingMessagesByClientId.has(remoteClient)) {
            this.pendingMessagesByClientId.set(remoteClient, new Map());
        }
        if (!this.receivedMessagesByClientId.has(remoteClient)) {
            this.receivedMessagesByClientId.set(remoteClient, new Map());
        }
        if (!this.lastProcessedIndexByClientId.has(remoteClient)) {
            this.lastProcessedIndexByClientId.set(remoteClient, -1);
        }

        p.onMessage = (rawMessage:string) => {

            let parsed = JSON.parse(rawMessage);

            if (parsed.receipt) {

                // Message has been received by remote peer,
                // No need to keep it locally anymore
                let receipt:PeerMessageReceipt = parsed;
                
                // Delete confirmed message
                if (this.pendingMessagesByClientId.has(remoteClient)) {
                    this.pendingMessagesByClientId.get(remoteClient).delete(parsed.index);
                }

            }
            else {
                // Get received messsage
                let message:PeerMessage = parsed;

                // If the message is new, keep it in mapping
                let lastProcessedIndex = this.lastProcessedIndexByClientId.get(remoteClient);
                let receivedMessages = this.receivedMessagesByClientId.get(remoteClient);
                if (
                    lastProcessedIndex < message.index &&
                    !receivedMessages.has(message.index)) {
                    
                    // Add message
                    receivedMessages.set(message.index, message);
                }

                // Process new messages (if any)
                // Messages are processed in strict order depending
                // on the order they were sent by the client
                while (receivedMessages.has(lastProcessedIndex + 1)) {

                    // Get message
                    let toProcess = receivedMessages.get(lastProcessedIndex + 1);

                    try {
                        // Process message
                        onMessage(toProcess.type, toProcess.data);
                    }
                    catch (e) {
                        console.error(e);
                    }

                    // Remove processed message from mapping
                    receivedMessages.delete(lastProcessedIndex + 1);

                    // Increment processed index
                    lastProcessedIndex++;
                    this.lastProcessedIndexByClientId.set(remoteClient, lastProcessedIndex);
                }

                // Even if it's not the first time we received it,
                // Reply with a confirmation to let remote peer know about our reception.
                p.send(JSON.stringify({
                    receipt: true,
                    index: message.index
                }));
            }

        };

    } //listenToPeerMessages

    sendPeerMessage(p:Peer, type:string, data?:any) {

        if (!p || p.destroyed) {
            console.error('Invalid peer: ' + p);
            return;
        }

        let remoteClient = p.remoteClient;

        // Check that this client is not expired
        if (this.expiredClientIds.has(remoteClient) && type !== 'sync') {
            console.warn('Cannot send message to expired client: ' + remoteClient);
            return;
        }

        // Create required mappings if needed
        //
        if (!this.pendingMessagesByClientId.has(remoteClient)) {
            this.pendingMessagesByClientId.set(remoteClient, new Map());
        }
        if (!this.lastSentIndexByClientId.has(remoteClient)) {
            this.lastSentIndexByClientId.set(remoteClient, -1);
        }

        // Get message index and increment
        let messageIndex = this.lastSentIndexByClientId.get(remoteClient) + 1;
        this.lastSentIndexByClientId.set(remoteClient, messageIndex);

        let message:PeerMessage = {
            index: messageIndex,
            type: type,
            data: data
        };

        // Keep message, to re-send it if needed
        this.pendingMessagesByClientId.get(remoteClient).set(messageIndex, {
            time: new Date().getTime(),
            message: message,
            attempts: 1
        });

        // Send it
        p.send(JSON.stringify(message));

    } //sendPeerMessage

/// Send/Receive project via Realtime

    sendMasterProjectToEveryone() {

        // Update online sync timestamp
        this.lastOnlineSyncTimestamp = new Date().getTime() / 1000.0;

        // Serialize
        let options = { entries: {}, recursive: true };
        let serialized = serializeModel(this, options);

        // Keep the stuff we want
        //
        let entries:Array<any> = [];
        for (let key in options.entries) {
            if (options.entries.hasOwnProperty(key)) {
                entries.push(options.entries[key].serialized);
            }
        }
        
        let data = {
            project: serialized,
            entries: entries
        };

        // Cleanup pending stuff
        this.nextLocalChangesetIndex = 0;
        this.pendingLocalChangesets = [];
        this.pendingRemoteChangesetsByClientId = new Map();
        this.lastProcessedChangesetIndexByClientId = new Map();
        this.lastProcessedIndexByClientId = new Map();

        // We are up to date, now
        this.isUpToDate = true;

        // Send to every peer
        let updatedClients:Array<string> = [this.clientId];
        for (let peer of this.peers) {
            if (updatedClients.indexOf(peer.remoteClient) === -1) {
                updatedClients.push(peer.remoteClient);
                this.expiredClientIds.delete(peer.remoteClient);
                this.upToDateClientIds.set(peer.remoteClient, true);
            }
        }
        for (let peer of this.peers) {
            this.sendPeerMessage(peer, 'sync', {
                status: 'reset',
                project: data,
                timestamp: this.lastOnlineSyncTimestamp,
                clients: updatedClients
            });

            // Let others retrieve latest files
            if (this.lastGitSyncCommitHash) {
                this.sendPeerMessage(peer, 'files', {
                    gitCommitHash: this.lastGitSyncCommitHash,
                    syncTimestamp: this.lastOnlineSyncTimestamp
                });
            }
        }

    } //sendMasterProjectToEveryone

    loadMasterProject(data:{project:any, entries:Array<any>}) {

        let serialized = data.project;

        // Remove footprint (we will compute ours)
        delete serialized.footprint;

        // Reset sync timestamp & footprint if not provided
        if (!serialized.lastGitSyncProjectFootprint) {
            serialized.lastGitSyncProjectFootprint = null;
        }
        if (!serialized.lastGitSyncTimestamp) {
            serialized.lastGitSyncTimestamp = null;
        }

        // Update db from project data
        for (let serializedItem of data.entries) {
            db.putSerialized(serializedItem, false);
        }
        for (let serializedItem of data.entries) {
            db.putSerialized(serializedItem, true);
        }

        // Put project (and trigger its update)
        db.putSerialized(serialized);

    } //loadMasterProject

/// Database changes listener

    onDbChange(changeset:{
        newSerialized:any,
        prevSerialized:any,
        hasHistoryItems:boolean,
        historyNewSerialized:any,
        historyPrevSerialized:any
    }) {

        let { undoing, redoing, doingItem } = history;
        let { newSerialized, prevSerialized, hasHistoryItems, historyNewSerialized, historyPrevSerialized } = changeset;

        let meta:any = {
            owner: this.clientId,
            syncTimestamp: this.lastOnlineSyncTimestamp
        };

        // Nothing to do in those cases
        if (this.onlineEnabled && this.hasRemotePeers) {

            // Get list if ids that belong to project
            // We need to browse full project for that.
            // Might want to find another solution later.
            let options = { entries: {}, recursive: true };
            let serializedProject = serializeModel(this, options);
            let projectEntries = options.entries;

            let keptSerialized:any = {};

            // Some data has changed. First, let's keep objects that belong to project
            let numEntries = 0;
            for (let itemId in newSerialized) {
                if (newSerialized.hasOwnProperty(itemId)) {
                    if (projectEntries[itemId] != null || itemId === 'project') {
                        keptSerialized[itemId] = newSerialized[itemId];
                        numEntries++;
                    }
                }
            }

            // Do we have something that changed?
            if (numEntries > 0) {

                meta.project = true;

                // Yes, then let's do things differently if we are master peer or not
                if (this.isMaster) {

                    let localChangesetIndex = this.nextLocalChangesetIndex++;
                    meta.localIndex = localChangesetIndex;

                    // We are master, let's send updated data to everyone
                    // Peers will either receive it or be marked as expired
                    for (let peer of this.peers) {
                        this.sendPeerMessage(peer, 'change', {
                            master: true,
                            lastSyncTimestamp: this.lastOnlineSyncTimestamp,
                            changesets: [{
                                index: localChangesetIndex,
                                consumedIndex: this.consumedChangesetIndexByMaster,
                                consumedClient: this.consumedClientByMaster,
                                data: keptSerialized,
                                redoing: redoing && doingItem ? {
                                    owner: doingItem.meta.owner,
                                    index: doingItem.meta.localIndex,
                                    syncTimestamp: doingItem.meta.syncTimestamp
                                } : null,
                                undoing: undoing && doingItem ? {
                                    owner: doingItem.meta.owner,
                                    index: doingItem.meta.localIndex,
                                    syncTimestamp: doingItem.meta.syncTimestamp
                                } : null
                            }]
                        });
                    }
                }
                else {

                    // Re-send changesets that where not sent to this client id
                    // (in case master peer changed)
                    let changesetsToSend:Array<PendingChangeset> = [];
                    for (let changeset of this.pendingLocalChangesets) {
                        if (changeset.targetClient !== this.masterPeer.remoteClient) {
                            changeset.targetClient = this.masterPeer.remoteClient;
                            changesetsToSend.push(changeset);
                        }
                    }

                    let localChangesetIndex = this.nextLocalChangesetIndex++;
                    meta.localIndex = localChangesetIndex;

                    // We are not master, and doing our own changes,
                    // let's send data to master,
                    // and also keep the changeset safe until it
                    // has been processed by master.
                    this.pendingLocalChangesets.push({
                        index: localChangesetIndex,
                        data: keptSerialized,
                        targetClient: this.masterPeer.remoteClient,
                        redoing: redoing && doingItem ? {
                            owner: doingItem.meta.owner,
                            index: doingItem.meta.localIndex,
                            syncTimestamp: doingItem.meta.syncTimestamp
                        } : null,
                        undoing: undoing && doingItem ? {
                            owner: doingItem.meta.owner,
                            index: doingItem.meta.localIndex,
                            syncTimestamp: doingItem.meta.syncTimestamp
                        } : null
                    });
                    changesetsToSend.push(this.pendingLocalChangesets[this.pendingLocalChangesets.length - 1]);

                    // Then send a message that includes all pending changesets
                    if (this.masterPeer != null && changesetsToSend.length > 0) {
                        this.sendPeerMessage(this.masterPeer, 'change', {
                            master: false,
                            lastSyncTimestamp: this.lastOnlineSyncTimestamp,
                            changesets: changesetsToSend
                        });
                    }
                }
            }
            else {
                meta.project = false;
            }

        }

        if (hasHistoryItems) {
            meta.time = new Date().getTime();
            history.push({
                meta: meta,
                do: historyNewSerialized,
                undo: historyPrevSerialized,
            });
        }

    }

} //Project

export default Project;
