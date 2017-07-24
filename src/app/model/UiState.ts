import { serialize, observe, compute, ceramic, keypath, Model } from 'utils';
import { project } from './index';

class UiState extends Model {

/// Properties
    
    @observe @serialize sceneTab:number;

    @observe expandedAsset?:{name:string, constName:string, paths:Array<string>};

    @observe addingVisual:boolean;

    @observe selectedItemId:string;

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

        ceramic.listen('set/*', (message) => {

            let [, key] = message.type.split('/');

            if (key.startsWith('ui.')) {
                keypath.set(this, key.substr(3), message.value);
            }

        });

    } //constructor

} //Scene

export default UiState;
