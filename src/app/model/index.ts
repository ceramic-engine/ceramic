
import { db } from 'utils';
import Project from './Project';

// Load db (if anything to load)
db.load();

// Export app instances
export const project = db.getOrCreate(Project, 'project', true);
if (!project.name) {
    project.createWithName('project');
}

// Export store classes
export { default as Project } from './Project';
export { default as Scene } from './Scene';
