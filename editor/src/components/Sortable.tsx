import * as React from 'react';
import {SortableContainer, SortableElement, arrayMove} from 'react-sortable-hoc';

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
class SortableContent extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode,
    };

    render() {

        return (
            <div className="sortable">
                {this.props.children != null ? (this.props.children as any[]).map((child, i) =>
                    <SortableItem key={i} index={i}>
                        {child}
                    </SortableItem>
                ) : null}
            </div>
        );

    } //render

}

const Sortable = SortableContainer(SortableContent);
export default Sortable;
