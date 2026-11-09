// Ported from vscode src/vs/editor/contrib/snippet/test/browser/snippetParser.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.snippet;

// Classes of this module:
// - SnippetParserTest
//
// All the tests are ported. `assert.deepStrictEqual` on the result of
// `enclosingPlaceholders` compares the placeholders by identity (stricter
// than vscode's structural comparison); `Object.getPrototypeOf(m).constructor`
// is `Type.getClass(m)`; the `Set<Marker>` of #30407 is an array.

import cityscape.base.common.RegExp;
import cityscape.contrib.snippet.view.SnippetParser;
import testing.TestCase;

/**
 * suite('SnippetParser')
 */
class SnippetParserTest extends TestCase {

    function testScanner() {

        final scanner = new Scanner();
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text('abc');
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text('{{abc}}');
        assertEquals(TokenType.CurlyOpen, scanner.next().type);
        assertEquals(TokenType.CurlyOpen, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.CurlyClose, scanner.next().type);
        assertEquals(TokenType.CurlyClose, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text('abc() ');
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.Format, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text('abc 123');
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.Format, scanner.next().type);
        assertEquals(TokenType.Int, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text("$foo");
        assertEquals(TokenType.Dollar, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text("$foo_bar");
        assertEquals(TokenType.Dollar, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text("$foo-bar");
        assertEquals(TokenType.Dollar, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.Dash, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text("${foo}");
        assertEquals(TokenType.Dollar, scanner.next().type);
        assertEquals(TokenType.CurlyOpen, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.CurlyClose, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text("${1223:foo}");
        assertEquals(TokenType.Dollar, scanner.next().type);
        assertEquals(TokenType.CurlyOpen, scanner.next().type);
        assertEquals(TokenType.Int, scanner.next().type);
        assertEquals(TokenType.Colon, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.CurlyClose, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);

        scanner.text("\\${}");
        assertEquals(TokenType.Backslash, scanner.next().type);
        assertEquals(TokenType.Dollar, scanner.next().type);
        assertEquals(TokenType.CurlyOpen, scanner.next().type);
        assertEquals(TokenType.CurlyClose, scanner.next().type);

        scanner.text("${foo/regex/format/option}");
        assertEquals(TokenType.Dollar, scanner.next().type);
        assertEquals(TokenType.CurlyOpen, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.Forwardslash, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.Forwardslash, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.Forwardslash, scanner.next().type);
        assertEquals(TokenType.VariableName, scanner.next().type);
        assertEquals(TokenType.CurlyClose, scanner.next().type);
        assertEquals(TokenType.EOF, scanner.next().type);
    }

    function assertText(value:String, expected:String, ?pos:haxe.PosInfos):Void {
        final actual = SnippetParser.asInsertText(value);
        assertEquals(expected, actual, value, pos);
    }

    /**
     * `assertMarker(input: TextmateSnippet | Marker[] | string, ...ctors)`.
     */
    function assertMarker(input:Any, ...ctors:Class<Dynamic>):Void {
        var marker:Array<Marker>;
        if (Std.isOfType(input, TextmateSnippet)) {
            marker = (input : TextmateSnippet).children.copy();
        }
        else if (Std.isOfType(input, std.String)) {
            final p = new SnippetParser();
            marker = p.parse((input : std.String)).children;
        }
        else {
            marker = (input : Array<Marker>).copy();
        }
        final ctors = ctors.toArray();
        final label = Std.isOfType(input, std.String) ? (input : std.String) : 'markers';
        while (marker.length > 0) {
            final m = marker.pop();
            final ctor = ctors.pop();
            assertTrue(ctor != null && Std.isOfType(m, ctor), label + ': ' + Type.getClassName(Type.getClass(m)) + ' is not a ' + (ctor != null ? Type.getClassName(ctor) : 'undefined'));
        }
        assertEquals(marker.length, ctors.length, label);
        assertEquals(0, marker.length, label);
    }

    function assertTextAndMarker(value:String, escaped:String, ...ctors:Class<Dynamic>):Void {
        assertText(value, escaped);
        assertMarker(value, ...ctors);
    }

    function assertEscaped(value:String, expected:String, ?pos:haxe.PosInfos):Void {
        final actual = SnippetParser.escape(value);
        assertEquals(expected, actual, value, pos);
    }

    function testParserEscaped() {
        // test('Parser, escaped')
        assertEscaped("foo$0", "foo\\$0");
        assertEscaped("foo\\$0", "foo\\\\\\$0");
        assertEscaped("f$1oo$0", "f\\$1oo\\$0");
        assertEscaped("${1:foo}$0", "\\${1:foo\\}\\$0");
        assertEscaped("$", "\\$");
    }

    function testParserText() {
        // test('Parser, text')
        assertText("$", "$");
        assertText("\\\\$", "\\$");
        assertText('{', '{');
        assertText('\\}', '}');
        assertText('\\abc', '\\abc');
        assertText("foo${f:\\}}bar", 'foo}bar');
        assertText('\\{', '\\{');
        assertText("I need \\\\\\$", "I need \\$");
        assertText('\\', '\\');
        assertText('\\{{', '\\{{');
        assertText('{{', '{{');
        assertText('{{dd', '{{dd');
        assertText('}}', '}}');
        assertText('ff}}', 'ff}}');

        assertText('farboo', 'farboo');
        assertText('far{{}}boo', 'far{{}}boo');
        assertText('far{{123}}boo', 'far{{123}}boo');
        assertText('far\\{{123}}boo', 'far\\{{123}}boo');
        assertText('far{{id:bern}}boo', 'far{{id:bern}}boo');
        assertText('far{{id:bern {{basel}}}}boo', 'far{{id:bern {{basel}}}}boo');
        assertText('far{{id:bern {{id:basel}}}}boo', 'far{{id:bern {{id:basel}}}}boo');
        assertText('far{{id:bern {{id2:basel}}}}boo', 'far{{id:bern {{id2:basel}}}}boo');
    }

    function testParserTMText() {
        // test('Parser, TM text')
        assertTextAndMarker("foo${1:bar}}", 'foobar}', Text, Placeholder, Text);
        assertTextAndMarker("foo${1:bar}${2:foo}}", 'foobarfoo}', Text, Placeholder, Placeholder, Text);

        assertTextAndMarker("foo${1:bar\\}${2:foo}}", 'foobar}foo', Text, Placeholder);

        final placeholder = new SnippetParser().parse("foo${1:bar\\}${2:foo}}").children[1];
        final children = placeholder.children;

        assertEquals(1.0, (cast placeholder : Placeholder).index);
        assertTrue(Std.isOfType(children[0], Text));
        assertEquals('bar}', children[0].toString());
        assertTrue(Std.isOfType(children[1], Placeholder));
        assertEquals('foo', children[1].toString());
    }

    function testParserPlaceholder() {
        // test('Parser, placeholder')
        assertTextAndMarker('farboo', 'farboo', Text);
        assertTextAndMarker('far{{}}boo', 'far{{}}boo', Text);
        assertTextAndMarker('far{{123}}boo', 'far{{123}}boo', Text);
        assertTextAndMarker('far\\{{123}}boo', 'far\\{{123}}boo', Text);
    }

    function testParserLiteralCode() {
        // test('Parser, literal code')
        assertTextAndMarker('far`123`boo', 'far`123`boo', Text);
        assertTextAndMarker('far\\`123\\`boo', 'far\\`123\\`boo', Text);
    }

    function testParserVariablesTabstop() {
        // test('Parser, variables/tabstop')
        assertTextAndMarker("$far-boo", '-boo', Variable, Text);
        assertTextAndMarker("\\$far-boo", "$far-boo", Text);
        assertTextAndMarker("far$farboo", 'far', Text, Variable);
        assertTextAndMarker("far${farboo}", 'far', Text, Variable);
        assertTextAndMarker("$123", '', Placeholder);
        assertTextAndMarker("$farboo", '', Variable);
        assertTextAndMarker("$far12boo", '', Variable);
        assertTextAndMarker("000_${far}_000", '000__000', Text, Variable, Text);
        assertTextAndMarker("FFF_${TM_SELECTED_TEXT}_FFF$0", 'FFF__FFF', Text, Variable, Text, Placeholder);
    }

    function testParserVariablesPlaceholderWithDefaults() {
        // test('Parser, variables/placeholder with defaults')
        assertTextAndMarker("${name:value}", 'value', Variable);
        assertTextAndMarker("${1:value}", 'value', Placeholder);
        assertTextAndMarker("${1:bar${2:foo}bar}", 'barfoobar', Placeholder);

        assertTextAndMarker("${name:value", "${name:value", Text);
        assertTextAndMarker("${1:bar${2:foobar}", "${1:barfoobar", Text, Placeholder);
    }

    function testParserVariableTransforms() {
        // test('Parser, variable transforms')
        assertTextAndMarker("${foo///}", '', Variable);
        assertTextAndMarker("${foo/regex/format/gmi}", '', Variable);
        assertTextAndMarker("${foo/([A-Z][a-z])/format/}", '', Variable);

        // invalid regex
        assertTextAndMarker("${foo/([A-Z][a-z])/format/GMI}", "${foo/([A-Z][a-z])/format/GMI}", Text);
        assertTextAndMarker("${foo/([A-Z][a-z])/format/funky}", "${foo/([A-Z][a-z])/format/funky}", Text);
        assertTextAndMarker("${foo/([A-Z][a-z]/format/}", "${foo/([A-Z][a-z]/format/}", Text);

        // tricky regex
        assertTextAndMarker("${foo/m\\/atch/$1/i}", '', Variable);
        assertMarker("${foo/regex/format/options}", Text); // '\/' is '/' in a JavaScript string

        // incomplete
        assertTextAndMarker("${foo///", "${foo///", Text);
        assertTextAndMarker("${foo/regex/format/options", "${foo/regex/format/options", Text);

        // format string
        assertMarker("${foo/.*/${0:fooo}/i}", Variable);
        assertMarker("${foo/.*/${1}/i}", Variable);
        assertMarker("${foo/.*/$1/i}", Variable);
        assertMarker("${foo/.*/This-$1-encloses/i}", Variable);
        assertMarker("${foo/.*/complex${1:else}/i}", Variable);
        assertMarker("${foo/.*/complex${1:-else}/i}", Variable);
        assertMarker("${foo/.*/complex${1:+if}/i}", Variable);
        assertMarker("${foo/.*/complex${1:?if:else}/i}", Variable);
        assertMarker("${foo/.*/complex${1:/upcase}/i}", Variable);
    }

    function testParserPlaceholderTransforms() {
        // test('Parser, placeholder transforms')
        assertTextAndMarker("${1///}", '', Placeholder);
        assertTextAndMarker("${1/regex/format/gmi}", '', Placeholder);
        assertTextAndMarker("${1/([A-Z][a-z])/format/}", '', Placeholder);

        // tricky regex
        assertTextAndMarker("${1/m\\/atch/$1/i}", '', Placeholder);
        assertMarker("${1/regex/format/options}", Text); // '\/' is '/' in a JavaScript string

        // incomplete
        assertTextAndMarker("${1///", "${1///", Text);
        assertTextAndMarker("${1/regex/format/options", "${1/regex/format/options", Text);
    }

    function testNoWayToEscapeForwardSlashInSnippetRegex36715() {
        // test('No way to escape forward slash in snippet regex #36715')
        assertMarker("${TM_DIRECTORY/src\\//$1/}", Variable);
    }

    function testNoWayToEscapeForwardSlashInSnippetFormatSection37562() {
        // test('No way to escape forward slash in snippet format section #37562')
        assertMarker("${TM_SELECTED_TEXT/a/\\/$1/g}", Variable);
        assertMarker("${TM_SELECTED_TEXT/a/in\\/$1ner/g}", Variable);
        assertMarker("${TM_SELECTED_TEXT/a/end\\//g}", Variable);
    }

    function testParserPlaceholderWithChoice() {
        // test('Parser, placeholder with choice')
        assertTextAndMarker("${1|one,two,three|}", 'one', Placeholder);
        assertTextAndMarker("${1|one|}", 'one', Placeholder);
        assertTextAndMarker("${1|one1,two2|}", 'one1', Placeholder);
        assertTextAndMarker("${1|one1\\,two2|}", 'one1,two2', Placeholder);
        assertTextAndMarker("${1|one1\\|two2|}", 'one1|two2', Placeholder);
        assertTextAndMarker("${1|one1\\atwo2|}", 'one1\\atwo2', Placeholder);
        assertTextAndMarker("${1|one,two,three,|}", "${1|one,two,three,|}", Text);
        assertTextAndMarker("${1|one,", "${1|one,", Text);

        final snippet = new SnippetParser().parse("${1|one,two,three|}");
        final expected:Array<(m:Marker) -> Bool> = [
            m -> Std.isOfType(m, Placeholder),
            m -> {
                if (!Std.isOfType(m, Choice)) {
                    return false;
                }
                final choice:Choice = cast m;
                if (choice.options.length != 3) {
                    return false;
                }
                for (x in choice.options) {
                    if (!Std.isOfType(x, Text)) {
                        return false;
                    }
                }
                return true;
            },
        ];
        snippet.walk(marker -> {
            final check = expected.shift();
            assertTrue(check != null && check(marker));
            return true;
        });
    }

    function testSnippetChoicesUnableToEscapeCommaAndPipe31521() {
        // test('Snippet choices: unable to escape comma and pipe, #31521')
        assertTextAndMarker("console.log(${1|not\\, not, five, 5, 1   23|});", 'console.log(not, not);', Text, Placeholder, Text);
    }

    function testMarkerToTextmateString() {
        // test('Marker, toTextmateString()')

        function assertTextsnippetString(input:String, expected:String, ?pos:haxe.PosInfos):Void {
            final snippet = new SnippetParser().parse(input);
            final actual = snippet.toTextmateString();
            assertEquals(expected, actual, input, pos);
        }

        assertTextsnippetString("$1", "$1");
        assertTextsnippetString("\\$1", "\\$1");
        assertTextsnippetString("console.log(${1|not\\, not, five, 5, 1   23|});", "console.log(${1|not\\, not, five, 5, 1   23|});");
        assertTextsnippetString("console.log(${1|not\\, not, \\| five, 5, 1   23|});", "console.log(${1|not\\, not, \\| five, 5, 1   23|});");
        assertTextsnippetString("${1|cho\\,ices,wi\\|th,esc\\\\aping,chall\\\\\\,enges|}", "${1|cho\\,ices,wi\\|th,esc\\\\aping,chall\\\\\\,enges|}");
        assertTextsnippetString('this is text', 'this is text');
        assertTextsnippetString("this ${1:is ${2:nested with $var}}", "this ${1:is ${2:nested with ${var}}}");
        assertTextsnippetString("this ${1:is ${2:nested with $var}}}", "this ${1:is ${2:nested with ${var}}}\\}");
    }

    function testMarkerToTextmateStringIdentity() {
        // test('Marker, toTextmateString() <-> identity')

        function assertIdent(input:String):Void {
            // full loop: (1) parse input, (2) generate textmate string, (3) parse, (4) ensure both trees are equal
            final snippet = new SnippetParser().parse(input);
            final input2 = snippet.toTextmateString();
            final snippet2 = new SnippetParser().parse(input2);

            function checkCheckChildren(marker1:Marker, marker2:Marker):Void {
                assertTrue(Std.isOfType(marker1, Type.getClass(marker2)), input);
                assertTrue(Std.isOfType(marker2, Type.getClass(marker1)), input);

                assertEquals(marker1.children.length, marker2.children.length, input);
                assertEquals(marker1.toString(), marker2.toString(), input);

                for (i in 0...marker1.children.length) {
                    checkCheckChildren(marker1.children[i], marker2.children[i]);
                }
            }

            checkCheckChildren(snippet, snippet2);
        }

        assertIdent("$1");
        assertIdent("\\$1");
        assertIdent("console.log(${1|not\\, not, five, 5, 1   23|});");
        assertIdent("console.log(${1|not\\, not, \\| five, 5, 1   23|});");
        assertIdent('this is text');
        assertIdent("this ${1:is ${2:nested with $var}}");
        assertIdent("this ${1:is ${2:nested with $var}}}");
        assertIdent("this ${1:is ${2:nested with $var}} and repeating $1");
    }

    function testParserChoiseMarker() {
        // test('Parser, choise marker')
        final placeholders = new SnippetParser().parse("${1|one,two,three|}").placeholders;

        assertEquals(1, placeholders.length);
        assertTrue(Std.isOfType(placeholders[0].choice, Choice));
        assertTrue(Std.isOfType(placeholders[0].children[0], Choice));
        assertEquals(3, (cast placeholders[0].children[0] : Choice).options.length);

        assertText("${1|one,two,three|}", 'one');
        assertText("\\${1|one,two,three|}", "${1|one,two,three|}");
        assertText("${1\\|one,two,three|}", "${1\\|one,two,three|}");
        assertText("${1||}", "${1||}");
    }

    function testBackslashCharacterEscapeInChoiceTabstopDoesntWork58494() {
        // test('Backslash character escape in choice tabstop doesn\'t work #58494')
        final placeholders = new SnippetParser().parse("${1|\\,,},$,\\|,\\\\|}").placeholders;
        assertEquals(1, placeholders.length);
        assertTrue(Std.isOfType(placeholders[0].choice, Choice));
    }

    function testParserOnlyTextmate() {
        // test('Parser, only textmate')
        final p = new SnippetParser();
        assertMarker(p.parse('far{{}}boo'), Text);
        assertMarker(p.parse('far{{123}}boo'), Text);
        assertMarker(p.parse('far\\{{123}}boo'), Text);

        assertMarker(p.parse("far$0boo"), Text, Placeholder, Text);
        assertMarker(p.parse("far${123}boo"), Text, Placeholder, Text);
        assertMarker(p.parse("far\\${123}boo"), Text);
    }

    function testParserRealWorld() {
        // test('Parser, real world')
        var marker = new SnippetParser().parse("console.warn(${1: $TM_SELECTED_TEXT })").children;

        assertEquals('console.warn(', marker[0].toString());
        assertTrue(Std.isOfType(marker[1], Placeholder));
        assertEquals(')', marker[2].toString());

        final placeholder:Placeholder = cast marker[1];
        assertEquals(1.0, placeholder.index);
        assertEquals(3, placeholder.children.length);
        assertTrue(Std.isOfType(placeholder.children[0], Text));
        assertTrue(Std.isOfType(placeholder.children[1], Variable));
        assertTrue(Std.isOfType(placeholder.children[2], Text));
        assertEquals(' ', placeholder.children[0].toString());
        assertEquals('', placeholder.children[1].toString());
        assertEquals(' ', placeholder.children[2].toString());

        final nestedVariable:Variable = cast placeholder.children[1];
        assertEquals('TM_SELECTED_TEXT', nestedVariable.name);
        assertEquals(0, nestedVariable.children.length);

        marker = new SnippetParser().parse("$TM_SELECTED_TEXT").children;
        assertEquals(1, marker.length);
        assertTrue(Std.isOfType(marker[0], Variable));
    }

    function testParserTransformExample() {
        // test('Parser, transform example')
        final children = new SnippetParser().parse("${1:name} : ${2:type}${3/\\s:=(.*)/${1:+ :=}${1}/};\n$0").children;

        //${1:name}
        assertTrue(Std.isOfType(children[0], Placeholder));
        assertEquals(1, children[0].children.length);
        assertEquals('name', children[0].children[0].toString());
        assertEquals(null, (cast children[0] : Placeholder).transform);

        // :
        assertTrue(Std.isOfType(children[1], Text));
        assertEquals(' : ', children[1].toString());

        //${2:type}
        assertTrue(Std.isOfType(children[2], Placeholder));
        assertEquals(1, children[2].children.length);
        assertEquals('type', children[2].children[0].toString());

        //${3/\\s:=(.*)/${1:+ :=}${1}/}
        assertTrue(Std.isOfType(children[3], Placeholder));
        assertEquals(0, children[3].children.length);
        assertNotEquals(null, (cast children[3] : Placeholder).transform);
        final transform = (cast children[3] : Placeholder).transform;
        assertDeepEquals(new RegExp('\\s:=(.*)'), transform.regexp);
        assertEquals(2, transform.children.length);
        assertTrue(Std.isOfType(transform.children[0], FormatString));
        assertEquals(1, (cast transform.children[0] : FormatString).index);
        assertEquals(' :=', (cast transform.children[0] : FormatString).ifValue);
        assertTrue(Std.isOfType(transform.children[1], FormatString));
        assertEquals(1, (cast transform.children[1] : FormatString).index);
        assertTrue(Std.isOfType(children[4], Text));
        assertEquals(';\n', children[4].toString());
    }

    // TODO @jrieken making this strictEqul causes circular json conversion errors
    function testParserDefaultPlaceholderValues() {
        // test('Parser, default placeholder values')
        assertMarker("errorContext: `${1:err}`, error: $1", Text, Placeholder, Text, Placeholder);

        final children = new SnippetParser().parse("errorContext: `${1:err}`, error:$1").children;
        final p1:Placeholder = cast children[1];
        final p2:Placeholder = cast children[3];

        assertEquals(1.0, p1.index);
        assertEquals(1, p1.children.length);
        assertEquals('err', p1.children[0].toString());

        assertEquals(1.0, p2.index);
        assertEquals(1, p2.children.length);
        assertEquals('err', p2.children[0].toString());
    }

    // TODO @jrieken making this strictEqul causes circular json conversion errors
    function testParserDefaultPlaceholderValuesAndOneTransform() {
        // test('Parser, default placeholder values and one transform')
        assertMarker("errorContext: `${1:err}`, error: ${1/err/ok/}", Text, Placeholder, Text, Placeholder);

        final children = new SnippetParser().parse("errorContext: `${1:err}`, error:${1/err/ok/}").children;
        final p3:Placeholder = cast children[1];
        final p4:Placeholder = cast children[3];

        assertEquals(1.0, p3.index);
        assertEquals(1, p3.children.length);
        assertEquals('err', p3.children[0].toString());
        assertEquals(null, p3.transform);

        assertEquals(1.0, p4.index);
        assertEquals(1, p4.children.length);
        assertEquals('err', p4.children[0].toString());
        assertNotEquals(null, p4.transform);
    }

    function testRepeatedSnippetPlaceholderShouldAlwaysInherit31040() {
        // test('Repeated snippet placeholder should always inherit, #31040')
        assertText("${1:foo}-abc-$1", 'foo-abc-foo');
        assertText("${1:foo}-abc-${1}", 'foo-abc-foo');
        assertText("${1:foo}-abc-${1:bar}", 'foo-abc-foo');
        assertText("${1}-abc-${1:foo}", 'foo-abc-foo');
    }

    function testBackspaceEsapceInTMOnly16212() {
        // test('backspace esapce in TM only, #16212')
        final actual = SnippetParser.asInsertText("Foo \\\\${abc}bar");
        assertEquals('Foo \\bar', actual);
    }

    function testColonAsVariablePlaceholderValue16717() {
        // test('colon as variable/placeholder value, #16717')
        var actual = SnippetParser.asInsertText("${TM_SELECTED_TEXT:foo:bar}");
        assertEquals('foo:bar', actual);

        actual = SnippetParser.asInsertText("${1:foo:bar}");
        assertEquals('foo:bar', actual);
    }

    function testIncompletePlaceholder() {
        // test('incomplete placeholder')
        assertTextAndMarker("${1:}", '', Placeholder);
    }

    function testMarkerLen() {
        // test('marker#len')

        function assertLen(template:String, lengths:Array<Int>, ?pos:haxe.PosInfos):Void {
            final snippet = new SnippetParser().parse(template, true);
            snippet.walk(m -> {
                final expected = lengths.shift();
                assertEquals(expected, m.len(), template, pos);
                return true;
            });
            assertEquals(0, lengths.length, template, pos);
        }

        assertLen("text$0", [4, 0]);
        assertLen("$1text$0", [0, 4, 0]);
        assertLen("te$1xt$0", [2, 0, 2, 0]);
        assertLen("errorContext: `${1:err}`, error: $0", [15, 0, 3, 10, 0]);
        assertLen("errorContext: `${1:err}`, error: $1$0", [15, 0, 3, 10, 0, 3, 0]);
        assertLen("$TM_SELECTED_TEXT$0", [0, 0]);
        assertLen("${TM_SELECTED_TEXT:def}$0", [0, 3, 0]);
    }

    function testParserParentNode() {
        // test('parser, parent node')
        var snippet = new SnippetParser().parse("This ${1:is ${2:nested}}$0", true);

        assertEquals(3, snippet.placeholders.length);
        var first = snippet.placeholders[0];
        final second = snippet.placeholders[1];
        assertEquals(1.0, first.index);
        assertEquals(2.0, second.index);
        assertTrue(second.parent == first);
        assertTrue(first.parent == snippet);

        snippet = new SnippetParser().parse("${VAR:default${1:value}}$0", true);
        assertEquals(2, snippet.placeholders.length);
        first = snippet.placeholders[0];
        assertEquals(1.0, first.index);

        assertTrue(Std.isOfType(snippet.children[0], Variable));
        assertTrue(first.parent == snippet.children[0]);
    }

    function testTextmateSnippetEnclosingPlaceholders() {
        // test('TextmateSnippet#enclosingPlaceholders')
        final snippet = new SnippetParser().parse("This ${1:is ${2:nested}}$0", true);
        final first = snippet.placeholders[0];
        final second = snippet.placeholders[1];

        assertEquals(0, snippet.enclosingPlaceholders(first).length);
        final enclosing = snippet.enclosingPlaceholders(second);
        assertEquals(1, enclosing.length);
        assertTrue(enclosing[0] == first);
    }

    function testTextmateSnippetOffset() {
        // test('TextmateSnippet#offset')
        var snippet = new SnippetParser().parse("te$1xt", true);
        assertEquals(0, snippet.offset(snippet.children[0]));
        assertEquals(2, snippet.offset(snippet.children[1]));
        assertEquals(2, snippet.offset(snippet.children[2]));

        snippet = new SnippetParser().parse("${TM_SELECTED_TEXT:def}", true);
        assertEquals(0, snippet.offset(snippet.children[0]));
        assertEquals(0, snippet.offset((cast snippet.children[0] : Variable).children[0]));

        // forgein marker
        assertEquals(-1, snippet.offset(new Text('foo')));
    }

    function testTextmateSnippetPlaceholder() {
        // test('TextmateSnippet#placeholder')
        var snippet = new SnippetParser().parse("te$1xt$0", true);
        var placeholders = snippet.placeholders;
        assertEquals(2, placeholders.length);

        snippet = new SnippetParser().parse("te$1xt$1$0", true);
        placeholders = snippet.placeholders;
        assertEquals(3, placeholders.length);


        snippet = new SnippetParser().parse("te$1xt$2$0", true);
        placeholders = snippet.placeholders;
        assertEquals(3, placeholders.length);

        snippet = new SnippetParser().parse("${1:bar${2:foo}bar}$0", true);
        placeholders = snippet.placeholders;
        assertEquals(3, placeholders.length);
    }

    function testTextmateSnippetReplace12() {
        // test('TextmateSnippet#replace 1/2')
        final snippet = new SnippetParser().parse("aaa${1:bbb${2:ccc}}$0", true);

        assertEquals(3, snippet.placeholders.length);
        final second = snippet.placeholders[1];
        assertEquals(2.0, second.index);

        final enclosing = snippet.enclosingPlaceholders(second);
        assertEquals(1, enclosing.length);
        assertEquals(1.0, enclosing[0].index);

        final nested = new SnippetParser().parse("ddd$1eee$0", true);
        snippet.replace(second, nested.children);

        assertEquals('aaabbbdddeee', snippet.toString());
        assertEquals(4, snippet.placeholders.length);
        assertEquals(1.0, snippet.placeholders[0].index);
        assertEquals(1.0, snippet.placeholders[1].index);
        assertEquals(0.0, snippet.placeholders[2].index);
        assertEquals(0.0, snippet.placeholders[3].index);

        final newEnclosing = snippet.enclosingPlaceholders(snippet.placeholders[1]);
        assertTrue(newEnclosing[0] == snippet.placeholders[0]);
        assertEquals(1, newEnclosing.length);
        assertEquals(1.0, newEnclosing[0].index);
    }

    function testTextmateSnippetReplace22() {
        // test('TextmateSnippet#replace 2/2')
        final snippet = new SnippetParser().parse("aaa${1:bbb${2:ccc}}$0", true);

        assertEquals(3, snippet.placeholders.length);
        final second = snippet.placeholders[1];
        assertEquals(2.0, second.index);

        final nested = new SnippetParser().parse("dddeee$0", true);
        snippet.replace(second, nested.children);

        assertEquals('aaabbbdddeee', snippet.toString());
        assertEquals(3, snippet.placeholders.length);
    }

    function testSnippetOrderForPlaceholders28185() {
        // test('Snippet order for placeholders, #28185')
        final _10 = new Placeholder(10);
        final _2 = new Placeholder(2);

        assertEquals(1, Placeholder.compareByIndex(_10, _2));
    }

    function testMaximumCallStackSizeExceeded28983() {
        // test('Maximum call stack size exceeded, #28983')
        new SnippetParser().parse("${1:${foo:${1}}}");
        assertTrue(true);
    }

    function testSnippetCanFreezeTheEditor30407() {
        // test('Snippet can freeze the editor, #30407')
        final seen:Array<Marker> = [];

        new SnippetParser().parse("class ${1:${TM_FILENAME/(?:\\A|_)([A-Za-z0-9]+)(?:\\.rb)?/(?2::\\u$1)/g}} < ${2:Application}Controller\n  $3\nend").walk(marker -> {
            assertTrue(seen.indexOf(marker) == -1);
            seen.push(marker);
            return true;
        });

        seen.resize(0);
        new SnippetParser().parse("${1:${FOO:abc$1def}}").walk(marker -> {
            assertTrue(seen.indexOf(marker) == -1);
            seen.push(marker);
            return true;
        });
    }

    function testSnippetsMakeParserIgnore0Choice31599() {
        // test('Snippets: make parser ignore `${0|choice|}`, #31599')
        assertTextAndMarker("${0|foo,bar|}", "${0|foo,bar|}", Text);
        assertTextAndMarker("${1|foo,bar|}", 'foo', Placeholder);
    }

    function testTransformFormatStringResolve() {
        // test('Transform -> FormatString#resolve')

        // shorthand functions
        assertEquals('FOO', new FormatString(1, 'upcase').resolve('foo'));
        assertEquals('foo', new FormatString(1, 'downcase').resolve('FOO'));
        assertEquals('Bar', new FormatString(1, 'capitalize').resolve('bar'));
        assertEquals('Bar no repeat', new FormatString(1, 'capitalize').resolve('bar no repeat'));
        assertEquals('BarFoo', new FormatString(1, 'pascalcase').resolve('bar-foo'));
        assertEquals('Bar42Foo', new FormatString(1, 'pascalcase').resolve('bar-42-foo'));
        assertEquals('SnakeAndPascalCase', new FormatString(1, 'pascalcase').resolve('snake_AndPascalCase'));
        assertEquals('KebabAndPascalCase', new FormatString(1, 'pascalcase').resolve('kebab-AndPascalCase'));
        assertEquals('JustPascalCase', new FormatString(1, 'pascalcase').resolve('_justPascalCase'));
        assertEquals('barFoo', new FormatString(1, 'camelcase').resolve('bar-foo'));
        assertEquals('bar42Foo', new FormatString(1, 'camelcase').resolve('bar-42-foo'));
        assertEquals('snakeAndCamelCase', new FormatString(1, 'camelcase').resolve('snake_AndCamelCase'));
        assertEquals('kebabAndCamelCase', new FormatString(1, 'camelcase').resolve('kebab-AndCamelCase'));
        assertEquals('justCamelCase', new FormatString(1, 'camelcase').resolve('_JustCamelCase'));
        assertEquals('input', new FormatString(1, 'notKnown').resolve('input'));

        // if
        assertEquals('', new FormatString(1, null, 'foo', null).resolve(null));
        assertEquals('', new FormatString(1, null, 'foo', null).resolve(''));
        assertEquals('foo', new FormatString(1, null, 'foo', null).resolve('bar'));

        // else
        assertEquals('foo', new FormatString(1, null, null, 'foo').resolve(null));
        assertEquals('foo', new FormatString(1, null, null, 'foo').resolve(''));
        assertEquals('bar', new FormatString(1, null, null, 'foo').resolve('bar'));

        // if-else
        assertEquals('foo', new FormatString(1, null, 'bar', 'foo').resolve(null));
        assertEquals('foo', new FormatString(1, null, 'bar', 'foo').resolve(''));
        assertEquals('bar', new FormatString(1, null, 'bar', 'foo').resolve('baz'));
    }

    function testSnippetVariableTransformationDoesntWorkIfRegexIsComplicated55627() {
        // test('Snippet variable transformation doesn\'t work if regex is complicated and snippet body contains \'$$\' #55627')
        final snippet = new SnippetParser().parse("const fileName = \"${TM_FILENAME/(.*)\\..+$/$1/}\"");
        assertEquals("const fileName = \"${TM_FILENAME/(.*)\\..+$/${1}/}\"", snippet.toTextmateString());
    }

    function testHTMLAttributeSuggestionsSnippetSessionDoesNotHaveEndPositionSet33147() {
        // test('[BUG] HTML attribute suggestions: Snippet session does not have end-position set, #33147')
        final placeholders = new SnippetParser().parse("src=\"$1\"", true).placeholders;
        final first = placeholders[0];
        final second = placeholders[1];

        assertEquals(2, placeholders.length);
        assertEquals(1.0, first.index);
        assertEquals(0.0, second.index);
    }

    function testSnippetOptionalTransformsAreNotAppliedCorrectlyWhenReusingTheSameVariable37702() {
        // test('Snippet optional transforms are not applied correctly when reusing the same variable, #37702')
        final transform = new Transform();
        transform.appendChild(new FormatString(1, 'upcase'));
        transform.appendChild(new FormatString(2, 'upcase'));
        transform.regexp = new RegExp('^(.)|-(.)', 'g');

        assertEquals('MyFileName', transform.resolve('my-file-name'));

        final clone = transform.clone();
        assertEquals('MyFileName', clone.resolve('my-file-name'));
    }

    function testProblemWithSnippetsRegex40570() {
        // test('problem with snippets regex #40570')
        final snippet = new SnippetParser().parse("${TM_DIRECTORY/.*src[\\/](.*)/$1/}");
        assertMarker(snippet, Variable);
    }

    function testVariableTransformationDoesntWorkIfUndefinedVariablesAreUsedInTheSameSnippet51769() {
        // test('Variable transformation doesn\'t work if undefined variables are used in the same snippet #51769')
        final transform = new Transform();
        transform.appendChild(new Text('bar'));
        transform.regexp = new RegExp('foo', 'gi');
        assertEquals('/foo/bar/ig', transform.toTextmateString());
    }

    function testSnippetParserFreeze53144() {
        // test('Snippet parser freeze #53144')
        final snippet = new SnippetParser().parse("${1/(void$)|(.+)/${1:?-\treturn nil;}/}");
        assertMarker(snippet, Placeholder);
    }

    function testSnippetsVariableNotResolvedInJSONProposal52931() {
        // test('snippets variable not resolved in JSON proposal #52931')
        assertTextAndMarker("FOO${1:/bin/bash}", 'FOO/bin/bash', Text, Placeholder);
    }

    function testMirroringSequenceOfNestedPlaceholdersNotSelectedProperlyOnBackjumping58736() {
        // test('Mirroring sequence of nested placeholders not selected properly on backjumping #58736')
        final snippet = new SnippetParser().parse("${3:nest1 ${1:nest2 ${2:nest3}}} $3");
        assertEquals(3, snippet.children.length);
        assertTrue(Std.isOfType(snippet.children[0], Placeholder));
        assertTrue(Std.isOfType(snippet.children[1], Text));
        assertTrue(Std.isOfType(snippet.children[2], Placeholder));

        function assertParent(marker:Marker):Void {
            for (child in marker.children) {
                assertParent(child);
            }
            if (!Std.isOfType(marker, Placeholder)) {
                return;
            }
            var found = false;
            var m:Null<Marker> = marker;
            while (m != null && !found) {
                if (m.parent == snippet) {
                    found = true;
                }
                m = m.parent;
            }
            assertTrue(found);
        }
        final clone = snippet.children[2];
        assertParent(clone);
    }

    function testBackspaceCantBeEscapedInSnippetVariableTransforms65412() {
        // test('Backspace can\'t be escaped in snippet variable transforms #65412')
        final snippet = new SnippetParser().parse("namespace ${TM_DIRECTORY/[\\/]/\\\\/g};");
        assertMarker(snippet, Text, Variable, Text);
    }

    function testSnippetCannotEscapeClosingBracketInsideConditionalInsertionVariableReplacement78883() {
        // test('Snippet cannot escape closing bracket inside conditional insertion variable replacement #78883')
        final snippet = new SnippetParser().parse("${TM_DIRECTORY/(.+)/${1:+import { hello \\} from world}/}");
        final variable:Variable = cast snippet.children[0];
        assertEquals(1, snippet.children.length);
        assertTrue(Std.isOfType(variable, Variable));
        assertTrue(variable.transform != null);
        assertEquals(1, variable.transform.children.length);
        assertTrue(Std.isOfType(variable.transform.children[0], FormatString));
        assertEquals('import { hello } from world', (cast variable.transform.children[0] : FormatString).ifValue);
        assertEquals(null, (cast variable.transform.children[0] : FormatString).elseValue);
    }

    function testSnippetEscapeBackslashesInsideConditionalInsertionVariableReplacement80394() {
        // test('Snippet escape backslashes inside conditional insertion variable replacement #80394')
        final snippet = new SnippetParser().parse("${CURRENT_YEAR/(.+)/${1:+\\\\}/}");
        final variable:Variable = cast snippet.children[0];
        assertEquals(1, snippet.children.length);
        assertTrue(Std.isOfType(variable, Variable));
        assertTrue(variable.transform != null);
        assertEquals(1, variable.transform.children.length);
        assertTrue(Std.isOfType(variable.transform.children[0], FormatString));
        assertEquals('\\', (cast variable.transform.children[0] : FormatString).ifValue);
        assertEquals(null, (cast variable.transform.children[0] : FormatString).elseValue);
    }

    function testSnippetPlaceholderEmptyRightAfterExpansion152553() {
        // test('Snippet placeholder empty right after expansion #152553')
        final snippet = new SnippetParser().parse("${1:prog}: ${2:$1.cc} - $2");
        final actual = snippet.toString();
        assertEquals('prog: prog.cc - prog.cc', actual);

        final snippet2 = new SnippetParser().parse("${1:prog}: ${3:${2:$1.cc}.33} - $2 $3");
        final actual2 = snippet2.toString();
        assertEquals('prog: prog.cc.33 - prog.cc prog.cc.33', actual2);

        // cyclic references of placeholders
        final snippet3 = new SnippetParser().parse("${1:$2.one} <> ${2:$1.two}");
        final actual3 = snippet3.toString();
        assertEquals('.two.one.two.one <> .one.two.one.two', actual3);
    }

    function testSnippetChoicesAreIncorrectlyEscapedApplied180132() {
        // test('Snippet choices are incorrectly escaped/applied #180132')
        assertTextAndMarker("${1|aaa$aaa|}bbb\\$bbb", "aaa$aaabbb$bbb", Placeholder, Text);
    }

}
