import * as electron from 'electron';

class Files {

    /** Open a dialog to choose a directory */
    chooseDirectory() {

        var result = electron.remote.dialog.showOpenDialog({
            title: 'Choose directory',
            properties: ['openDirectory', 'createDirectory']
        });

        return result != null ? result[0] : null;

    } //chooseDirectory

}

export default new Files();
