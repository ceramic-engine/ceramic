
import { db } from 'utils';
import Project from './Project';

// Export app instances
export const project = db.getOrCreate(Project, 'project');

// Export store classes
export { default as Project } from './Project';
