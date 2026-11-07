package scenarios;

/**
 * Opening a document in the code editor of `EditorBench`: `step` replaces
 * the whole text (`setValue`), alternating between 3000 and 2999 lines of
 * JSON (about 54 KB, under gpui-kit's 64 KB `SYNC_PARSE_MAX_BYTES`), so
 * every frame tokenizes and folds the whole document again: the cost of the
 * highlighter's regex engine (the pure Haxe Oniguruma, or onig.wasm with
 * `gpui_onig_wasm` on the web).
 */
class EditorOpen extends EditorBench {

    static inline final LINES = 3000;

    public function new() {
        super('editor-open', LINES);
    }

    override function step(frame:Int):Void {
        final text = EditorBench.jsonCode(frame % 2 == 0 ? LINES - 1 : LINES);
        app.update(cx -> state.update(cx, (state, cx) -> state.setValue(text, window, cast cx)));
        KitBench.runUntilParked(app);
    }

}
