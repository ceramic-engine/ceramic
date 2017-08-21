import * as React from 'react';
import * as ReactDOM from 'react-dom';
import ReactApp from './ReactApp';

it('renders without crashing', () => {
    const div = document.createElement('div');
    ReactDOM.render(<ReactApp />, div);
});
