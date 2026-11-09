package scenarios;

import cityscape.Cityscape;
import cityscape.common.Model;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;

/**
 * Helpers of the model scenarios: a deterministic 10 000 line text and
 * pseudo random numbers (same sequence on every target).
 */
class ModelBench {

    public static inline final LINE_COUNT = 10000;

    var seed:Int = 12345;

    public function new() {}

    public function next():Int {
        seed = lehmer(seed);
        return seed;
    }

    /**
     * Lehmer generator in Float math: the same sequence on every target.
     */
    static inline function lehmer(s:Int):Int {
        return Std.int((s * 48271.0) % 2147483647.0);
    }

    /**
     * 10 000 lines of code-like text (indentation, words, symbols).
     */
    public static function createText():String {
        final words = ['function', 'return', 'value', 'index', 'model', 'line', 'count', 'if', 'else', 'var', 'final', '=', '+', '(', ')', '{', '}', ';', 'text', 'range'];
        final buf = new StringBuf();
        var s = 987;
        for (i in 0...LINE_COUNT) {
            s = lehmer(s);
            final indent = s % 4;
            for (_ in 0...indent) {
                buf.add('    ');
            }
            final wordCount = 3 + (s >> 8) % 6;
            for (w in 0...wordCount) {
                s = lehmer(s);
                if (w > 0) {
                    buf.addChar(' '.code);
                }
                buf.add(words[s % words.length]);
            }
            if (i < LINE_COUNT - 1) {
                buf.addChar('\n'.code);
            }
        }
        return buf.toString();
    }

    public static function createModel(text:String, context:Cityscape):TextModel {
        return new TextModel(text, 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
    }

    /**
     * One single character edit at a pseudo random position: an insertion
     * when `insert`, otherwise the deletion of one character (when the line
     * is not empty).
     */
    public function randomEdit(model:TextModel, insert:Bool):IIdentifiedSingleEditOperation {
        final lineNumber = 1 + next() % model.getLineCount();
        final maxColumn = model.getLineMaxColumn(lineNumber);
        final column = 1 + next() % maxColumn;
        if (insert || maxColumn == 1) {
            return {range: new Range(lineNumber, column, lineNumber, column), text: String.fromCharCode('a'.code + next() % 26)};
        }
        final start = (column == maxColumn ? column - 1 : column);
        return {range: new Range(lineNumber, start, lineNumber, start + 1), text: null};
    }

}
