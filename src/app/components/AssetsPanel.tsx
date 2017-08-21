
import * as React from 'react';
import { observer } from 'utils';
import { Button, Form, Field, Panel, NumberInput, Title, Alt } from 'components';
import { project } from 'app/model';
import { context } from 'app/context';

@observer class ScenePanel extends React.Component {

    props:{
        /** Available height */
        height:number
    };

/// Lifecycle

    render() {

        return (
            <Panel>
                <div style={{ maxHeight: this.props.height - 28, overflowY: 'auto' }}>
                {(
                    context.ceramicReady ?
                        project.allAssets != null ?
                            <div>
                                <Title>Images</Title>
                                <Alt>
                                    {project.imageAssets.map((val, i) =>
                                        <div
                                            key={i}
                                            className={
                                                'entry in-alt'
                                                + (i < project.imageAssets.length - 1 ? ' with-separator' : '')
                                            }
                                            onMouseOver={(e) => {
                                                project.ui.assetInfo = {
                                                    asset: val,
                                                    y: (e.currentTarget as HTMLElement).getClientRects()[0].top
                                                };
                                            }}
                                            onMouseOut={() => {
                                                project.ui.assetInfo = null;
                                            }}
                                        >
                                            <div className="name">{val.name}</div>
                                            <div className="info">{val.paths.join(', ')}</div>
                                        </div>
                                    )}
                                </Alt>
                                <Title>Texts</Title>
                                <Alt>
                                    {project.textAssets.map((val, i) =>
                                        <div
                                            key={i}
                                            className={
                                                'entry in-alt'
                                                + (i < project.textAssets.length - 1 ? ' with-separator' : '')
                                            }
                                        >
                                            <div className="name">{val.name}</div>
                                            <div className="info">{val.paths.join(', ')}</div>
                                        </div>
                                    )}
                                </Alt>
                                <Title>Sounds</Title>
                                <Alt>
                                    {project.soundAssets.map((val, i) =>
                                        <div
                                            key={i}
                                            className={
                                                'entry in-alt'
                                                + (i < project.soundAssets.length - 1 ? ' with-separator' : '')
                                            }
                                        >
                                            <div className="name">{val.name}</div>
                                            <div className="info">{val.paths.join(', ')}</div>
                                        </div>
                                    )}
                                </Alt>
                                <Title>Fonts</Title>
                                <Alt>
                                    {project.fontAssets.map((val, i) =>
                                        <div
                                            key={i}
                                            className={
                                                'entry in-alt'
                                                + (i < project.fontAssets.length - 1 ? ' with-separator' : '')
                                            }
                                        >
                                            <div className="name">{val.name}</div>
                                            <div className="info">{val.paths.join(', ')}</div>
                                        </div>
                                    )}
                                </Alt>
                                <Form>
                                    <Field>
                                        <Button
                                            value="Change directory"
                                            onClick={() => { project.chooseAssetsPath(); }}
                                        />
                                    </Field>
                                </Form>
                            </div>
                        :
                        <Form>
                            <Field>
                                <Button
                                    value="Choose directory"
                                    onClick={() => { project.chooseAssetsPath(); }}
                                />
                            </Field>
                        </Form>
                    :
                        null
                )}
                </div>
            </Panel>
        );

    } //render
    
}

export default ScenePanel;
