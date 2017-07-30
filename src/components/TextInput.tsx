import * as React from 'react';
import { autobind } from 'utils';

/** Text input */
class TextInput extends React.Component {

    props:{
        /** Value */
        value:string,
        /** Disabled */
        disabled?:boolean,
        /** onChange */
        onChange?:(value:string) => void
    };

    render() {

        let className = 'input input-number';
        if (this.props.disabled) className += ' disabled';

        return (
            <input disabled={this.props.disabled} className={className} type="text" value={this.props.value} onChange={this.handleChange} onFocus={this.handleFocus} />
        );

    } //render

    @autobind handleChange(e:any) {

        if (this.props.onChange) {
            this.props.onChange(e.target.value);
        }

    } //handleChange

    @autobind handleFocus(e:any) {

        if (!this.props.disabled) {
            e.target.select();
        }

    } //handleFocus

}

export default TextInput;
