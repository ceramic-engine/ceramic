// Ported from vscode src/vs/editor/test/common/modes/supports/autoClosingPairsRules.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.common.languages.LanguageConfiguration;

/**
 * Test data of autoClosingPairsRules.ts.
 */
class AutoClosingPairsRules {

    public static final javascriptAutoClosingPairsRules:Array<IAutoClosingPairConditional> = [
        { open: '{', close: '}' },
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '\'', close: '\'', notIn: ['string', 'comment'] },
        { open: '"', close: '"', notIn: ['string'] },
        { open: '`', close: '`', notIn: ['string', 'comment'] },
        { open: '/**', close: ' */', notIn: ['string'] }
    ];

    public static final latexAutoClosingPairsRules:Array<IAutoClosingPair> = [
        { open: '\\left(', close: '\\right)' },
        { open: '\\left[', close: '\\right]' },
        { open: '\\left\\{', close: '\\right\\}' },
        { open: '\\bigl(', close: '\\bigr)' },
        { open: '\\bigl[', close: '\\bigr]' },
        { open: '\\bigl\\{', close: '\\bigr\\}' },
        { open: '\\Bigl(', close: '\\Bigr)' },
        { open: '\\Bigl[', close: '\\Bigr]' },
        { open: '\\Bigl\\{', close: '\\Bigr\\}' },
        { open: '\\biggl(', close: '\\biggr)' },
        { open: '\\biggl[', close: '\\biggr]' },
        { open: '\\biggl\\{', close: '\\biggr\\}' },
        { open: '\\Biggl(', close: '\\Biggr)' },
        { open: '\\Biggl[', close: '\\Biggr]' },
        { open: '\\Biggl\\{', close: '\\Biggr\\}' },
        { open: '\\(', close: '\\)' },
        { open: '\\[', close: '\\]' },
        { open: '\\{', close: '\\}' },
        { open: '{', close: '}' },
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '`', close: '\'' },
    ];

}
