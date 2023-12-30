package ceramic;

import ceramic.macros.EnumAbstractMacro;

enum abstract CollectionViewItemsBehavior(Int) {

    /**
     * Create new items that need to be displayed, recycle items that got out of bounds
     */
    var RECYCLE = 1;

    /**
     * No item is created or removed
     */
    var FREEZE = 2;

    /**
     * New items are created as needed, existing items are not removed or recycled
     */
    var LAZY = 3;

    public function toString() {
        return EnumAbstractMacro.toStringSwitch(CollectionViewItemsBehavior, abstract);
    }

}