import * as React from 'react';
import { observer } from 'mobx-react';
import { project } from 'app/model';
import { context } from 'app/context';
import { EditScene, AddVisual } from 'app/components';

@observer class App extends React.Component {

/// Lifecycle

    render() {

        const navHeight = 22;
        const leftSideWidth = 44;

        return (
            <div
                style={{
                    position: 'relative',
                    left: 0,
                    top: 0,
                    width: context.width,
                    height: context.height
                }}
            >
                <div
                    style={{
                        width: context.width,
                        height: context.height,
                        position: 'absolute',
                        left: 0,
                        top: 0
                    }}
                >
                    <div>
                        {project.ui.addingVisual ?
                            <AddVisual>YOUPI</AddVisual>
                        :
                            null
                        }
                    </div>
                    <div
                        style={{
                            position: 'absolute',
                            left: 0,
                            top: 0,
                            width: '100%',
                            zIndex: 500,
                            lineHeight: navHeight + 'px',
                            height: navHeight,
                            WebkitAppRegion: 'drag',
                            textAlign: 'center'
                        }}
                        className="topnav"
                    >
                        {project.name != null ? (
                            <span>{project.name}</span>
                        ) : (
                            <span>New project</span>
                        )}
                    </div>
                    <div
                        className="leftside"
                        style={{
                            width: leftSideWidth,
                            height: context.height - navHeight,
                            position: 'absolute',
                            left: 0,
                            top: navHeight
                        }}
                    />
                    <div
                        style={{
                            width: context.width - leftSideWidth,
                            height: context.height - navHeight,
                            position: 'absolute',
                            left: leftSideWidth,
                            top: navHeight
                        }}
                    >
                        <EditScene width={context.width - leftSideWidth} height={context.height - navHeight} />
                    </div>
                </div>
            </div>
        );

    } //render
    
}

export default App;
