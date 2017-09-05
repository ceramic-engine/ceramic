import * as React from 'react';
import { observer, autobind, ceramic } from 'utils';
import { Button, Inline } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project } from 'app/model';

@observer class Prompt extends React.Component {

/// Lifecycle

    render() {

        return project.ui.prompt ? (
            <Overlay>
                <Dialog title={project.ui.prompt.title}>
                    <div className="message">{project.ui.prompt.message.split("\n").map((val, index) =>
                        val ? <div key={index} className="line">{val}</div> : null
                    )}</div>
                    <div style={{ height: 12 }} />
                    <div className="prompt-choices">
                        {project.ui.prompt.choices.map((val, index) =>
                            <Inline key={index}>
                                <Button
                                    value={val}
                                    onClick={() => {
                                        project.ui.prompt = null;
                                        project.ui.promptResult = index;
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

export default Prompt;
