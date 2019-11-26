package ceramic.ui;

class CollectionViewFlowLayout implements CollectionViewLayout {

    public var itemSizing:Float = -1.0;

    public var insetStart:Float = 0.0;

    public var insetEnd:Float = 0.0;

    public var itemSpacingX:Float = 0.0;

    public var itemSpacingY:Float = 0.0;

    public var visibleOutset:Float = 0.0;

    public var allItemsVisible:Bool = false;

    public function new() {

    } //new

    public function collectionViewLayout(collectionView:CollectionView, frames:ImmutableArray<CollectionViewItemFrame>):Void {

        var x = 0.0;
        var y = 0.0;
        var maxX = 0.0;
        var maxY = 0.0;

        var direction = collectionView.direction;
        var width = collectionView.width;
        var height = collectionView.height;

        if (direction == VERTICAL) {

            y += insetStart;
            maxY = y;

            for (i in 0...frames.length) {
                var frame = frames.unsafeGet(i);

                // Fit item width
                if (itemSizing > 0) {
                    frame.width = Math.min(width, width * itemSizing);
                }
                if (x > 0 && x + frame.width > width) {
                    x = 0;
                    y = maxY + itemSpacingY;
                }
                frame.x = x;
                frame.y = y;
                maxY = Math.max(maxY, y + frame.height);
                x += frame.width + itemSpacingX;
            }

            collectionView.contentSize = maxY + insetEnd;

        }
        else { // HORIZONTAL

            x += insetStart;
            maxX = x;

            for (i in 0...frames.length) {
                var frame = frames.unsafeGet(i);

                // Fit item height
                if (itemSizing > 0) {
                    frame.height = Math.min(height, height * itemSizing);
                }
                if (y > 0 && y + frame.height > height) {
                    y = 0;
                    x = maxX + itemSpacingX;
                }
                frame.x = x;
                frame.y = y;
                maxX = Math.max(maxX, x + frame.width);
                y += frame.height + itemSpacingY;
            }

            collectionView.contentSize = maxX + insetEnd;

        }

    } //collectionViewLayout

    public function isFrameVisible(collectionView:CollectionView, frame:CollectionViewItemFrame):Bool {

        if (allItemsVisible) return true;

        if (collectionView.direction == VERTICAL) {
            var minY = -collectionView.scroller.scrollTransform.ty - visibleOutset;
            var maxY = minY + collectionView.height + visibleOutset * 2;
            return (frame.y < maxY && frame.y + frame.height >= minY);
        }
        else {
            var minX = -collectionView.scroller.scrollTransform.tx - visibleOutset;
            var maxX = minX + collectionView.width + visibleOutset * 2;
            return (frame.x < maxX && frame.x + frame.width >= minX);
        }

    } //isFrameVisible

} //CollectionViewFlowLayout
