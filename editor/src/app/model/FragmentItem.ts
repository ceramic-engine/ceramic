import { serialize, observe, serializeModel, Model } from 'utils';

class FragmentItem extends Model {

/// Sort

    /** Item sort index */
    @observe @serialize sortIndex:number = 0;

/// Lock

    /** Item locked state */
    @observe @serialize locked:boolean = false;

/// Properties

    /** Item entity class */
    @observe @serialize entity:string;

    /** Item name */
    @observe @serialize name:string = '';

/// Helpers

    serializeForCeramic() {

        let serialized = serializeModel(this, { exclude: ['_model'] });
        let data:any = { props: {}, data: {} };

        for (let key in serialized) {
            if (serialized.hasOwnProperty(key)) {
                if (key === 'locked' || key === 'name') {
                    data.data[key] = serialized[key];
                } else if (key === 'id' || key === 'entity' || key === 'sortIndex') {
                    data[key] = serialized[key];
                } else if (key === 'explicitWidth') {
                    if (serialized[key] != null) {
                        data.props.width = serialized[key];
                    }
                } else if (key === 'explicitHeight') {
                    if (serialized[key] != null) {
                        data.props.height = serialized[key];
                    }
                }
                else {
                    data.props[key] = serialized[key];
                }
            }
        }

        return data;

    } //serializeForCeramic

} //FragmentItem

export default FragmentItem;
