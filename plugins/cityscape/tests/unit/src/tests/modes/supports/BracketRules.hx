// Ported from vscode src/vs/editor/test/common/modes/supports/bracketRules.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.common.languages.LanguageConfiguration.CharacterPair;

/**
 * Test data of bracketRules.ts.
 */
class BracketRules {

    public static final standardBracketRules:Array<CharacterPair> = [
        ['{', '}'],
        ['[', ']'],
        ['(', ')']
    ];

    public static final rubyBracketRules = standardBracketRules;

    public static final cppBracketRules = standardBracketRules;

    public static final goBracketRules = standardBracketRules;

    public static final phpBracketRules = standardBracketRules;

    public static final vbBracketRules = standardBracketRules;

    public static final luaBracketRules = standardBracketRules;

    public static final htmlBracketRules:Array<CharacterPair> = [
        ['<!--', '-->'],
        ['{', '}'],
        ['(', ')']
    ];

    public static final typescriptBracketRules:Array<CharacterPair> = [
        ["${", '}'],
        ['{', '}'],
        ['[', ']'],
        ['(', ')']
    ];

    public static final latexBracketRules:Array<CharacterPair> = [
        ['{', '}'],
        ['[', ']'],
        ['(', ')'],
        ['[', ')'],
        ['(', ']'],
        ['\\left(', '\\right)'],
        ['\\left(', '\\right.'],
        ['\\left.', '\\right)'],
        ['\\left[', '\\right]'],
        ['\\left[', '\\right.'],
        ['\\left.', '\\right]'],
        ['\\left\\{', '\\right\\}'],
        ['\\left\\{', '\\right.'],
        ['\\left.', '\\right\\}'],
        ['\\left<', '\\right>'],
        ['\\bigl(', '\\bigr)'],
        ['\\bigl[', '\\bigr]'],
        ['\\bigl\\{', '\\bigr\\}'],
        ['\\Bigl(', '\\Bigr)'],
        ['\\Bigl[', '\\Bigr]'],
        ['\\Bigl\\{', '\\Bigr\\}'],
        ['\\biggl(', '\\biggr)'],
        ['\\biggl[', '\\biggr]'],
        ['\\biggl\\{', '\\biggr\\}'],
        ['\\Biggl(', '\\Biggr)'],
        ['\\Biggl[', '\\Biggr]'],
        ['\\Biggl\\{', '\\Biggr\\}'],
        ['\\langle', '\\rangle'],
        ['\\lvert', '\\rvert'],
        ['\\lVert', '\\rVert'],
        ['\\left|', '\\right|'],
        ['\\left\\vert', '\\right\\vert'],
        ['\\left\\|', '\\right\\|'],
        ['\\left\\Vert', '\\right\\Vert'],
        ['\\left\\langle', '\\right\\rangle'],
        ['\\left\\lvert', '\\right\\rvert'],
        ['\\left\\lVert', '\\right\\rVert'],
        ['\\bigl\\langle', '\\bigr\\rangle'],
        ['\\bigl|', '\\bigr|'],
        ['\\bigl\\vert', '\\bigr\\vert'],
        ['\\bigl\\lvert', '\\bigr\\rvert'],
        ['\\bigl\\|', '\\bigr\\|'],
        ['\\bigl\\lVert', '\\bigr\\rVert'],
        ['\\bigl\\Vert', '\\bigr\\Vert'],
        ['\\Bigl\\langle', '\\Bigr\\rangle'],
        ['\\Bigl|', '\\Bigr|'],
        ['\\Bigl\\lvert', '\\Bigr\\rvert'],
        ['\\Bigl\\vert', '\\Bigr\\vert'],
        ['\\Bigl\\|', '\\Bigr\\|'],
        ['\\Bigl\\lVert', '\\Bigr\\rVert'],
        ['\\Bigl\\Vert', '\\Bigr\\Vert'],
        ['\\biggl\\langle', '\\biggr\\rangle'],
        ['\\biggl|', '\\biggr|'],
        ['\\biggl\\lvert', '\\biggr\\rvert'],
        ['\\biggl\\vert', '\\biggr\\vert'],
        ['\\biggl\\|', '\\biggr\\|'],
        ['\\biggl\\lVert', '\\biggr\\rVert'],
        ['\\biggl\\Vert', '\\biggr\\Vert'],
        ['\\Biggl\\langle', '\\Biggr\\rangle'],
        ['\\Biggl|', '\\Biggr|'],
        ['\\Biggl\\lvert', '\\Biggr\\rvert'],
        ['\\Biggl\\vert', '\\Biggr\\vert'],
        ['\\Biggl\\|', '\\Biggr\\|'],
        ['\\Biggl\\lVert', '\\Biggr\\rVert'],
        ['\\Biggl\\Vert', '\\Biggr\\Vert']
    ];

}
