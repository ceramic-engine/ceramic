import { serialize, observe, action, Model } from 'utils';
import Scene from './Scene';

class Project extends Model {

/// Properties

    /** Related scene */
    @observe @serialize scene:Scene;

    /** Project error */
    @observe error:string;

    /** Project name */
    @observe name:string;

/// Public API

    @action createWithName(name:string) {

        // Set name
        this.name = name;

        // Set scene
        let scene = new Scene();
        scene.name = 'scene';
        scene.data = {};
        scene.width = 320;
        scene.height = 568;
        this.scene = scene;

    } //createWithName

} //Project

export default Project;
