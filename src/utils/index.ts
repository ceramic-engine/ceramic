
export { default as files } from './files';
export { default as storage } from './storage';
export { history, History, HistoryItem, HistoryListener } from './history';

// Export external utilities
export { default as autobind } from 'autobind-decorator';

// Export core classes
export { default as Model } from './Model';

// Assign db
//import Model from './Model';
import { db } from './database'; //ok

// Export db instance
export { db, Database } from './database';

// Let db listen to history changes
import { history } from './history';
history.listener = db;

// Export mobx utilities
export { action, observable as observe, computed as compute } from 'mobx';
export { observer } from 'mobx-react';

// Export serializer
export { serialize } from './serialize-decorator';
export { serializeValue, serializeModel, deserializeModel, deserializeValue, deserializeModelInto } from './serialize';
