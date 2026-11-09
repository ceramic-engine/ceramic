// Ported from vscode src/vs/editor/contrib/parameterHints/browser/provideSignatureHelp.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.parameterHints.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.Promise;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.SignatureHelpContext;
import cityscape.common.Languages.SignatureHelpProvider;
import cityscape.common.Languages.SignatureHelpResult;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.platform.contextkey.common.ContextKey.RawContextKey;

/**
 * The context keys of the parameter hints (Monaco's `Context` of
 * provideSignatureHelp.ts).
 */
class ParameterHintsContext {

    public static final Visible = new RawContextKey<Bool>('parameterHintsVisible', false);
    public static final MultipleSignatures = new RawContextKey<Bool>('parameterHintsMultipleSignatures', false);

}

/**
 * Module functions of provideSignatureHelp.ts. The
 * `_executeSignatureHelpProvider` command is not ported (no `_execute...`
 * command of the language features is: there is no `ITextModelService`).
 */
class ProvideSignatureHelp {

    /**
     * The signature help of the first provider (in the order of the
     * registry) that gives one; null when none does. The providers are
     * asked one after the other, each once the previous one answered.
     */
    public static function provideSignatureHelp(registry:LanguageFeatureRegistry<SignatureHelpProvider>, model:ITextModel, position:Position, context:SignatureHelpContext, token:CancellationToken):Promise<SignatureHelpResult> {

        final supports = registry.ordered(model);

        return provideFrom(supports, 0, model, position, context, token);
    }

    static function provideFrom(supports:Array<SignatureHelpProvider>, index:Int, model:ITextModel, position:Position, context:SignatureHelpContext, token:CancellationToken):Promise<SignatureHelpResult> {
        if (index >= supports.length) {
            return Promise.resolve(null);
        }
        final support = supports[index];
        return Promise.fromCallback((done:(value:Null<SignatureHelpResult>) -> Void) -> {
            try {
                support.provideSignatureHelp(model, position, token, context, done);
            }
            catch (err:Dynamic) {
                Errors.onUnexpectedExternalError(err);
                done(null);
            }
        }).thenPromise(result -> {
            if (result != null) {
                return Promise.resolve(result);
            }
            return provideFrom(supports, index + 1, model, position, context, token);
        });
    }

}
