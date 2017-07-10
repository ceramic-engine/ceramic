import * as React from 'react';
import { autobind } from 'utils';

/** Number input */
class NumberInput extends React.Component {

    props:{
        /** Value */
        value:number,
        /** onChange */
        onChange?:(value:number) => void
    };

    render() {

        return (
            <input className="input input-number" type="numeric" value={this.props.value} onChange={this.handleChange} onFocus={this.handleFocus} />
        );

    } //render

    @autobind handleChange(e:any) {

        if (this.props.onChange) {
            let num:number = parseFloat(e.target.value);
            if (!isNaN(num)) {
                this.props.onChange(num);
            } else if (e.target.value === '') {
                this.props.onChange(0);
            }
        }

    } //handleChange

    @autobind handleFocus(e:any) {

        e.target.select();

    } //handleFocus

}

export default NumberInput;
