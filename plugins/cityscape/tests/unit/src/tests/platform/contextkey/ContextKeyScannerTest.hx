// Ported from vscode src/vs/platform/contextkey/test/common/scanner.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.platform.contextkey;

import cityscape.platform.contextkey.common.Scanner;
import testing.TestCase;

/**
 * vscode's 'Context Key Scanner' tests: the inputs and expected tokens are
 * vscode's (generated from its test file), written as
 * `type@offset:lexeme` items joined with a middle dot.
 */
class ContextKeyScannerTest extends TestCase {

    static function tokenTypeToStr(token:Token):String {
        return switch (token.type) {
            case TokenType.LParen: '(';
            case TokenType.RParen: ')';
            case TokenType.Neg: '!';
            case TokenType.Eq: token.isTripleEq ? '===' : '==';
            case TokenType.NotEq: token.isTripleEq ? '!==' : '!=';
            case TokenType.Lt: '<';
            case TokenType.LtEq: '<=';
            case TokenType.Gt: '>';
            case TokenType.GtEq: '>=';
            case TokenType.RegexOp: '=~';
            case TokenType.RegexStr: 'RegexStr';
            case TokenType.True: 'true';
            case TokenType.False: 'false';
            case TokenType.In: 'in';
            case TokenType.Not: 'not';
            case TokenType.And: '&&';
            case TokenType.Or: '||';
            case TokenType.Str: 'Str';
            case TokenType.QuotedStr: 'QuotedStr';
            case TokenType.Error: 'ErrorToken';
            case TokenType.EOF: 'EOF';
            default: '?';
        }
    }

    static function scan(input:String):String {
        final tokens = (new Scanner()).reset(input).scan();
        return [for (token in tokens) {
            final hasLexeme = token.type == TokenType.RegexStr || token.type == TokenType.Str || token.type == TokenType.QuotedStr || token.type == TokenType.Error;
            tokenTypeToStr(token) + '@' + token.offset + (hasLexeme ? ':' + token.lexeme : '');
        }].join(' · ');
    }

    function checkScan(input:String, expected:String, ?pos:haxe.PosInfos):Void {
        assertEquals(expected, scan(input), null, pos);
    }

    /** vscode: foo.bar<C-shift+2> */
    function testFooBarCShift2() {
        checkScan("foo.bar<C-shift+2>", "Str@0:foo.bar<C-shift+2> \u{b7} EOF@18");
    }

    /** vscode: !foo */
    function testFoo() {
        checkScan("!foo", "!@0 \u{b7} Str@1:foo \u{b7} EOF@4");
    }

    /** vscode: foo === bar */
    function testFooBar() {
        checkScan("foo === bar", "Str@0:foo \u{b7} ===@4 \u{b7} Str@8:bar \u{b7} EOF@11");
    }

    /** vscode: foo  !== bar */
    function testFooBar3() {
        checkScan("foo  !== bar", "Str@0:foo \u{b7} !==@5 \u{b7} Str@9:bar \u{b7} EOF@12");
    }

    /** vscode: !(foo && bar) */
    function testFooBar4() {
        checkScan("!(foo && bar)", "!@0 \u{b7} (@1 \u{b7} Str@2:foo \u{b7} &&@6 \u{b7} Str@9:bar \u{b7} )@12 \u{b7} EOF@13");
    }

    /** vscode: =~  */
    function testCase() {
        checkScan("=~ ", "=~@0 \u{b7} EOF@3");
    }

    /** vscode: foo =~ /bar/ */
    function testFooBar6() {
        checkScan("foo =~ /bar/", "Str@0:foo \u{b7} =~@4 \u{b7} RegexStr@7:/bar/ \u{b7} EOF@12");
    }

    /** vscode: foo =~ /zee/i */
    function testFooZeeI() {
        checkScan("foo =~ /zee/i", "Str@0:foo \u{b7} =~@4 \u{b7} RegexStr@7:/zee/i \u{b7} EOF@13");
    }

    /** vscode: foo =~ /zee/gm */
    function testFooZeeGm() {
        checkScan("foo =~ /zee/gm", "Str@0:foo \u{b7} =~@4 \u{b7} RegexStr@7:/zee/gm \u{b7} EOF@14");
    }

    /** vscode: foo in barrr   */
    function testFooInBarrr() {
        checkScan("foo in barrr  ", "Str@0:foo \u{b7} in@4 \u{b7} Str@7:barrr \u{b7} EOF@14");
    }

    /** vscode: resource =~ //FileCabinet/(SuiteScripts|Templates/(E-mail%20Templates|Marketing%20Templates)|Web%20Site%20Hosting%20Files)(/.*)*$/ */
    function testResourceFileCabinetSuiteScriptsTemplatesEMail20TemplatesMark() {
        checkScan("resource =~ //FileCabinet/(SuiteScripts|Templates/(E-mail%20Templates|Marketing%20Templates)|Web%20Site%20Hosting%20Files)(/.*)*$/", "Str@0:resource \u{b7} =~@9 \u{b7} RegexStr@12:// \u{b7} Str@14:FileCabinet/ \u{b7} (@26 \u{b7} Str@27:SuiteScripts \u{b7} ErrorToken@39:| \u{b7} Str@40:Templates/ \u{b7} (@50 \u{b7} Str@51:E-mail%20Templates \u{b7} ErrorToken@69:| \u{b7} Str@70:Marketing%20Templates \u{b7} )@91 \u{b7} ErrorToken@92:| \u{b7} Str@93:Web%20Site%20Hosting%20Files \u{b7} )@121 \u{b7} (@122 \u{b7} RegexStr@123:/.*)*$/ \u{b7} EOF@130");
    }

    /** vscode: editorLangId in testely.supportedLangIds && resourceFilename =~ /^.+(.test.(w+))$/gm */
    function testEditorLangIdInTestelySupportedLangIdsResourceFilenameTestWGm() {
        checkScan("editorLangId in testely.supportedLangIds && resourceFilename =~ /^.+(.test.(w+))$/gm", "Str@0:editorLangId \u{b7} in@13 \u{b7} Str@16:testely.supportedLangIds \u{b7} &&@41 \u{b7} Str@44:resourceFilename \u{b7} =~@61 \u{b7} RegexStr@64:/^.+(.test.(w+))$/gm \u{b7} EOF@84");
    }

    /** vscode: !(foo && bar) && baz */
    function testFooBarBaz() {
        checkScan("!(foo && bar) && baz", "!@0 \u{b7} (@1 \u{b7} Str@2:foo \u{b7} &&@6 \u{b7} Str@9:bar \u{b7} )@12 \u{b7} &&@14 \u{b7} Str@17:baz \u{b7} EOF@20");
    }

    /** vscode: foo.bar:zed==completed - equality with no space */
    function testFooBarZedCompletedEqualityWithNoSpace() {
        checkScan("foo.bar:zed==completed", "Str@0:foo.bar:zed \u{b7} ==@11 \u{b7} Str@13:completed \u{b7} EOF@22");
    }

    /** vscode: a && b || c */
    function testABC() {
        checkScan("a && b || c", "Str@0:a \u{b7} &&@2 \u{b7} Str@5:b \u{b7} ||@7 \u{b7} Str@10:c \u{b7} EOF@11");
    }

    /** vscode: fooBar && baz.jar && fee.bee<K-loo+1> */
    function testFooBarBazJarFeeBeeKLoo1() {
        checkScan("fooBar && baz.jar && fee.bee<K-loo+1>", "Str@0:fooBar \u{b7} &&@7 \u{b7} Str@10:baz.jar \u{b7} &&@18 \u{b7} Str@21:fee.bee<K-loo+1> \u{b7} EOF@37");
    }

    /** vscode: foo.barBaz<C-r> < 2 */
    function testFooBarBazCR2() {
        checkScan("foo.barBaz<C-r> < 2", "Str@0:foo.barBaz<C-r> \u{b7} <@16 \u{b7} Str@18:2 \u{b7} EOF@19");
    }

    /** vscode: foo.bar >= -1 */
    function testFooBar1() {
        checkScan("foo.bar >= -1", "Str@0:foo.bar \u{b7} >=@8 \u{b7} Str@11:-1 \u{b7} EOF@13");
    }

    /** vscode: foo.bar <= -1 */
    function testFooBar118() {
        checkScan("foo.bar <= -1", "Str@0:foo.bar \u{b7} <=@8 \u{b7} Str@11:-1 \u{b7} EOF@13");
    }

    /** vscode: resource =~ /\/Objects\/.+\.xml$/ */
    function testResourceObjectsXml() {
        checkScan("resource =~ /\\/Objects\\/.+\\.xml$/", "Str@0:resource \u{b7} =~@9 \u{b7} RegexStr@12:/\\/Objects\\/.+\\.xml$/ \u{b7} EOF@33");
    }

    /** vscode: view == vsc-packages-activitybar-folders && vsc-packages-folders-loaded */
    function testViewVscPackagesActivitybarFoldersVscPackagesFoldersLoaded() {
        checkScan("view == vsc-packages-activitybar-folders\u{a0}&& vsc-packages-folders-loaded", "Str@0:view \u{b7} ==@5 \u{b7} Str@8:vsc-packages-activitybar-folders \u{b7} &&@41 \u{b7} Str@44:vsc-packages-folders-loaded \u{b7} EOF@71");
    }

    /** vscode: sfdx:project_opened && resource =~ /.*\/functions\/.*\/[^\/]+(\/[^\/]+.(ts|js|java|json|toml))?$/ && resourceFilename != package.json && resourceFilename != package-lock.json && resourceFilename != tsconfig.json */
    function testSfdxProjectOpenedResourceFunctionsTsJsJavaJsonTomlResourceFi() {
        checkScan("sfdx:project_opened && resource =~ /.*\\/functions\\/.*\\/[^\\/]+(\\/[^\\/]+.(ts|js|java|json|toml))?$/ && resourceFilename != package.json && resourceFilename != package-lock.json && resourceFilename != tsconfig.json", "Str@0:sfdx:project_opened \u{b7} &&@20 \u{b7} Str@23:resource \u{b7} =~@32 \u{b7} RegexStr@35:/.*\\/functions\\/.*\\/[^\\/]+(\\/[^\\/]+.(ts|js|java|json|toml))?$/ \u{b7} &&@98 \u{b7} Str@101:resourceFilename \u{b7} !=@118 \u{b7} Str@121:package.json \u{b7} &&@134 \u{b7} Str@137:resourceFilename \u{b7} !=@154 \u{b7} Str@157:package-lock.json \u{b7} &&@175 \u{b7} Str@178:resourceFilename \u{b7} !=@195 \u{b7} Str@198:tsconfig.json \u{b7} EOF@211");
    }

    /** vscode: view =~ '/(servers)/' && viewItem =~ '/^(Starting|Started|Debugging|Stopping|Stopped)/' */
    function testViewServersViewItemStartingStartedDebuggingStoppingStopped() {
        checkScan("view =~ '/(servers)/' && viewItem =~ '/^(Starting|Started|Debugging|Stopping|Stopped)/'", "Str@0:view \u{b7} =~@5 \u{b7} QuotedStr@9:/(servers)/ \u{b7} &&@22 \u{b7} Str@25:viewItem \u{b7} =~@34 \u{b7} QuotedStr@38:/^(Starting|Started|Debugging|Stopping|Stopped)/ \u{b7} EOF@87");
    }

    /** vscode: resourcePath =~ /.md(.yml|.txt)*$/gim */
    function testResourcePathMdYmlTxtGim() {
        checkScan("resourcePath =~ /.md(.yml|.txt)*$/gim", "Str@0:resourcePath \u{b7} =~@13 \u{b7} RegexStr@16:/.md(.yml|.txt)*$/gim \u{b7} EOF@37");
    }

    /** vscode: foo === bar' */
    function testFooBar24() {
        checkScan("foo === bar'", "Str@0:foo \u{b7} ===@4 \u{b7} Str@8:bar \u{b7} ErrorToken@11:' \u{b7} EOF@12");
    }

    /** vscode: foo === ' */
    function testFoo25() {
        checkScan("foo === '", "Str@0:foo \u{b7} ===@4 \u{b7} ErrorToken@8:' \u{b7} EOF@9");
    }

    /** vscode: foo && 'bar - unterminated single quote */
    function testFooBarUnterminatedSingleQuote() {
        checkScan("foo && 'bar", "Str@0:foo \u{b7} &&@4 \u{b7} ErrorToken@7:'bar \u{b7} EOF@11");
    }

    /** vscode: vim<c-r> == 1 && vim<2 <= 3 */
    function testVimCR1Vim23() {
        checkScan("vim<c-r> == 1 && vim<2 <= 3", "Str@0:vim<c-r> \u{b7} ==@9 \u{b7} Str@12:1 \u{b7} &&@14 \u{b7} Str@17:vim<2 \u{b7} <=@23 \u{b7} Str@26:3 \u{b7} EOF@27");
    }

    /** vscode: vim<c-r>==1 && vim<2<=3 */
    function testVimCR1Vim2328() {
        checkScan("vim<c-r>==1 && vim<2<=3", "Str@0:vim<c-r> \u{b7} ==@8 \u{b7} Str@10:1 \u{b7} &&@12 \u{b7} Str@15:vim<2< \u{b7} ErrorToken@21:= \u{b7} Str@22:3 \u{b7} EOF@23");
    }

    /** vscode: foo|bar */
    function testFooBar29() {
        checkScan("foo|bar", "Str@0:foo \u{b7} ErrorToken@3:| \u{b7} Str@4:bar \u{b7} EOF@7");
    }

    /** vscode: resource =~ //foo/(barr|door/(Foo-Bar%20Templates|Soo%20Looo)|Web%20Site%Jjj%20Llll)(/.*)*$/ */
    function testResourceFooBarrDoorFooBar20TemplatesSoo20LoooWeb20SiteJjj20L() {
        checkScan("resource =~ //foo/(barr|door/(Foo-Bar%20Templates|Soo%20Looo)|Web%20Site%Jjj%20Llll)(/.*)*$/", "Str@0:resource \u{b7} =~@9 \u{b7} RegexStr@12:// \u{b7} Str@14:foo/ \u{b7} (@18 \u{b7} Str@19:barr \u{b7} ErrorToken@23:| \u{b7} Str@24:door/ \u{b7} (@29 \u{b7} Str@30:Foo-Bar%20Templates \u{b7} ErrorToken@49:| \u{b7} Str@50:Soo%20Looo \u{b7} )@60 \u{b7} ErrorToken@61:| \u{b7} Str@62:Web%20Site%Jjj%20Llll \u{b7} )@83 \u{b7} (@84 \u{b7} RegexStr@85:/.*)*$/ \u{b7} EOF@92");
    }

    /** vscode: /((/foo/(?!bar)(.*)/)|((/src/).* /)).*$/ */
    function testFooBarSrc() {
        checkScan("/((/foo/(?!bar)(.*)/)|((/src/).*/)).*$/", "RegexStr@0:/((/ \u{b7} Str@4:foo/ \u{b7} (@8 \u{b7} Str@9:? \u{b7} !@10 \u{b7} Str@11:bar \u{b7} )@14 \u{b7} (@15 \u{b7} Str@16:.* \u{b7} )@18 \u{b7} RegexStr@19:/)|((/s \u{b7} Str@26:rc/ \u{b7} )@29 \u{b7} Str@30:.*/ \u{b7} )@33 \u{b7} )@34 \u{b7} Str@35:.*$/ \u{b7} EOF@39");
    }

    /** vscode: resourcePath =~ //foo/barr// || resourcePath =~ //view/(jarrr|doooor|bees)/(web|templates)// && resourceExtname in foo.Bar */
    function testResourcePathFooBarrResourcePathViewJarrrDoooorBeesWebTemplat() {
        checkScan("resourcePath =~ //foo/barr// || resourcePath =~ //view/(jarrr|doooor|bees)/(web|templates)// && resourceExtname in foo.Bar", "Str@0:resourcePath \u{b7} =~@13 \u{b7} RegexStr@16:// \u{b7} Str@18:foo/barr// \u{b7} ||@29 \u{b7} Str@32:resourcePath \u{b7} =~@45 \u{b7} RegexStr@48:// \u{b7} Str@50:view/ \u{b7} (@55 \u{b7} Str@56:jarrr \u{b7} ErrorToken@61:| \u{b7} Str@62:doooor \u{b7} ErrorToken@68:| \u{b7} Str@69:bees \u{b7} )@73 \u{b7} RegexStr@74:/(web|templates)/ \u{b7} ErrorToken@91:/ && resourceExtname in foo.Bar \u{b7} EOF@122");
    }

    /** vscode: foo =~ /file:// || bar */
    function testFooFileBar() {
        checkScan("foo =~ /file:// || bar", "Str@0:foo \u{b7} =~@4 \u{b7} RegexStr@7:/file:/ \u{b7} ErrorToken@14:/ || bar \u{b7} EOF@22");
    }

}
