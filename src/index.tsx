import 'reflect-metadata';
import * as React from 'react';
import * as ReactDOM from 'react-dom';
import ReactApp from './ReactApp';
import registerServiceWorker from './registerServiceWorker';
import './index.css';
import 'antd/dist/antd.css';

ReactDOM.render(
    <ReactApp />,
    document.getElementById('root') as HTMLElement
);
registerServiceWorker();
