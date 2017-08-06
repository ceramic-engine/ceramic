import { serialize, observe, compute, Model } from 'utils';
import { project } from './index';
import { VisualItem, QuadItem, SceneItem, TextItem } from './index';

class UiState extends Model {

/// Properties
    
    @observe @serialize sceneTab:number;

    @observe expandedAsset?:{name:string, constName:string, paths:Array<string>};

    @observe addingVisual:boolean;

    @observe @serialize selectedItemName:string;

/// Computed

    @compute get selectedItem():VisualItem|QuadItem|SceneItem {

        for (let item of project.scene.items) {
            if (item.name === this.selectedItemName) {
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
