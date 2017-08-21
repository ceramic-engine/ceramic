
import { db, registerModel } from 'utils';
import Project from './Project';
import User from './User';

// Register model types
import Scene from './Scene';
registerModel(Scene);
import SceneItem from './SceneItem';
registerModel(SceneItem);
import VisualItem from './VisualItem';
registerModel(VisualItem);
import QuadItem from './QuadItem';
registerModel(QuadItem);
import TextItem from './TextItem';
registerModel(TextItem);
import UiState from './UiState';
registerModel(UiState);

// Export store classes
export { default as Project } from './Project';
export { default as User } from './User';
export { default as Scene } from './Scene';
export { default as SceneItem } from './SceneItem';
export { default as VisualItem } from './VisualItem';
export { default as QuadItem } from './QuadItem';
export { default as TextItem } from './TextItem';
export { default as UiState } from './UiState';

// Load db (if anything to load)
db.load();

// Export app instances
//
export const user = db.getOrCreate(User, 'user', true);
user.keep = true;
export const project = db.getOrCreate(Project, 'project', true);
project.keep = true;
if (!project.initialized) {
    project.createNew();
}
