// Ported from vscode src/vs/editor/common/services/semanticTokensStyling.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.common.Languages.DocumentRangeSemanticTokensProvider;
import cityscape.common.Languages.DocumentSemanticTokensProvider;
import haxe.extern.EitherType;

/**
 * A document or a range semantic tokens provider (Monaco's
 * `DocumentTokensProvider`).
 */
typedef DocumentTokensProvider = EitherType<DocumentSemanticTokensProvider, DocumentRangeSemanticTokensProvider>;

/**
 * The styling of the semantic tokens of each provider in the current
 * theme (one service per `Cityscape` context).
 */
interface ISemanticTokensStylingService {

    function getStyling(provider:DocumentTokensProvider):SemanticTokensProviderStyling;

}
