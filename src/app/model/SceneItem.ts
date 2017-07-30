import { serialize, observe, serializeModel, Model } from 'utils';

class SceneItem extends Model {

/// Properties

    /** Item name (identifier) */
    @observe @serialize name:string;

    /** Item entity class */
    @observe @serialize entity:string;

/// Helpers

    serializeForCeramic() {

        let serialized = serializeModel(this, { exclude: ['_model', 'id'] });
        let data:any = { props: {} };

        for (let key in serialized) {
            if (serialized.hasOwnProperty(key)) {
                if (key === 'name' || key === 'entity') {
                    data[key] = serialized[key];
                } else {
                    data.props[key] = serialized[key];
                }
            }
        }

        return data;

    } //serializeForCeramic

} //SceneItem

export default SceneItem;
