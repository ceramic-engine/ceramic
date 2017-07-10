import * as React from 'react';
import { autobind } from 'utils';

/** Text input */
class TextInput extends React.Component {

    props:{
        /** Value */
        value:string,
        /** onChange */
        onChange?:(value:string) => void
    };

    render() {

        return (
            <input className="input input-text" type="text" value={this.props.value} onChange={this.handleChange} onFocus={this.handleFocus} />
        );

    } //render

    @autobind handleChange(e:any) {

        if (this.props.onChange) {
            this.props.onChange(e.target.value);
        }

    } //handleChange

    @autobind handleFocus(e:any) {

        e.target.select();

    } //handleFocus

}

export default TextInput;
