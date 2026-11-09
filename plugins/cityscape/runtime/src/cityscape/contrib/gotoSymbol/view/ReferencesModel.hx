// Ported from vscode src/vs/editor/contrib/gotoSymbol/browser/referencesModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoSymbol.view;

import cityscape.Nls;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.Filters.IMatch;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Strings;
import cityscape.base.common.Uri;
import cityscape.common.Languages.Location;
import cityscape.common.Languages.LocationLink;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * The text of a reference with the surrounding words (`FilePreview.preview`).
 */
typedef FilePreviewResult = {
    final value:String;
    final highlight:IMatch;
}

class OneReference {

    /**
     * Monaco's `defaultGenerator` (`IdGenerator('id#')`): a global id counter.
     */
    static var _lastId:Int = 0;

    public final id:String = 'id#' + (++_lastId);

    var _range:Null<IRange> = null;

    public final isProviderFirst:Bool;
    public final parent:FileReferences;
    public final link:LocationLink;
    final _rangeCallback:(ref:OneReference) -> Void;

    public function new(isProviderFirst:Bool, parent:FileReferences, link:LocationLink, _rangeCallback:(ref:OneReference) -> Void) {
        this.isProviderFirst = isProviderFirst;
        this.parent = parent;
        this.link = link;
        this._rangeCallback = _rangeCallback;
    }

    public var uri(get, never):Uri;
    inline function get_uri():Uri {
        return this.link.uri;
    }

    public var range(get, set):IRange;
    function get_range():IRange {
        if (this._range != null) {
            return this._range;
        }
        final targetSelectionRange = this.link.targetSelectionRange;
        return targetSelectionRange != null ? targetSelectionRange : this.link.range;
    }
    function set_range(value:IRange):IRange {
        this._range = value;
        this._rangeCallback(this);
        return value;
    }

    /**
     * Monaco's `ariaMessage` getter; the text is localized by `nls` (the
     * English text when null).
     */
    public function ariaMessage(?nls:Nls):String {

        final filePreview = this.parent.getPreview(this);
        final preview = filePreview != null ? filePreview.preview(this.range) : null;

        if (preview == null) {
            return ReferencesModel.localize(nls,
                'aria.oneReference', "in {0} on line {1} at column {2}",
                [ReferencesModel.basename(this.uri), this.range.startLineNumber, this.range.startColumn]
            );
        }
        else {
            return ReferencesModel.localize(nls,
                'aria.oneReference.preview', "{0} in {1} on line {2} at column {3}",
                [preview.value, ReferencesModel.basename(this.uri), this.range.startLineNumber, this.range.startColumn]
            );
        }
    }

}

/**
 * The preview of the references of a file. Monaco keeps a reference to the
 * model from its text model service; here it is the model itself, and
 * `dispose` calls the optional `onDispose` (to release the model).
 */
class FilePreview implements IDisposable {

    final _model:Null<ITextModel>;
    final _onDispose:Null<() -> Void>;

    public function new(model:Null<ITextModel>, ?onDispose:() -> Void) {
        this._model = model;
        this._onDispose = onDispose;
    }

    public function dispose():Void {
        if (this._onDispose != null) {
            this._onDispose();
        }
    }

    /**
     * Monaco's `Constants.MAX_SAFE_SMALL_INTEGER` (uint.ts).
     */
    static inline final MAX_SAFE_SMALL_INTEGER = 1 << 30;

    public function preview(range:IRange, n:Int = 8):Null<FilePreviewResult> {
        final model = this._model;

        if (model == null) {
            return null;
        }

        final startLineNumber = range.startLineNumber;
        final startColumn = range.startColumn;
        final endLineNumber = range.endLineNumber;
        final endColumn = range.endColumn;
        final word = model.getWordUntilPosition({lineNumber: startLineNumber, column: startColumn - n});
        final beforeRange = new Range(startLineNumber, word.startColumn, startLineNumber, startColumn);
        final afterRange = new Range(endLineNumber, endColumn, endLineNumber, MAX_SAFE_SMALL_INTEGER);

        final before = trimStart(model.getValueInRange(beforeRange)); // .replace(/^\s+/, '')
        final inside = model.getValueInRange(range);
        final after = trimEnd(model.getValueInRange(afterRange)); // .replace(/\s+$/, '')

        return {
            value: before + inside + after,
            highlight: {start: before.length, end: before.length + inside.length}
        };
    }

    static function trimStart(text:String):String {
        var start = 0;
        while (start < text.length && Strings.isJsWhitespace(StringTools.fastCodeAt(text, start))) {
            start++;
        }
        return start == 0 ? text : text.substring(start);
    }

    static function trimEnd(text:String):String {
        var end = text.length;
        while (end > 0 && Strings.isJsWhitespace(StringTools.fastCodeAt(text, end - 1))) {
            end--;
        }
        return end == text.length ? text : text.substring(0, end);
    }

}

class FileReferences implements IDisposable {

    public final children:Array<OneReference> = [];

    /**
     * Monaco's `ResourceMap<FilePreview>` (keyed by `uri.toString()`).
     */
    final _previews:Map<String, FilePreview> = new Map();
    var _previewCount:Int = 0;

    public final parent:ReferencesModel;
    public final uri:Uri;

    public function new(parent:ReferencesModel, uri:Uri) {
        this.parent = parent;
        this.uri = uri;
    }

    public function dispose():Void {
        for (preview in this._previews) {
            preview.dispose();
        }
        this._previews.clear();
        this._previewCount = 0;
    }

    public function getPreview(child:OneReference):Null<FilePreview> {
        return this._previews.get(child.uri.toString());
    }

    /**
     * Monaco's `ariaMessage` getter; the text is localized by `nls` (the
     * English text when null).
     */
    public function ariaMessage(?nls:Nls):String {
        final len = this.children.length;
        if (len == 1) {
            return ReferencesModel.localize(nls, 'aria.fileReferences.1', "1 symbol in {0}, full path {1}", [ReferencesModel.basename(this.uri), this.uri.fsPath]);
        }
        else {
            return ReferencesModel.localize(nls, 'aria.fileReferences.N', "{0} symbols in {1}, full path {2}", [len, ReferencesModel.basename(this.uri), this.uri.fsPath]);
        }
    }

    /**
     * Creates the previews of the children with the models `resolveModel`
     * gives (Monaco asks its text model service, asynchronously; for
     * example `uri -> context.modelService.getModel(uri)` here). A resolver
     * that throws is reported to `Errors.onUnexpectedError`.
     */
    public function resolve(resolveModel:(uri:Uri) -> Null<ITextModel>):FileReferences {
        if (this._previewCount != 0) {
            return this;
        }
        for (child in this.children) {
            final key = child.uri.toString();
            if (this._previews.exists(key)) {
                continue;
            }
            try {
                final model = resolveModel(child.uri);
                if (model == null) {
                    throw 'no model for ' + key;
                }
                this._previews.set(key, new FilePreview(model));
                this._previewCount++;
            }
            catch (err:Any) {
                Errors.onUnexpectedError(err);
            }
        }
        return this;
    }

}

class ReferencesModel implements IDisposable {

    final _links:Array<LocationLink>;
    final _title:String;

    public final groups:Array<FileReferences> = [];
    public final references:Array<OneReference> = [];

    public final _onDidChangeReferenceRange = new Emitter<OneReference>();
    public final onDidChangeReferenceRange:Event<OneReference>;

    /**
     * Sorts `links` (in place, like Monaco) by uri and range and groups them
     * by file; equal links are kept once.
     */
    public function new(links:Array<LocationLink>, title:String) {
        this.onDidChangeReferenceRange = this._onDidChangeReferenceRange.event;
        this._links = links;
        this._title = title;

        // grouping and sorting
        final providersFirst = links.length > 0 ? links[0] : null;
        haxe.ds.ArraySort.sort(links, _compareLinks);

        var current:Null<FileReferences> = null;
        for (link in links) {
            if (current == null || !uriIsEqual(current.uri, link.uri, true)) {
                // new group
                current = new FileReferences(this, link.uri);
                this.groups.push(current);
            }

            // append, check for equality first!
            if (current.children.length == 0 || ReferencesModel._compareReferences(link.uri, link.range, current.children[current.children.length - 1].uri, current.children[current.children.length - 1].range) != 0) {

                final oneRef = new OneReference(
                    providersFirst == link,
                    current,
                    link,
                    ref -> this._onDidChangeReferenceRange.fire(ref)
                );
                this.references.push(oneRef);
                current.children.push(oneRef);
            }
        }
    }

    public function dispose():Void {
        for (group in this.groups) {
            group.dispose();
        }
        this._onDidChangeReferenceRange.dispose();
        this.groups.resize(0);
    }

    public function clone():ReferencesModel {
        return new ReferencesModel(this._links, this._title);
    }

    public var title(get, never):String;
    function get_title():String {
        return this._title;
    }

    public var isEmpty(get, never):Bool;
    function get_isEmpty():Bool {
        return this.groups.length == 0;
    }

    /**
     * Monaco's `ariaMessage` getter; the text is localized by `nls` (the
     * English text when null).
     */
    public function ariaMessage(?nls:Nls):String {
        if (this.isEmpty) {
            return localize(nls, 'aria.result.0', "No results found");
        }
        else if (this.references.length == 1) {
            return localize(nls, 'aria.result.1', "Found 1 symbol in {0}", [this.references[0].uri.fsPath]);
        }
        else if (this.groups.length == 1) {
            return localize(nls, 'aria.result.n1', "Found {0} symbols in {1}", [this.references.length, this.groups[0].uri.fsPath]);
        }
        else {
            return localize(nls, 'aria.result.nm', "Found {0} symbols in {1} files", [this.references.length, this.groups.length]);
        }
    }

    public function nextOrPreviousReference(reference:OneReference, next:Bool):OneReference {

        final parent = reference.parent;

        var idx = parent.children.indexOf(reference);
        final childCount = parent.children.length;
        final groupCount = parent.parent.groups.length;

        if (groupCount == 1 || next && idx + 1 < childCount || !next && idx > 0) {
            // cycling within one file
            if (next) {
                idx = (idx + 1) % childCount;
            }
            else {
                idx = (idx + childCount - 1) % childCount;
            }
            return parent.children[idx];
        }

        idx = parent.parent.groups.indexOf(parent);
        if (next) {
            idx = (idx + 1) % groupCount;
            return parent.parent.groups[idx].children[0];
        }
        else {
            idx = (idx + groupCount - 1) % groupCount;
            return parent.parent.groups[idx].children[parent.parent.groups[idx].children.length - 1];
        }
    }

    /**
     * The reference whose uri shares the longest prefix with `resource`,
     * then the closest to `position`. Monaco maps the references and sorts
     * them (stable) to take the first; the first minimum of the same order
     * is the same reference.
     */
    public function nearestReference(resource:Uri, position:Position):Null<OneReference> {

        final resourceString = resource.toString();
        var nearestIdx = -1;
        var nearestPrefixLen = 0;
        var nearestOffsetDist = 0;
        for (idx in 0...this.references.length) {
            final ref = this.references[idx];
            final prefixLen = Strings.commonPrefixLength(ref.uri.toString(), resourceString);
            final offsetDist = Std.int(Math.abs(ref.range.startLineNumber - position.lineNumber) * 100 + Math.abs(ref.range.startColumn - position.column));
            if (nearestIdx < 0
                || prefixLen > nearestPrefixLen
                || (prefixLen == nearestPrefixLen && offsetDist < nearestOffsetDist)) {
                nearestIdx = idx;
                nearestPrefixLen = prefixLen;
                nearestOffsetDist = offsetDist;
            }
        }

        if (nearestIdx >= 0) {
            return this.references[nearestIdx];
        }
        return null;
    }

    public function referenceAt(resource:Uri, position:Position):Null<OneReference> {
        final resourceString = resource.toString();
        for (ref in this.references) {
            if (ref.uri.toString() == resourceString) {
                if (Range.containsPositionStatic(ref.range, position)) {
                    return ref;
                }
            }
        }
        return null;
    }

    public function firstReference():Null<OneReference> {
        for (ref in this.references) {
            if (ref.isProviderFirst) {
                return ref;
            }
        }
        return this.references.length > 0 ? this.references[0] : null;
    }

    static function _compareLinks(a:LocationLink, b:LocationLink):Int {
        return _compareReferences(a.uri, a.range, b.uri, b.range);
    }

    /**
     * Monaco's `_compareReferences(a: Location, b: Location)`, with the uri
     * and range of each (a `OneReference` gives its own `range`).
     */
    static function _compareReferences(aUri:Uri, aRange:IRange, bUri:Uri, bRange:IRange):Int {
        final result = uriCompare(aUri, bUri);
        return result != 0 ? result : Range.compareRangesUsingStarts(aRange, bRange);
    }

    // ---- vs/base/common/resources.ts (`extUri`, which keeps the path casing)

    /**
     * `extUri.getComparisonKey(uri, ignoreFragment)`.
     */
    static function uriComparisonKey(uri:Uri, ignoreFragment:Bool):String {
        // Monaco's `fragment: null` empties the fragment; `''` here
        return ignoreFragment ? uri.with({fragment: ''}).toString() : uri.toString();
    }

    /**
     * `extUri.compare(uri1, uri2)`: the comparison keys compared by UTF-16
     * code units (JavaScript's `<`).
     */
    public static function uriCompare(uri1:Uri, uri2:Uri, ignoreFragment:Bool = false):Int {
        if (uri1 == uri2) {
            return 0;
        }
        return Strings.compareSubstring(uriComparisonKey(uri1, ignoreFragment), uriComparisonKey(uri2, ignoreFragment));
    }

    /**
     * `extUri.isEqual(uri1, uri2, ignoreFragment)`.
     */
    public static function uriIsEqual(uri1:Null<Uri>, uri2:Null<Uri>, ignoreFragment:Bool = false):Bool {
        if (uri1 == uri2) {
            return true;
        }
        if (uri1 == null || uri2 == null) {
            return false;
        }
        return uriComparisonKey(uri1, ignoreFragment) == uriComparisonKey(uri2, ignoreFragment);
    }

    /**
     * `resources.basename`: the last segment of the path (`paths.posix.basename`).
     */
    public static function basename(resource:Uri):String {
        var path = resource.path;
        // trailing slashes are ignored
        var end = path.length;
        while (end > 0 && StringTools.fastCodeAt(path, end - 1) == '/'.code) {
            end--;
        }
        if (end == 0) {
            return '';
        }
        final start = path.lastIndexOf('/', end - 1) + 1;
        return path.substring(start, end);
    }

    @:allow(cityscape.contrib.gotoSymbol.view)
    static function localize(nls:Null<Nls>, key:String, defaultMessage:String, ?args:Array<Any>):String {
        if (nls != null) {
            return nls.localize(key, defaultMessage, args);
        }
        return Nls.format(defaultMessage, args != null ? args : []);
    }

}
