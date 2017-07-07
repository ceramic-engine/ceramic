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

    /** Scene x */
    @observe @serialize x:number;

    /** Scene y */
    @observe @serialize y:number;

    /** Scene anchorX */
    @observe @serialize anchorX:number;

    /** Scene anchorY */
    @observe @serialize anchorY:number;

} //Scene

export default Scene;
