package scenarios;

import gpui.Keystroke;
import gpui.Modifiers;

/**
 * Typing in the code editor of `EditorBench`: `step` types one character per
 * frame at the caret (a keystroke through `Window.dispatchKeystroke`, the
 * path of the golden `type` steps), cycling over a JSON snippet, with an
 * Enter every 40 characters.
 */
class EditorType extends EditorBench {

    static inline final ENTER_EVERY = 40;

    static final SNIPPET = '"key": [1, 2, 3], "name": "value", ';

    /** The keystrokes of the snippet, built once (`space` for a space like the golden script). */
    final keys:Array<Keystroke> = [];

    final enter:Keystroke = Keystroke.parse('enter');

    /**
     * `editor-type`: 5000 lines (about 100 KB, above gpui-kit's 64 KB
     * `SYNC_PARSE_MAX_BYTES`: the highlighter waits for a pause in the
     * typing, so the measured frames do not tokenize); `editor-type-sync`:
     * 3000 lines (about 54 KB), tokenized and folded on every keystroke.
     */
    public function new(name:String = 'editor-type', lineCount:Int = EditorBench.LINE_COUNT) {
        super(name, lineCount);
        for (c in new haxe.iterators.StringIteratorUnicode(SNIPPET)) {
            final buf = new StringBuf();
            buf.addChar(c);
            keys.push(new Keystroke(Modifiers.none(), c == ' '.code ? 'space' : buf.toString(), null));
        }
    }

    override function step(frame:Int):Void {
        if (frame % ENTER_EVERY == ENTER_EVERY - 1) {
            KitBench.keystroke(app, window, enter);
        }
        else {
            KitBench.keystroke(app, window, keys[frame % keys.length]);
        }
    }

}
