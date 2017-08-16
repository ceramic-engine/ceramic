import { serialize, observe, compute, Model } from 'utils';
import { project } from './index';
import { Scene, VisualItem, QuadItem, SceneItem, TextItem } from './index';

class UiState extends Model {

/// Properties

    @observe @serialize editor:'scene'|'atlas' = 'scene';
    
    @observe @serialize sceneTab:'visuals'|'scenes'|'assets';

    @observe assetInfo:{asset:{name:string, constName:string, paths:Array<string>}, y:number};

    @observe menuInfo:{text:string, y:number};

    @observe addingVisual:boolean;

/// Properties (selected)

    @observe @serialize selectedItemId:string;

    @observe @serialize selectedSceneId:string;

/// Computed

    @compute get selectedScene():Scene {

        for (let scene of project.scenes) {
            if (scene.id === this.selectedSceneId) {
                return scene;
            }
        }

        return null;

    } //selectedScene

    @compute get selectedItem():VisualItem|QuadItem|SceneItem {

        if (!this.selectedScene) return null;

        for (let item of this.selectedScene.items) {
            if (item.id === this.selectedItemId) {
                return item;
            }
        }

        return null;

    } //selectedItem

    @compute get selectedVisual():VisualItem {

        if (this.selectedItem != null && this.selectedItem instanceof VisualItem) {
            return this.selectedItem;
        }

        return null;

    } //selectedVisual

    @compute get selectedQuad():QuadItem {

        if (this.selectedItem != null && this.selectedItem instanceof QuadItem) {
            return this.selectedItem;
        }

        return null;

    } //selectedQuad

    @compute get selectedText():TextItem {

        if (this.selectedItem != null && this.selectedItem instanceof TextItem) {
            return this.selectedItem;
        }

        return null;

    } //selectedText

/// Lifecycle

    constructor(id?:string) {

        super(id);

    } //constructor

} //Scene

export default UiState;
