
import { db, registerModel } from 'utils';
import Project from './Project';

// Register model types
import Scene from './Scene';
registerModel(Scene);
import SceneItem from './SceneItem';
registerModel(SceneItem);
import VisualItem from './VisualItem';
registerModel(VisualItem);
import UiState from './UiState';
registerModel(UiState);
import Asset from './Asset';
registerModel(Asset);

// Export store classes
export { default as Project } from './Project';
export { default as Scene } from './Scene';
export { default as SceneItem } from './SceneItem';
export { default as VisualItem } from './VisualItem';
export { default as UiState } from './UiState';
export { default as Asset } from './Asset';

// Load db (if anything to load)
db.load();

// Export app instances
export const project = db.getOrCreate(Project, 'project', true);
project.keep = true;
if (!project.name) {
    project.createWithName('project');
}
