package ceramic.ui;

interface CollectionViewLayout {

    function collectionViewLayout(collectionView:CollectionView, frames:ImmutableArray<CollectionViewItemFrame>):Void;

    function isFrameVisible(collectionView:CollectionView, frame:CollectionViewItemFrame):Bool;

}
