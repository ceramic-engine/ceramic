import * as React from 'react';
import { autobind, observe, observer, autorun } from 'utils';

/** Color input */
@observer class ColorInput extends React.Component {

    props:{
        /** Value */
        value:string,
        /** Disabled */
        disabled?:boolean,
        /** onChange */
        onChange?:(value:string) => void
    };

    @observe editedValue:string = null;

    lastPropValue:string = null;

    render() {

        let className = 'input input-color';
        if (this.props.disabled) className += ' disabled';

        let value = this.lastPropValue === this.props.value ? this.editedValue : null;
        this.lastPropValue = this.props.value;
        if (!value) value = this.props.value;

        return (
            <div className="input-color-container">
                <input
                    disabled={this.props.disabled}
                    className={className}
                    type="text"
                    value={value}
                    onChange={this.handleChange}
                    onFocus={this.handleFocus}
                />
                <div
                    className="color-preview"
                    onClick={this.handlePreviewClick}
                    style={{
                        backgroundColor: this.props.value
                    }}
                />
            </div>
        );

    } //render

    @autobind handleFocus(e:any) {

        if (!this.props.disabled) {
            e.target.select();
        }

    } //handleFocus

    @autobind handlePreviewClick(e:any) {

        if (!this.props.disabled) {
            let preview = e.currentTarget;
            preview.previousElementSibling.focus();
        }

    } //handleFocus

    @autobind handleChange(e:any) {

        let newValue:string = e.target.value.toUpperCase();
        if (!newValue.startsWith('#')) newValue = '#' + newValue;
        if (newValue.length > 7 || !/^#[0-9A-Fa-f]*/.test(newValue)) {
            return;
        }

        if (newValue.length === 7) {
            this.editedValue = '';
            if (this.props.onChange) {
                this.props.onChange(newValue);
            }
        } else {
            this.editedValue = newValue;
            this.forceUpdate(); // Seems that mobx doesn't update in this case otherwise. No idea why :'(
        }

    } //handleChange

}

export default ColorInput;
