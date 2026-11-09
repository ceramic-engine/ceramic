// Ported from vscode src/vs/editor/contrib/inlayHints/browser/inlayHints.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlayHints.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.Promise;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.Command;
import cityscape.common.Languages.InlayHint;
import cityscape.common.Languages.InlayHintList;
import cityscape.common.Languages.InlayHintsProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * The range an inlay hint is attached to and the side it shows on.
 */
class InlayHintAnchor {

    public final range:Range;
    /**
     * `'before'` or `'after'`.
     */
    public final direction:String;

    public function new(range:Range, direction:String) {
        this.range = range;
        this.direction = direction;
    }

}

/**
 * An inlay hint of a provider, resolved once on demand.
 */
class InlayHintItem {

    var _isResolved:Bool = false;
    var _currentResolve:Null<Promise<Any>> = null;

    public final hint:InlayHint;
    public final anchor:InlayHintAnchor;
    public final provider:InlayHintsProvider;

    public function new(hint:InlayHint, anchor:InlayHintAnchor, provider:InlayHintsProvider) {
        this.hint = hint;
        this.anchor = anchor;
        this.provider = provider;
    }

    public function with(delta:{anchor:InlayHintAnchor}):InlayHintItem {
        final result = new InlayHintItem(this.hint, delta.anchor, this.provider);
        result._isResolved = this._isResolved;
        result._currentResolve = this._currentResolve;
        return result;
    }

    /**
     * Resolves the hint with the provider's `resolveInlayHint` (once):
     * settles when done (at once when the provider answers at once).
     */
    public function resolve(token:CancellationToken):Promise<Any> {
        if (this.provider.resolveInlayHint == null) {
            return Promise.resolve(null);
        }
        final current = this._currentResolve;
        if (current != null) {
            // wait for an active resolve operation and try again
            // when that's done.
            return current.thenPromise(_ -> {
                if (token.isCancellationRequested) {
                    return Promise.resolve(null);
                }
                return this.resolve(token);
            });
        }
        if (!this._isResolved) {
            final p = this._doResolve(token);
            // (assigned before the reaction: the promise may be settled already)
            this._currentResolve = p;
            p.finally(() -> {
                if (this._currentResolve == p) {
                    this._currentResolve = null;
                }
            });
            return p;
        }
        return Promise.resolve(null);
    }

    function _doResolve(token:CancellationToken):Promise<Any> {
        final resolveInlayHint = this.provider.resolveInlayHint;
        var failed = false;
        return Promise.fromCallback((done:(value:Null<InlayHint>) -> Void) -> {
            try {
                resolveInlayHint(this.hint, token, done);
            }
            catch (err:Dynamic) {
                Errors.onUnexpectedExternalError(err);
                failed = true;
                done(null);
            }
        }).then(newHint -> {
            if (failed) {
                this._isResolved = false;
                return null;
            }
            if (newHint != null) {
                if (newHint.tooltip != null) {
                    this.hint.tooltip = newHint.tooltip;
                }
                if (newHint.label != null) {
                    this.hint.label = newHint.label;
                }
                if (newHint.textEdits != null) {
                    this.hint.textEdits = newHint.textEdits;
                }
            }
            this._isResolved = true;
            return null;
        });
    }

}

/**
 * The inlay hints of the providers of a model for some ranges.
 */
class InlayHintsFragments {

    static final _emptyInlayHintList:InlayHintList = {hints: []};

    /**
     * Asks the providers (in reverse order of score) for the hints of each
     * range: settles once all answered, rejected with a `CancellationError`
     * when the token is cancelled or the model disposed meanwhile.
     */
    public static function create(registry:LanguageFeatureRegistry<InlayHintsProvider>, model:ITextModel, ranges:Array<Range>, token:CancellationToken):Promise<InlayHintsFragments> {

        final data:Array<{list:InlayHintList, provider:InlayHintsProvider}> = [];

        final providers = registry.ordered(model).copy();
        providers.reverse();
        final promises:Array<Promise<Any>> = [];
        for (provider in providers) {
            for (range in ranges) {
                promises.push(Promise.fromCallback((done:(value:Null<InlayHintList>) -> Void) -> {
                    try {
                        provider.provideInlayHints(model, range, token, done);
                    }
                    catch (err:Dynamic) {
                        Errors.onUnexpectedExternalError(err);
                        done(null);
                    }
                }).then(result -> {
                    if ((result != null && result.hints != null && result.hints.length > 0) || provider.onDidChangeInlayHints != null) {
                        data.push({list: result != null ? result : InlayHintsFragments._emptyInlayHintList, provider: provider});
                    }
                    return null;
                }));
            }
        }

        return Promise.all(promises).thenPromise(_ -> {
            if (token.isCancellationRequested || model.isDisposed()) {
                return Promise.reject(new CancellationError());
            }
            return Promise.resolve(new InlayHintsFragments(ranges, data, model));
        });
    }

    var _disposed = false;
    final _lists:Array<InlayHintList> = [];

    public final items:Array<InlayHintItem>;
    public final ranges:Array<Range>;
    /**
     * The providers that gave hints (Monaco's `Set`, in insertion order).
     */
    public final provider:Array<InlayHintsProvider>;

    function new(ranges:Array<Range>, data:Array<{list:InlayHintList, provider:InlayHintsProvider}>, model:ITextModel) {
        this.ranges = ranges;
        this.provider = [];
        final items:Array<InlayHintItem> = [];
        for (entry in data) {
            final list = entry.list;
            final provider = entry.provider;
            this._lists.push(list);
            if (this.provider.indexOf(provider) == -1) {
                this.provider.push(provider);
            }

            for (hint in list.hints) {
                // compute the range to which the item should be attached to
                final position = model.validatePosition(hint.position);
                var direction = 'before';

                final wordRange = InlayHintsFragments._getRangeAtPosition(model, position);
                var range:Range;

                if (wordRange.getStartPosition().isBefore(position)) {
                    range = Range.fromPositions(wordRange.getStartPosition(), position);
                    direction = 'after';
                } else {
                    range = Range.fromPositions(position, wordRange.getEndPosition());
                    direction = 'before';
                }

                items.push(new InlayHintItem(hint, new InlayHintAnchor(range, direction), provider));
            }
        }
        // a stable sort, like JavaScript's
        haxe.ds.ArraySort.sort(items, (a, b) -> Position.compare(Position.lift(a.hint.position), Position.lift(b.hint.position)));
        this.items = items;
    }

    public function dispose():Void {
        if (_disposed) {
            return;
        }
        _disposed = true;
        for (list in _lists) {
            final dispose = list.dispose;
            if (dispose != null) {
                dispose();
            }
        }
    }

    static function _getRangeAtPosition(model:ITextModel, position:Position):Range {
        final line = position.lineNumber;
        final word = model.getWordAtPosition(position);
        if (word != null) {
            // always prefer the word range
            return new Range(line, word.startColumn, line, word.endColumn);
        }

        model.tokenization.tokenizeIfCheap(line);
        final tokens = model.tokenization.getLineTokens(line);
        final offset = position.column - 1;
        final idx = tokens.findTokenIndexAtOffset(offset);

        var start = tokens.getStartOffset(idx);
        var end = tokens.getEndOffset(idx);

        if (end - start == 1) {
            // single character token, when at its end try leading/trailing token instead
            if (start == offset && idx > 1) {
                // leading token
                start = tokens.getStartOffset(idx - 1);
                end = tokens.getEndOffset(idx - 1);
            } else if (end == offset && idx < tokens.getCount() - 1) {
                // trailing token
                start = tokens.getStartOffset(idx + 1);
                end = tokens.getEndOffset(idx + 1);
            }
        }

        return new Range(line, start + 1, line, end + 1);
    }

}

/**
 * Module functions of inlayHints.ts.
 */
class InlayHints {

    /**
     * Monaco's `asCommandLink`: a `command:` link running `command` (its
     * arguments as JSON in the query).
     */
    public static function asCommandLink(command:Command):String {
        return Uri.from({
            scheme: 'command',
            path: command.id,
            query: command.arguments != null ? StringTools.urlEncode(haxe.Json.stringify(command.arguments)) : null
        }).toString();
    }

}
