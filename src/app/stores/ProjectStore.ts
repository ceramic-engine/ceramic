
import { observable, action, autorun } from 'mobx';
import { files, storage } from '../../utils';
import autobind from 'autobind-decorator';

@autobind class ProjectStore {

/// Data

    /** Project path */
    @observable path:string;

    /** Project name */
    @observable name:string;

/// Lifecycle

    constructor(load:boolean, save:boolean) {

        var key = 'stores/project';
        var local = storage.get(key);

        if (load && local != null) {
            this.path = local.path;
        }

        if (save) {
            autorun(() => {
                local.path = this.path;
                storage.set(key, local);
            });
        }

    } //constructor

/// Actions

    /** Open native dialog to select project path */
    @action selectPath() {

        // If path is already defined, there is nothing to choose.
        // We need to do this check because it can happen that the selectPath()
        // method is triggered twice because the UI got multiple events whe the
        // native dialog was opening.
        if (this.path != null) return;

        var directory = files.chooseDirectory();
        if (directory != null) {
            this.path = directory;
        }

    } //selectPath

} //Project

export default ProjectStore;
