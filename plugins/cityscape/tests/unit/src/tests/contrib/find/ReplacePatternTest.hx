// Ported from vscode src/vs/editor/contrib/find/test/browser/replacePattern.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.find;

import cityscape.base.common.RegExp;
import cityscape.base.common.Search;
import cityscape.contrib.find.view.ReplacePattern;
import testing.TestCase;

/**
 * suite('Replace Pattern test').
 *
 * `assert.deepStrictEqual(actual, new ReplacePattern(pieces))` compares the
 * state of the patterns (`assertPatternEquals`). The expected values of
 * 'replace has JavaScript semantics' are JavaScript's `String.replace`
 * results: computed by the native `String.replace` on the JavaScript
 * target (and compared with the written values), written out elsewhere.
 */
class ReplacePatternTest extends TestCase {

    static function execMatches(search:RegExp, target:String):Null<Array<String>> {
        final m = search.exec(target);
        if (m == null) {
            return null;
        }
        return [for (i in 0...m.length) m[i]];
    }

    function assertPatternEquals(expected:ReplacePattern, actual:ReplacePattern, message:String, ?pos:haxe.PosInfos):Void {
        assertEquals(@:privateAccess expected._staticValue, @:privateAccess actual._staticValue, message, pos);
        final e:Null<Array<ReplacePiece>> = @:privateAccess expected._pieces;
        final a:Null<Array<ReplacePiece>> = @:privateAccess actual._pieces;
        assertEquals(e == null, a == null, message, pos);
        if (e != null && a != null) {
            assertEquals(e.length, a.length, message, pos);
            for (i in 0...Std.int(Math.min(e.length, a.length))) {
                assertEquals(e[i].staticValue, a[i].staticValue, message, pos);
                assertEquals(e[i].matchIndex, a[i].matchIndex, message, pos);
                assertDeepEquals(e[i].caseOps, a[i].caseOps, message, pos);
            }
        }
    }

    function doTestParse(input:String, expectedPieces:Array<ReplacePiece>, ?pos:haxe.PosInfos):Void {
        final actual = ReplacePatternParser.parseReplaceString(input);
        final expected = new ReplacePattern(expectedPieces);
        assertPatternEquals(expected, actual, 'Parsing ' + input, pos);
    }

    function assertReplace(target:String, search:RegExp, replaceString:String, expected:String, ?pos:haxe.PosInfos):Void {
        final replacePattern = ReplacePatternParser.parseReplaceString(replaceString);
        final m = execMatches(search, target);
        final actual = replacePattern.buildReplaceString(m);

        assertEquals(expected, actual, '${target}.replace(${search}, ${replaceString}) === ${expected}', pos);
    }

    static inline function staticValue(value:String):ReplacePiece {
        return ReplacePiece.staticValueStatic(value);
    }

    static inline function matchIndex(index:Int):ReplacePiece {
        return ReplacePiece.matchIndexStatic(index);
    }

    static inline function caseOps(index:Int, ops:Array<String>):ReplacePiece {
        return ReplacePiece.caseOpsStatic(index, ops);
    }

    function testParseReplaceString() {
        // no backslash => no treatment
        doTestParse("hello", [staticValue("hello")]);

        // \t => TAB
        doTestParse("\\thello", [staticValue("\thello")]);
        doTestParse("h\\tello", [staticValue("h\tello")]);
        doTestParse("hello\\t", [staticValue("hello\t")]);

        // \n => LF
        doTestParse("\\nhello", [staticValue("\nhello")]);

        // \\t => \t
        doTestParse("\\\\thello", [staticValue("\\thello")]);
        doTestParse("h\\\\tello", [staticValue("h\\tello")]);
        doTestParse("hello\\\\t", [staticValue("hello\\t")]);

        // \\\t => \TAB
        doTestParse("\\\\\\thello", [staticValue("\\\thello")]);

        // \\\\t => \\t
        doTestParse("\\\\\\\\thello", [staticValue("\\\\thello")]);

        // \ at the end => no treatment
        doTestParse("hello\\", [staticValue("hello\\")]);

        // \ with unknown char => no treatment
        doTestParse("hello\\x", [staticValue("hello\\x")]);

        // \ with back reference => no treatment
        doTestParse("hello\\0", [staticValue("hello\\0")]);

        doTestParse("hello$&", [staticValue("hello"), matchIndex(0)]);
        doTestParse("hello$0", [staticValue("hello"), matchIndex(0)]);
        doTestParse("hello$02", [staticValue("hello"), matchIndex(0), staticValue("2")]);
        doTestParse("hello$1", [staticValue("hello"), matchIndex(1)]);
        doTestParse("hello$2", [staticValue("hello"), matchIndex(2)]);
        doTestParse("hello$9", [staticValue("hello"), matchIndex(9)]);
        doTestParse("$9hello", [matchIndex(9), staticValue("hello")]);

        doTestParse("hello$12", [staticValue("hello"), matchIndex(12)]);
        doTestParse("hello$99", [staticValue("hello"), matchIndex(99)]);
        doTestParse("hello$99a", [staticValue("hello"), matchIndex(99), staticValue("a")]);
        doTestParse("hello$1a", [staticValue("hello"), matchIndex(1), staticValue("a")]);
        doTestParse("hello$100", [staticValue("hello"), matchIndex(10), staticValue("0")]);
        doTestParse("hello$100a", [staticValue("hello"), matchIndex(10), staticValue("0a")]);
        doTestParse("hello$10a0", [staticValue("hello"), matchIndex(10), staticValue("a0")]);
        doTestParse("hello$$", [staticValue("hello$")]);
        doTestParse("hello$$0", [staticValue("hello$0")]);

        doTestParse("hello$`", [staticValue("hello$`")]);
        doTestParse("hello$'", [staticValue("hello$'")]);
    }

    function testParseReplaceStringWithCaseModifiers() {
        // \U, \u => uppercase  \L, \l => lowercase  \E => cancel

        doTestParse("hello\\U$1", [staticValue("hello"), caseOps(1, ["U"])]);
        assertReplace("func privateFunc(", new RegExp("func (\\w+)\\("), "func \\U$1(", "func PRIVATEFUNC(");

        doTestParse("hello\\u$1", [staticValue("hello"), caseOps(1, ["u"])]);
        assertReplace("func privateFunc(", new RegExp("func (\\w+)\\("), "func \\u$1(", "func PrivateFunc(");

        doTestParse("hello\\L$1", [staticValue("hello"), caseOps(1, ["L"])]);
        assertReplace("func privateFunc(", new RegExp("func (\\w+)\\("), "func \\L$1(", "func privatefunc(");

        doTestParse("hello\\l$1", [staticValue("hello"), caseOps(1, ["l"])]);
        assertReplace("func PrivateFunc(", new RegExp("func (\\w+)\\("), "func \\l$1(", "func privateFunc(");

        doTestParse("hello$1\\u\\u\\U$4goodbye", [staticValue("hello"), matchIndex(1), caseOps(4, ["u", "u", "U"]), staticValue("goodbye")]);
        assertReplace("hellogooDbye", new RegExp("hello(\\w+)"), "hello\\u\\u\\l\\l\\U$1", "helloGOodBYE");
    }

    /**
     * `target.replace(search, replaceString)` in JavaScript: the native
     * result on the JavaScript target, compared with `expected` (the value
     * JavaScript gives, written out for the other targets).
     */
    function jsReplace(target:String, search:String, flags:String, replaceString:String, expected:String, ?pos:haxe.PosInfos):String {
        #if js
        final native:String = js.Syntax.code("{0}.replace(new RegExp({1}, {2}), {3})", target, search, flags, replaceString);
        assertEquals(expected, native, 'JavaScript replace', pos);
        return native;
        #else
        return expected;
        #end
    }

    function doTestJSReplaceSemantics(target:String, search:RegExp, replaceString:String, expected:String, ?pos:haxe.PosInfos):Void {
        final replacePattern = ReplacePatternParser.parseReplaceString(replaceString);
        final m = execMatches(search, target);
        final actual = replacePattern.buildReplaceString(m);

        assertEquals(expected, actual, '${target}.replace(${search}, ${replaceString})', pos);
    }

    function testReplaceHasJavaScriptSemantics() {
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "hello", jsReplace("hi", "hi", "", "hello", "hello"));
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "\\t", jsReplace("hi", "hi", "", "\t", "\t"));
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "\\n", jsReplace("hi", "hi", "", "\n", "\n"));
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "\\\\t", jsReplace("hi", "hi", "", "\\t", "\\t"));
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "\\\\n", jsReplace("hi", "hi", "", "\\n", "\\n"));

        // implicit capture group 0
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "hello$&", jsReplace("hi", "hi", "", "hello$&", "hellohi"));
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "hello$0", jsReplace("hi", "hi", "", "hello$&", "hellohi"));
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "hello$&1", jsReplace("hi", "hi", "", "hello$&1", "hellohi1"));
        doTestJSReplaceSemantics("hi", new RegExp("hi"), "hello$01", jsReplace("hi", "hi", "", "hello$&1", "hellohi1"));

        // capture groups have funny semantics in replace strings
        // the replace string interprets $nn as a captured group only if it exists in the search regex
        doTestJSReplaceSemantics("hi", new RegExp("(hi)"), "hello$10", jsReplace("hi", "(hi)", "", "hello$10", "hellohi0"));
        doTestJSReplaceSemantics("hi", new RegExp("(hi)()()()()()()()()()"), "hello$10", jsReplace("hi", "(hi)()()()()()()()()()", "", "hello$10", "hello"));
        doTestJSReplaceSemantics("hi", new RegExp("(hi)"), "hello$100", jsReplace("hi", "(hi)", "", "hello$100", "hellohi00"));
        doTestJSReplaceSemantics("hi", new RegExp("(hi)"), "hello$20", jsReplace("hi", "(hi)", "", "hello$20", "hello$20"));
    }

    function testGetReplaceStringIfGivenTextIsACompleteMatch() {
        assertReplace("bla", new RegExp("bla"), "hello", "hello");
        assertReplace("bla", new RegExp("(bla)"), "hello", "hello");
        assertReplace("bla", new RegExp("(bla)"), "hello$0", "hellobla");

        final searchRegex = new RegExp("let\\s+(\\w+)\\s*=\\s*require\\s*\\(\\s*['\"]([\\w\\.\\-/]+)\\s*['\"]\\s*\\)\\s*");
        assertReplace("let fs = require('fs')", searchRegex, "import * as $1 from '$2';", "import * as fs from 'fs';");
        assertReplace("let something = require('fs')", searchRegex, "import * as $1 from '$2';", "import * as something from 'fs';");
        assertReplace("let something = require('fs')", searchRegex, "import * as $1 from '$1';", "import * as something from 'something';");
        assertReplace("let something = require('fs')", searchRegex, "import * as $2 from '$1';", "import * as fs from 'something';");
        assertReplace("let something = require('fs')", searchRegex, "import * as $0 from '$0';", "import * as let something = require('fs') from 'let something = require('fs')';");
        assertReplace("let fs = require('fs')", searchRegex, "import * as $1 from '$2';", "import * as fs from 'fs';");
        assertReplace("for ()", new RegExp("for(.*)"), "cat$1", "cat ()");

        // issue #18111
        assertReplace("HRESULT OnAmbientPropertyChange(DISPID   dispid);", new RegExp("\\b\\s{3}\\b"), " ", " ");
    }

    function testGetReplaceStringIfMatchIsSubStringOfTheText() {
        assertReplace("this is a bla text", new RegExp("bla"), "hello", "hello");
        assertReplace("this is a bla text", new RegExp("this(?=.*bla)"), "that", "that");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "$1at", "that");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "$1e", "the");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "$1ere", "there");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "$1", "th");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "ma$1", "math");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "ma$1s", "maths");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "$0", "this");
        assertReplace("this is a bla text", new RegExp("(th)is(?=.*bla)"), "$0$1", "thisth");
        assertReplace("this is a bla text", new RegExp("bla(?=\\stext$)"), "foo", "foo");
        assertReplace("this is a bla text", new RegExp("b(la)(?=\\stext$)"), "f$1", "fla");
        assertReplace("this is a bla text", new RegExp("b(la)(?=\\stext$)"), "f$0", "fbla");
        assertReplace("this is a bla text", new RegExp("b(la)(?=\\stext$)"), "$0ah", "blaah");
    }

    function testIssue19740FindAndReplaceCaptureGroupBackreferenceInsertsUndefinedInsteadOfEmptyString() {
        final replacePattern = ReplacePatternParser.parseReplaceString("a{$1}");
        final matches = execMatches(new RegExp("a(z)?"), "abcd");
        final actual = replacePattern.buildReplaceString(matches);
        assertEquals("a{}", actual);
    }

    function testBuildReplaceStringWithCasePreservedTest() {
        function assertReplace(target:Array<String>, replaceString:String, expected:String, ?pos:haxe.PosInfos):Void {
            var actual:String = '';
            actual = Search.buildReplaceStringWithCasePreserved(target, replaceString);
            assertEquals(expected, actual, null, pos);
        }

        assertReplace(["abc"], "Def", "def");
        assertReplace(["Abc"], "Def", "Def");
        assertReplace(["ABC"], "Def", "DEF");
        assertReplace(["abc", "Abc"], "Def", "def");
        assertReplace(["Abc", "abc"], "Def", "Def");
        assertReplace(["ABC", "abc"], "Def", "DEF");
        assertReplace(["aBc", "abc"], "Def", "def");
        assertReplace(["AbC"], "Def", "Def");
        assertReplace(["aBC"], "Def", "def");
        assertReplace(["aBc"], "DeF", "deF");
        assertReplace(["Foo-Bar"], "newfoo-newbar", "Newfoo-Newbar");
        assertReplace(["Foo-Bar-Abc"], "newfoo-newbar-newabc", "Newfoo-Newbar-Newabc");
        assertReplace(["Foo-Bar-abc"], "newfoo-newbar", "Newfoo-newbar");
        assertReplace(["foo-Bar"], "newfoo-newbar", "newfoo-Newbar");
        assertReplace(["foo-BAR"], "newfoo-newbar", "newfoo-NEWBAR");
        assertReplace(["foO-BAR"], "NewFoo-NewBar", "newFoo-NEWBAR");
        assertReplace(["Foo_Bar"], "newfoo_newbar", "Newfoo_Newbar");
        assertReplace(["Foo_Bar_Abc"], "newfoo_newbar_newabc", "Newfoo_Newbar_Newabc");
        assertReplace(["Foo_Bar_abc"], "newfoo_newbar", "Newfoo_newbar");
        assertReplace(["Foo_Bar-abc"], "newfoo_newbar-abc", "Newfoo_newbar-abc");
        assertReplace(["foo_Bar"], "newfoo_newbar", "newfoo_Newbar");
        assertReplace(["Foo_BAR"], "newfoo_newbar", "Newfoo_NEWBAR");
    }

    function testPreserveCase() {
        function assertReplace(target:Array<String>, replaceString:String, expected:String, ?pos:haxe.PosInfos):Void {
            final replacePattern = ReplacePatternParser.parseReplaceString(replaceString);
            final actual = replacePattern.buildReplaceString(target, true);
            assertEquals(expected, actual, null, pos);
        }

        assertReplace(["abc"], "Def", "def");
        assertReplace(["Abc"], "Def", "Def");
        assertReplace(["ABC"], "Def", "DEF");
        assertReplace(["abc", "Abc"], "Def", "def");
        assertReplace(["Abc", "abc"], "Def", "Def");
        assertReplace(["ABC", "abc"], "Def", "DEF");
        assertReplace(["aBc", "abc"], "Def", "def");
        assertReplace(["AbC"], "Def", "Def");
        assertReplace(["aBC"], "Def", "def");
        assertReplace(["aBc"], "DeF", "deF");
        assertReplace(["Foo-Bar"], "newfoo-newbar", "Newfoo-Newbar");
        assertReplace(["Foo-Bar-Abc"], "newfoo-newbar-newabc", "Newfoo-Newbar-Newabc");
        assertReplace(["Foo-Bar-abc"], "newfoo-newbar", "Newfoo-newbar");
        assertReplace(["foo-Bar"], "newfoo-newbar", "newfoo-Newbar");
        assertReplace(["foo-BAR"], "newfoo-newbar", "newfoo-NEWBAR");
        assertReplace(["foO-BAR"], "NewFoo-NewBar", "newFoo-NEWBAR");
        assertReplace(["Foo_Bar"], "newfoo_newbar", "Newfoo_Newbar");
        assertReplace(["Foo_Bar_Abc"], "newfoo_newbar_newabc", "Newfoo_Newbar_Newabc");
        assertReplace(["Foo_Bar_abc"], "newfoo_newbar", "Newfoo_newbar");
        assertReplace(["Foo_Bar-abc"], "newfoo_newbar-abc", "Newfoo_newbar-abc");
        assertReplace(["foo_Bar"], "newfoo_newbar", "newfoo_Newbar");
        assertReplace(["foo_BAR"], "newfoo_newbar", "newfoo_NEWBAR");
    }

}
