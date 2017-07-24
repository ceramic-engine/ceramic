import * as React from 'react';
import { autobind, observer, observe } from 'utils';

/** Number input */
@observer class NumberInput extends React.Component {

    props:{
        /** Value */
        value:number,
        /** onChange */
        onChange?:(value:number) => void
    };

    @observe endDot:boolean = false;

    @observe startMinus:boolean = false;

    render() {

        let val = '' + this.props.value;
        if (this.endDot) val += '.';
        if (this.startMinus) val = '-' + val;

        return (
            <input className="input input-number" type="numeric" value={val} onChange={this.handleChange} onFocus={this.handleFocus} onBlur={this.handleBlur} />
        );

    } //render

    @autobind handleChange(e:any) {

        if (this.props.onChange) {
            let val:string = e.target.value;

            // Be smart about changing sign/handling comma/dot
            //
            val = val.split(',').join('.');
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

        e.target.select();

    } //handleFocus

    @autobind handleBlur(e:any) {

        this.endDot = false;

    } //handleBlur

}

export default NumberInput;
