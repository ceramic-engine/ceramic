package elements;

enum abstract WindowItemKind(Int) from Int to Int {

    var UNKNOWN;

    var SELECT;

    var EDIT_TEXT;

    var EDIT_FLOAT;

    var EDIT_INT;

    var EDIT_COLOR;

    #if plugin_dialogs

    var EDIT_DIR;

    var EDIT_FILE;

    #end

    var SLIDE_FLOAT;

    var SLIDE_INT;

    var BUTTON;

    var CHECK;

    var TEXT;

    var VISUAL;

    var SPACE;

    var SEPARATOR;

    var LIST;

    var TABS;

}
