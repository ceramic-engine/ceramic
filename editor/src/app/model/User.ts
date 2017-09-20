import { serialize, observe, compute, action, history, Model } from 'utils';

/** User-specific data that don't belong to the shared project file */
class User extends Model {

/// Properties (serialized)

    /** Project absolute path */
    @observe @serialize projectPath:string = null;

    /** Whether current project is dirty (has unsaved changes) or not */
    @observe @serialize projectDirty:boolean = true;

    /** Whether current project (github repository, master branch) is dirty (has uncommited changes) or not */
    @observe @serialize manualGithubProjectDirty:boolean = true;

    /** Whether current project (github repository, auto branch) is dirty (has uncommited changes) or not */
    @observe @serialize autoGithubProjectDirty:boolean = true;

/// Github access
    
    /** Github personal access token */
    @observe @serialize githubToken?:string;

/// Room / realtime

    @observe @serialize realtimeApiKey?:string;

/// Internal

    private ignoreProjectChanges = false;

/// Lifecycle

    constructor(id?:string) {

        super(id);

        // Track history changes to mark project as dirty
        history.on('push', () => {
            if (!this.ignoreProjectChanges) {
                this.projectDirty = true;
                this.manualGithubProjectDirty = true;
                this.autoGithubProjectDirty = true;
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

    markManualGithubProjectAsClean():void {

        this.ignoreProjectChanges = true;

        this.manualGithubProjectDirty = false;

        setImmediate(() => {
            setImmediate(() => {
                this.ignoreProjectChanges = false;
            });
        });

    } //markManualGithubProjectAsClean

    markAutoGithubProjectAsClean():void {

        this.ignoreProjectChanges = true;

        this.autoGithubProjectDirty = false;

        setImmediate(() => {
            setImmediate(() => {
                this.ignoreProjectChanges = false;
            });
        });

    } //markAutoGithubProjectAsClean

} //User

export default User;
