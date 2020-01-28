package ceramic;

interface TextInputDelegate {

    /** Returns the position in `toLine` which is closest
        to the position in `fromLine`/`fromPosition` (in X coordinates).
        Positions are relative to their line. */
    function textInputClosestPositionInLine(fromPosition:Int, fromLine:Int, toLine:Int):Int;

    function textInputNumberOfLines():Int;

    function textInputIndexForPosInLine(lineNumber:Int, lineOffset:Int):Int;

    function textInputLineForIndex(index:Int):Int;

    function textInputPosInLineForIndex(index:Int):Int;

}
