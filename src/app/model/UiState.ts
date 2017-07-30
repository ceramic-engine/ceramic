import { serialize, observe, compute, Model } from 'utils';
import { project } from './index';

class UiState extends Model {

/// Properties
    
    @observe @serialize sceneTab:number;

    @observe expandedAsset?:{name:string, constName:string, paths:Array<string>};

    @observe addingVisual:boolean;

    @observe @serialize selectedItemId:string;

/// Computed

    @compute get selectedItem() {

        for (let item of project.scene.items) {
            if (item.id === this.selectedItemId) {
                return item;
            }
        }

        return null;

    } //selectedItem

/// Lifecycle

    constructor(id?:string) {

        super(id);

    } //constructor

} //Scene

export default UiState;
