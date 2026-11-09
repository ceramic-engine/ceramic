package scenarios;

import cityscape.common.core.Range;

/**
 * Sorts 10 000 ranges with `Range.compareRangesUsingStarts` each frame: a
 * placeholder that exercises the runner until the model and editor
 * scenarios exist (typing, scrolling and opening 10 000 lines).
 */
class RangeSort implements Scenario {

    public var name:String = 'range-sort';

    final ranges:Array<Range> = [];

    var work:Array<Range> = [];

    public function new() {}

    public function setup():Void {
        // Deterministic pseudo random ranges
        var seed = 12345;
        inline function next():Int {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            return seed;
        }
        for (_ in 0...10000) {
            final line = 1 + next() % 5000;
            final column = 1 + next() % 120;
            ranges.push(new Range(line, column, line + next() % 3, 1 + next() % 120));
        }
    }

    public function step(frame:Int):Void {
        work = ranges.copy();
        work.sort(Range.compareRangesUsingStarts);
    }

    public function teardown():Void {
        work = [];
    }

}
