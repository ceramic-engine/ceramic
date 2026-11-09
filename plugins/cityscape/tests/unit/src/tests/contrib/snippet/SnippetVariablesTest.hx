// Ported from vscode src/vs/editor/contrib/snippet/test/browser/snippetVariables.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.snippet;

// Classes of this module:
// - SnippetVariablesTest
//
// All the tests are ported, with the paths of a posix system (vscode's
// `!isWindows` branches). The label services of vscode's tests are small
// classes (`mock<ILabelService>`). 'Time-based snippet variables resolve to
// the same values even as time progresses' cannot fake the clock (sinon):
// it resolves twice with the same resolver, a second later, and checks the
// values did not change. 'Add workspace name and folder variables' builds
// the multi root workspace by hand (vscode's `toWorkspaceFolders` is not
// ported: the folders of a workspace with a configuration are not read by
// the resolver).

import cityscape.base.common.Uri;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.snippet.view.SnippetParser;
import cityscape.contrib.snippet.view.SnippetVariables;
import cityscape.platform.label.common.Label;
import cityscape.platform.workspace.common.Workspace;
import testing.TestCase;
import tests.TestTextModel;

private class FsPathLabelService implements ILabelService {
    public function new() {}

    public function getUriLabel(uri:Uri, ?options:UriLabelOptions):String {
        return uri.fsPath;
    }

    public function getUriBasenameLabel(uri:Uri):String {
        throw 'not implemented';
    }
}

private class PipeLabelService implements ILabelService {
    public function new() {}

    public function getUriLabel(uri:Uri, ?options:UriLabelOptions):String {
        // uri.fsPath.replace(/\/|\\/g, '|')
        return StringTools.replace(StringTools.replace(uri.fsPath, '/', '|'), '\\', '|');
    }

    public function getUriBasenameLabel(uri:Uri):String {
        throw 'not implemented';
    }
}

/**
 * Mock a label service (only coded for file uris)
 */
private class WorkspaceLabelService implements ILabelService {
    final rootPath:String;

    public function new(rootPath:String) {
        this.rootPath = rootPath;
    }

    public function getUriLabel(uri:Uri, ?options:UriLabelOptions):String {
        final rootFsPath = Uri.file(rootPath).fsPath + '/';
        final fsPath = uri.fsPath;
        if (options != null && options.relative == true && rootPath.length > 0 && StringTools.startsWith(fsPath, rootFsPath)) {
            return fsPath.substring(rootFsPath.length);
        }
        return fsPath;
    }

    public function getUriBasenameLabel(uri:Uri):String {
        throw 'not implemented';
    }
}

private class ConstantResolver implements VariableResolver {
    final fn:(variable:Variable) -> Null<String>;

    public function new(fn:(variable:Variable) -> Null<String>) {
        this.fn = fn;
    }

    public function resolve(variable:Variable):Null<String> {
        return fn(variable);
    }
}

private class TestWorkspaceService implements IWorkspaceContextService {
    public var workspace:Null<IWorkspace> = null;

    public function new() {}

    public function getWorkspace():IWorkspace {
        return workspace;
    }
}

/**
 * suite('Snippet Variables Resolver')
 */
class SnippetVariablesTest extends TestCase {

    final labelService:ILabelService = new FsPathLabelService();

    var model:TextModel;
    var resolver:VariableResolver;

    override public function setup():Void {
        model = TestTextModel.createTextModel([
            'this is line one',
            'this is line two',
            '    this is line three'
        ].join('\n'), null, null, Uri.parse('file:///foo/files/text.txt'));

        resolver = new CompositeSnippetVariableResolver([
            new ModelBasedVariableResolver(labelService, model),
            new SelectionBasedVariableResolver(model, new Selection(1, 1, 1, 1), 0, null),
        ]);
    }

    override public function teardown():Void {
        model.dispose();
    }

    function assertVariableResolve(resolver:VariableResolver, varName:String, expected:Null<String>, ?pos:haxe.PosInfos) {
        final snippet = new SnippetParser().parse("$" + varName);
        final variable:Variable = cast snippet.children[0];
        variable.resolve(resolver);
        if (variable.children.length == 0) {
            assertEquals(null, expected, varName, pos);
        }
        else {
            assertEquals(expected, variable.toString(), varName, pos);
        }
    }

    function testEditorVariablesBasics() {
        assertVariableResolve(resolver, 'TM_FILENAME', 'text.txt');
        assertVariableResolve(resolver, 'something', null);
    }

    function testEditorVariablesFileDir() {

        final models:Array<TextModel> = [];

        assertVariableResolve(resolver, 'TM_FILENAME', 'text.txt');
        assertVariableResolve(resolver, 'TM_DIRECTORY', '/foo/files');
        assertVariableResolve(resolver, 'TM_FILEPATH', '/foo/files/text.txt');

        var m = TestTextModel.createTextModel('', null, null, Uri.parse('http://www.pb.o/abc/def/ghi'));
        models.push(m);
        resolver = new ModelBasedVariableResolver(labelService, m);
        assertVariableResolve(resolver, 'TM_FILENAME', 'ghi');
        assertVariableResolve(resolver, 'TM_DIRECTORY', '/abc/def');
        assertVariableResolve(resolver, 'TM_FILEPATH', '/abc/def/ghi');

        m = TestTextModel.createTextModel('', null, null, Uri.parse('mem:fff.ts'));
        models.push(m);
        resolver = new ModelBasedVariableResolver(labelService, m);
        assertVariableResolve(resolver, 'TM_DIRECTORY', '');
        assertVariableResolve(resolver, 'TM_FILEPATH', 'fff.ts');

        for (m in models) {
            m.dispose();
        }
    }

    function testPathDelimitersInCodeSnippetVariablesArentSpecificToRemoteOS76840() {

        final labelService = new PipeLabelService();

        final model = TestTextModel.createTextModel([].join('\n'), null, null, Uri.parse('foo:///foo/files/text.txt'));

        final resolver = new CompositeSnippetVariableResolver([new ModelBasedVariableResolver(labelService, model)]);

        assertVariableResolve(resolver, 'TM_FILEPATH', '|foo|files|text.txt');

        model.dispose();
    }

    function testEditorVariablesSelection() {

        resolver = new SelectionBasedVariableResolver(model, new Selection(1, 2, 2, 3), 0, null);
        assertVariableResolve(resolver, 'TM_SELECTED_TEXT', 'his is line one\nth');
        assertVariableResolve(resolver, 'TM_CURRENT_LINE', 'this is line two');
        assertVariableResolve(resolver, 'TM_LINE_INDEX', '1');
        assertVariableResolve(resolver, 'TM_LINE_NUMBER', '2');
        assertVariableResolve(resolver, 'CURSOR_INDEX', '0');
        assertVariableResolve(resolver, 'CURSOR_NUMBER', '1');

        resolver = new SelectionBasedVariableResolver(model, new Selection(1, 2, 2, 3), 4, null);
        assertVariableResolve(resolver, 'CURSOR_INDEX', '4');
        assertVariableResolve(resolver, 'CURSOR_NUMBER', '5');

        resolver = new SelectionBasedVariableResolver(model, new Selection(2, 3, 1, 2), 0, null);
        assertVariableResolve(resolver, 'TM_SELECTED_TEXT', 'his is line one\nth');
        assertVariableResolve(resolver, 'TM_CURRENT_LINE', 'this is line one');
        assertVariableResolve(resolver, 'TM_LINE_INDEX', '0');
        assertVariableResolve(resolver, 'TM_LINE_NUMBER', '1');

        resolver = new SelectionBasedVariableResolver(model, new Selection(1, 2, 1, 2), 0, null);
        assertVariableResolve(resolver, 'TM_SELECTED_TEXT', null);

        assertVariableResolve(resolver, 'TM_CURRENT_WORD', 'this');

        resolver = new SelectionBasedVariableResolver(model, new Selection(3, 1, 3, 1), 0, null);
        assertVariableResolve(resolver, 'TM_CURRENT_WORD', null);
    }

    function testTextmateSnippetResolveVariable() {
        final snippet = new SnippetParser().parse("\"$TM_CURRENT_WORD\"", true);
        assertEquals('""', snippet.toString());
        snippet.resolveVariables(resolver);
        assertEquals('"this"', snippet.toString());
    }

    function testTextmateSnippetResolveVariableWithDefault() {
        final snippet = new SnippetParser().parse("\"${TM_CURRENT_WORD:foo}\"", true);
        assertEquals('"foo"', snippet.toString());
        snippet.resolveVariables(resolver);
        assertEquals('"this"', snippet.toString());
    }

    function testMoreUsefulEnvironmentVariablesForSnippets32737() {

        final models:Array<TextModel> = [];

        assertVariableResolve(resolver, 'TM_FILENAME_BASE', 'text');

        var m = TestTextModel.createTextModel('', null, null, Uri.parse('http://www.pb.o/abc/def/ghi'));
        models.push(m);
        resolver = new ModelBasedVariableResolver(labelService, m);
        assertVariableResolve(resolver, 'TM_FILENAME_BASE', 'ghi');

        m = TestTextModel.createTextModel('', null, null, Uri.parse('mem:.git'));
        models.push(m);
        resolver = new ModelBasedVariableResolver(labelService, m);
        assertVariableResolve(resolver, 'TM_FILENAME_BASE', '.git');

        m = TestTextModel.createTextModel('', null, null, Uri.parse('mem:foo.'));
        models.push(m);
        resolver = new ModelBasedVariableResolver(labelService, m);
        assertVariableResolve(resolver, 'TM_FILENAME_BASE', 'foo');

        for (m in models) {
            m.dispose();
        }
    }

    function assertVariableResolve2(input:String, expected:String, ?varValue:String, ?pos:haxe.PosInfos) {
        final snippet = new SnippetParser().parse(input)
            .resolveVariables(new ConstantResolver(variable -> varValue != null && varValue.length > 0 ? varValue : variable.name));

        final actual = snippet.toString();
        assertEquals(expected, actual, input, pos);
    }

    function testVariableSnippetTransform() {

        final snippet = new SnippetParser().parse("name=${TM_FILENAME/(.*)\\..+$/$1/}", true);
        snippet.resolveVariables(resolver);
        assertEquals('name=text', snippet.toString());

        assertVariableResolve2("${ThisIsAVar/([A-Z]).*(Var)/$2/}", 'Var');
        assertVariableResolve2("${ThisIsAVar/([A-Z]).*(Var)/$2-${1:/downcase}/}", 'Var-t');
        assertVariableResolve2("${Foo/(.*)/${1:+Bar}/img}", 'Bar');

        //https://github.com/microsoft/vscode/issues/33162
        assertVariableResolve2("export default class ${TM_FILENAME/(\\w+)\\.js/$1/g}", 'export default class FooFile', 'FooFile.js');

        assertVariableResolve2("${foobarfoobar/(foo)/${1:+FAR}/g}", 'FARbarFARbar'); // global
        assertVariableResolve2("${foobarfoobar/(foo)/${1:+FAR}/}", 'FARbarfoobar'); // first match
        assertVariableResolve2("${foobarfoobar/(bazz)/${1:+FAR}/g}", 'foobarfoobar'); // no match, no else
        // assertVariableResolve2('${foobarfoobar/(bazz)/${1:+FAR}/g}', ''); // no match

        assertVariableResolve2("${foobarfoobar/(foo)/${2:+FAR}/g}", 'barbar'); // bad group reference
    }

    function testSnippetTransformsDoNotHandleRegexWithAlternativesOrOptionalMatches36089() {

        assertVariableResolve2(
            "${TM_FILENAME/^(.)|(?:-(.))|(\\.js)/${1:/upcase}${2:/upcase}/g}",
            'MyClass',
            'my-class.js'
        );

        // no hyphens
        assertVariableResolve2(
            "${TM_FILENAME/^(.)|(?:-(.))|(\\.js)/${1:/upcase}${2:/upcase}/g}",
            'Myclass',
            'myclass.js'
        );

        // none matching suffix
        assertVariableResolve2(
            "${TM_FILENAME/^(.)|(?:-(.))|(\\.js)/${1:/upcase}${2:/upcase}/g}",
            'Myclass.foo',
            'myclass.foo'
        );

        // more than one hyphen
        assertVariableResolve2(
            "${TM_FILENAME/^(.)|(?:-(.))|(\\.js)/${1:/upcase}${2:/upcase}/g}",
            'ThisIsAFile',
            'this-is-a-file.js'
        );

        // KEBAB CASE
        assertVariableResolve2(
            "${TM_FILENAME_BASE/([A-Z][a-z]+)([A-Z][a-z]+$)?/${1:/downcase}-${2:/downcase}/g}",
            'capital-case',
            'CapitalCase'
        );

        assertVariableResolve2(
            "${TM_FILENAME_BASE/([A-Z][a-z]+)([A-Z][a-z]+$)?/${1:/downcase}-${2:/downcase}/g}",
            'capital-case-more',
            'CapitalCaseMore'
        );
    }

    function testAddVariableToInsertValueFromClipboardToASnippet40153() {

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> null, 1, 0, true), 'CLIPBOARD', null);

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> null, 1, 0, true), 'CLIPBOARD', null);

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> '', 1, 0, true), 'CLIPBOARD', null);

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'foo', 1, 0, true), 'CLIPBOARD', 'foo');

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'foo', 1, 0, true), 'foo', null);
        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'foo', 1, 0, true), 'cLIPBOARD', null);
    }

    function testAddVariableToInsertValueFromClipboardToASnippet40153_2() {

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'line1', 1, 2, true), 'CLIPBOARD', 'line1');
        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'line1\nline2\nline3', 1, 2, true), 'CLIPBOARD', 'line1\nline2\nline3');

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'line1\nline2', 1, 2, true), 'CLIPBOARD', 'line2');
        resolver = new ClipboardBasedVariableResolver(() -> 'line1\nline2', 0, 2, true);
        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'line1\nline2', 0, 2, true), 'CLIPBOARD', 'line1');

        assertVariableResolve(new ClipboardBasedVariableResolver(() -> 'line1\nline2', 0, 2, false), 'CLIPBOARD', 'line1\nline2');
    }

    function assertVariableResolve3(resolver:VariableResolver, varName:String, ?pos:haxe.PosInfos) {
        final snippet = new SnippetParser().parse("$" + varName);
        final variable:Variable = cast snippet.children[0];

        assertEquals(true, variable.resolve(resolver), "$varName failed to resolve", pos);
    }

    function testAddTimeVariablesForSnippets41631_43140() {

        final resolver = new TimeBasedVariableResolver();

        assertVariableResolve3(resolver, 'CURRENT_YEAR');
        assertVariableResolve3(resolver, 'CURRENT_YEAR_SHORT');
        assertVariableResolve3(resolver, 'CURRENT_MONTH');
        assertVariableResolve3(resolver, 'CURRENT_DATE');
        assertVariableResolve3(resolver, 'CURRENT_HOUR');
        assertVariableResolve3(resolver, 'CURRENT_MINUTE');
        assertVariableResolve3(resolver, 'CURRENT_SECOND');
        assertVariableResolve3(resolver, 'CURRENT_DAY_NAME');
        assertVariableResolve3(resolver, 'CURRENT_DAY_NAME_SHORT');
        assertVariableResolve3(resolver, 'CURRENT_MONTH_NAME');
        assertVariableResolve3(resolver, 'CURRENT_MONTH_NAME_SHORT');
        assertVariableResolve3(resolver, 'CURRENT_SECONDS_UNIX');
        assertVariableResolve3(resolver, 'CURRENT_TIMEZONE_OFFSET');
    }

    function asyncTestTimeBasedSnippetVariablesResolveToTheSameValuesEvenAsTimeProgresses(done:() -> Void) {
        final snippetText = "
			$CURRENT_YEAR
			$CURRENT_YEAR_SHORT
			$CURRENT_MONTH
			$CURRENT_DATE
			$CURRENT_HOUR
			$CURRENT_MINUTE
			$CURRENT_SECOND
			$CURRENT_DAY_NAME
			$CURRENT_DAY_NAME_SHORT
			$CURRENT_MONTH_NAME
			$CURRENT_MONTH_NAME_SHORT
			$CURRENT_SECONDS_UNIX
			$CURRENT_TIMEZONE_OFFSET
		";

        final resolver = new TimeBasedVariableResolver();

        final firstResolve = new SnippetParser().parse(snippetText).resolveVariables(resolver);
        // the clock cannot be faked: wait a second instead of a year, a day, an hour, a minute and a second
        ceramic.Timer.delay(null, 1.1, () -> {
            final secondResolve = new SnippetParser().parse(snippetText).resolveVariables(resolver);
            assertEquals(firstResolve.toString(), secondResolve.toString(), 'Time-based snippet variables resolved differently');
            done();
        });
    }

    /**
     * Not in vscode: the formats of the time variables (vscode only checks
     * that they resolve), and `CURRENT_TIMEZONE_OFFSET` against the
     * offset of JavaScript's `Date`.
     */
    function testTimeVariablesFormats() {
        final resolver = new TimeBasedVariableResolver();
        function value(name:String):String {
            final snippet = new SnippetParser().parse("$" + name);
            snippet.resolveVariables(resolver);
            return snippet.toString();
        }
        assertTrue(~/^[0-9]{4}$/.match(value('CURRENT_YEAR')));
        assertTrue(~/^[0-9]{2}$/.match(value('CURRENT_YEAR_SHORT')));
        assertTrue(~/^(0[1-9]|1[0-2])$/.match(value('CURRENT_MONTH')));
        assertTrue(~/^(0[1-9]|[12][0-9]|3[01])$/.match(value('CURRENT_DATE')));
        assertTrue(~/^([01][0-9]|2[0-3])$/.match(value('CURRENT_HOUR')));
        assertTrue(~/^[0-5][0-9]$/.match(value('CURRENT_MINUTE')));
        assertTrue(~/^[0-5][0-9]$/.match(value('CURRENT_SECOND')));
        assertTrue(['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'].indexOf(value('CURRENT_DAY_NAME')) >= 0);
        assertTrue(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(value('CURRENT_DAY_NAME_SHORT')) >= 0);
        assertTrue(~/^[0-9]+$/.match(value('CURRENT_SECONDS_UNIX')));
        assertTrue(~/^[+-][0-9]{2}:[0-9]{2}$/.match(value('CURRENT_TIMEZONE_OFFSET')));
        #if js
        final offset:Int = js.Syntax.code('new Date().getTimezoneOffset()');
        #else
        final offset = TimeBasedVariableResolver.getTimezoneOffset(Date.now());
        #end
        final tz = value('CURRENT_TIMEZONE_OFFSET');
        final minutes = (Std.parseInt(tz.substr(1, 2)) * 60 + Std.parseInt(tz.substr(4, 2))) * (tz.charAt(0) == '+' ? -1 : 1);
        assertEquals(offset, minutes);
        // `Math.random().toString().slice(-6)` and `.toString(16).slice(-6)`
        assertTrue(~/^[0-9]{6}$/.match(new SnippetParser().parse("$RANDOM").resolveVariables(new RandomBasedVariableResolver()).toString()));
        assertTrue(~/^[0-9a-f]{6}$/.match(new SnippetParser().parse("$RANDOM_HEX").resolveVariables(new RandomBasedVariableResolver()).toString()));
        assertTrue(~/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.match(new SnippetParser().parse("$UUID").resolveVariables(new RandomBasedVariableResolver()).toString()));
    }

    function testCreatingSnippetFormatConditionDoesntWork53617() {

        final snippet = new SnippetParser().parse("${TM_LINE_NUMBER/(10)/${1:?It is:It is not}/} line 10", true);
        snippet.resolveVariables(new ConstantResolver(_ -> '10'));
        assertEquals('It is line 10', snippet.toString());

        snippet.resolveVariables(new ConstantResolver(_ -> '11'));
        assertEquals('It is not line 10', snippet.toString());
    }

    function testAddWorkspaceNameAndFolderVariablesForSnippets68261() {

        final workspaceService = new TestWorkspaceService();

        final resolver = new WorkspaceBasedVariableResolver(workspaceService);

        // empty workspace
        workspaceService.workspace = {id: '', folders: []};
        assertVariableResolve(resolver, 'WORKSPACE_NAME', null);
        assertVariableResolve(resolver, 'WORKSPACE_FOLDER', null);

        // single folder workspace without config
        workspaceService.workspace = {id: '', folders: [WorkspaceUtils.toWorkspaceFolder(Uri.file('/folderName'))]};
        assertVariableResolve(resolver, 'WORKSPACE_NAME', 'folderName');
        assertVariableResolve(resolver, 'WORKSPACE_FOLDER', '/folderName');

        // workspace with config
        final workspaceConfigPath = Uri.file('testWorkspace.code-workspace');
        workspaceService.workspace = {id: '', folders: [WorkspaceUtils.toWorkspaceFolder(Uri.file('/folderName'))], configuration: workspaceConfigPath};
        assertVariableResolve(resolver, 'WORKSPACE_NAME', 'testWorkspace');
        assertVariableResolve(resolver, 'WORKSPACE_FOLDER', '/');
    }

    /**
     * Not in vscode: Monaco's standalone workspace (one folder,
     * `inmemory://model/`) gives an empty `WORKSPACE_NAME` and `/` as
     * `WORKSPACE_FOLDER`.
     */
    function testStandaloneWorkspaceVariables() {
        final resolver = new WorkspaceBasedVariableResolver(new cityscape.standalone.StandaloneServices.StandaloneWorkspaceContextService());
        assertVariableResolve(resolver, 'WORKSPACE_NAME', '');
        assertVariableResolve(resolver, 'WORKSPACE_FOLDER', '/');
    }

    function testAddRELATIVEFILEPATHSnippetVariable114208() {

        var resolver:VariableResolver;

        final model = TestTextModel.createTextModel('', null, null, Uri.parse('file:///foo/files/text.txt'));

        // empty workspace
        resolver = new ModelBasedVariableResolver(new WorkspaceLabelService(''), model);

        assertVariableResolve(resolver, 'RELATIVE_FILEPATH', '/foo/files/text.txt');

        // single folder workspace
        resolver = new ModelBasedVariableResolver(new WorkspaceLabelService('/foo'), model);
        assertVariableResolve(resolver, 'RELATIVE_FILEPATH', 'files/text.txt');

        model.dispose();
    }

    /**
     * Not in vscode: Monaco's standalone label service gives the file system
     * path of a `file` URI and the path of the others (`RELATIVE_FILEPATH`
     * too).
     */
    function testStandaloneLabelService() {
        final labels = new cityscape.standalone.StandaloneServices.StandaloneUriLabelService();
        final m = TestTextModel.createTextModel('', null, null, Uri.parse('inmemory://model/1'));
        final resolver = new ModelBasedVariableResolver(labels, m);
        assertVariableResolve(resolver, 'TM_FILENAME', '1');
        assertVariableResolve(resolver, 'TM_FILEPATH', '/1');
        assertVariableResolve(resolver, 'RELATIVE_FILEPATH', '/1');
        assertVariableResolve(resolver, 'TM_DIRECTORY', '/');
        m.dispose();
        assertVariableResolve(new ModelBasedVariableResolver(labels, model), 'TM_DIRECTORY', '/foo/files');
    }

}
