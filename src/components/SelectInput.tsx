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

    inputElement:HTMLSelectElement = null;

    render() {

        let className = 'input-select-container';
        if (this.props.empty != null && this.props.selected === this.props.empty) {
            className += ' empty';
        }

        return (
            <div className={className}>
                <select
                    value={this.props.selected}
                    className="input input-select"
                    onChange={this.handleChange}
                    onFocus={this.handleFocus}
                    onBlur={this.handleBlur}
                    ref={(el) => { this.inputElement = el; }}
                >
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

        global['focusedInput'] = this;

    } //handleFocus

    @autobind handleBlur(e:any) {

        e.target.parentNode.classList.remove('focus');

        if (global['focusedInput'] === this) {
            global['focusedInput'] = undefined;
        }

    } //handleBlur

/// Clipboard

    getSelected(cut:boolean = false) {

        let input = this.inputElement;
        let val = input.options[input.selectedIndex].text.trim();

        // No cut in select. How would we do that?

        return val;

    } //getSelected

    setSelected(content:string) {

        let input = this.inputElement;

        for (let i = 0; i < input.options.length; i++) {
            if (input.options[i].text.trim().toLowerCase() === content.trim().toLowerCase()) {
                input.selectedIndex = i;

                this.handleChange({
                    target: input
                });

                break;
            }
        }

    } //setSelected

}

export default SelectInput;
