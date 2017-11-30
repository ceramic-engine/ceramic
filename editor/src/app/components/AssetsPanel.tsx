
import * as React from 'react';
import { observer } from 'utils';
import { Button, Form, Field, Panel, NumberInput, Title, Alt } from 'components';
import { project } from 'app/model';
import { context } from 'app/context';

@observer class FragmentPanel extends React.Component {

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
                                <Title>Databases</Title>
                                <Alt>
                                    {project.databaseAssets.map((val, i) =>
                                        <div
                                            key={i}
                                            className={
                                                'entry in-alt'
                                                + (i < project.databaseAssets.length - 1 ? ' with-separator' : '')
                                            }
                                        >
                                            <div className="name">{val.name}</div>
                                            <div className="info">{val.paths.join(', ')}</div>
                                        </div>
                                    )}
                                </Alt>
                                {project.customAssets ?
                                this.mapEntries(project.customAssets).map((entry) => <div>
                                    <Title>{this.assetListName(entry.key)}</Title>
                                    <Alt>
                                        {project.customAssets.get(entry.key).map((val, i) =>
                                            <div
                                                key={i}
                                                className={
                                                    'entry in-alt'
                                                    + (i < project.customAssets.get(entry.key).length - 1 ? ' with-separator' : '')
                                                }
                                            >
                                                <div className="name">{val.name}</div>
                                                <div className="info">{val.paths.join(', ')}</div>
                                            </div>
                                        )}
                                    </Alt>
                                </div>) : null}
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

    mapEntries(map:Map<string,any>):Array<{key:string, value:any}> {

        let entries:Array<{key:string, value:any}> = [];

        map.forEach((value, key) => {
            entries.push({ key, value });
        });

        return entries;

    } //mapEntries

    assetListName(key:string):string {

        return key.charAt(0).toUpperCase() + key.slice(1) + 's';

    } //assetListName
    
}

export default FragmentPanel;
