// Ported from vscode src/vs/editor/contrib/suggest/browser/suggestMemory.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position.IPosition;
import cityscape.contrib.suggest.view.Suggest.CompletionItem;

/**
 * `'first'`, `'recentlyUsed'` or `'recentlyUsedByPrefix'` (the
 * `suggestSelection` option).
 */
typedef MemMode = String;

typedef MemItem = {
    var type:Int;
    var insertText:String;
    var touch:Int;
}

abstract class Memory {

    public final name:MemMode;

    public function new(name:MemMode) {
        this.name = name;
    }

    public function select(model:ITextModel, pos:IPosition, items:Array<CompletionItem>):Int {
        if (items.length == 0) {
            return 0;
        }
        final topScore = items[0].score[0];
        for (i in 0...items.length) {
            final score = items[i].score;
            final suggestion = items[i].completion;
            if (score[0] != topScore) {
                // stop when leaving the group of top matches
                break;
            }
            if (suggestion.preselect == true) {
                // stop when seeing an auto-select-item
                return i;
            }
        }
        return 0;
    }

    abstract public function memorize(model:ITextModel, pos:IPosition, item:CompletionItem):Void;

}

class NoMemory extends Memory {

    public function new() {
        super('first');
    }

    public function memorize(model:ITextModel, pos:IPosition, item:CompletionItem):Void {
        // no-op
    }

}

class LRUMemory extends Memory {

    public function new() {
        super('recentlyUsed');
    }

    /**
     * Monaco's `LRUCache<string, MemItem>(300, 0.66)`: the entries in
     * order of use, trimmed to 66% when over 300.
     */
    final _cache = new Map<String, MemItem>();
    final _order:Array<String> = [];
    var _seq = 0;

    function _set(key:String, value:MemItem):Void {
        if (_cache.exists(key)) {
            _order.remove(key);
        }
        _cache.set(key, value);
        _order.push(key);
        if (_order.length > 300) {
            final keep = Math.round(300 * 0.66);
            while (_order.length > keep) {
                _cache.remove(_order.shift());
            }
        }
    }

    public function memorize(model:ITextModel, pos:IPosition, item:CompletionItem):Void {
        final key = model.getLanguageId() + '/' + item.textLabel;
        _set(key, {
            touch: this._seq++,
            type: item.completion.kind,
            insertText: item.completion.insertText
        });
    }

    override public function select(model:ITextModel, pos:IPosition, items:Array<CompletionItem>):Int {

        if (items.length == 0) {
            return 0;
        }

        // substr(pos.column - 10, pos.column - 1) (JavaScript's substr with a
        // negative start counts from the end)
        final line = model.getLineContent(pos.lineNumber);
        var start = pos.column - 10;
        if (start < 0) {
            start = Std.int(Math.max(0, line.length + start));
        }
        final lineSuffix = line.substr(start, pos.column - 1);
        if (lineSuffix.length > 0 && StringTools.isSpace(lineSuffix, lineSuffix.length - 1)) {
            return super.select(model, pos, items);
        }

        final topScore = items[0].score[0];
        var indexPreselect = -1;
        var indexRecency = -1;
        var seq = -1;
        for (i in 0...items.length) {
            if (items[i].score[0] != topScore) {
                // consider only top items
                break;
            }
            final key = model.getLanguageId() + '/' + items[i].textLabel;
            final item = this._cache.get(key);
            if (item != null && item.touch > seq && item.type == (items[i].completion.kind : Int) && item.insertText == items[i].completion.insertText) {
                seq = item.touch;
                indexRecency = i;
            }
            if (items[i].completion.preselect == true && indexPreselect == -1) {
                // stop when seeing an auto-select-item
                return indexPreselect = i;
            }
        }
        if (indexRecency != -1) {
            return indexRecency;
        }
        else if (indexPreselect != -1) {
            return indexPreselect;
        }
        else {
            return 0;
        }
    }

}

class PrefixMemory extends Memory {

    public function new() {
        super('recentlyUsedByPrefix');
    }

    /**
     * Monaco's `TernarySearchTree.forStrings<MemItem>()`: the items by key;
     * `findSubstr` is the item of the longest key that is a prefix of the
     * key looked up.
     */
    final _trie = new Map<String, MemItem>();
    var _seq = 0;

    function _findSubstr(key:String):Null<MemItem> {
        var best:Null<MemItem> = null;
        var bestLength = -1;
        for (k => v in _trie) {
            if (k.length > bestLength && StringTools.startsWith(key, k)) {
                best = v;
                bestLength = k.length;
            }
        }
        return best;
    }

    public function memorize(model:ITextModel, pos:IPosition, item:CompletionItem):Void {
        final word = model.getWordUntilPosition(pos).word;
        final key = model.getLanguageId() + '/' + word;
        this._trie.set(key, {
            type: item.completion.kind,
            insertText: item.completion.insertText,
            touch: this._seq++
        });
    }

    override public function select(model:ITextModel, pos:IPosition, items:Array<CompletionItem>):Int {
        final word = model.getWordUntilPosition(pos).word;
        if (word.length == 0) {
            return super.select(model, pos, items);
        }
        final key = model.getLanguageId() + '/' + word;
        var item = this._trie.get(key);
        if (item == null) {
            item = this._findSubstr(key);
        }
        if (item != null) {
            for (i in 0...items.length) {
                final kind:Int = items[i].completion.kind;
                final insertText = items[i].completion.insertText;
                if (kind == item.type && insertText == item.insertText) {
                    return i;
                }
            }
        }
        return super.select(model, pos, items);
    }

}

/**
 * Remembers the accepted completions to select them first next time
 * (Monaco's `SuggestMemoryService`, one per `Cityscape` context). The mode
 * comes from the `suggestSelection` option of the editor asking. Monaco
 * saves the memories in the storage service when the window closes; here
 * they live as long as the context.
 */
class SuggestMemoryService {

    var _strategy:Null<Memory> = null;

    public function new() {}

    function _withStrategy(mode:MemMode):Memory {
        if (this._strategy == null || this._strategy.name != mode) {
            this._strategy = switch mode {
                case 'recentlyUsedByPrefix': new PrefixMemory();
                case 'recentlyUsed': new LRUMemory();
                case _: new NoMemory();
            };
        }
        return this._strategy;
    }

    public function memorize(mode:MemMode, model:ITextModel, pos:IPosition, item:CompletionItem):Void {
        this._withStrategy(mode).memorize(model, pos, item);
    }

    public function select(mode:MemMode, model:ITextModel, pos:IPosition, items:Array<CompletionItem>):Int {
        return this._withStrategy(mode).select(model, pos, items);
    }

}
