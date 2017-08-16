import * as React from 'react';
import { autobind, observer, observe } from 'utils';

/** Number input */
@observer class NumberInput extends React.Component {

    props:{
        /** Value */
        value:number,
        /** Disabled */
        disabled?:boolean,
        /** onChange */
        onChange?:(value:number) => void
    };

    @observe endDot:boolean = false;

    @observe startMinus:boolean = false;

    inputElement:HTMLInputElement = null;

    render() {

        let val = '' + this.props.value;
        if (this.endDot) val += '.';
        if (this.startMinus) val = '-' + val;

        let className = 'input input-number';
        if (this.props.disabled) className += ' disabled';

        return (
            <input
                disabled={this.props.disabled}
                className={className}
                type="numeric"
                value={val}
                onChange={this.handleChange}
                onFocus={this.handleFocus}
                onBlur={this.handleBlur}
                ref={(el) => { this.inputElement = el; }}
            />
        );

    } //render

    @autobind handleChange(e:any) {

        if (this.props.onChange) {
            let val:string = e.target.value;

            // Be smart about changing sign/handling comma/dot
            //
            val = this.sanitize(val);

            // Then compute final valid number
            let num:number = parseFloat(val);
            if (!isNaN(num)) {
                if (num < 0) {
                    this.startMinus = false;
                }
                this.props.onChange(num);
            } else if (e.target.value === '') {
                this.props.onChange(0);
            }
        }

    } //handleChange

    @autobind handleFocus(e:any) {

        if (!this.props.disabled) {
            e.target.select();

            global['focusedInput'] = this;
        }

    } //handleFocus

    @autobind handleBlur(e:any) {

        if (global['focusedInput'] === this) {
            global['focusedInput'] = undefined;
        }

        this.endDot = false;

    } //handleBlur

/// Helpers

    sanitize(val:string):string {

        val = val.split(',').join('.');

        // Forbid multiple dots
        let parts = val.split('.');
        while (parts.length > 2) {
            parts.pop();
        }
        val = parts.join('.');

        this.endDot = val.endsWith('.') && val.substr(0, val.length - 1).indexOf('.') === -1;
        if (this.endDot) {
            val += '0';
        }
        if (!this.startMinus) {
            if (val === '-' || val === '0-') {
                this.startMinus = true;
                val += '0';
            }
            else if (val.length > 1 && val.endsWith('-')) {
                val = '-' + val.substr(0, val.length - 1);
            }
        }
        else {
            if (val === '' || val === '-') {
                this.startMinus = false;
                val = '0';
            }
        }
        if (val.startsWith('-') && val.endsWith('+')) {
            this.startMinus = false;
            val = val.substr(1, val.length - 2);
        }

        this.forceUpdate();

        return val;

    } //sanitize

/// Clipboard

    getSelected(cut:boolean = false) {

        let input = this.inputElement;
        let val = input.value.substring(input.selectionStart, input.selectionEnd);

        if (cut && val.length > 0) {
            
            input.value = input.value.substring(0, input.selectionStart) + input.value.substring(input.selectionEnd);
            this.handleChange({
                target: input
            });
        }

        return val;

    } //getSelected

    setSelected(content:string) {

        let input = this.inputElement;

        let val = input.value.substring(0, input.selectionStart) + content + input.value.substring(input.selectionEnd);

        input.value = this.sanitize(val);

        this.handleChange({
            target: input
        });

        input.selectionStart = input.selectionEnd;

    } //setSelected

}

export default NumberInput;
