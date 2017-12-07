import { serialize, observe, compute, serializeModel, serializeValue, stableSort, Model } from 'utils';
import FragmentItem from './FragmentItem';
import VisualItem from './VisualItem';
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

    /** Fragment overrides */
    @observe @serialize overrides:Map<string,string> = new Map();

    /** Fragment items */
    @observe @serialize(FragmentItem) items:Array<FragmentItem|VisualItem> = [];

/// Computed

    @compute get itemsById() {
        
        let byId:Map<string, FragmentItem|VisualItem> = new Map();

        for (let item of this.items) {
            byId.set(item.id, item);
        }

        return byId;

    } //itemsById

    @compute get itemsByName() {
        
        let byName:Map<string, FragmentItem|VisualItem> = new Map();

        for (let item of this.items) {
            if (!byName.has(item.name)) byName.set(item.name, item);
        }

        return byName;

    } //itemsByName

    @compute get visualItems() {
        
        let result:Array<VisualItem> = [];

        for (let item of this.items) {
            if (item instanceof VisualItem) {
                result.push(item);
            }
        }

        return result;

    } //visualItems

    @compute get visualItemsSorted() {
        
        let result:Array<VisualItem> = [];

        for (let item of this.visualItems) {
            result.push(item);
        }

        stableSort(result, function(a, b) {
            if (a.props.get('depth') < b.props.get('depth')) return 1;
            if (a.props.get('depth') > b.props.get('depth')) return -1;
            return 0;
        });

        return result;

    } //visualItems

/// Helpers

    serializeForCeramic() {

        return serializeModel(this, { exclude: ['_model', 'items', 'bundle'] });

    } //serializeForCeramic

    serializeForCeramicSubFragment(overridesData?:Map<string,any>) {

        let serialized = serializeModel(this, { exclude: ['_model', 'bundle'], recursive: true });

        if (overridesData && this.overrides) {
            overridesData.forEach((value, key) => {
                let info = this.overrides.get(key);
                if (info) {
                    let dotIndex = info.lastIndexOf('.');
                    if (dotIndex !== -1) {
                        let anItemName = info.slice(0, dotIndex);
                        let aFieldName = info.slice(dotIndex + 1);
                        for (let serializedItem of serialized.items) {
                            if (serializedItem.name === anItemName) {
                                serializedItem.props[aFieldName] = serializeValue(value);
                                break;
                            }
                        }
                    }
                }
            });
        }

        return serialized;

    } //serializeForCeramic

} //Fragment

export default Fragment;
