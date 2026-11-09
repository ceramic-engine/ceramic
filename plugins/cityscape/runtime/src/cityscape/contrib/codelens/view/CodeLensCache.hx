// Ported from vscode src/vs/editor/contrib/codelens/browser/codeLensCache.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codelens.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.CodeLens;
import cityscape.common.Languages.CodeLensList;
import cityscape.common.Languages.CodeLensProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.contrib.inlayHints.view.InlayHintsController.LRUCache;
import cityscape.platform.storage.common.Storage;

private typedef ISerializedCacheData = {
    var lineCount:Int;
    var lines:Array<Int>;
}

private class CacheItem {

    public final lineCount:Int;
    public final data:CodeLensModel;

    public function new(lineCount:Int, data:CodeLensModel) {
        this.lineCount = lineCount;
        this.data = data;
    }

}

/**
 * The provider of the cached lenses (it is never asked).
 */
private class FakeCodeLensProvider implements CodeLensProvider {

    public var onDidChange(default, null):Null<Event<CodeLensProvider>> = null;
    public var resolveCodeLens(default, null):Null<(model:ITextModel, codeLens:CodeLens, token:CancellationToken, resolve:(codeLens:Null<CodeLens>) -> Void) -> Void> = null;

    public function new() {}

    public function provideCodeLenses(model:ITextModel, token:CancellationToken, resolve:(lenses:Null<CodeLensList>) -> Void):Void {
        throw 'not supported';
    }

}

/**
 * The last code lenses of the models (their lines and titles), shown when
 * an editor shows a model again while the providers compute the new ones,
 * to reduce flicker (Monaco's `CodeLensCache`, a service of the page; here
 * `Cityscape.codeLensCache`).
 *
 * The lines of the lenses are read from the storage service of the context
 * when the cache is created (key `codelens/cache2`, workspace scope) and
 * stored by `saveState()`: Monaco stores them when the window closes
 * (`onWillSaveState` with the shutdown reason), which a host does here.
 */
class CodeLensCache {

    final _fakeProvider:CodeLensProvider = new FakeCodeLensProvider();

    final _cache = new LRUCache<CacheItem>(20, 0.75);

    final _storageService:IStorageService;

    public function new(storageService:IStorageService) {
        this._storageService = storageService;

        // remove old data
        final oldkey = 'codelens/cache';
        storageService.remove(oldkey, StorageScope.WORKSPACE);

        // restore lens data on start
        final key = 'codelens/cache2';
        final raw = storageService.get(key, StorageScope.WORKSPACE, '{}');
        this._deserialize(raw);
    }

    /**
     * Stores the lines of the cached lenses in the storage service (Monaco
     * does so when the window closes).
     */
    public function saveState():Void {
        this._storageService.store('codelens/cache2', this._serialize(), StorageScope.WORKSPACE, StorageTarget.MACHINE);
    }

    public function put(model:ITextModel, data:CodeLensModel):Void {
        // create a copy of the model that is without command-ids
        // but with comand-labels
        final copyItems:Array<CodeLens> = [for (item in data.lenses) {
            range: item.symbol.range,
            command: item.symbol.command != null ? {id: '', title: item.symbol.command.title} : null
        }];
        final copyModel = new CodeLensModel();
        copyModel.add({lenses: copyItems}, this._fakeProvider);

        final item = new CacheItem(model.getLineCount(), copyModel);
        this._cache.set(model.uri.toString(), item);
    }

    public function get(model:ITextModel):Null<CodeLensModel> {
        final item = this._cache.get(model.uri.toString());
        return item != null && item.lineCount == model.getLineCount() ? item.data : null;
    }

    public function delete(model:ITextModel):Void {
        this._cache.delete(model.uri.toString());
    }

    // --- persistence

    function _serialize():String {
        final data = new haxe.DynamicAccess<ISerializedCacheData>();
        for (key in this._cache.keys()) {
            @:privateAccess final value = this._cache._map.get(key);
            final lines:Array<Int> = [];
            for (d in value.data.lenses) {
                final line = d.symbol.range.startLineNumber;
                if (lines.indexOf(line) == -1) {
                    lines.push(line);
                }
            }
            data.set(key, {
                lineCount: value.lineCount,
                lines: lines
            });
        }
        return haxe.Json.stringify(data);
    }

    function _deserialize(raw:Null<String>):Void {
        if (raw == null) {
            return;
        }
        try {
            final data:haxe.DynamicAccess<Any> = haxe.Json.parse(raw);
            for (key in data.keys()) {
                final element:Any = data.get(key);
                final lineCount:Any = JsValues.field(element, 'lineCount');
                final lines:Any = JsValues.field(element, 'lines');
                if (!JsValues.isArray(lines)) {
                    continue;
                }
                final lenses:Array<CodeLens> = [];
                for (line in (lines : Array<Any>)) {
                    final n:Int = Std.int((line : Float));
                    lenses.push({range: new Range(n, 1, n, 11)});
                }

                final model = new CodeLensModel();
                model.add({lenses: lenses}, this._fakeProvider);
                this._cache.set(key, new CacheItem(Std.int((lineCount : Float)), model));
            }
        }
        catch (e:Dynamic) {
            // ignore...
        }
    }

}
