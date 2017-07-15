import * as electron from 'electron';
import * as fs from 'fs';
import { join, normalize } from 'path';

class Files {

    /** Open a dialog to choose a directory */
    chooseDirectory() {

        var result = electron.remote.dialog.showOpenDialog({
            title: 'Choose directory',
            properties: ['openDirectory', 'createDirectory']
        });

        return result != null ? result[0] : null;

    } //chooseDirectory

    /** Get flat directory, meaning all file paths in the given root path, recursively. */
    getFlatDirectory(dir:string, excludeSystemFiles:boolean = true, subCall:boolean = false):Array<string> {

        var result:Array<string> = [];

        for (let name of fs.readdirSync(dir)) {

            if (excludeSystemFiles && name === '.DS_Store') continue;

            var path = join(dir, name);
            if (fs.statSync(path).isDirectory()) {
                result = result.concat(this.getFlatDirectory(path, excludeSystemFiles, true));
            } else {
                result.push(path);
            }
        }

        if (!subCall) {
            var prevResult = result;
            result = [];
            var prefix = normalize(dir);
            if (!prefix.endsWith('/')) prefix += '/';
            for (let item of prevResult) {
                result.push(item.substr(prefix.length));
            }
        }

        return result;

    } //getFlatDirectory
}

export default new Files();
