import { serialize, observe } from 'utils';
import SceneItem from './SceneItem';

class VisualItem extends SceneItem {

/// Properties

    /** Item width */
    @observe @serialize width:number = 100;

    /** Item height */
    @observe @serialize height:number = 100;

    /** Item x */
    @observe @serialize x:number = 0;

    /** Item y */
    @observe @serialize y:number = 0;

    /** Item anchorX */
    @observe @serialize anchorX:number = 0.5;

    /** Item anchorY */
    @observe @serialize anchorY:number = 0.5;

    /** Item skewX */
    @observe @serialize skewX:number = 0;

    /** Item skewY */
    @observe @serialize skewY:number = 0;

    /** Item color */
    @observe @serialize color:number = 0xFFFFFF;

    /** Item alpha */
    @observe @serialize alpha:number = 1;

} //Scene

export default VisualItem;
