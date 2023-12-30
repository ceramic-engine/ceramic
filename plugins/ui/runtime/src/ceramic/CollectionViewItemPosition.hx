package ceramic;

import ceramic.macros.EnumAbstractMacro;

enum abstract CollectionViewItemPosition(Int) {

    var START = 0;

    var MIDDLE = 1;

    var END = 2;

    var ENSURE_VISIBLE = 3;

    public function toString() {
        return EnumAbstractMacro.toStringSwitch(CollectionViewItemPosition, abstract);
    }

}
