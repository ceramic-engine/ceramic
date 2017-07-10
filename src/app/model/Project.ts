import { serialize, observe, action, autobind, files, Model } from 'utils';
import { statSync, readFileSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';
import Scene from './Scene';

class Project extends Model {

/// Properties

    /** Project path */
    @observe @serialize path:string;

    /** Related scene */
    @observe @serialize scene:Scene;

    /** Project error */
    @observe error:string;

    /** Project name */
    @observe name:string;

/// Computed

    // TODO

/// Public API

    @autobind chooseDirectory() {

        // Ensure we don't run this twice (can happen)
        if (this.path != null) return;

        // Open path
        this.setProjectPath(files.chooseDirectory());

    } //chooseDirectory

/// Actions

    @action setProjectPath(path:string|null) {

        // Set path
        if (path != null) {
            this.path = path;
        } else if (this.path != null) {
            delete this.path;
        }

        // Load data from path (if any)
        if (this.path != null) {
            if (existsSync(this.path)) {
                if (!statSync(this.path).isDirectory()) {
                    this.error = "Project path exists but is not a directory: " + this.path;
                }
                else {
                    let jsonPath = join(this.path, 'data.json');
                    if (existsSync(jsonPath)) {
                        // We open an existing project
                        try {
                            let data = JSON.parse(String(readFileSync(jsonPath)));
                            if (data.name) {
                                // Set project name
                                this.name = data.name;

                                // Set scene TODO remove
                                let scene = new Scene();
                                scene.name = 'scene';
                                scene.data = {};
                                scene.width = 320;
                                scene.height = 568;
                                scene.x = 640 / 2;
                                scene.y = 480 / 2;
                                scene.anchorX = 0.5;
                                scene.anchorY = 0.5;
                                this.scene = scene;

                            } else {
                                this.error = "Invalid project data: name is empty.";
                            }
                        }
                        catch (e) {
                            this.error = "Error when loading project data: " + e;
                        }
                    } else {
                        // The project is new
                        delete this.name;
                        delete this.error;
                    }
                }
            }
            else {
                this.error = "Project path doesn't exist: " + this.path;
            }
        }
        else {
            delete this.error;
        }

    } //setProjectPath

    @action createWithName(name:string) {

        // Set name
        this.name = name;

        // Set scene
        let scene = new Scene();
        scene.name = 'scene';
        scene.data = {};
        scene.width = 320;
        scene.height = 568;
        scene.x = 640 / 2;
        scene.y = 480 / 2;
        scene.anchorX = 0.5;
        scene.anchorY = 0.5;
        this.scene = scene;

        // Create data
        let data = {
            name: this.name
        };

        // Save data
        let jsonPath = join(this.path, 'data.json');
        writeFileSync(jsonPath, JSON.stringify(data));

    } //createWithName

} //Project

export default Project;
