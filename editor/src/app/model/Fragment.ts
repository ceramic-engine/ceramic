import { serialize, observe, compute, serializeModel, stableSort, Model } from 'utils';
import FragmentItem from './FragmentItem';
import VisualItem from './VisualItem';
import QuadItem from './QuadItem';
import TextItem from './TextItem';
import { project } from './index';

class Fragment extends Model {

/// Properties

    /** Fragment arbitrary data */
    @observe @serialize data:Map<string, any> = new Map();

    /** Fragment bundle name (default: project's default bundle) */
    @observe @serialize bundle:string = null;

    /** Fragment name */
    @observe @serialize name:string = '';

    /** Fragment width */
    @observe @serialize width:number = 800;

    /** Fragment height */
    @observe @serialize height:number = 600;

    /** Fragment items */
    @observe @serialize(FragmentItem) items:Array<FragmentItem|VisualItem|QuadItem|TextItem> = [];

/// Computed

    @compute get itemsById() {
        
        let byName:Map<string, FragmentItem|VisualItem|QuadItem|TextItem> = new Map();

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

    @compute get quadItems() {
        
        let result:Array<QuadItem> = [];

        for (let item of this.items) {
            if (item instanceof QuadItem) {
                result.push(item);
            }
        }

        return result;

    } //quadItems

    @compute get textItems() {
        
        let result:Array<TextItem> = [];

        for (let item of this.items) {
            if (item instanceof TextItem) {
                result.push(item);
            }
        }

        return result;

    } //textItems

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

        return serializeModel(this, { exclude: ['_model', 'items', 'bundle'] });

    } //serializeForCeramic

} //Fragment

export default Fragment;
