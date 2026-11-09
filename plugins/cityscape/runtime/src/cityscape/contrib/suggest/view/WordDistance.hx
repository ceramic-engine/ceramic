// Ported from vscode src/vs/editor/contrib/suggest/browser/wordDistance.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.common.core.Position.IPosition;

/**
 * The distance between a completion and the word at the cursor, used to
 * sort the completions (`suggest.localityBonus`).
 *
 * Monaco computes it from the bracket selection ranges of the smart select
 * contribution and the word ranges of its editor worker. Neither is ported
 * yet: `create` always gives `WordDistance.None` (the default, without
 * `localityBonus`), whose distance is 0.
 * TODO(step 7): smart select (bracket selections) and the word ranges for
 * `localityBonus`.
 */
abstract class WordDistance {

    static var _none:Null<WordDistance> = null;

    public static var None(get, never):WordDistance;
    static function get_None():WordDistance {
        if (_none == null) {
            _none = new NoneWordDistance();
        }
        return _none;
    }

    /**
     * The word distance of an editor (always `None` for now, see the class
     * comment).
     */
    public static function create(editor:cityscape.view.EditorBrowser.ICodeEditor):WordDistance {
        return WordDistance.None;
    }

    abstract public function distance(anchor:IPosition, suggestion:cityscape.common.Languages.CompletionItem):Int;

}

private class NoneWordDistance extends WordDistance {

    public function new() {}

    public function distance(anchor:IPosition, suggestion:cityscape.common.Languages.CompletionItem):Int {
        return 0;
    }

}
