package backend;

enum abstract StencilState(Int) from Int to Int {

    var NONE = 0;

    var TEST = 1;

    var WRITE = 2;
    
    var CLEAR = 3;

}