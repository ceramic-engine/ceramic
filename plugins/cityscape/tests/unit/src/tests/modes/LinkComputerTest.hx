// Ported from vscode src/vs/editor/test/common/modes/linkComputer.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes;

import cityscape.common.Languages.ILink;
import cityscape.common.languages.LinkComputer;
import haxe.PosInfos;
import testing.TestCase;

private class SimpleLinkComputerTarget implements ILinkComputerTarget {

    final _lines:Array<String>;

    public function new(_lines:Array<String>) {
        this._lines = _lines;
    }

    public function getLineCount():Int {
        return this._lines.length;
    }

    public function getLineContent(lineNumber:Int):String {
        return this._lines[lineNumber - 1];
    }
}

/**
 * suite('Editor Modes - Link Computer'): every test, same expected values.
 */
class LinkComputerTest extends TestCase {

    function myComputeLinks(lines:Array<String>):Array<ILink> {
        final target = new SimpleLinkComputerTarget(lines);
        return LinkComputerUtils.computeLinks(target);
    }

    function assertLink(text:String, extractedLink:String, ?pos:PosInfos):Void {
        var startColumn = 0;
        var endColumn = 0;

        for (i in 0...extractedLink.length) {
            final chr = extractedLink.charAt(i);
            if (chr != ' ' && chr != '\t') {
                startColumn = i + 1;
                break;
            }
        }

        var i = extractedLink.length - 1;
        while (i >= 0) {
            final chr = extractedLink.charAt(i);
            if (chr != ' ' && chr != '\t') {
                endColumn = i + 2;
                break;
            }
            i--;
        }

        final r = myComputeLinks([text]);
        assertEquals(1, r.length, text, pos);
        assertDeepEquals({
            startLineNumber: 1,
            startColumn: startColumn,
            endLineNumber: 1,
            endColumn: endColumn
        }, {
            startLineNumber: r[0].range.startLineNumber,
            startColumn: r[0].range.startColumn,
            endLineNumber: r[0].range.endLineNumber,
            endColumn: r[0].range.endColumn
        }, text, pos);
        final url:String = cast r[0].url;
        assertEquals(extractedLink.substring(startColumn - 1, endColumn - 1), url, text, pos);
    }

    function testNullModel() {
        final r = LinkComputerUtils.computeLinks(null);
        assertEquals(0, r.length);
    }

    function testParsing() {

        assertLink(
            'x = "http://foo.bar";',
            '     http://foo.bar  '
        );

        assertLink(
            'x = (http://foo.bar);',
            '     http://foo.bar  '
        );

        assertLink(
            'x = [http://foo.bar];',
            '     http://foo.bar  '
        );

        assertLink(
            'x = \'http://foo.bar\';',
            '     http://foo.bar  '
        );

        assertLink(
            'x =  http://foo.bar ;',
            '     http://foo.bar  '
        );

        assertLink(
            'x = <http://foo.bar>;',
            '     http://foo.bar  '
        );

        assertLink(
            'x = {http://foo.bar};',
            '     http://foo.bar  '
        );

        assertLink(
            '(see http://foo.bar)',
            '     http://foo.bar  '
        );
        assertLink(
            '[see http://foo.bar]',
            '     http://foo.bar  '
        );
        assertLink(
            '{see http://foo.bar}',
            '     http://foo.bar  '
        );
        assertLink(
            '<see http://foo.bar>',
            '     http://foo.bar  '
        );
        assertLink(
            '<url>http://mylink.com</url>',
            '     http://mylink.com      '
        );
        assertLink(
            '// Click here to learn more. https://go.microsoft.com/fwlink/?LinkID=513275&clcid=0x409',
            '                             https://go.microsoft.com/fwlink/?LinkID=513275&clcid=0x409'
        );
        assertLink(
            '// Click here to learn more. https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx',
            '                             https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx'
        );
        assertLink(
            '// https://github.com/projectkudu/kudu/blob/master/Kudu.Core/Scripts/selectNodeVersion.js',
            '   https://github.com/projectkudu/kudu/blob/master/Kudu.Core/Scripts/selectNodeVersion.js'
        );
        assertLink(
            '<!-- !!! Do not remove !!!   WebContentRef(link:https://go.microsoft.com/fwlink/?LinkId=166007, area:Admin, updated:2015, nextUpdate:2016, tags:SqlServer)   !!! Do not remove !!! -->',
            '                                                https://go.microsoft.com/fwlink/?LinkId=166007                                                                                        '
        );
        assertLink(
            'For instructions, see https://go.microsoft.com/fwlink/?LinkId=166007.</value>',
            '                      https://go.microsoft.com/fwlink/?LinkId=166007         '
        );
        assertLink(
            'For instructions, see https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx.</value>',
            '                      https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx         '
        );
        assertLink(
            'x = "https://en.wikipedia.org/wiki/Zürich";',
            '     https://en.wikipedia.org/wiki/Zürich  '
        );
        assertLink(
            '請參閱 http://go.microsoft.com/fwlink/?LinkId=761051。',
            '    http://go.microsoft.com/fwlink/?LinkId=761051 '
        );
        assertLink(
            '（請參閱 http://go.microsoft.com/fwlink/?LinkId=761051）',
            '     http://go.microsoft.com/fwlink/?LinkId=761051 '
        );

        assertLink(
            'x = "file:///foo.bar";',
            '     file:///foo.bar  '
        );
        assertLink(
            'x = "file://c:/foo.bar";',
            '     file://c:/foo.bar  '
        );

        assertLink(
            'x = "file://shares/foo.bar";',
            '     file://shares/foo.bar  '
        );

        assertLink(
            'x = "file://shäres/foo.bar";',
            '     file://shäres/foo.bar  '
        );
        assertLink(
            'Some text, then http://www.bing.com.',
            '                http://www.bing.com '
        );
        assertLink(
            'let url = `http://***/_api/web/lists/GetByTitle(\'Teambuildingaanvragen\')/items`;',
            '           http://***/_api/web/lists/GetByTitle(\'Teambuildingaanvragen\')/items  '
        );
    }

    function testIssue7855() {
        assertLink(
            '7. At this point, ServiceMain has been called.  There is no functionality presently in ServiceMain, but you can consult the [MSDN documentation](https://msdn.microsoft.com/en-us/library/windows/desktop/ms687414(v=vs.85).aspx) to add functionality as desired!',
            '                                                                                                                                                 https://msdn.microsoft.com/en-us/library/windows/desktop/ms687414(v=vs.85).aspx                                  '
        );
    }

    function testIssue62278CtrlClickToFollowLinkForIPv6Urls() {
        assertLink(
            'let x = "http://[::1]:5000/connect/token"',
            '         http://[::1]:5000/connect/token  '
        );
    }

    function testIssue70254BoldLinksDontOpenInMarkdownFileUsingEditorModeWithCtrlClick() {
        assertLink(
            '2. Navigate to **https://portal.azure.com**',
            '                 https://portal.azure.com  '
        );
    }

    function testIssue86358UrlWrongRecognitionPattern() {
        assertLink(
            'POST|https://portal.azure.com|2019-12-05|',
            '     https://portal.azure.com            '
        );
    }

    function testIssue67022SpaceAsEndOfHyperlinkIsntAlwaysGoodIdea() {
        assertLink(
            'aa  https://foo.bar/[this is foo site]  aa',
            '    https://foo.bar/[this is foo site]    '
        );
    }

    function testIssue100353LinkDetectionStopsAtDoubleByteAmpersand() {
        assertLink(
            'aa  http://tree-mark.chips.jp/レーズン＆ベリーミックス  aa',
            '    http://tree-mark.chips.jp/レーズン＆ベリーミックス    '
        );
    }

    function testIssue121438LinkDetectionStopsAtLenticularBrackets() {
        assertLink(
            'aa  https://zh.wikipedia.org/wiki/【我推的孩子】 aa',
            '    https://zh.wikipedia.org/wiki/【我推的孩子】   '
        );
    }

    function testIssue121438LinkDetectionStopsAtDoubleAngleBrackets() {
        assertLink(
            'aa  https://zh.wikipedia.org/wiki/《新青年》编辑部旧址 aa',
            '    https://zh.wikipedia.org/wiki/《新青年》编辑部旧址   '
        );
    }

    function testIssue121438LinkDetectionStopsAtQuotes() {
        assertLink(
            'aa  https://zh.wikipedia.org/wiki/“常凯申”误译事件 aa',
            '    https://zh.wikipedia.org/wiki/“常凯申”误译事件   '
        );
    }

    function testIssue150905ColonAfterBareHyperlinkIsTreatedAsItsPart() {
        assertLink(
            'https://site.web/page.html: blah blah blah',
            'https://site.web/page.html                '
        );
    }

    function testIssue156875LinksIncludeQuotes() {
        assertLink(
            '"This file has been converted from https://github.com/jeff-hykin/better-c-syntax/blob/master/autogenerated/c.tmLanguage.json",',
            '                                   https://github.com/jeff-hykin/better-c-syntax/blob/master/autogenerated/c.tmLanguage.json  '
        );
    }

}
