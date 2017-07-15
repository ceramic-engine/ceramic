import { serialize, observe, Model } from 'utils';

class Asset extends Model {

/// Properties

    /** Asset name (identifier) */
    @observe @serialize name:string;

    /** Asset blob */
    blob:Blob;

} //Asset

export default Asset;
