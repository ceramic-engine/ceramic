package ceramic.ui;

interface CollectionViewDataSource {

    /** Get the number of elements. */
    function collectionViewSize():Int;

    /** Get the item frame at the requested index. */
    function collectionViewItemFrameAtIndex(itemIndex:Int, frame:CollectionViewItemFrame):Void;

    /** Called when a view is not used anymore at the given index. Lets the dataSource
        do some cleanup if needed, before this view gets reused (if it can).
        Returns `true` if the view can be reused at another index of `false` otherwise. */
    function collectionViewReleaseItemAtIndex(itemIndex:Int, view:View):Bool;

    /** Get a view at the given index. If `reusableView` is provided,
        it can be recycled as the new item to avoid creating new instances. */
    function collectionViewItemAtIndex(itemIndex:Int, reusableView:View):View;

} //CollectionViewDataSource
