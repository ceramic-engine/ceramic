// Ported from vscode src/vs/editor/common/languageFeatureRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.LanguageSelector;
import cityscape.common.Model.ITextModel;
import cityscape.common.Model.ModelUtils;
import haxe.extern.EitherType;

private class Entry<T> {
    public final selector:LanguageSelector;
    public final provider:T;
    public var _score:Int;
    public final _time:Int;

    public function new(selector:LanguageSelector, provider:T, score:Int, time:Int) {
        this.selector = selector;
        this.provider = provider;
        this._score = score;
        this._time = time;
    }
}

private class MatchCandidate {
    public final uri:Uri;
    public final languageId:String;
    public final notebookUri:Null<Uri>;
    public final notebookType:Null<String>;
    public final recursive:Bool;

    public function new(uri:Uri, languageId:String, notebookUri:Null<Uri>, notebookType:Null<String>, recursive:Bool) {
        this.uri = uri;
        this.languageId = languageId;
        this.notebookUri = notebookUri;
        this.notebookType = notebookType;
        this.recursive = recursive;
    }

    public function equals(other:MatchCandidate):Bool {
        return this.notebookType == other.notebookType
            && this.languageId == other.languageId
            && this.uri.toString() == other.uri.toString()
            && (this.notebookUri == null ? null : this.notebookUri.toString()) == (other.notebookUri == null ? null : other.notebookUri.toString())
            && this.recursive == other.recursive;
    }
}

/**
 * The providers of a language feature, with the language selector each was
 * registered for; ordered by score for a model.
 *
 * Monaco's registries are global services (`ILanguageFeaturesService`);
 * Cityscape's are fields of a context (`Cityscape.languageFeaturesService`).
 * Notebooks are not supported (no notebook info resolver).
 */
class LanguageFeatureRegistry<T> {

    var _clock:Int = 0;
    final _entries:Array<Entry<T>> = [];

    final _onDidChange = new Emitter<Int>();
    public final onDidChange:Event<Int>;

    public function new() {
        onDidChange = _onDidChange.event;
    }

    public function register(selector:LanguageSelector, provider:T):IDisposable {

        var entry:Null<Entry<T>> = new Entry<T>(selector, provider, -1, _clock++);

        _entries.push(entry);
        _lastCandidate = null;
        _onDidChange.fire(_entries.length);

        return Lifecycle.toDisposable(() -> {
            if (entry != null) {
                final idx = _entries.indexOf(entry);
                if (idx >= 0) {
                    _entries.splice(idx, 1);
                    _lastCandidate = null;
                    _onDidChange.fire(_entries.length);
                    entry = null;
                }
            }
        });
    }

    public function has(model:ITextModel):Bool {
        return all(model).length > 0;
    }

    public function all(model:Null<ITextModel>):Array<T> {
        if (model == null) {
            return [];
        }

        _updateScores(model, false);
        final result:Array<T> = [];

        // from registry
        for (entry in _entries) {
            if (entry._score > 0) {
                result.push(entry.provider);
            }
        }

        return result;
    }

    public function allNoModel():Array<T> {
        return [for (entry in _entries) entry.provider];
    }

    public function ordered(model:ITextModel, recursive:Bool = false):Array<T> {
        final result:Array<T> = [];
        _orderedForEach(model, recursive, entry -> result.push(entry.provider));
        return result;
    }

    public function orderedGroups(model:ITextModel):Array<Array<T>> {
        final result:Array<Array<T>> = [];
        var lastBucket:Null<Array<T>> = null;
        var lastBucketScore = 0;

        _orderedForEach(model, false, entry -> {
            if (lastBucket != null && lastBucketScore == entry._score) {
                lastBucket.push(entry.provider);
            }
            else {
                lastBucketScore = entry._score;
                lastBucket = [entry.provider];
                result.push(lastBucket);
            }
        });

        return result;
    }

    function _orderedForEach(model:ITextModel, recursive:Bool, callback:(provider:Entry<T>) -> Void):Void {

        _updateScores(model, recursive);

        for (entry in _entries) {
            if (entry._score > 0) {
                callback(entry);
            }
        }
    }

    var _lastCandidate:Null<MatchCandidate> = null;

    function _updateScores(model:ITextModel, recursive:Bool):Void {

        final candidate = new MatchCandidate(model.uri, model.getLanguageId(), null, null, recursive);

        if (_lastCandidate != null && _lastCandidate.equals(candidate)) {
            // nothing has changed
            return;
        }

        _lastCandidate = candidate;

        for (entry in _entries) {
            entry._score = LanguageSelectorUtils.score(entry.selector, candidate.uri, candidate.languageId, ModelUtils.shouldSynchronizeModel(model), candidate.notebookUri, candidate.notebookType);

            if (isExclusive(entry.selector) && entry._score > 0) {
                if (recursive) {
                    entry._score = 0;
                }
                else {
                    // support for one exclusive selector that overwrites
                    // any other selector
                    for (entry in _entries) {
                        entry._score = 0;
                    }
                    entry._score = 1000;
                    break;
                }
            }
        }

        // needs sorting (stable, like JavaScript's sort)
        haxe.ds.ArraySort.sort(_entries, _compareByScoreAndTime);
    }

    static function _compareByScoreAndTime<T>(a:Entry<T>, b:Entry<T>):Int {
        if (a._score < b._score) {
            return 1;
        }
        else if (a._score > b._score) {
            return -1;
        }

        // De-prioritize built-in providers
        if (isBuiltinSelector(a.selector) && !isBuiltinSelector(b.selector)) {
            return 1;
        }
        else if (!isBuiltinSelector(a.selector) && isBuiltinSelector(b.selector)) {
            return -1;
        }

        if (a._time < b._time) {
            return 1;
        }
        else if (a._time > b._time) {
            return -1;
        }
        else {
            return 0;
        }
    }

    static function isExclusive(selector:LanguageSelector):Bool {
        if (JsValues.isString(selector)) {
            return false;
        }
        else if (JsValues.isArray(selector)) {
            final filters:Array<EitherType<String, LanguageFilter>> = cast selector;
            for (f in filters) {
                if (!isExclusive(cast f)) {
                    return false;
                }
            }
            return true;
        }
        else {
            return (cast selector : LanguageFilter).exclusive == true;
        }
    }

    static function isBuiltinSelector(selector:LanguageSelector):Bool {
        if (JsValues.isString(selector)) {
            return false;
        }

        if (JsValues.isArray(selector)) {
            final filters:Array<EitherType<String, LanguageFilter>> = cast selector;
            for (f in filters) {
                if (isBuiltinSelector(cast f)) {
                    return true;
                }
            }
            return false;
        }

        return (cast selector : LanguageFilter).isBuiltin == true;
    }

}
