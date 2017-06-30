
import ProjectStore from './ProjectStore';

// Export store instances
export const project = new ProjectStore(true, true);

// Export store classes
export { default as ProjectStore } from './ProjectStore';
