// Ported from vscode src/vs/editor/contrib/documentSymbols/browser/outlineModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.documentSymbols.view;

import cityscape.base.common.Arrays;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Promise;
import cityscape.base.common.Strings;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.DocumentSymbol;
import cityscape.common.Languages.DocumentSymbolProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.services.LanguageFeaturesService;
import cityscape.common.services.ModelService;
import cityscape.platform.markers.common.Markers.MarkerSeverity;

/**
 * A map keeping the insertion order of its keys, like JavaScript's `Map`
 * (Haxe's `Map` does not): the children of the outline elements, whose
 * order is the order of the providers' symbols.
 */
class InsertionOrderMap<V> {

    final _map:Map<String, V> = new Map();
    final _keys:Array<String> = [];

    public function new() {}

    public var size(get, never):Int;
    inline function get_size():Int {
        return _keys.length;
    }

    public function get(key:String):Null<V> {
        return _map.get(key);
    }

    public function has(key:String):Bool {
        return _map.exists(key);
    }

    /**
     * Sets the value of `key`; a key already present keeps its place.
     */
    public function set(key:String, value:V):InsertionOrderMap<V> {
        if (!_map.exists(key)) {
            _keys.push(key);
        }
        _map.set(key, value);
        return this;
    }

    public function delete(key:String):Bool {
        if (!_map.exists(key)) {
            return false;
        }
        _map.remove(key);
        _keys.splice(_keys.indexOf(key), 1);
        return true;
    }

    public function clear():Void {
        _map.clear();
        _keys.resize(0);
    }

    /**
     * The key at `index` in insertion order (0 is the oldest).
     */
    public inline function keyAt(index:Int):String {
        return _keys[index];
    }

    /**
     * The value at `index` in insertion order (0 is the oldest).
     */
    public inline function valueAt(index:Int):V {
        return _map.get(_keys[index]);
    }

    /**
     * A copy of the keys in insertion order.
     */
    public function keys():Array<String> {
        return _keys.copy();
    }

    /**
     * The values in insertion order (a new array).
     */
    public function values():Array<V> {
        return [for (key in _keys) _map.get(key)];
    }

    /**
     * Iterates over the values in insertion order.
     */
    public inline function iterator():InsertionOrderMapIterator<V> {
        return new InsertionOrderMapIterator<V>(this);
    }

}

class InsertionOrderMapIterator<V> {

    final map:InsertionOrderMap<V>;
    var index:Int = 0;

    public inline function new(map:InsertionOrderMap<V>) {
        this.map = map;
    }

    public inline function hasNext():Bool {
        return index < map.size;
    }

    public inline function next():V {
        return map.valueAt(index++);
    }

}

/**
 * An element of an outline: the model, a group (one per provider) or a
 * symbol.
 *
 * Monaco's abstract `children` map is typed per subclass; the base class
 * reads it through `_childMap` (the same map, seen with `TreeElement`
 * values).
 */
abstract class TreeElement {

    public final id:String;
    public var parent:Null<TreeElement>;

    function new(id:String, parent:Null<TreeElement>) {
        this.id = id;
        this.parent = parent;
    }

    /**
     * The `children` map of the element.
     */
    abstract function _childMap():InsertionOrderMap<TreeElement>;

    /**
     * The values of the `children` map, in insertion order.
     */
    public function childElements():Array<TreeElement> {
        return this._childMap().values();
    }

    public function remove():Void {
        if (this.parent != null) {
            this.parent._childMap().delete(this.id);
        }
    }

    /**
     * The id of a new child of `container`: `candidate` is a `DocumentSymbol`
     * or a string.
     */
    public static function findId(candidate:haxe.extern.EitherType<String, DocumentSymbol>, container:TreeElement):String {
        // complex id-computation which contains the origin/extension,
        // the parent path, and some dedupe logic when names collide
        final children = container._childMap();
        var candidateId:String;
        if (cityscape.base.common.JsValues.isString(candidate)) {
            candidateId = container.id + '/' + (candidate : String);
        }
        else {
            final symbol:DocumentSymbol = candidate;
            candidateId = container.id + '/' + symbol.name;
            if (children.get(candidateId) != null) {
                candidateId = container.id + '/' + symbol.name + '_' + symbol.range.startLineNumber + '_' + symbol.range.startColumn;
            }
        }

        var id = candidateId;
        var i = 0;
        while (children.get(id) != null) {
            id = candidateId + '_' + i;
            i++;
        }

        return id;
    }

    public static function getElementById(id:Null<String>, element:TreeElement):Null<TreeElement> {
        if (id == null || id.length == 0) {
            return null;
        }
        final len = Strings.commonPrefixLength(id, element.id);
        if (len == id.length) {
            return element;
        }
        if (len < element.id.length) {
            return null;
        }
        for (child in element._childMap()) {
            final candidate = getElementById(id, child);
            if (candidate != null) {
                return candidate;
            }
        }
        return null;
    }

    public static function size(element:TreeElement):Int {
        var res = 1;
        for (child in element._childMap()) {
            res += size(child);
        }
        return res;
    }

    public static function empty(element:TreeElement):Bool {
        return element._childMap().size == 0;
    }

}

typedef IOutlineMarker = {
    final startLineNumber:Int;
    final startColumn:Int;
    final endLineNumber:Int;
    final endColumn:Int;
    final severity:MarkerSeverity;
}

/**
 * The markers of an outline element (Monaco's `{ count, topSev }`).
 */
typedef OutlineElementMarker = {
    final count:Int;
    final topSev:MarkerSeverity;
}

class OutlineElement extends TreeElement {

    public final children:InsertionOrderMap<OutlineElement> = new InsertionOrderMap<OutlineElement>();
    public var marker:Null<OutlineElementMarker> = null;

    public final symbol:DocumentSymbol;

    public function new(id:String, parent:Null<TreeElement>, symbol:DocumentSymbol) {
        super(id, parent);
        this.symbol = symbol;
    }

    function _childMap():InsertionOrderMap<TreeElement> {
        return cast children;
    }

}

class OutlineGroup extends TreeElement {

    public final children:InsertionOrderMap<OutlineElement> = new InsertionOrderMap<OutlineElement>();

    public final label:Null<String>;
    public final order:Int;

    public function new(id:String, parent:Null<TreeElement>, label:Null<String>, order:Int) {
        super(id, parent);
        this.label = label;
        this.order = order;
    }

    function _childMap():InsertionOrderMap<TreeElement> {
        return cast children;
    }

    public function getItemEnclosingPosition(position:Null<IPosition>):Null<OutlineElement> {
        return position != null ? this._getItemEnclosingPosition(position, this.children) : null;
    }

    function _getItemEnclosingPosition(position:IPosition, children:InsertionOrderMap<OutlineElement>):Null<OutlineElement> {
        for (item in children) {
            if (item.symbol.range == null || !Range.containsPositionStatic(item.symbol.range, position)) {
                continue;
            }
            final inner = this._getItemEnclosingPosition(position, item.children);
            return inner != null ? inner : item;
        }
        return null;
    }

    /**
     * `marker` is sorted by start (`Range.compareRangesUsingStarts`); the
     * markers matched by an element are removed from it.
     */
    public function updateMarker(marker:Array<IOutlineMarker>):Void {
        for (child in this.children) {
            this._updateMarker(marker, child);
        }
    }

    function _updateMarker(markers:Array<Null<IOutlineMarker>>, item:OutlineElement):Void {
        item.marker = null;

        // find the proper start index to check for item/marker overlap.
        final range = item.symbol.range;
        final idx = Arrays.binarySearch2(markers.length, i -> Range.compareRangesUsingStarts(markers[i], range));
        var start:Int;
        if (idx < 0) {
            start = ~idx;
            if (start > 0 && Range.areIntersecting(markers[start - 1], range)) {
                start -= 1;
            }
        }
        else {
            start = idx;
        }

        final myMarkers:Array<Null<IOutlineMarker>> = [];
        var myTopSev:Null<Int> = null;

        while (start < markers.length && Range.areIntersecting(range, markers[start])) {
            // remove markers intersecting with this outline element
            // and store them in a 'private' array.
            final marker = markers[start];
            myMarkers.push(marker);
            markers[start] = null;
            if (myTopSev == null || myTopSev == 0 || (marker.severity : Int) > myTopSev) {
                myTopSev = marker.severity;
            }
            start++;
        }

        // Recurse into children and let them match markers that have matched
        // this outline element. This might remove markers from this element and
        // therefore we remember that we have had markers. That allows us to render
        // the dot, saying 'this element has children with markers'
        for (child in item.children) {
            this._updateMarker(myMarkers, child);
        }

        if (myTopSev != null && myTopSev != 0) {
            item.marker = {
                count: myMarkers.length,
                topSev: myTopSev
            };
        }

        coalesceInPlace(markers);
    }

    /**
     * Monaco's `coalesceInPlace` (arrays.ts): removes the null items, in
     * place, keeping the order.
     */
    static function coalesceInPlace<T>(array:Array<Null<T>>):Void {
        var to = 0;
        for (i in 0...array.length) {
            final item = array[i];
            if (item != null) {
                array[to] = item;
                to += 1;
            }
        }
        array.resize(to);
    }

}

class OutlineModel extends TreeElement {

    /**
     * Asks the providers of `registry` for the symbols of `textModel`, the
     * outline model once all answered (the providers answer through their
     * `resolve` callback, at once or later). A provider that throws counts
     * as no symbol (`Errors.onUnexpectedExternalError`). When the providers
     * of the model change meanwhile, the model is created again.
     */
    public static function create(registry:LanguageFeatureRegistry<DocumentSymbolProvider>, textModel:ITextModel, token:CancellationToken):Promise<OutlineModel> {

        final cts = new CancellationTokenSource(token);
        final result = new OutlineModel(textModel.uri);
        final provider = registry.ordered(textModel);
        final promises:Array<Promise<Any>> = [];
        for (index in 0...provider.length) {
            final p = provider[index];

            final id = TreeElement.findId('provider_' + index, result);
            final group = new OutlineGroup(id, result, p.displayName != null ? p.displayName : 'Unknown Outline Provider', index);

            promises.push(Promise.fromCallback(done -> p.provideDocumentSymbols(textModel, cts.token, done)).then(symbols -> {
                if (symbols != null) {
                    for (info in symbols) {
                        OutlineModel._makeOutlineElement(info, group);
                    }
                }
                return group;
            }, err -> {
                Errors.onUnexpectedExternalError(err);
                return group;
            }).then(group -> {
                if (!TreeElement.empty(group)) {
                    result._groups.set(id, group);
                }
                else {
                    group.remove();
                }
                return (null : Any);
            }));
        }

        final listener:IDisposable = registry.onDidChange(_ -> {
            final newProvider = registry.ordered(textModel);
            if (!Arrays.equals(newProvider, provider)) {
                cts.cancel();
            }
        });

        return Promise.all(promises).thenPromise(_ -> {
            if (cts.token.isCancellationRequested && !token.isCancellationRequested) {
                return OutlineModel.create(registry, textModel, token);
            }
            else {
                return Promise.resolve(result._compact());
            }
        }).finally(() -> {
            cts.dispose();
            listener.dispose();
            cts.dispose();
        });
    }

    static function _makeOutlineElement(info:DocumentSymbol, container:TreeElement):Void {
        final id = TreeElement.findId(info, container);
        final res = new OutlineElement(id, container, info);
        if (info.children != null) {
            for (childInfo in info.children) {
                OutlineModel._makeOutlineElement(childInfo, res);
            }
        }
        container._childMap().set(res.id, res);
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

    var _groups:InsertionOrderMap<OutlineGroup> = new InsertionOrderMap<OutlineGroup>();

    /**
     * The children: `OutlineGroup`s (several providers answered) or
     * `OutlineElement`s (the elements of the only group).
     */
    public var children:InsertionOrderMap<TreeElement> = new InsertionOrderMap<TreeElement>();

    function new(uri:Uri) {
        super('root', null);
        this.uri = uri;
    }

    function _childMap():InsertionOrderMap<TreeElement> {
        return children;
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
            this.children = cast this._groups;
        }
        else {
            // adopt all elements of the first group
            final group = this._groups.valueAt(0);
            for (child in group.children) {
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
        for (group in this._groups) {
            result = group.getItemEnclosingPosition(position);
            if (result != null && (preferredGroup == null || preferredGroup == group)) {
                break;
            }
        }
        return result;
    }

    public function getItemById(id:String):Null<TreeElement> {
        return TreeElement.getElementById(id, this);
    }

    /**
     * Sorts `marker` by start, then gives a copy to each group.
     */
    public function updateMarker(marker:Array<IOutlineMarker>):Void {
        // sort markers by start range so that we can use
        // outline element starts for quicker look up
        haxe.ds.ArraySort.sort(marker, (a, b) -> Range.compareRangesUsingStarts(a, b));

        for (group in this._groups) {
            group.updateMarker(marker.slice(0));
        }
    }

    public function getTopLevelSymbols():Array<DocumentSymbol> {
        final roots:Array<DocumentSymbol> = [];
        for (child in this.children) {
            final element = Std.downcast(child, OutlineElement);
            if (element != null) {
                roots.push(element.symbol);
            }
            else {
                for (child in (cast child : OutlineGroup).children) {
                    roots.push(child.symbol);
                }
            }
        }
        haxe.ds.ArraySort.sort(roots, (a, b) -> Range.compareRangesUsingStarts(a.range, b.range));
        return roots;
    }

    public function asListOfDocumentSymbols():Array<DocumentSymbol> {
        final roots = this.getTopLevelSymbols();
        final bucket:Array<DocumentSymbol> = [];
        OutlineModel._flattenDocumentSymbols(bucket, roots, '');
        haxe.ds.ArraySort.sort(bucket, _compareStartThenEndReversed);
        return bucket;
    }

    /**
     * `Position.compare(start(a), start(b)) || Position.compare(end(b), end(a))`
     * without creating the positions.
     */
    static function _compareStartThenEndReversed(a:DocumentSymbol, b:DocumentSymbol):Int {
        final ra = a.range;
        final rb = b.range;
        if (ra.startLineNumber != rb.startLineNumber) {
            return ra.startLineNumber - rb.startLineNumber;
        }
        if (ra.startColumn != rb.startColumn) {
            return ra.startColumn - rb.startColumn;
        }
        if (rb.endLineNumber != ra.endLineNumber) {
            return rb.endLineNumber - ra.endLineNumber;
        }
        return rb.endColumn - ra.endColumn;
    }

    static function _flattenDocumentSymbols(bucket:Array<DocumentSymbol>, entries:Array<DocumentSymbol>, overrideContainerLabel:String):Void {
        for (entry in entries) {
            bucket.push({
                kind: entry.kind,
                tags: entry.tags,
                name: entry.name,
                detail: entry.detail,
                containerName: entry.containerName != null && entry.containerName.length > 0 ? entry.containerName : overrideContainerLabel,
                range: entry.range,
                selectionRange: entry.selectionRange,
                children: null, // we flatten it...
            });

            // Recurse over children
            if (entry.children != null) {
                OutlineModel._flattenDocumentSymbols(bucket, entry.children, entry.name);
            }
        }
    }

}

private class CacheEntry {
    public final versionId:Int;
    public final provider:Array<DocumentSymbolProvider>;

    public var promiseCnt:Int = 0;
    public final source:CancellationTokenSource;
    public final promise:Promise<OutlineModel>;
    public var model:Null<OutlineModel> = null;

    public function new(versionId:Int, provider:Array<DocumentSymbolProvider>, source:CancellationTokenSource, promise:Promise<OutlineModel>) {
        this.versionId = versionId;
        this.provider = provider;
        this.source = source;
        this.promise = promise;
    }
}

/**
 * The outline models of the text models, cached by model id and version
 * (Monaco's `IOutlineModelService`). Monaco's service is a singleton; here
 * an instance belongs to a context (no shared state).
 *
 * Monaco's language feature debounce service is not ported: Monaco measures
 * how long the providers take for each model and `getDebounceValue` gives
 * that average (at least 350 ms); here it is always the minimum, 350 ms.
 */
class OutlineModelService {

    /**
     * Monaco's `LRUCache<string, CacheEntry>(10, 0.7)`: the oldest entries
     * (least recently read or written) go first when there are more than 10.
     */
    static inline final _cacheLimit = 10;
    static inline final _cacheRatio = 0.7;

    final _languageFeaturesService:LanguageFeaturesService;
    final _cache = new InsertionOrderMap<CacheEntry>();
    final _modelRemovedListener:Null<IDisposable>;

    /**
     * `modelService` (optional) removes the outline model of a text model
     * removed from it ("don't cache outline models longer than their text
     * model").
     */
    public function new(languageFeaturesService:LanguageFeaturesService, ?modelService:ModelService) {
        this._languageFeaturesService = languageFeaturesService;

        // don't cache outline models longer than their text model
        this._modelRemovedListener = modelService != null ? modelService.onModelRemoved(textModel -> {
            this._cache.delete(textModel.id);
        }) : null;
    }

    public function dispose():Void {
        if (this._modelRemovedListener != null) {
            this._modelRemovedListener.dispose();
        }
    }

    /**
     * The outline model of `textModel` (cached while the version and the
     * providers of the model do not change). Cancelling `token` cancels the
     * request of the providers once every caller waiting for it cancelled.
     */
    public function getOrCreate(textModel:ITextModel, token:CancellationToken):Promise<OutlineModel> {

        final registry = this._languageFeaturesService.documentSymbolProvider;
        final provider = registry.ordered(textModel);

        var cached = this._cacheGet(textModel.id);
        if (cached == null || cached.versionId != textModel.getVersionId() || !Arrays.equals(cached.provider, provider)) {
            final source = new CancellationTokenSource();
            final entry = new CacheEntry(
                textModel.getVersionId(),
                provider,
                source,
                OutlineModel.create(registry, textModel, source.token)
            );
            cached = entry;
            this._cacheSet(textModel.id, entry);

            entry.promise.done(outlineModel -> {
                entry.model = outlineModel;
            }, _err -> {
                this._cache.delete(textModel.id);
            });
        }

        final data:CacheEntry = cached;

        if (data.model != null) {
            // resolved -> return data
            return Promise.resolve(data.model);
        }

        // increase usage counter
        data.promiseCnt += 1;

        final listener = token.onCancellationRequested(() -> {
            // last -> cancel provider request, remove cached promise
            if (--data.promiseCnt == 0) {
                data.source.cancel();
                this._cache.delete(textModel.id);
            }
        });

        return data.promise.finally(() -> {
            listener.dispose();
        });
    }

    /**
     * The delay to wait after a change before asking for the outline (in
     * milliseconds): always 350 (see the class comment).
     */
    public function getDebounceValue(textModel:ITextModel):Int {
        return 350;
    }

    /**
     * `LRUCache.get` (touches the entry).
     */
    function _cacheGet(key:String):Null<CacheEntry> {
        final entry = this._cache.get(key);
        if (entry != null) {
            this._cache.delete(key);
            this._cache.set(key, entry);
        }
        return entry;
    }

    /**
     * `LRUCache.set` (touches the entry, then trims the oldest ones).
     */
    function _cacheSet(key:String, entry:CacheEntry):Void {
        this._cache.delete(key);
        this._cache.set(key, entry);
        if (this._cache.size > _cacheLimit) {
            final newSize = Math.round(_cacheLimit * _cacheRatio);
            while (this._cache.size > newSize) {
                this._cache.delete(this._cache.keyAt(0));
            }
        }
    }

}
