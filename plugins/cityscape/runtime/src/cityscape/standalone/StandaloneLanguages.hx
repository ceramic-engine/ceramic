// Ported from vscode src/vs/editor/standalone/browser/standaloneLanguages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.standalone;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.LanguageSelector;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.platform.markers.common.Markers;

/**
 * The metadata of a code action provider (Monaco's
 * `CodeActionProviderMetadata`).
 */
typedef CodeActionProviderMetadata = {
    /**
     * List of code action kinds that a `CodeActionProvider` may return.
     *
     * This list is used to determine if a given `CodeActionProvider` should be invoked or not.
     * To avoid unnecessary computation, every `CodeActionProvider` should list use `providedCodeActionKinds`. The
     * list of kinds may either be generic, such as `["quickfix", "refactor", "source"]`, or list out every kind provided,
     * such as `["quickfix.removeLine", "source.fixAll" ...]`.
     */
    @:optional var providedCodeActionKinds:Null<Array<String>>;

    @:optional var documentation:Null<Array<CodeActionProviderDocumentation>>;
}

/**
 * The provider registration functions of `monaco.languages`, on a
 * `Cityscape` context (`context.registerHoverProvider(...)` forwards here).
 */
class StandaloneLanguages {

    /**
     * Register a hover provider (used by e.g. editor hover). A hover without
     * range gets the range of the word at the position (or the position).
     */
    public static function registerHoverProvider(context:Cityscape, languageSelector:LanguageSelector, provider:HoverProvider):IDisposable {
        return context.languageFeaturesService.hoverProvider.register(languageSelector, new StandaloneHoverProvider(provider));
    }

    /**
     * Register a code action provider (used by e.g. quick fix). The context
     * given to the provider has the markers of the model touching the range.
     */
    public static function registerCodeActionProvider(context:Cityscape, languageSelector:LanguageSelector, provider:CodeActionProvider, ?metadata:CodeActionProviderMetadata):IDisposable {
        return context.languageFeaturesService.codeActionProvider.register(languageSelector, new StandaloneCodeActionProvider(context, provider, metadata));
    }

    /**
     * The marker data of a marker (Monaco passes the marker itself).
     */
    public static function toMarkerData(m:IMarker):IMarkerData {
        final data:IMarkerData = {
            severity: m.severity,
            message: m.message,
            startLineNumber: m.startLineNumber,
            startColumn: m.startColumn,
            endLineNumber: m.endLineNumber,
            endColumn: m.endColumn
        };
        if (m.code != null) {
            data.code = m.code;
        }
        if (m.source != null) {
            data.source = m.source;
        }
        if (m.modelVersionId != null) {
            data.modelVersionId = m.modelVersionId;
        }
        if (m.relatedInformation != null) {
            data.relatedInformation = m.relatedInformation;
        }
        if (m.tags != null) {
            data.tags = m.tags;
        }
        return data;
    }

}

private class StandaloneHoverProvider implements HoverProvider {

    final provider:HoverProvider;

    public function new(provider:HoverProvider) {
        this.provider = provider;
    }

    public function provideHover(model:ITextModel, position:Position, token:CancellationToken, context:Null<HoverContext>, resolve:(hover:Null<Hover>) -> Void):Void {
        final word = model.getWordAtPosition(position);
        provider.provideHover(model, position, token, context, value -> {
            if (value == null) {
                resolve(null);
                return;
            }
            if (value.range == null && word != null) {
                value.range = new Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn);
            }
            if (value.range == null) {
                value.range = new Range(position.lineNumber, position.column, position.lineNumber, position.column);
            }
            resolve(value);
        });
    }

}

private class StandaloneCodeActionProvider implements CodeActionProvider {

    final context:Cityscape;
    final provider:CodeActionProvider;

    public var displayName(default, null):Null<String>;
    public var resolveCodeAction(default, null):Null<(codeAction:CodeAction, token:CancellationToken, resolve:(codeAction:Null<CodeAction>) -> Void) -> Void>;
    public var providedCodeActionKinds(default, null):Null<Array<String>>;
    public var documentation(default, null):Null<Array<CodeActionProviderDocumentation>>;

    public function new(context:Cityscape, provider:CodeActionProvider, metadata:Null<CodeActionProviderMetadata>) {
        this.context = context;
        this.provider = provider;
        this.displayName = provider.displayName;
        this.providedCodeActionKinds = metadata != null && metadata.providedCodeActionKinds != null ? metadata.providedCodeActionKinds : provider.providedCodeActionKinds;
        this.documentation = metadata != null && metadata.documentation != null ? metadata.documentation : provider.documentation;
        this.resolveCodeAction = provider.resolveCodeAction;
    }

    public function provideCodeActions(model:ITextModel, range:Range, codeActionContext:CodeActionContext, token:CancellationToken, resolve:(list:Null<CodeActionList>) -> Void):Void {
        final markers = [for (m in context.markerService.read({resource: model.uri})) if (Range.areIntersectingOrTouching(cast {startLineNumber: m.startLineNumber, startColumn: m.startColumn, endLineNumber: m.endLineNumber, endColumn: m.endColumn}, range)) StandaloneLanguages.toMarkerData(m)];
        provider.provideCodeActions(model, range, {markers: markers, only: codeActionContext.only, trigger: codeActionContext.trigger}, token, resolve);
    }

}
