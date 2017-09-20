import { serialize, observe, compute, Model } from 'utils';
import { project } from './index';
import { context } from '../context';
import { Scene, VisualItem, QuadItem, SceneItem, TextItem } from './index';

class UiState extends Model {

/// Properties

    @observe @serialize editor:'scene'|'atlas' = 'scene';
    
    @observe @serialize sceneTab:'visuals'|'scenes'|'assets';

    @observe assetInfo:{asset:{name:string, constName:string, paths:Array<string>}, y:number};

    @observe menuInfo:{text:string, y:number};

    @observe addVisual:boolean;
    
    @observe editSettings:boolean;

/// Properties (selected)

    @observe selectedItemId:string;

    @observe @serialize selectedSceneId:string;

/// Status bar text

    @observe statusBarText:string = '';

    @observe statusBarTextKind:'default'|'success'|'failure'|'warning';

    @observe statusBarBisText:string = '';

    @observe statusBarBisTextKind:'default'|'success'|'failure'|'warning';

/// Loading

    @observe loadingMessage:string = '';

/// Prompt

    @observe promptChoice?:{
        title:string,
        message:string,
        choices:Array<string>
    };

    @observe promptChoiceResult:number;

    @observe promptText?:{
        title:string,
        message:string,
        placeholder:string,
        validate:string,
        cancel?:string
    };

    @observe promptTextResult:string;

    @observe promptTextCanceled:boolean;

/// Computed

    @compute get canEditHistory():boolean {

        return !(this.promptChoice || this.promptText || this.addVisual || (project.onlineEnabled && context.connectionStatus !== 'online') || (!project.ui.editSettings && project.onlineEnabled && !project.isUpToDate));

    } //canEditHistory

    @compute get canDragFileIntoWindow():boolean {

        return !(this.promptChoice || this.promptText || this.addVisual || (project.onlineEnabled && context.connectionStatus !== 'online') || (!project.ui.editSettings && project.onlineEnabled && !project.isUpToDate));

    } //canDragFileIntoWindow

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
