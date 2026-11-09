// Ported from vscode src/vs/editor/contrib/semanticTokens/common/getSemanticTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.semanticTokens.common;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.JsValues;
import cityscape.base.common.Promise;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.DocumentRangeSemanticTokensProvider;
import cityscape.common.Languages.DocumentSemanticTokensProvider;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensEdits;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import haxe.extern.EitherType;

typedef SemanticTokensOrEdits = EitherType<SemanticTokens, SemanticTokensEdits>;

class DocumentSemanticTokensResult {

    public final provider:DocumentSemanticTokensProvider;
    public final tokens:Null<SemanticTokensOrEdits>;
    public final error:Any;

    public function new(provider:DocumentSemanticTokensProvider, tokens:Null<SemanticTokensOrEdits>, error:Any) {
        this.provider = provider;
        this.tokens = tokens;
        this.error = error;
    }

}

class DocumentRangeSemanticTokensResult {

    public final provider:DocumentRangeSemanticTokensProvider;
    public final tokens:Null<SemanticTokens>;

    public function new(provider:DocumentRangeSemanticTokensProvider, tokens:Null<SemanticTokens>) {
        this.provider = provider;
        this.tokens = tokens;
    }

}

/**
 * The module functions of getSemanticTokens.ts. The commands of its API
 * bridge (`_provideDocumentSemanticTokensLegend`,
 * `_provideDocumentSemanticTokens`, `_provideDocumentRangeSemanticTokensLegend`,
 * `_provideDocumentRangeSemanticTokens`) are not ported: they return
 * results to the extension host, and Cityscape's command handlers return
 * nothing.
 */
class GetSemanticTokens {

    public static function isSemanticTokens(v:Null<SemanticTokensOrEdits>):Bool {
        return v != null && JsValues.truthy(JsValues.field(v, 'data'));
    }

    public static function isSemanticTokensEdits(v:Null<SemanticTokensOrEdits>):Bool {
        return v != null && JsValues.isArray(JsValues.field(v, 'edits'));
    }

    public static function hasDocumentSemanticTokensProvider(registry:LanguageFeatureRegistry<DocumentSemanticTokensProvider>, model:ITextModel):Bool {
        return registry.has(model);
    }

    static function getDocumentSemanticTokensProviders(registry:LanguageFeatureRegistry<DocumentSemanticTokensProvider>, model:ITextModel):Array<DocumentSemanticTokensProvider> {
        final groups = registry.orderedGroups(model);
        return (groups.length > 0 ? groups[0] : []);
    }

    /**
     * Asks the providers of the highest group at the same time; resolves
     * with the first result with tokens (or rejects with the first error
     * before it), else the first result, else null.
     */
    public static function getDocumentSemanticTokens(registry:LanguageFeatureRegistry<DocumentSemanticTokensProvider>, model:ITextModel, lastProvider:Null<DocumentSemanticTokensProvider>, lastResultId:Null<String>, token:CancellationToken):Promise<DocumentSemanticTokensResult> {
        final providers = getDocumentSemanticTokensProviders(registry, model);

        // Get tokens from all providers at the same time.
        final requests:Array<Promise<DocumentSemanticTokensResult>> = [for (provider in providers) {
            final request = new Promise<SemanticTokensOrEdits>((resolve, reject) -> {
                provider.provideDocumentSemanticTokens(model, (provider == lastProvider ? lastResultId : null), token, resolve);
            });
            request.then(result -> {
                if (result == null || (!isSemanticTokens(result) && !isSemanticTokensEdits(result))) {
                    result = null;
                }
                return new DocumentSemanticTokensResult(provider, result, null);
            }, err -> new DocumentSemanticTokensResult(provider, null, err));
        }];

        return Promise.all(requests).then(results -> {
            // Try to return the first result with actual tokens or
            // the first result which threw an error (!!)
            for (result in results) {
                if (JsValues.truthy(result.error)) {
                    throw result.error;
                }
                if (result.tokens != null) {
                    return result;
                }
            }

            // Return the first result, even if it doesn't have tokens
            if (results.length > 0) {
                return results[0];
            }

            return null;
        });
    }

    public static function hasDocumentRangeSemanticTokensProvider(providers:LanguageFeatureRegistry<DocumentRangeSemanticTokensProvider>, model:ITextModel):Bool {
        return providers.has(model);
    }

    static function getDocumentRangeSemanticTokensProviders(providers:LanguageFeatureRegistry<DocumentRangeSemanticTokensProvider>, model:ITextModel):Array<DocumentRangeSemanticTokensProvider> {
        final groups = providers.orderedGroups(model);
        return (groups.length > 0 ? groups[0] : []);
    }

    public static function getDocumentRangeSemanticTokens(registry:LanguageFeatureRegistry<DocumentRangeSemanticTokensProvider>, model:ITextModel, range:Range, token:CancellationToken):Promise<DocumentRangeSemanticTokensResult> {
        final providers = getDocumentRangeSemanticTokensProviders(registry, model);

        // Get tokens from all providers at the same time.
        final requests:Array<Promise<DocumentRangeSemanticTokensResult>> = [for (provider in providers) {
            final request = new Promise<SemanticTokens>((resolve, reject) -> {
                provider.provideDocumentRangeSemanticTokens(model, range, token, resolve);
            });
            request.then(result -> {
                if (result == null || !isSemanticTokens(result)) {
                    result = null;
                }
                return new DocumentRangeSemanticTokensResult(provider, result);
            }, err -> {
                Errors.onUnexpectedExternalError(err);
                return new DocumentRangeSemanticTokensResult(provider, null);
            });
        }];

        return Promise.all(requests).then(results -> {
            // Try to return the first result with actual tokens
            for (result in results) {
                if (result.tokens != null) {
                    return result;
                }
            }

            // Return the first result, even if it doesn't have tokens
            if (results.length > 0) {
                return results[0];
            }

            return null;
        });
    }

}
