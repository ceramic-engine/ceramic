import * as React from 'react';
import { autobind } from 'utils';

/** Select input */
class SelectInput extends React.Component {

    props:{
        /** Selected */
        selected:number,
        /** Empty index */
        empty?:number,
        /** Options */
        options:Array<string>,
        /** onChange */
        onChange?:(value:number) => void
    };

    render() {

        let className = 'input-select-container';
        if (this.props.empty != null && this.props.selected === this.props.empty) {
            className += ' empty';
        }

        return (
            <div className={className}>
                <select value={this.props.selected} className="input input-select" onChange={this.handleChange} onFocus={this.handleFocus} onBlur={this.handleBlur}>
                    {this.props.options.map((opt, i) =>
                        <option key={i} value={i}>{opt}</option>
                    )}
                </select>
            </div>
        );

    } //render

    @autobind handleChange(e:any) {

        let value = parseInt(e.target.value, 10);

        if (this.props.onChange) {
            this.props.onChange(value);
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
