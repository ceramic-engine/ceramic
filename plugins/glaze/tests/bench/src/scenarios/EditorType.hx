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

    public function new() {
        super('editor-type');
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
