import { serialize, observe, compute, action, history, Model } from 'utils';

/** User-specific data that don't belong to the shared project file */
class User extends Model {

/// Properties (serialized)

    /** Project absolute path */
    @observe @serialize projectPath:string = null;

    /** Whether current project is dirty (has unsaved changes) or not */
    @observe @serialize projectDirty:boolean = true;

    /** Whether current project (github repository) is dirty (has uncommited changes) or not */
    @observe @serialize githubProjectDirty:boolean = true;

/// Github access
    
    /** Github personal access token */
    @observe @serialize githubToken?:string;

/// Internal

    private ignoreProjectChanges = false;

/// Lifecycle

    constructor(id?:string) {

        super(id);

        // Track history changes to mark project as dirty
        history.on('push', () => {
            if (!this.ignoreProjectChanges) {
                this.projectDirty = true;
                this.githubProjectDirty = true;
            }
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

    markGithubProjectAsClean():void {

        this.ignoreProjectChanges = true;

        this.githubProjectDirty = false;

        setImmediate(() => {
            setImmediate(() => {
                this.ignoreProjectChanges = false;
            });
        });

    } //markGithubProjectAsClean

} //User

export default User;
