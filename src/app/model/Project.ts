import { serialize, observe, action, compute, files, autorun, ceramic, keypath, history, uuid, db, serializeModel, Model } from 'utils';
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

class Project extends Model {

/// Properties

    /** Project scenes */
    @observe @serialize(Scene) scenes:Array<Scene> = [];

    /** Project error */
    @observe error?:string;

    /** Project name */
    @observe @serialize name?:string;

/// UI State

    @observe @serialize ui:UiState;

/// Assets

    /** Assets path */
    @observe @serialize assetsPath?:string;

    /** All assets */
    @observe allAssets?:Array<string>;

    /** All asset directories */
    @observe allAssetDirs?:Array<string>;

    /** All assets by name */
    @observe allAssetsByName?:Map<string, Array<string>>;

    /** All asset directories */
    @observe allAssetDirsByName?:Map<string, Array<string>>;

    /** Image assets */
    @observe imageAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

    /** Text assets */
    @observe textAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

    /** Sound assets */
    @observe soundAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

    /** Font assets */
    @observe fontAssets?:Array<{name:string, constName:string, paths:Array<string>}>;

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

    @compute get cwd():string {

        if (this.path) return dirname(this.path);
        return null;

    } //cwd

/// Lifecycle

    constructor(id?:string) {

        super(id);

        // Update asset info from assets path
        //
        autorun(() => {

            let electronApp = electron.remote.require('./app.js');

            electronApp.sourceAssetsPath = this.absoluteAssetsPath;
            electronApp.assetsPath = null;

            if (this.absoluteAssetsPath != null) {
                console.debug('ABSOLUTE ASSETS: ' + this.absoluteAssetsPath);
                electronApp.processingAssets = true;
                let processedAssetsPath = join(os.tmpdir(), 'ceramic', this.id);
                let proc = ceramic.run([
                    'luxe', 'assets', 'web',
                    '--from', this.absoluteAssetsPath,
                    '--to', processedAssetsPath
                ], process.cwd(), (code) => {
                    if (code !== 0) {
                        console.error('Failed to process assets');
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

        // Reset assets path
        this.assetsPath = null;

        // Reset project path
        user.projectPath = null;

        // Set scene
        this.scenes = [];

        // Set UI state
        this.ui = new UiState('ui');

    } //createNew

    @action chooseAssetsPath() {

        let path = files.chooseDirectory();
        if (path != null) {
            this.assetsPath = path;
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

/// Save

    save():void {

        if (!this.path || !fs.existsSync(dirname(this.path))) {
            this.saveAs();
            return;
        }

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
        console.log('saved project at: ' + this.path);

        // Mark project as `clean`
        user.markProjectAsClean();

    } //save

    saveAs():void {

        let path = files.chooseSaveAs(
        'Save project',
        [
            {
                name: 'Ceramic Project File',
                extensions: ['cproj']
            }
        ],
        this.path ? this.path : undefined
        );

        if (path) {

            // Keep current absolute assets path
            let assetsPath = this.absoluteAssetsPath;

            // Update project path
            user.projectPath = path;

            // Update assets path (make it relative to new project path)
            if (assetsPath) {

                let projectDir = normalize(dirname(path));
                let assetsDir = normalize(assetsPath);
                
                if (projectDir === assetsDir) {
                    this.assetsPath = '.';
                } else {
                    let res = relative(projectDir, assetsDir);
                    if (!res.startsWith('.')) res = './' + res;
                    this.assetsPath = res;
                }
            
            }

            // Set project name from file path
            this.name = basename(path).split('.')[0];

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

        // Update name
        if (data.name != null && !data.name.endsWith(' (copy)')) {
            data.name += ' (copy)';
        }

        // Put item in db
        db.putSerialized(data);

        // Create instance
        let item = db.getOrCreate(Model, data.id) as SceneItem;

        // Add item
        scene.items.push(item);

        // Select item
        this.ui.selectedItemId = item.id;

    } //copySelectedItem

} //Project

export default Project;
