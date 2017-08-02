import { serialize, observe, compute, Model } from 'utils';
import { project } from './index';
import { VisualItem, QuadItem, SceneItem } from './index';

class UiState extends Model {

/// Properties
    
    @observe @serialize sceneTab:number;

    @observe expandedAsset?:{name:string, constName:string, paths:Array<string>};

    @observe addingVisual:boolean;

    @observe @serialize selectedItemId:string;

/// Computed

    @compute get selectedItem():VisualItem|QuadItem|SceneItem {

        for (let item of project.scene.items) {
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

/// Lifecycle

    constructor(id?:string) {

        super(id);

    } //constructor

} //Scene

export default UiState;
