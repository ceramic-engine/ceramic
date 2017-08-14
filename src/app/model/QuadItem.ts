import { serialize, observe, compute, action } from 'utils';
import VisualItem from './VisualItem';

class QuadItem extends VisualItem {

/// Properties

    /** Item texture (name) */
    @observe @serialize texture:string = null;

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

} //QuadItem

export default QuadItem;
