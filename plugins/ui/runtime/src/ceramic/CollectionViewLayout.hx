package ceramic;

interface CollectionViewLayout {

    function collectionViewLayout(collectionView:CollectionView, frames:ReadOnlyArray<CollectionViewItemFrame>):Void;

    function isFrameVisible(collectionView:CollectionView, frame:CollectionViewItemFrame):Bool;

}
