// Ported from vscode src/vs/editor/contrib/codelens/browser/codelens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codelens.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.Promise;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.CodeLens;
import cityscape.common.Languages.CodeLensList;
import cityscape.common.Languages.CodeLensProvider;
import cityscape.common.Model.ITextModel;

/**
 * A code lens and its provider.
 */
typedef CodeLensItem = {
    var symbol:CodeLens;
    var provider:CodeLensProvider;
}

/**
 * The code lenses of a model (all the providers).
 *
 * The module function `getCodeLensModel` of codelens.ts is
 * `CodeLensModel.getCodeLensModel`. The `_executeCodeLensProvider` command
 * is not ported (no `_execute*` command is).
 */
class CodeLensModel {

    public var lenses:Array<CodeLensItem> = [];

    final _lists:Array<CodeLensList> = [];
    var _isDisposed = false;

    public function new() {}

    public function dispose():Void {
        if (_isDisposed) {
            return;
        }
        _isDisposed = true;
        for (list in _lists) {
            final dispose = list.dispose;
            if (dispose != null) {
                dispose();
            }
        }
        _lists.resize(0);
    }

    public var isDisposed(get, never):Bool;
    inline function get_isDisposed():Bool {
        return _isDisposed;
    }

    public function add(list:CodeLensList, provider:CodeLensProvider):Void {
        if (_isDisposed) {
            // DisposableStore.add after dispose: the list is disposed at once
            final dispose = list.dispose;
            if (dispose != null) {
                dispose();
            }
        } else {
            _lists.push(list);
        }
        for (symbol in list.lenses) {
            this.lenses.push({symbol: symbol, provider: provider});
        }
    }

    /**
     * The code lenses of the providers of `model`, sorted by line, provider
     * rank and column: settles once all the providers answered (at once when
     * they answer at once).
     */
    public static function getCodeLensModel(registry:LanguageFeatureRegistry<CodeLensProvider>, model:ITextModel, token:CancellationToken):Promise<CodeLensModel> {

        final provider = registry.ordered(model);
        final providerRanks:Array<CodeLensProvider> = [];
        final result = new CodeLensModel();

        final promises:Array<Promise<Any>> = [];
        for (i in 0...provider.length) {
            final p = provider[i];
            providerRanks.push(p);
            promises.push(Promise.fromCallback((done:(value:Null<CodeLensList>) -> Void) -> {
                try {
                    p.provideCodeLenses(model, token, done);
                }
                catch (err:Dynamic) {
                    Errors.onUnexpectedExternalError(err);
                    done(null);
                }
            }).then(list -> {
                if (list != null) {
                    result.add(list, p);
                }
                return null;
            }));
        }

        return Promise.all(promises).then(_ -> {
            haxe.ds.ArraySort.sort(result.lenses, (a, b) -> {
                // sort by lineNumber, provider-rank, and column
                final rankA = providerRanks.indexOf(a.provider);
                final rankB = providerRanks.indexOf(b.provider);
                if (a.symbol.range.startLineNumber < b.symbol.range.startLineNumber) {
                    return -1;
                } else if (a.symbol.range.startLineNumber > b.symbol.range.startLineNumber) {
                    return 1;
                } else if (rankA < rankB) {
                    return -1;
                } else if (rankA > rankB) {
                    return 1;
                } else if (a.symbol.range.startColumn < b.symbol.range.startColumn) {
                    return -1;
                } else if (a.symbol.range.startColumn > b.symbol.range.startColumn) {
                    return 1;
                } else {
                    return 0;
                }
            });
            return result;
        });
    }

}
