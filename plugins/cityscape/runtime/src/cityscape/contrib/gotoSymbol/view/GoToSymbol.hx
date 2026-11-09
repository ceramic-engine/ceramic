// Ported from vscode src/vs/editor/contrib/gotoSymbol/browser/goToSymbol.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoSymbol.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Promise;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.DeclarationProvider;
import cityscape.common.Languages.DefinitionProvider;
import cityscape.common.Languages.ImplementationProvider;
import cityscape.common.Languages.Location;
import cityscape.common.Languages.LocationLink;
import cityscape.common.Languages.ReferenceProvider;
import cityscape.common.Languages.TypeDefinitionProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Module functions of goToSymbol.ts: the locations the providers of a
 * registry give for a position. The providers answer through their
 * `resolve` callback (at once or later); a provider that throws is
 * reported to `Errors.onUnexpectedExternalError` and counts as no result.
 *
 * Monaco's API commands (`_executeDefinitionProvider`...) are not
 * registered; their sorting and deduplication is `sortedAndDeduped`.
 */
class GoToSymbol {

    /**
     * Monaco's `Schemas.walkThroughSnippet`, `Schemas.vscodeChatCodeBlock`
     * and `Schemas.vscodeChatCodeCompareBlock` (network.ts).
     */
    static inline final walkThroughSnippet = 'walkThroughSnippet';
    static inline final vscodeChatCodeBlock = 'vscode-chat-code-block';
    static inline final vscodeChatCodeCompareBlock = 'vscode-chat-code-compare-block';

    static function shouldIncludeLocationLink(sourceModel:ITextModel, loc:LocationLink):Bool {
        // Always allow the location if the request comes from a document with the same scheme.
        if (loc.uri.scheme == sourceModel.uri.scheme) {
            return true;
        }

        // Otherwise filter out locations from internal schemes
        // (`matchesSomeScheme`: the scheme compared ignoring case)
        final scheme = loc.uri.scheme.toLowerCase();
        if (scheme == walkThroughSnippet.toLowerCase() || scheme == vscodeChatCodeBlock || scheme == vscodeChatCodeCompareBlock) {
            return false;
        }

        return true;
    }

    static function getLocationLinks<T>(
        model:ITextModel,
        position:Position,
        registry:LanguageFeatureRegistry<T>,
        recursive:Bool,
        provide:(provider:T, model:ITextModel, position:Position) -> Promise<Array<LocationLink>>
    ):Promise<Array<LocationLink>> {
        final provider = registry.ordered(model, recursive);

        // get results
        final promises:Array<Promise<Array<LocationLink>>> = [for (p in provider) {
            Promise.resolve(null).thenPromise(_ -> provide(p, model, position)).then(links -> links, err -> {
                Errors.onUnexpectedExternalError(err);
                return null;
            });
        }];

        return Promise.all(promises).then(values -> {
            final result:Array<LocationLink> = [];
            for (links in values) {
                if (links != null) {
                    for (loc in links) {
                        if (loc != null && shouldIncludeLocationLink(model, loc)) {
                            result.push(loc);
                        }
                    }
                }
            }
            return result;
        });
    }

    public static function getDefinitionsAtPosition(registry:LanguageFeatureRegistry<DefinitionProvider>, model:ITextModel, position:Position, recursive:Bool, token:CancellationToken):Promise<Array<LocationLink>> {
        return getLocationLinks(model, position, registry, recursive, (provider, model, position) -> {
            return Promise.fromCallback(done -> provider.provideDefinition(model, position, token, done));
        });
    }

    public static function getDeclarationsAtPosition(registry:LanguageFeatureRegistry<DeclarationProvider>, model:ITextModel, position:Position, recursive:Bool, token:CancellationToken):Promise<Array<LocationLink>> {
        return getLocationLinks(model, position, registry, recursive, (provider, model, position) -> {
            return Promise.fromCallback(done -> provider.provideDeclaration(model, position, token, done));
        });
    }

    public static function getImplementationsAtPosition(registry:LanguageFeatureRegistry<ImplementationProvider>, model:ITextModel, position:Position, recursive:Bool, token:CancellationToken):Promise<Array<LocationLink>> {
        return getLocationLinks(model, position, registry, recursive, (provider, model, position) -> {
            return Promise.fromCallback(done -> provider.provideImplementation(model, position, token, done));
        });
    }

    public static function getTypeDefinitionsAtPosition(registry:LanguageFeatureRegistry<TypeDefinitionProvider>, model:ITextModel, position:Position, recursive:Bool, token:CancellationToken):Promise<Array<LocationLink>> {
        return getLocationLinks(model, position, registry, recursive, (provider, model, position) -> {
            return Promise.fromCallback(done -> provider.provideTypeDefinition(model, position, token, done));
        });
    }

    /**
     * The references (declaration included). With `compact`, a result of
     * two references becomes the result without the declaration when that
     * one has a single reference.
     */
    public static function getReferencesAtPosition(registry:LanguageFeatureRegistry<ReferenceProvider>, model:ITextModel, position:Position, compact:Bool, recursive:Bool, token:CancellationToken):Promise<Array<LocationLink>> {
        return getLocationLinks(model, position, registry, recursive, (provider, model, position) -> {
            return Promise.fromCallback(done -> provider.provideReferences(model, position, {includeDeclaration: true}, token, done)).thenPromise(references -> {
                final result = filterReferences(model, references);
                if (!compact || result == null || result.length != 2) {
                    return Promise.resolve(result);
                }
                return Promise.fromCallback(done -> provider.provideReferences(model, position, {includeDeclaration: false}, token, done)).then(references -> {
                    final resultWithoutDeclaration = filterReferences(model, references);
                    if (resultWithoutDeclaration != null && resultWithoutDeclaration.length == 1) {
                        return resultWithoutDeclaration;
                    }
                    return result;
                });
            });
        });
    }

    /**
     * `?.filter(ref => shouldIncludeLocationLink(model, ref))` on the
     * locations of a reference provider (a `Location` is a `LocationLink`
     * without the optional ranges).
     */
    static function filterReferences(model:ITextModel, references:Null<Array<Location>>):Null<Array<LocationLink>> {
        if (references == null) {
            return null;
        }
        final result:Array<LocationLink> = [];
        for (ref in references) {
            final link:LocationLink = cast ref;
            if (shouldIncludeLocationLink(model, link)) {
                result.push(link);
            }
        }
        return result;
    }

    // -- API commands ----

    /**
     * The links sorted by uri and range, without duplicates (Monaco's
     * `_sortedAndDeduped`, used by its `_execute...Provider` commands).
     */
    public static function sortedAndDeduped(links:Promise<Array<LocationLink>>):Promise<Array<LocationLink>> {
        return links.then(rawLinks -> {
            final model = new ReferencesModel(rawLinks != null ? rawLinks : [], '');
            final modelLinks = [for (ref in model.references) ref.link];
            model.dispose();
            return modelLinks;
        });
    }

}
