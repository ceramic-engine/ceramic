import 'reflect-metadata';
import * as React from 'react';
import * as ReactDOM from 'react-dom';
import CeramicEditor from './CeramicEditor';
import registerServiceWorker from './registerServiceWorker';
import './index.css';

ReactDOM.render(
    <CeramicEditor />,
    document.getElementById('root') as HTMLElement
);
registerServiceWorker();
