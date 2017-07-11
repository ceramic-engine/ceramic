import { serialize, observe, Model } from 'utils';

class Scene extends Model {

/// Properties

    /** Scene name (identifier) */
    @observe @serialize name:string;

    /** Scene arbitrary data */
    @observe @serialize data:{ [key: string]: any } = {};

    /** Scene width */
    @observe @serialize width:number;

    /** Scene height */
    @observe @serialize height:number;

} //Scene

export default Scene;
