import { serialize, observe, compute, serializeModel, Model } from 'utils';
import SceneItem from './SceneItem';
import VisualItem from './VisualItem';
import QuadItem from './QuadItem';

class Scene extends Model {

/// Properties

    /** Scene name (identifier) */
    @observe @serialize name:string;

    /** Scene arbitrary data */
    @observe @serialize data:Map<string, any>;

    /** Scene width */
    @observe @serialize width:number;

    /** Scene height */
    @observe @serialize height:number;

    /** Scene items */
    @observe @serialize(SceneItem) items:Array<SceneItem|VisualItem|QuadItem> = [];

/// Computed

    @compute get itemsByName() {
        
        let byName:Map<string, SceneItem|VisualItem|QuadItem> = new Map();

        for (let item of this.items) {
            byName.set(item.name, item);
        }

        return byName;

    } //itemsByName

    @compute get visualItems() {
        
        let result:Array<VisualItem|QuadItem> = [];

        for (let item of this.items) {
            if (item instanceof VisualItem) {
                result.push(item);
            }
        }

        return result;

    } //visualItems

/// Helpers

    serializeForCeramic() {

        return serializeModel(this, { exclude: ['_model', 'id', 'items'] });

    } //serializeForCeramic

} //Scene

export default Scene;
