// Ported from vscode src/vs/editor/contrib/documentSymbols/browser/outlineModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.documentSymbols.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.DocumentSymbol;
import cityscape.common.Languages.DocumentSymbolProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position.IPosition;
import cityscape.common.core.Range;

/*
 * The outline of a model built from its document symbol providers (used by
 * the sticky scroll). Not ported yet: the markers of the outline elements
 * (`updateMarker`, used by the outline view of VS Code) and
 * `OutlineModelService` (a cache of outline models with a debounce; the
 * sticky scroll asks `OutlineModel.create` directly).
 */

/**
 * JavaScript's `Map` keeps the insertion order, which the outline relies
 * on (children are visited in the order the providers gave them): a map
 * with its keys in insertion order.
 */
class OrderedMap<V> {

    final _keys:Array<String> = [];
    final _values:Map<String, V> = new Map();

    public function new() {}

    public var size(get, never):Int;
    inline function get_size():Int {
        return _keys.length;
    }

    public function get(key:String):Null<V> {
        return _values.get(key);
    }

    public function exists(key:String):Bool {
        return _values.exists(key);
    }

    public function set(key:String, value:V):Void {
        if (!_values.exists(key)) {
            _keys.push(key);
        }
        _values.set(key, value);
    }

    public function delete(key:String):Bool {
        if (!_values.exists(key)) {
            return false;
        }
        _values.remove(key);
        _keys.remove(key);
        return true;
    }

    public function keys():Array<String> {
        return _keys.copy();
    }

    /**
     * The values in insertion order.
     */
    public function values():Array<V> {
        return [for (k in _keys) _values.get(k)];
    }

}

abstract class TreeElement {

    public var id(default, null):String;
    public var parent:Null<TreeElement>;

    /**
     * The children (`OutlineGroup` or `OutlineElement`), in insertion order.
     */
    abstract public function childElements():Array<TreeElement>;

    abstract public function hasChild(id:String):Bool;

    abstract public function removeChild(id:String):Void;

    public function remove():Void {
        if (this.parent != null) {
            this.parent.removeChild(this.id);
        }
    }

    public static function findId(candidate:Dynamic, container:TreeElement):String {
        // complex id-computation which contains the origin/extension,
        // the parent path, and some dedupe logic when names collide
        var candidateId:String;
        if (Std.isOfType(candidate, String)) {
            candidateId = container.id + '/' + (candidate : String);
        }
        else {
            final symbol:DocumentSymbol = candidate;
            candidateId = container.id + '/' + symbol.name;
            if (container.hasChild(candidateId)) {
                candidateId = container.id + '/' + symbol.name + '_' + symbol.range.startLineNumber + '_' + symbol.range.startColumn;
            }
        }

        var id = candidateId;
        var i = 0;
        while (container.hasChild(id)) {
            id = candidateId + '_' + i;
            i++;
        }

        return id;
    }

    public static function size(element:TreeElement):Int {
        var res = 1;
        for (child in element.childElements()) {
            res += TreeElement.size(child);
        }
        return res;
    }

    public static function empty(element:TreeElement):Bool {
        return element.childElements().length == 0;
    }

}

class OutlineElement extends TreeElement {

    public final children = new OrderedMap<OutlineElement>();
    public final symbol:DocumentSymbol;

    public function new(id:String, parent:Null<TreeElement>, symbol:DocumentSymbol) {
        this.id = id;
        this.parent = parent;
        this.symbol = symbol;
    }

    public function childElements():Array<TreeElement> {
        return cast children.values();
    }

    public function hasChild(id:String):Bool {
        return children.exists(id);
    }

    public function removeChild(id:String):Void {
        children.delete(id);
    }

}

class OutlineGroup extends TreeElement {

    public final children = new OrderedMap<OutlineElement>();
    public final label:String;
    public final order:Int;

    public function new(id:String, parent:Null<TreeElement>, label:String, order:Int) {
        this.id = id;
        this.parent = parent;
        this.label = label;
        this.order = order;
    }

    public function childElements():Array<TreeElement> {
        return cast children.values();
    }

    public function hasChild(id:String):Bool {
        return children.exists(id);
    }

    public function removeChild(id:String):Void {
        children.delete(id);
    }

    public function getItemEnclosingPosition(position:Null<IPosition>):Null<OutlineElement> {
        return position != null ? this._getItemEnclosingPosition(position, this.children) : null;
    }

    function _getItemEnclosingPosition(position:IPosition, children:OrderedMap<OutlineElement>):Null<OutlineElement> {
        for (item in children.values()) {
            if (item.symbol.range == null || !Range.containsPositionStatic(item.symbol.range, position)) {
                continue;
            }
            final inner = this._getItemEnclosingPosition(position, item.children);
            return inner != null ? inner : item;
        }
        return null;
    }

}

class OutlineModel extends TreeElement {

    /**
     * Builds the outline of `textModel` from the providers of `registry`
     * (all of them, each in its group) and gives it to `done` once every
     * provider answered (Monaco returns a promise).
     */
    public static function create(registry:LanguageFeatureRegistry<DocumentSymbolProvider>, textModel:ITextModel, token:CancellationToken, done:(model:OutlineModel) -> Void):Void {

        final cts = new CancellationTokenSource(token);
        final result = new OutlineModel(textModel.uri);
        final provider = registry.ordered(textModel);
        var pending = provider.length;

        var listener:Null<cityscape.base.common.Lifecycle.IDisposable> = null;

        function finish():Void {
            if (listener != null) {
                listener.dispose();
            }
            final cancelled = cts.token.isCancellationRequested;
            cts.dispose();
            if (cancelled && !token.isCancellationRequested) {
                OutlineModel.create(registry, textModel, token, done);
            }
            else {
                done(result._compact());
            }
        }

        listener = registry.onDidChange((_) -> {
            final newProvider = registry.ordered(textModel);
            var same = newProvider.length == provider.length;
            if (same) {
                for (i in 0...provider.length) {
                    if (newProvider[i] != provider[i]) {
                        same = false;
                        break;
                    }
                }
            }
            if (!same) {
                cts.cancel();
            }
        });

        if (pending == 0) {
            finish();
            return;
        }

        for (index in 0...provider.length) {
            final p = provider[index];
            final id = TreeElement.findId('provider_' + index, result);
            final group = new OutlineGroup(id, result, p.displayName != null ? p.displayName : 'Unknown Outline Provider', index);

            var answered = false;
            function onSymbols(symbols:Null<Array<DocumentSymbol>>):Void {
                if (answered) {
                    return;
                }
                answered = true;
                if (symbols != null) {
                    for (info in symbols) {
                        OutlineModel._makeOutlineElement(info, group);
                    }
                }
                if (!TreeElement.empty(group)) {
                    result._groups.set(id, group);
                }
                else {
                    group.remove();
                }
                pending--;
                if (pending == 0) {
                    finish();
                }
            }
            try {
                p.provideDocumentSymbols(textModel, cts.token, onSymbols);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
                onSymbols(null);
            }
        }
    }

    static function _makeOutlineElement(info:DocumentSymbol, container:TreeElement):Void {
        final id = TreeElement.findId(info, container);
        final res = new OutlineElement(id, container, info);
        if (info.children != null) {
            for (childInfo in info.children) {
                OutlineModel._makeOutlineElement(childInfo, res);
            }
        }
        if (Std.isOfType(container, OutlineGroup)) {
            (cast container : OutlineGroup).children.set(res.id, res);
        }
        else {
            (cast container : OutlineElement).children.set(res.id, res);
        }
    }

    public static function get(element:Null<TreeElement>):Null<OutlineModel> {
        while (element != null) {
            if (Std.isOfType(element, OutlineModel)) {
                return cast element;
            }
            element = element.parent;
        }
        return null;
    }

    public final uri:Uri;

    var _groups = new OrderedMap<OutlineGroup>();

    /**
     * The groups (when several providers gave symbols) or the elements of
     * the only group (`OutlineGroup` or `OutlineElement` values).
     */
    public var children = new OrderedMap<TreeElement>();

    function new(uri:Uri) {
        this.uri = uri;
        this.id = 'root';
        this.parent = null;
    }

    public function childElements():Array<TreeElement> {
        return children.values();
    }

    public function hasChild(id:String):Bool {
        return children.exists(id);
    }

    public function removeChild(id:String):Void {
        children.delete(id);
    }

    function _compact():OutlineModel {
        var count = 0;
        for (key in this._groups.keys()) {
            final group = this._groups.get(key);
            if (group.children.size == 0) { // empty
                this._groups.delete(key);
            }
            else {
                count += 1;
            }
        }
        if (count != 1) {
            //
            this.children = new OrderedMap<TreeElement>();
            for (key in this._groups.keys()) {
                this.children.set(key, this._groups.get(key));
            }
        }
        else {
            // adopt all elements of the first group
            final group = this._groups.values()[0];
            for (child in group.children.values()) {
                child.parent = this;
                this.children.set(child.id, child);
            }
        }
        return this;
    }

    public function merge(other:OutlineModel):Bool {
        if (this.uri.toString() != other.uri.toString()) {
            return false;
        }
        if (this._groups.size != other._groups.size) {
            return false;
        }
        this._groups = other._groups;
        this.children = other.children;
        return true;
    }

    public function getItemEnclosingPosition(position:IPosition, ?context:OutlineElement):Null<OutlineElement> {

        var preferredGroup:Null<OutlineGroup> = null;
        if (context != null) {
            var candidate = context.parent;
            while (candidate != null && preferredGroup == null) {
                if (Std.isOfType(candidate, OutlineGroup)) {
                    preferredGroup = cast candidate;
                }
                candidate = candidate.parent;
            }
        }

        var result:Null<OutlineElement> = null;
        for (group in this._groups.values()) {
            result = group.getItemEnclosingPosition(position);
            if (result != null && (preferredGroup == null || preferredGroup == group)) {
                break;
            }
        }
        return result;
    }

    public function getTopLevelSymbols():Array<DocumentSymbol> {
        final roots:Array<DocumentSymbol> = [];
        for (child in this.children.values()) {
            if (Std.isOfType(child, OutlineElement)) {
                roots.push((cast child : OutlineElement).symbol);
            }
            else {
                for (element in (cast child : OutlineGroup).children.values()) {
                    roots.push(element.symbol);
                }
            }
        }
        haxe.ds.ArraySort.sort(roots, (a, b) -> Range.compareRangesUsingStarts(a.range, b.range));
        return roots;
    }

}
