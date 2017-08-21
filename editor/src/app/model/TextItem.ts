import { serialize, observe, compute, action } from 'utils';
import VisualItem from './VisualItem';

class TextItem extends VisualItem {

/// Properties

    /** Item font (name) */
    @observe @serialize font:string = null;

    /** Item width */
    @observe width:number = 0;

    /** Item height */
    @observe height:number = 0;

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

    /** Item color */
    @observe @serialize color:number = 0xFFFFFF;

/// Computed

    @compute get hexColor():string {

        var hex = Number(this.color).toString(16).toUpperCase();
        while (hex.length < 6) {
            hex = '0' + hex;
        }

        return '#' + hex;

    } //hexColor

    @action setHexColor(value:string) {

        this.color = parseInt('0x' + value.substr(1), 16);

    } //setHexColor

} //TextItem

export default TextItem;
