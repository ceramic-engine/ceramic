import { serialize, observe, compute, action } from 'utils';
import VisualItem from './VisualItem';

class QuadItem extends VisualItem {

/// Properties

    /** Item width (explicit) */
    @observe @serialize explicitWidth:number = 100;

    /** Item height (explicit) */
    @observe @serialize explicitHeight:number = 100;

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

/// Actions

    @action setHexColor(value:string) {

        this.color = parseInt('0x' + value.substr(1), 16);

    } //setHexColor

/// Helpers

    serializeForCeramic() {

        let data = super.serializeForCeramic();

        // Let ceramic compute size if texture is provided
        if (data.props.texture) {
            delete data.props.width;
            delete data.props.height;
        }

        return data;

    } //serializeForCeramic

} //QuadItem

export default QuadItem;
