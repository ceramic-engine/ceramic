package ceramic;

interface TextInputDelegate {

    /** Returns the position in `toLine` which is closest
        to the position in `fromLine`/`fromPosition` (in X coordinates).
        Positions are relative to their line. */
    function textInputClosestPositionInLine(text:String, fromPosition:Int, fromLine:Int, toLine:Int):Int;

} //TextInputDelegate
