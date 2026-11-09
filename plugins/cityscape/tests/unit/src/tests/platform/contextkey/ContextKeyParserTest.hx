// Ported from vscode src/vs/platform/contextkey/test/common/parser.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.platform.contextkey;

import cityscape.platform.contextkey.common.ContextKey;
import testing.TestCase;

/**
 * vscode's 'Context Key Parser' tests (inputs and expected outputs
 * generated from its test file).
 */
class ContextKeyParserTest extends TestCase {

    static function parseToStr(input:String):String {
        final parser = new Parser();

        final prints:Array<String> = [];

        final print = (ss:Array<String>) -> {
            for (s in ss) {
                prints.push(s);
            }
        };

        final expr = parser.parse(input);
        if (expr == null) {
            if (parser.lexingErrors.length > 0) {
                print(['Lexing errors:', '\n\n']);
                for (lexingError in parser.lexingErrors) {
                    // `${undefined}` is 'undefined' in JavaScript
                    final info = lexingError.additionalInfo != null ? lexingError.additionalInfo : 'undefined';
                    print(['Unexpected token \'' + lexingError.lexeme + '\' at offset ' + lexingError.offset + '. ' + info, '\n']);
                }
            }

            if (parser.parsingErrors.length > 0) {
                if (parser.lexingErrors.length > 0) {
                    print(['\n --- \n']);
                }
                print(['Parsing errors:', '\n\n']);
                for (parsingError in parser.parsingErrors) {
                    print(['Unexpected \'' + parsingError.lexeme + '\' at offset ' + parsingError.offset + '.', '\n']);
                }
            }

        }
        else {
            print([expr.serialize()]);
        }

        return prints.join('');
    }

    /** vscode:  foo */
    function testFoo() {
        assertEquals("foo", parseToStr(" foo"));
    }

    /** vscode: !foo */
    function testFoo1() {
        assertEquals("!foo", parseToStr("!foo"));
    }

    /** vscode: foo =~ /bar/ */
    function testFooBar() {
        assertEquals("foo =~ /bar/", parseToStr("foo =~ /bar/"));
    }

    /** vscode: foo || (foo =~ /bar/ && baz) */
    function testFooFooBarBaz() {
        assertEquals("foo || baz && foo =~ /bar/", parseToStr("foo || (foo =~ /bar/ && baz)"));
    }

    /** vscode: foo || (foo =~ /bar/ || baz) */
    function testFooFooBarBaz4() {
        assertEquals("baz || foo || foo =~ /bar/", parseToStr("foo || (foo =~ /bar/ || baz)"));
    }

    /** vscode: (foo || bar) && (jee || jar) */
    function testFooBarJeeJar() {
        assertEquals("bar && jar || bar && jee || foo && jar || foo && jee", parseToStr("(foo || bar) && (jee || jar)"));
    }

    /** vscode: foo && foo =~ /zee/i */
    function testFooFooZeeI() {
        assertEquals("foo && foo =~ /zee/i", parseToStr("foo && foo =~ /zee/i"));
    }

    /** vscode: foo.bar==enabled */
    function testFooBarEnabled() {
        assertEquals("foo.bar == 'enabled'", parseToStr("foo.bar==enabled"));
    }

    /** vscode: foo.bar == 'enabled' */
    function testFooBarEnabled8() {
        assertEquals("foo.bar == 'enabled'", parseToStr("foo.bar == 'enabled'"));
    }

    /** vscode: foo.bar:zed==completed - equality with no space */
    function testFooBarZedCompletedEqualityWithNoSpace() {
        assertEquals("foo.bar:zed == 'completed'", parseToStr("foo.bar:zed==completed"));
    }

    /** vscode: a && b || c */
    function testABC() {
        assertEquals("c || a && b", parseToStr("a && b || c"));
    }

    /** vscode: fooBar && baz.jar && fee.bee<K-loo+1> */
    function testFooBarBazJarFeeBeeKLoo1() {
        assertEquals("baz.jar && fee.bee<K-loo+1> && fooBar", parseToStr("fooBar && baz.jar && fee.bee<K-loo+1>"));
    }

    /** vscode: foo.barBaz<C-r> < 2 */
    function testFooBarBazCR2() {
        assertEquals("foo.barBaz<C-r> < 2", parseToStr("foo.barBaz<C-r> < 2"));
    }

    /** vscode: foo.bar >= -1 */
    function testFooBar1() {
        assertEquals("foo.bar >= -1", parseToStr("foo.bar >= -1"));
    }

    /** vscode: key contains &nbsp: view == vsc-packages-activitybar-folders && vsc-packages-folders-loaded */
    function testKeyContainsNbspViewVscPackagesActivitybarFoldersVscPackagesF() {
        assertEquals("vsc-packages-folders-loaded && view == 'vsc-packages-activitybar-folders'", parseToStr("view == vsc-packages-activitybar-folders\u{a0}&& vsc-packages-folders-loaded"));
    }

    /** vscode: foo.bar <= -1 */
    function testFooBar115() {
        assertEquals("foo.bar <= -1", parseToStr("foo.bar <= -1"));
    }

    /** vscode: !cmake:hideBuildCommand && cmake:enableFullFeatureSet */
    function testCmakeHideBuildCommandCmakeEnableFullFeatureSet() {
        assertEquals("cmake:enableFullFeatureSet && !cmake:hideBuildCommand", parseToStr("!cmake:hideBuildCommand && cmake:enableFullFeatureSet"));
    }

    /** vscode: !(foo && bar) */
    function testFooBar17() {
        assertEquals("!bar || !foo", parseToStr("!(foo && bar)"));
    }

    /** vscode: !(foo && bar || boar) || deer */
    function testFooBarBoarDeer() {
        assertEquals("deer || !bar && !boar || !boar && !foo", parseToStr("!(foo && bar || boar) || deer"));
    }

    /** vscode: !(!foo) */
    function testFoo19() {
        assertEquals("foo", parseToStr("!(!foo)"));
    }

    /** vscode: debugState == "stopped" */
    function testDebugStateStopped() {
        assertEquals("debugState == '\"stopped\"'", parseToStr("debugState == \"stopped\""));
    }

    /** vscode:  viewItem == VSCode WorkSpace */
    function testViewItemVSCodeWorkSpace() {
        assertEquals("Parsing errors:\n\nUnexpected 'WorkSpace' at offset 20.\n", parseToStr(" viewItem == VSCode WorkSpace"));
    }

    /** vscode: resource =~ //foo/(barr|door/(Foo-Bar%20Templates|Soo%20Looo)|Web%20Site%Jjj%20Llll)(/.*)*$/ */
    function testResourceFooBarrDoorFooBar20TemplatesSoo20LoooWeb20SiteJjj20L() {
        assertEquals("resource =~ /\\/foo\\/(barr|door\\/(Foo-Bar%20Templates|Soo%20Looo)|Web%20Site%Jjj%20Llll)(\\/.*)*$/", parseToStr("resource =~ //foo/(barr|door/(Foo-Bar%20Templates|Soo%20Looo)|Web%20Site%Jjj%20Llll)(/.*)*$/"));
    }

    /** vscode: resource =~ /((/scratch/(?!update)(.*)/)|((/src/).* /)).*$/ */
    function testResourceScratchUpdateSrc() {
        assertEquals("resource =~ /((\\/scratch\\/(?!update)(.*)\\/)|((\\/src\\/).*\\/)).*$/", parseToStr("resource =~ /((/scratch/(?!update)(.*)/)|((/src/).*/)).*$/"));
    }

    /** vscode: resourcePath =~ /.md(.yml|.txt)*$/giym */
    function testResourcePathMdYmlTxtGiym() {
        assertEquals("resourcePath =~ /.md(.yml|.txt)*$/im", parseToStr("resourcePath =~ /.md(.yml|.txt)*$/giym"));
    }

    /** vscode: /foo */
    function testFoo25() {
        assertEquals("Lexing errors:\n\nUnexpected token '/foo' at offset 0. Did you forget to escape the '/' (slash) character? Put two backslashes before it to escape, e.g., '\\\\/'.\n\n --- \nParsing errors:\n\nUnexpected '/foo' at offset 0.\n", parseToStr("/foo"));
    }

    /** vscode: !b == 'true' */
    function testBTrue() {
        assertEquals("Parsing errors:\n\nUnexpected '==' at offset 3.\n", parseToStr("!b == 'true'"));
    }

    /** vscode: !foo &&  in bar */
    function testFooInBar() {
        assertEquals("Parsing errors:\n\nUnexpected 'in' at offset 9.\n", parseToStr("!foo &&  in bar"));
    }

    /** vscode: vim<c-r> == 1 && vim<2<=3 */
    function testVimCR1Vim23() {
        assertEquals("Lexing errors:\n\nUnexpected token '=' at offset 23. Did you mean == or =~?\n\n --- \nParsing errors:\n\nUnexpected '=' at offset 23.\n", parseToStr("vim<c-r> == 1 && vim<2<=3"));
    }

    /** vscode: foo && 'bar */
    function testFooBar29() {
        assertEquals("Lexing errors:\n\nUnexpected token ''bar' at offset 7. Did you forget to open or close the quote?\n\n --- \nParsing errors:\n\nUnexpected ''bar' at offset 7.\n", parseToStr("foo && 'bar"));
    }

    /** vscode: config.foo &&  &&bar =~ /^foo$|^bar-foo$|^joo$|^jar$/ && !foo */
    function testConfigFooBarFooBarFooJooJarFoo() {
        assertEquals("Parsing errors:\n\nUnexpected '&&' at offset 15.\n", parseToStr("config.foo &&  &&bar =~ /^foo$|^bar-foo$|^joo$|^jar$/ && !foo"));
    }

    /** vscode: !foo == 'test' */
    function testFooTest() {
        assertEquals("Parsing errors:\n\nUnexpected '==' at offset 5.\n", parseToStr("!foo == 'test'"));
    }

    /** vscode: !!foo */
    function testFoo32() {
        assertEquals("Parsing errors:\n\nUnexpected '!' at offset 1.\n", parseToStr("!!foo"));
    }

}
