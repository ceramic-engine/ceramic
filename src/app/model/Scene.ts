import { serialize, observe, serializeModel, Model } from 'utils';
import SceneItem from './SceneItem';
import VisualItem from './VisualItem';

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
    @observe @serialize(SceneItem) items:Array<SceneItem|VisualItem> = [];

/// Helpers

    serializeForCeramic() {

        return serializeModel(this, { exclude: ['_model', 'id', 'items'] });

    } //serializeForCeramic

} //Scene

export default Scene;
