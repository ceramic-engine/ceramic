import { serialize } from './serialize-decorator';
import uuid from './uuid';
import { db } from './database';

/** Parent model class */
class Model {

    static rootInstances:Array<Model> = [];

/// Properties

    /** This model unique identifier */
    @serialize id:string;

/// Keep

    private _keep:boolean = false;
    
    /** Tell this model should be kept no matter what if set to `true`. This means that this object
        and its children won't be removed from `db` when cleaning. */
    get keep():boolean {
        return this._keep;
    }
    set keep(value:boolean) {
        if (this._keep === value) return;
        this._keep = value;
        if (value) {
            Model.rootInstances.push(this);
        } else {
            Model.rootInstances.splice(Model.rootInstances.indexOf(this), 1);
        }
    }

/// Lifecycle

    constructor(id?:string) {

        // Set id
        if (id != null) {
            this.id = id;
        } else {
            this.id = uuid();
        }

        // Ensure item is put in db, but let additional user code run first
        setImmediate(() => {
            db.put(this, undefined, false);
        });

    } //constructor

    set instance(val:any) {
        throw 'CANNOT SET INSTANCE ON MODEL';
    }

} //Model

export default Model;
