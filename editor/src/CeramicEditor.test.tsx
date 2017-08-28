import * as React from 'react';
import * as ReactDOM from 'react-dom';
import CeramicEditor from './CeramicEditor';

it('renders without crashing', () => {
    const div = document.createElement('div');
    ReactDOM.render(<CeramicEditor />, div);
});
