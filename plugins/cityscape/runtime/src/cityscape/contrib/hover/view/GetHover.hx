// Ported from vscode src/vs/editor/contrib/hover/browser/getHover.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.Promise;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.Hover;
import cityscape.common.Languages.HoverProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

class HoverProviderResult {
    public final provider:HoverProvider;
    public final hover:Hover;
    public final ordinal:Int;

    public function new(provider:HoverProvider, hover:Hover, ordinal:Int) {
        this.provider = provider;
        this.hover = hover;
        this.ordinal = ordinal;
    }
}

/**
 * Module functions of getHover.ts.
 */
class GetHover {

    /**
     * Does not throw or return a rejected promise (resolves null instead).
     */
    static function executeProvider(provider:HoverProvider, ordinal:Int, model:ITextModel, position:Position, token:CancellationToken):Promise<HoverProviderResult> {
        return Promise.fromCallback(done -> {
            try {
                provider.provideHover(model, position, token, null, done);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
                done(null);
            }
        }).then(result -> {
            if (result == null || !isValid(result)) {
                return null;
            }
            return new HoverProviderResult(provider, result, ordinal);
        });
    }

    /**
     * The results of the hover providers of the model as they come (Monaco's
     * `getHoverProviderResultsAsAsyncIterable`): `onItem` gets each result
     * in the order the providers answer, `onDone` is called once all
     * answered.
     */
    public static function getHoverProviderResults(registry:LanguageFeatureRegistry<HoverProvider>, model:ITextModel, position:Position, token:CancellationToken, onItem:(result:HoverProviderResult) -> Void, onDone:() -> Void, recursive:Bool = false):Void {
        final providers = registry.ordered(model, recursive);
        final promises = [for (index in 0...providers.length) executeProvider(providers[index], index, model, position, token)];
        for (p in promises) {
            p.done(item -> {
                if (item != null) {
                    onItem(item);
                }
            });
        }
        Promise.allSettled(promises).done(_ -> onDone());
    }

    /**
     * Monaco's `getHoversPromise`: all the hovers.
     */
    public static function getHoversPromise(registry:LanguageFeatureRegistry<HoverProvider>, model:ITextModel, position:Position, token:CancellationToken, recursive:Bool = false):Promise<Array<Hover>> {
        return new Promise<Array<Hover>>((resolve, reject) -> {
            final result:Array<Hover> = [];
            getHoverProviderResults(registry, model, position, token, item -> result.push(item.hover), () -> resolve(result), recursive);
        });
    }

    static function isValid(result:Hover):Bool {
        final hasRange = result.range != null;
        final hasHtmlContent = result.contents != null && result.contents.length > 0;
        return hasRange && hasHtmlContent;
    }

}
