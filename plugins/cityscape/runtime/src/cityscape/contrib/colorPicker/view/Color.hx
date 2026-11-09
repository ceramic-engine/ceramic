// Ported from vscode src/vs/editor/contrib/colorPicker/browser/color.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Promise;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.DocumentColorProvider;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.Languages.IColorPresentation;
import cityscape.common.Model.ITextModel;

/**
 * A color of a document and the provider that gave it.
 */
typedef IColorData = {
    var colorInfo:IColorInformation;
    var provider:DocumentColorProvider;
}

/**
 * Monaco's `DataCollector<T>`: asks a provider, adds its results, and
 * calls back with whether the provider gave an array.
 */
private interface DataCollector<T> {
    function compute(provider:DocumentColorProvider, model:ITextModel, token:CancellationToken, result:Array<T>, done:(valid:Bool) -> Void):Void;
}

private class ColorDataCollector implements DataCollector<IColorData> {
    public function new() {}

    public function compute(provider:DocumentColorProvider, model:ITextModel, token:CancellationToken, colors:Array<IColorData>, done:(valid:Bool) -> Void):Void {
        provider.provideDocumentColors(model, token, documentColors -> {
            if (documentColors != null) {
                for (colorInfo in documentColors) {
                    colors.push({colorInfo: colorInfo, provider: provider});
                }
            }
            done(documentColors != null);
        });
    }
}

private class ColorPresentationsCollector implements DataCollector<IColorPresentation> {
    final colorInfo:IColorInformation;

    public function new(colorInfo:IColorInformation) {
        this.colorInfo = colorInfo;
    }

    public function compute(provider:DocumentColorProvider, model:ITextModel, _token:CancellationToken, colors:Array<IColorPresentation>, done:(valid:Bool) -> Void):Void {
        provider.provideColorPresentations(model, this.colorInfo, CancellationTokens.None, documentColors -> {
            if (documentColors != null) {
                for (c in documentColors) {
                    colors.push(c);
                }
            }
            done(documentColors != null);
        });
    }
}

/**
 * The module functions of color.ts. The `_executeDocumentColorProvider`
 * and `_executeColorPresentationProvider` commands are not ported:
 * Cityscape's commands return nothing (call `getColors` and
 * `findColorPresentations`).
 */
class ColorUtils {

    /**
     * The colors of the model: those of the providers, else (when none gave
     * an array) those of the default provider when
     * `isDefaultColorDecoratorsEnabled`.
     */
    public static function getColors(colorProviderRegistry:LanguageFeatureRegistry<DocumentColorProvider>, model:ITextModel, token:CancellationToken, isDefaultColorDecoratorsEnabled:Bool = true):Promise<Array<IColorData>> {
        return _findColorData(new ColorDataCollector(), colorProviderRegistry, model, token, isDefaultColorDecoratorsEnabled);
    }

    /**
     * The presentations of a color by one provider (null when it gives none).
     */
    public static function getColorPresentations(model:ITextModel, colorInfo:IColorInformation, provider:DocumentColorProvider, token:CancellationToken):Promise<Array<IColorPresentation>> {
        return Promise.fromCallback((done:(value:Null<Array<IColorPresentation>>) -> Void) -> provider.provideColorPresentations(model, colorInfo, token, done));
    }

    /**
     * The presentations of a color by all the providers (the
     * `_executeColorPresentationProvider` command, with the model itself).
     */
    public static function findColorPresentations(colorProviderRegistry:LanguageFeatureRegistry<DocumentColorProvider>, model:ITextModel, colorInfo:IColorInformation, isDefaultColorDecoratorsEnabled:Bool):Promise<Array<IColorPresentation>> {
        return _findColorData(new ColorPresentationsCollector(colorInfo), colorProviderRegistry, model, CancellationTokens.None, isDefaultColorDecoratorsEnabled);
    }

    static function _findColorData<T>(collector:DataCollector<T>, colorProviderRegistry:LanguageFeatureRegistry<DocumentColorProvider>, model:ITextModel, token:CancellationToken, isDefaultColorDecoratorsEnabled:Bool):Promise<Array<T>> {
        return Promise.fromCallback((resolve:(value:Null<Array<T>>) -> Void) -> {
            var validDocumentColorProviderFound = false;
            var defaultProvider:Null<DefaultDocumentColorProvider> = null;
            final colorData:Array<T> = [];
            final documentColorProviders = colorProviderRegistry.ordered(model);

            function finish():Void {
                if (validDocumentColorProviderFound) {
                    resolve(colorData);
                    return;
                }
                if (defaultProvider != null && isDefaultColorDecoratorsEnabled) {
                    collector.compute(defaultProvider, model, token, colorData, _ -> resolve(colorData));
                    return;
                }
                resolve([]);
            }

            // for (let i = documentColorProviders.length - 1; i >= 0; i--), one
            // provider after the other (Monaco awaits each)
            function next(i:Int):Void {
                if (i < 0) {
                    finish();
                    return;
                }
                final provider = documentColorProviders[i];
                final asDefault = Std.downcast(provider, DefaultDocumentColorProvider);
                if (asDefault != null) {
                    defaultProvider = asDefault;
                    next(i - 1);
                }
                else {
                    var called = false;
                    try {
                        collector.compute(provider, model, token, colorData, valid -> {
                            if (called) {
                                return;
                            }
                            called = true;
                            if (valid) {
                                validDocumentColorProviderFound = true;
                            }
                            next(i - 1);
                        });
                    }
                    catch (e:Dynamic) {
                        Errors.onUnexpectedExternalError(e);
                        if (!called) {
                            called = true;
                            next(i - 1);
                        }
                    }
                }
            }
            next(documentColorProviders.length - 1);
        });
    }

}
