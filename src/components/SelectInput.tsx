import * as React from 'react';
import { autobind } from 'utils';

/** Select input */
class SelectInput extends React.Component {

    props:{
        /** Value */
        value:string,
        /** Options */
        options:Array<string>,
        /** onChange */
        onChange?:(value:string) => void
    };

    render() {

        return (
            <div className="input-select-container">
                <select className="input input-select" onChange={this.handleChange} onFocus={this.handleFocus} onBlur={this.handleBlur}>
                    <option value="val1">Val 1</option>
                    <option value="val2">Val 2</option>
                    <option value="val3">Val 3</option>
                </select>
            </div>
        );

    } //render

    @autobind handleChange(e:any) {

        if (this.props.onChange) {
            // TODO
        }

    } //handleChange

    @autobind handleFocus(e:any) {

        e.target.parentNode.classList.add('focus');

    } //handleFocus

    @autobind handleBlur(e:any) {

        e.target.parentNode.classList.remove('focus');

    } //handleBlur

}

export default SelectInput;
