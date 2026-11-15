// New code for the Haxe port of gpui-kit (no gpui-kit origin): the selection of one paragraph that is not part of a
// parsed document (the kit's `RichText`). See NOTICE.md.
package glaze.kit.base.text;

/**
 * What a `TextViewState` selects when it holds one `InlineFlow` instead of a
 * parsed document (`TextViewState.singleFlow`): the states of the text
 * items of that flow, kept from one frame to the next.
 *
 * The text leaves of the flow (`Inline`) write the selected range of each
 * item in its state while they paint, exactly as they do for the paragraphs
 * of a markdown document; this class reads them back the way
 * `Paragraph.selectedText` does.
 */
class InlineFlowSelection {

    /** One state per text item of the flow, by text item index. */
    final states:Array<InlineState> = [];

    var count:Int = 0;

    var changed:Bool = false;

    public function new() {}

    /** Starts the items of a frame. */
    public function begin():Void {
        count = 0;
        changed = false;
    }

    /** The state of the next text item of the frame, whose text is `text`. */
    public function itemState(text:String):InlineState {
        final ix = count++;
        if (ix < states.length) {
            final state = states[ix];
            if (state.text != text) {
                changed = true;
                state.selection = null;
                state.setText(text);
            }
            return state;
        }
        final state = new InlineState();
        state.setText(text);
        // A first frame has nothing selected yet: it is not a change.
        if (states.length > 0 || ix > 0) {
            changed = true;
        }
        states.push(state);
        return state;
    }

    /**
     * Ends the items of a frame. Returns whether the text differs from the
     * frame before: what was selected is then no longer there.
     */
    public function end():Bool {
        if (states.length > count) {
            for (ix in count...states.length) {
                states[ix].selection = null;
            }
            states.resize(count);
            changed = true;
        }
        return changed;
    }

    /** The whole text of the flow. */
    public function text():String {
        final out = new StringBuf();
        for (state in states) {
            out.add(state.text);
        }
        return out.toString();
    }

    /** The selected text of the flow. */
    public function selectedText():String {
        final out = new StringBuf();
        for (state in states) {
            final selection = state.selection;
            if (selection != null) {
                out.add(TextUtils.slice(state.text, selection.start, selection.end));
            }
        }
        return out.toString();
    }

    /** Whether an item carries a selection, even an empty one. */
    public function hasSelection():Bool {
        for (state in states) {
            if (state.selection != null) return true;
        }
        return false;
    }

    /** Clears the selection stored in every item state, without waiting for a paint. */
    public function clearSelection():Void {
        for (state in states) {
            state.selection = null;
        }
    }

}
