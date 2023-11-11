package ceramic;

enum abstract PreloadStatus(Int) {

    var NONE = 0;

    var LOADING = 1;

    var SUCCESS = 2;

    var ERROR = -1;

    function toString():String {

        return ceramic.macros.EnumAbstractMacro.toStringSwitch(PreloadStatus, abstract);

    }

}
