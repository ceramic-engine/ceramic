import * as React from 'react';
import { observe, observer } from 'utils';
import { SortableContainer, SortableElement, arrayMove } from 'react-sortable-hoc';

/** SortableItemContent */
class SortableItemContent extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode,
    };

    render() {

        return (
            <div className="sortable-item">
                {this.props.children}
            </div>
        );

    } //render

} //SortableItemContent

const SortableItem = SortableElement(SortableItemContent);

/** SortableContent */
@observer class SortableContent extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode
    };

    sortableEl?:HTMLDivElement;

    mounted:boolean = false;

    mountedTimeout:any = null;

    @observe scrollHeight:number = -1;

    render() {

        let styles:any = {};

        if (this.scrollHeight > 0) {
            styles.overflowY = 'scroll';
            styles.height = this.scrollHeight;
        }

        return (
            <div className="sortable" style={styles} ref={(el) => { this.sortableEl = el; }}>
                {this.props.children != null ? (this.props.children as any[]).map((child, i) =>
                    <SortableItem key={i} index={i}>
                        {child}
                    </SortableItem>
                ) : null}
            </div>
        );

    } //render
    
/// Lifecycle

    componentDidMount() {

        // Flag as mounted
        this.mounted = true;

        const checkParent = () => {

            // Unmounted? Nothing to do
            if (!this.mounted) return;

            // Get parent element
            let parent = this.sortableEl.parentElement;
            if (parent != null && parent.style.overflowY === 'auto' && parent.style.height.endsWith('px')) {
                this.scrollHeight = parseInt(parent.style.height, 10);
            }
            else {
                this.scrollHeight = -1;
            }

            // Check again in 0.5s
            this.mountedTimeout = setTimeout(checkParent, 500);
        };

        // Try to reach iframe window
        this.mountedTimeout = setTimeout(checkParent, 500);

    } //componentDidMount

    componentWillUnmount() {

        // Flag as unmounted
        this.mounted = false;

        if (this.mountedTimeout != null) clearTimeout(this.mountedTimeout);

    } //componentWillUnmount

}

const Sortable = SortableContainer(SortableContent);
export default Sortable;
