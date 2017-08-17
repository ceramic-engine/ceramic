import { serialize, observe, compute, action, history, Model } from 'utils';

/** User-specific data that don't belong to the shared project file */
class User extends Model {

/// Properties (serialized)

    /** Project absolute path */
    @observe @serialize projectPath:string = null;

    /** Whether current project is dirty (has unsaved changes) or not */
    @observe @serialize projectDirty:boolean = true;

    private ignoreProjectChanges = false;

/// Lifecycle

    constructor(id?:string) {

        super(id);

        // Track history changes to mark project as dirty
        history.on('push', () => {
            if (this.ignoreProjectChanges) return;
            this.projectDirty = true;
        });

    } //constructor

/// Helpers

    markProjectAsClean():void {

        this.ignoreProjectChanges = true;

        this.projectDirty = false;

        setImmediate(() => {
            setImmediate(() => {
                this.ignoreProjectChanges = false;
            });
        });

    } //markProjectAsClean

} //User

export default User;
