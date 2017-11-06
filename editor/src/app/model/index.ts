
import { db, uuid, registerModel } from 'utils';
import Project from './Project';
import User from './User';
import { context } from '../context';

// Register model types
import Fragment from './Fragment';
registerModel(Fragment);
import FragmentItem from './FragmentItem';
registerModel(FragmentItem);
import VisualItem from './VisualItem';
registerModel(VisualItem);
import UiState from './UiState';
registerModel(UiState);

// Export store classes
export { default as Project } from './Project';
export { default as User } from './User';
export { default as Fragment } from './Fragment';
export { default as FragmentItem } from './FragmentItem';
export { default as VisualItem } from './VisualItem';
export { default as UiState } from './UiState';
export { default as CollectionEntry } from './CollectionEntry';

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
// Just for retro-compatibility ; TODO remove
if (!project.uuid) project.uuid = uuid();
