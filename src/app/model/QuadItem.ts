import { serialize, observe } from 'utils';
import VisualItem from './VisualItem';

class QuadItem extends VisualItem {

/// Properties

    /** Item texture (name) */
    @observe @serialize texture:string = null;

} //QuadItem

export default QuadItem;
