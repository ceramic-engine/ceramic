import 'reflect-metadata';
import * as React from 'react';
import * as ReactDOM from 'react-dom';
import ReactApp from './ReactApp';
import registerServiceWorker from './registerServiceWorker';
import './index.css';

ReactDOM.render(
    <ReactApp />,
    document.getElementById('root') as HTMLElement
);
registerServiceWorker();
