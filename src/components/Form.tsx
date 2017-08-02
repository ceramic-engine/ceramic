import * as React from 'react';
import { autobind } from 'utils';

/** Form */
class Form extends React.Component {

    render() {

        return (
            <form onSubmit={this.handleSubmit}>
                {this.props.children}
                <span onFocus={this.handleFocusLoop} tabIndex={0} />
            </form>
        );

    } //render

    @autobind handleSubmit(e:any) {

        e.preventDefault();

    } //handleSubmit

    @autobind handleFocusLoop(e:any) {

        e.preventDefault();

        let inputs:Array<HTMLElement> = e.target.parentNode.querySelectorAll('.input');
        for (let el of inputs) {
            if (!el.classList.contains('disabled') && !(el as any).disabled) {
                el.focus();
                break;
            }
        }

    } //handleFocusLoop

}

export default Form;
