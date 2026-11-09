// Ported from vscode src/vs/editor/contrib/links/browser/links.ts and links.css
// (with the default link provider of src/vs/editor/browser/services/editorWorkerService.ts)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.links.view;

import cityscape.Cityscape;
import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.Languages.ILinksList;
import cityscape.common.Languages.LinkProvider;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.services.EditorSimpleWorker;
import cityscape.common.services.LanguageFeatureDebounce.FeatureDebounceInformation;
import cityscape.contrib.gotoSymbol.view.GoToCommands.ClickLinkGesture;
import cityscape.contrib.gotoSymbol.view.GoToCommands.ClickLinkKeyboardEvent;
import cityscape.contrib.gotoSymbol.view.GoToCommands.ClickLinkMouseEvent;
import cityscape.contrib.links.view.GetLinks;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;
import cityscape.view.EditorWidgets;
import haxe.extern.EitherType;

/**
 * Detects the links of the model (the link providers, and the default link
 * computer for every language), underlines them (`detected-link`), and
 * opens the one under the mouse on Cmd+click (Ctrl+click, or Alt+click with
 * `multiCursorModifier: 'ctrlCmd'`), the link under Cmd being
 * `detected-link-active` with the pointer cursor (Monaco's `LinkDetector`).
 * Links open through the context's opener (`Cityscape.openLink`, then
 * Monaco's default openers). Monaco's notification of a link that fails to
 * open goes to `Cityscape.onNoResult`.
 */
class LinkDetector extends Disposable implements IEditorContribution {

    public static inline final ID:String = 'editor.linkDetector';

    public static function get(editor:ICodeEditor):Null<LinkDetector> {
        return editor.getContribution(LinkDetector.ID);
    }

    final editor:ICodeEditor;
    final r:EditorExtensionsRegistry;
    final providers:LanguageFeatureRegistry<LinkProvider>;
    final debounceInformation:FeatureDebounceInformation;
    final computeLinks:RunOnceScheduler;
    var computePromise:Null<CancellationTokenSource>;
    var activeLinksList:Null<LinksList>;
    var activeLinkDecorationId:Null<String>;
    var currentOccurrences:Map<String, LinkOccurrence>;

    public function new(editor:ICodeEditor, r:EditorExtensionsRegistry) {
        super();
        this.editor = editor;
        this.r = r;

        this.providers = editor.context.languageFeaturesService.linkProvider;
        this.debounceInformation = new FeatureDebounceInformation(1000, 4000);
        this.computeLinks = this._register(new RunOnceScheduler(() -> this.computeLinksNow(), 1000));
        this.computePromise = null;
        this.activeLinksList = null;
        this.currentOccurrences = new Map();
        this.activeLinkDecorationId = null;

        final clickLinkGesture = this._register(new ClickLinkGesture(editor));

        this._register(clickLinkGesture.onMouseMoveOrRelevantKeyDown(e -> {
            this._onEditorMouseMove(e.mouseEvent, e.keyboardEvent);
        }));
        this._register(clickLinkGesture.onExecute(e -> {
            this.onEditorMouseUp(e);
        }));
        this._register(clickLinkGesture.onCancel(() -> {
            this.cleanUpActiveLinkDecoration();
        }));
        this._register(editor.onDidChangeConfiguration(e -> {
            if (!e.hasChanged(EditorOption.links)) {
                return;
            }
            // Remove any links (for the getting disabled case)
            this.updateDecorations([]);

            // Stop any computation (for the getting disabled case)
            this.stop();

            // Start computing (for the getting enabled case)
            this.computeLinks.schedule(0);
        }));
        this._register(editor.onDidChangeModelContent(e -> {
            if (!this.editor.hasModel()) {
                return;
            }
            this.computeLinks.schedule(this.debounceInformation.get(this.editor.getModel()));
        }));
        this._register(editor.onDidChangeModel(e -> {
            this.currentOccurrences = new Map();
            this.activeLinkDecorationId = null;
            this.stop();
            this.computeLinks.schedule(0);
        }));
        this._register(editor.onDidChangeModelLanguage(e -> {
            this.stop();
            this.computeLinks.schedule(0);
        }));
        this._register(this.providers.onDidChange(e -> {
            this.stop();
            this.computeLinks.schedule(0);
        }));

        this.computeLinks.schedule(0);
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * Runs a pending computation of the links now (tests; Monaco waits for
     * the scheduler).
     */
    public function _flushComputeLinks():Void {
        this.computeLinks.flush();
    }

    function computeLinksNow():Void {
        if (!this.editor.hasModel() || !this.editor.getOption(EditorOption.links)) {
            return;
        }

        final model = this.editor.getModel();

        if (model.isTooLargeForSyncing()) {
            return;
        }

        if (!this.providers.has(model)) {
            return;
        }

        if (this.activeLinksList != null) {
            this.activeLinksList.dispose();
            this.activeLinksList = null;
        }

        final source = new CancellationTokenSource();
        this.computePromise = source;
        final start = haxe.Timer.stamp();
        GetLinks.getLinks(this.providers, model, source.token).done(list -> {
            if (source.token.isCancellationRequested) {
                // createCancelablePromise rejects when cancelled
                if (list != null) {
                    list.dispose();
                }
                return;
            }
            this.activeLinksList = list;
            this.debounceInformation.update(model, (haxe.Timer.stamp() - start) * 1000);
            if (this.computePromise == source) {
                this.computePromise = null;
            }
            if (model.isDisposed()) {
                return;
            }
            this.updateDecorations(list.links);
        }, err -> {
            if (this.computePromise == source) {
                this.computePromise = null;
            }
            Errors.onUnexpectedError(err);
        });
    }

    function updateDecorations(links:Array<Link>):Void {
        final useMetaKey = (this.editor.getOption(EditorOption.multiCursorModifier) == 'altKey');
        final oldDecorations:Array<String> = [];
        for (decorationId in this.currentOccurrences.keys()) {
            final occurence = this.currentOccurrences.get(decorationId);
            oldDecorations.push(occurence.decorationId);
        }

        final hadActiveLink = this.activeLinkDecorationId != null;

        final newDecorations:Array<IModelDeltaDecoration> = [];
        if (links != null) {
            // Not sure why this is sometimes null
            for (link in links) {
                newDecorations.push(LinkOccurrence.decoration(r, link, useMetaKey));
            }
        }

        this.editor.changeDecorations(changeAccessor -> {
            final decorations = changeAccessor.deltaDecorations(oldDecorations, newDecorations);

            this.currentOccurrences = new Map();
            this.activeLinkDecorationId = null;
            for (i in 0...decorations.length) {
                final occurence = new LinkOccurrence(links[i], decorations[i]);
                this.currentOccurrences.set(occurence.decorationId, occurence);
            }
            return null;
        });
        if (hadActiveLink) {
            EditorWidgets.setMouseCursor(this.editor, null);
        }
    }

    function _onEditorMouseMove(mouseEvent:ClickLinkMouseEvent, withKey:Null<ClickLinkKeyboardEvent>):Void {
        final useMetaKey = (this.editor.getOption(EditorOption.multiCursorModifier) == 'altKey');
        if (this.isEnabled(mouseEvent, withKey)) {
            this.cleanUpActiveLinkDecoration(); // always remove previous link decoration as their can only be one
            final occurrence = this.getLinkOccurrence(mouseEvent.target.position);
            if (occurrence != null) {
                this.editor.changeDecorations(changeAccessor -> {
                    occurrence.activate(r, changeAccessor, useMetaKey);
                    this.activeLinkDecorationId = occurrence.decorationId;
                    return null;
                });
                // links.css: `.detected-link-active { cursor: pointer }`
                EditorWidgets.setMouseCursor(this.editor, glaze.CursorStyle.PointingHand);
            }
        }
        else {
            this.cleanUpActiveLinkDecoration();
        }
    }

    function cleanUpActiveLinkDecoration():Void {
        final useMetaKey = (this.editor.getOption(EditorOption.multiCursorModifier) == 'altKey');
        if (this.activeLinkDecorationId != null) {
            final occurrence = this.currentOccurrences.get(this.activeLinkDecorationId);
            if (occurrence != null) {
                this.editor.changeDecorations(changeAccessor -> {
                    occurrence.deactivate(r, changeAccessor, useMetaKey);
                    return null;
                });
            }

            this.activeLinkDecorationId = null;
            EditorWidgets.setMouseCursor(this.editor, null);
        }
    }

    function onEditorMouseUp(mouseEvent:ClickLinkMouseEvent):Void {
        if (!this.isEnabled(mouseEvent)) {
            return;
        }
        final occurrence = this.getLinkOccurrence(mouseEvent.target.position);
        if (occurrence == null) {
            return;
        }
        this.openLinkOccurrence(occurrence, mouseEvent.hasSideBySideModifier, true /* from user gesture */);
    }

    public function openLinkOccurrence(occurrence:LinkOccurrence, openToSide:Bool, fromUserGesture:Bool = false):Void {

        final link = occurrence.link;

        link.resolve(CancellationTokens.None).done(resolved -> {
            var uri:EitherType<Uri, String> = resolved;

            // Support for relative file URIs of the shape file://./relativeFile.txt or file:///./relativeFile.txt
            if (Std.isOfType(uri, std.String) && this.editor.hasModel()) {
                final uriString:String = cast uri;
                final modelUri = this.editor.getModel().uri;
                if (modelUri.scheme == 'file' && StringTools.startsWith(uriString, 'file:')) {
                    final parsedUri = Uri.parse(uriString);
                    if (parsedUri.scheme == 'file') {
                        // resources.originalFSPath
                        final fsPath = Uri.uriToFsPath(parsedUri, true);

                        var relativePath:Null<String> = null;
                        if (StringTools.startsWith(fsPath, '/./') || StringTools.startsWith(fsPath, '\\.\\')) {
                            relativePath = '.' + fsPath.substr(1);
                        }
                        else if (StringTools.startsWith(fsPath, '//./') || StringTools.startsWith(fsPath, '\\\\.\\')) {
                            relativePath = '.' + fsPath.substr(2);
                        }

                        if (relativePath != null) {
                            uri = joinPath(modelUri, relativePath);
                        }
                    }
                }
            }

            this.editor.context.openerService.open(uri, {
                openToSide: openToSide,
                fromUserGesture: fromUserGesture,
                allowContributedOpeners: true,
                allowCommands: true,
                fromWorkspace: true
            });

        }, err -> {
            final messageOrError:Null<String> = Std.isOfType(err, std.String) ? (cast err : String) : null;
            // different error cases
            final position = Range.lift(link.range).getStartPosition();
            final onNoResult = this.editor.context.onNoResult;
            if (messageOrError == 'invalid') {
                if (onNoResult != null) {
                    onNoResult(this.editor, r.localize('invalid.url', 'Failed to open this link because it is not well-formed: {0}', [Std.string(link.url)]), position);
                }
            }
            else if (messageOrError == 'missing') {
                if (onNoResult != null) {
                    onNoResult(this.editor, r.localize('missing.url', 'Failed to open this link because its target is missing.'), position);
                }
            }
            else {
                Errors.onUnexpectedError(err);
            }
        });
    }

    /**
     * `resources.joinPath`: the path of `resource` joined with `path`, like
     * `posix.join` (the `.` and `..` segments resolved).
     */
    static function joinPath(resource:Uri, path:String):Uri {
        final segments:Array<String> = [];
        final absolute = StringTools.startsWith(resource.path, '/');
        for (part in (resource.path + '/' + path).split('/')) {
            if (part == '' || part == '.') {
                continue;
            }
            if (part == '..') {
                if (segments.length > 0 && segments[segments.length - 1] != '..') {
                    segments.pop();
                }
                else if (!absolute) {
                    segments.push('..');
                }
                continue;
            }
            segments.push(part);
        }
        return resource.with({path: (absolute ? '/' : '') + segments.join('/')});
    }

    public function getLinkOccurrence(position:Null<Position>):Null<LinkOccurrence> {
        if (!this.editor.hasModel() || position == null) {
            return null;
        }
        final decorations = this.editor.getModel().getDecorationsInRange({
            startLineNumber: position.lineNumber,
            startColumn: position.column,
            endLineNumber: position.lineNumber,
            endColumn: position.column
        }, 0, true);

        for (decoration in decorations) {
            final currentOccurrence = this.currentOccurrences.get(decoration.id);
            if (currentOccurrence != null) {
                return currentOccurrence;
            }
        }

        return null;
    }

    /**
     * The ranges of the link decorations and whether each is the active one
     * (tests).
     */
    public function getLinkDecorations():Array<{range:Range, active:Bool, hoverMessage:String}> {
        final result:Array<{range:Range, active:Bool, hoverMessage:String}> = [];
        if (!this.editor.hasModel()) {
            return result;
        }
        final model = this.editor.getModel();
        for (id in this.currentOccurrences.keys()) {
            final range = model.getDecorationRange(id);
            final options = model.getDecorationOptions(id);
            if (range == null || options == null) {
                continue;
            }
            final hover:Null<IMarkdownString> = cast options.hoverMessage;
            result.push({range: range, active: options.inlineClassName == 'detected-link-active', hoverMessage: hover != null ? hover.value : ''});
        }
        haxe.ds.ArraySort.sort(result, (a, b) -> Range.compareRangesUsingStarts(a.range, b.range));
        return result;
    }

    function isEnabled(mouseEvent:ClickLinkMouseEvent, ?withKey:Null<ClickLinkKeyboardEvent>):Bool {
        return (mouseEvent.target.type == MouseTargetType.CONTENT_TEXT)
            && (mouseEvent.hasTriggerModifier || (withKey != null && withKey.keyCodeIsTriggerKey));
    }

    function stop():Void {
        this.computeLinks.cancel();
        if (this.activeLinksList != null) {
            this.activeLinksList.dispose();
            this.activeLinksList = null;
        }
        if (this.computePromise != null) {
            this.computePromise.cancel();
            this.computePromise = null;
        }
    }

    override public function dispose():Void {
        super.dispose();
        this.stop();
    }
}

/**
 * A link of the editor and its decoration.
 */
class LinkOccurrence {

    static final generalOptions:IModelDecorationOptions = {
        description: 'detected-link',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        collapseOnReplaceEdit: true,
        inlineClassName: 'detected-link'
    };

    static final activeOptions:IModelDecorationOptions = {
        description: 'detected-link-active',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        collapseOnReplaceEdit: true,
        inlineClassName: 'detected-link-active'
    };

    public static function decoration(r:EditorExtensionsRegistry, link:Link, useMetaKey:Bool):IModelDeltaDecoration {
        return {
            range: link.range,
            options: LinkOccurrence._getOptions(r, link, useMetaKey, false)
        };
    }

    static function _getOptions(r:EditorExtensionsRegistry, link:Link, useMetaKey:Bool, isActive:Bool):IModelDecorationOptions {
        final base = isActive ? activeOptions : generalOptions;
        return {
            description: base.description,
            stickiness: base.stickiness,
            collapseOnReplaceEdit: base.collapseOnReplaceEdit,
            inlineClassName: base.inlineClassName,
            hoverMessage: getHoverMessage(r, link, useMetaKey)
        };
    }

    public var decorationId:String;
    public var link:Link;

    public function new(link:Link, decorationId:String) {
        this.link = link;
        this.decorationId = decorationId;
    }

    public function activate(r:EditorExtensionsRegistry, changeAccessor:IModelDecorationsChangeAccessor, useMetaKey:Bool):Void {
        changeAccessor.changeDecorationOptions(this.decorationId, LinkOccurrence._getOptions(r, this.link, useMetaKey, true));
    }

    public function deactivate(r:EditorExtensionsRegistry, changeAccessor:IModelDecorationsChangeAccessor, useMetaKey:Bool):Void {
        changeAccessor.changeDecorationOptions(this.decorationId, LinkOccurrence._getOptions(r, this.link, useMetaKey, false));
    }

    /**
     * `link.url.toString()`.
     */
    static function urlToString(url:EitherType<Uri, String>, skipEncoding:Bool = false):String {
        return Std.isOfType(url, std.String) ? (cast url : String) : (cast url : Uri).toString(skipEncoding);
    }

    static function isCommand(url:String):Bool {
        // /^command:/i
        return url.length >= 8 && url.substr(0, 8).toLowerCase() == 'command:';
    }

    /**
     * Monaco's `getHoverMessage`: `[Follow link](url) (cmd + click)`.
     */
    public static function getHoverMessage(r:EditorExtensionsRegistry, link:Link, useMetaKey:Bool):IMarkdownString {
        final url = link.url;
        final executeCmd = url != null && isCommand(urlToString(url));

        final label = link.tooltip != null && link.tooltip.length > 0
            ? link.tooltip
            : executeCmd
                ? r.localize('links.navigate.executeCmd', 'Execute command')
                : r.localize('links.navigate.follow', 'Follow link');

        final kb = useMetaKey
            ? Platform.isMacintosh
                ? r.localize('links.navigate.kb.meta.mac', "cmd + click")
                : r.localize('links.navigate.kb.meta', "ctrl + click")
            : Platform.isMacintosh
                ? r.localize('links.navigate.kb.alt.mac', "option + click")
                : r.localize('links.navigate.kb.alt', "alt + click");

        if (url != null && urlToString(url).length > 0) {
            var nativeLabel = '';
            final urlString = urlToString(url);
            if (isCommand(urlString)) {
                // Don't show complete command arguments in the native tooltip
                // urlString.match(/^command:([^?#]+)/)
                var end = 8;
                while (end < urlString.length && urlString.charAt(end) != '?' && urlString.charAt(end) != '#') {
                    end++;
                }
                if (end > 8) {
                    final commandId = urlString.substring(8, end);
                    nativeLabel = r.localize('tooltip.explanation', "Execute command {0}", [commandId]);
                }
            }
            // new MarkdownString('', true).appendLink(...).appendMarkdown(` (${kb})`)
            final target = StringTools.replace(urlToString(url, true), ' ', '%20');
            var value = '[' + _escape(label, ']') + '](' + _escape(target, ')');
            if (nativeLabel.length > 0) {
                value += ' "' + _escape(_escape(nativeLabel, '"'), ')') + '"';
            }
            value += ')';
            value += ' (' + kb + ')';
            return {value: value, isTrusted: true};
        }
        else {
            return {value: appendText(label + ' (' + kb + ')')};
        }
    }

    /**
     * `MarkdownString._escape`: a backslash before each `ch` not already
     * escaped.
     */
    static function _escape(value:String, ch:String):String {
        final buf = new StringBuf();
        for (i in 0...value.length) {
            final c = value.charAt(i);
            if (c == ch && (i == 0 || value.charAt(i - 1) != '\\')) {
                buf.add('\\');
            }
            buf.add(c);
        }
        return buf.toString();
    }

    /**
     * `new MarkdownString().appendText(value)`: markdown syntax escaped,
     * runs of spaces and tabs as `&nbsp;`, `>` escaped, new lines as
     * paragraphs.
     */
    static function appendText(value:String):String {
        final buf = new StringBuf();
        for (i in 0...value.length) {
            final c = value.charAt(i);
            if ('\\`*_{}[]()#+-!~'.indexOf(c) >= 0) {
                buf.add('\\');
                buf.add(c);
            }
            else if (c == ' ' || c == '\t') {
                buf.add('&nbsp;');
            }
            else if (c == '>') {
                buf.add('\\>');
            }
            else if (c == '\n') {
                buf.add('\n\n');
            }
            else {
                buf.add(c);
            }
        }
        return buf.toString();
    }
}

/**
 * Opens the link at each cursor (Monaco's `editor.action.openLink`).
 */
class OpenLinkAction extends EditorAction {

    public static inline final ID = 'editor.action.openLink';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('label', "Open Link"),
            alias: 'Open Link',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final linkDetector = LinkDetector.get(editor);
        if (linkDetector == null) {
            return;
        }
        if (!editor.hasModel()) {
            return;
        }

        final selections = editor.getSelections();
        for (sel in selections) {
            final link = linkDetector.getLinkOccurrence(sel.getEndPosition());
            if (link != null) {
                linkDetector.openLinkOccurrence(link, false);
            }
        }
    }
}

/**
 * Monaco's link provider for every language of `EditorWorkerService`
 * (`linkProvider.register({language: '*', hasAccessToAllModels: true})`):
 * the links of the default link computer, computed in place (Monaco asks
 * its editor worker).
 */
class DefaultLinkProvider implements LinkProvider {

    public var resolveLink(default, null):Null<(link:cityscape.common.Languages.ILink, token:CancellationToken, resolve:(link:Null<cityscape.common.Languages.ILink>) -> Void) -> Void> = null;

    public function new() {}

    public function provideLinks(model:ITextModel, token:CancellationToken, resolve:(links:Null<ILinksList>) -> Void):Void {
        if (model.isTooLargeForSyncing()) {
            resolve({links: []}); // File too large
            return;
        }
        final links = EditorSimpleWorker.computeLinks(model);
        resolve(links != null ? {links: links} : null);
    }

}

/**
 * The module level code of links.ts (the contribution, the action, the
 * look of the link decorations) and the default link provider of
 * editorWorkerService.ts.
 */
class LinksRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        // links.css, unless the host registered its own
        if (r.context.decorationStyles.get('detected-link') == null) {
            r.context.registerDecorationStyle('detected-link', {
                underline: {}
            });
        }
        if (r.context.decorationStyles.get('detected-link-active') == null) {
            r.context.registerDecorationStyle('detected-link-active', {
                important: true,
                color: {id: 'editorLink.activeForeground'},
                underline: {color: {id: 'editorLink.activeForeground'}}
            });
        }
        r.context.languageFeaturesService.linkProvider.register(({language: '*', hasAccessToAllModels: true} : cityscape.common.LanguageSelector.LanguageFilter), new DefaultLinkProvider());
        r.registerEditorContribution(LinkDetector.ID, editor -> new LinkDetector(editor, r), EditorContributionInstantiation.AfterFirstRender);
        r.registerEditorAction(new OpenLinkAction(r));
    }

}
