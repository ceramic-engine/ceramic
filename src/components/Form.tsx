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

        let firstInput = e.target.parentNode.querySelector('.input');
        if (firstInput != null) {
            firstInput.focus();
        }

    } //handleFocusLoop

}

export default Form;
