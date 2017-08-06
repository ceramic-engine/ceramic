import { serialize, observe } from 'utils';
import VisualItem from './VisualItem';

class TextItem extends VisualItem {

/// Properties

    /** Item font (name) */
    @observe @serialize font:string = null;

    /** Item content */
    @observe @serialize content:string = '';

    /** Item text alignment */
    @observe @serialize align:('left'|'right'|'center') = 'left';

    /** Item text point size */
    @observe @serialize pointSize:number = 20;

    /** Item text line height */
    @observe @serialize lineHeight:number = 1.0;

    /** Item text letter spacing */
    @observe @serialize letterSpacing:number = 0.0;

} //TextItem

export default TextItem;
