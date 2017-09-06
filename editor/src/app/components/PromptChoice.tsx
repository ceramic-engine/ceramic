import * as React from 'react';
import { observer, autobind, ceramic } from 'utils';
import { Button, Inline } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project } from 'app/model';

@observer class PromptChoice extends React.Component {

/// Lifecycle

    render() {

        return project.ui.promptChoice ? (
            <Overlay>
                <Dialog title={project.ui.promptChoice.title}>
                    <div className="message">{project.ui.promptChoice.message.split("\n").map((val, index) =>
                        val ? <div key={index} className="line">{val}</div> : null
                    )}</div>
                    <div style={{ height: 12 }} />
                    <div className="prompt-choices">
                        {project.ui.promptChoice.choices.map((val, index) =>
                            <Inline key={index}>
                                <Button
                                    value={val}
                                    onClick={() => {
                                        project.ui.promptChoice = null;
                                        project.ui.promptChoiceResult = index;
                                    }}
                                />
                            </Inline>
                        )}
                    </div>
                </Dialog>
            </Overlay>
        ) : null;

    } //render
    
}

export default PromptChoice;
