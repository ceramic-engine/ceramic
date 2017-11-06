import { serialize, observe } from 'utils';
import { project } from 'app/model';

export default class CollectionEntry {

    /** Entry name */
    @observe name:string = '';

    /** Entry id */
    @observe id:string = '';

    /** Props */
    @observe @serialize props:Map<string,any> = new Map();

} //CollectionEntry
