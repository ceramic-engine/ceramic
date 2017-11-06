import * as React from 'react';
import { autobind } from 'utils';

/** Select input */
class SelectInput extends React.Component {

    props:{
        /** Selected */
        selected:number,
        /** Empty index */
        empty?:number,
        /** Width */
        size?:"large",
        /** Options */
        options:Array<string>,
        /** onChange */
        onChange?:(value:number) => void
    };

    inputElement:HTMLSelectElement = null;

    render() {

        let className = 'input-select-container' + (process.platform === 'win32' ? ' windows' : ' mac');
        if (this.props.empty != null && this.props.selected === this.props.empty) {
            className += ' empty';
        }

        return (
            <div className={className + (this.props.size === 'large' ? ' large' : '')}>
                <select
                    value={this.props.selected}
                    className={'input input-select'}
                    onKeyDown={this.handleKeyDown}
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

    @autobind handleKeyDown(e:any) {

        var moveBy = 0;
        if (e.keyCode === 40) { // Arrow down
            e.preventDefault();
            moveBy = 1;
        }
        else if (e.keyCode === 38) { // Arrow up
            e.preventDefault();
            moveBy = -1;
        }

        if ((moveBy === -1 && this.props.selected > 0 ) || (moveBy === 1 && this.props.selected < this.props.options.length - 1)) {

            let input = this.inputElement;

            input.selectedIndex += moveBy;

            this.handleChange({
                target: input
            });

        }

    } //handleKeyDown

/// Clipboard

    copySelected(cut:boolean = false) {

        let input = this.inputElement;
        let val = input.options[input.selectedIndex].text.trim();

        // No cut in select. How would we do that?

        return val;

    } //copySelected

    pasteToSelected(content:string) {

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

    } //pasteToSelected

}

export default SelectInput;
