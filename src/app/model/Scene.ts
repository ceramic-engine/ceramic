import { serialize, observe, compute, serializeModel, stableSort, Model } from 'utils';
import SceneItem from './SceneItem';
import VisualItem from './VisualItem';
import QuadItem from './QuadItem';
import TextItem from './TextItem';

class Scene extends Model {

/// Properties

    /** Scene arbitrary data */
    @observe @serialize data:Map<string, any>;

    /** Scene width */
    @observe @serialize width:number;

    /** Scene height */
    @observe @serialize height:number;

    /** Scene items */
    @observe @serialize(SceneItem) items:Array<SceneItem|VisualItem|QuadItem|TextItem> = [];

/// Computed

    @compute get itemsById() {
        
        let byName:Map<string, SceneItem|VisualItem|QuadItem|TextItem> = new Map();

        for (let item of this.items) {
            byName.set(item.id, item);
        }

        return byName;

    } //itemsByName

    @compute get visualItems() {
        
        let result:Array<VisualItem|QuadItem|TextItem> = [];

        for (let item of this.items) {
            if (item instanceof VisualItem) {
                result.push(item);
            }
        }

        return result;

    } //visualItems

    @compute get visualItemsSorted() {
        
        let result:Array<VisualItem|QuadItem|TextItem> = [];

        for (let item of this.visualItems) {
            result.push(item);
        }

        stableSort(result, function(a, b) {
            if (a.depth < b.depth) return 1;
            if (a.depth > b.depth) return -1;
            return 0;
        });

        return result;

    } //visualItems

/// Helpers

    serializeForCeramic() {

        return serializeModel(this, { exclude: ['_model', 'items'] });

    } //serializeForCeramic

} //Scene

export default Scene;
