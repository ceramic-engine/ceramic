// Ported from vscode src/vs/editor/contrib/codeAction/browser/codeActionMenu.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codeAction.view;

import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.Keybindings.ResolvedKeybinding;
import cityscape.base.common.Lifecycle;
import cityscape.common.Languages.CodeAction;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import cityscape.view.SymbolIcons;
import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Context;
import glaze.DismissEvent;
import glaze.Empty;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.menu.PopupMenu;

import glaze.Prelude.*;

typedef ActionGroup = {
    final kind:HierarchicalKind;
    final title:String;
    /** A codicon id (`wrench`...), null for none. */
    @:optional final icon:Null<String>;
}

enum abstract ActionListItemKind(String) {
    var Action = 'action';
    var Header = 'header';
}

/**
 * An item of the action list (Monaco's `IActionListItem<CodeActionItem>`).
 */
typedef IActionListItem = {
    final kind:ActionListItemKind;
    @:optional final item:Null<CodeActionItem>;
    final group:ActionGroup;
    @:optional final label:Null<String>;
    @:optional final disabled:Null<Bool>;
    @:optional final keybinding:Null<ResolvedKeybinding>;
    @:optional final canPreview:Null<Bool>;
}

/**
 * Module functions of codeActionMenu.ts.
 */
class CodeActionMenu {

    static function uncategorizedCodeActionGroup(localize:(key:String, message:String) -> String):ActionGroup {
        return {kind: HierarchicalKind.Empty, title: localize('codeAction.widget.id.more', 'More Actions...')};
    }

    static function codeActionGroups(localize:(key:String, message:String) -> String):Array<ActionGroup> {
        return [
            {kind: CodeActionKind.QuickFix, title: localize('codeAction.widget.id.quickfix', 'Quick Fix')},
            {kind: CodeActionKind.RefactorExtract, title: localize('codeAction.widget.id.extract', 'Extract'), icon: 'wrench'},
            {kind: CodeActionKind.RefactorInline, title: localize('codeAction.widget.id.inline', 'Inline'), icon: 'wrench'},
            {kind: CodeActionKind.RefactorRewrite, title: localize('codeAction.widget.id.convert', 'Rewrite'), icon: 'wrench'},
            {kind: CodeActionKind.RefactorMove, title: localize('codeAction.widget.id.move', 'Move'), icon: 'wrench'},
            {kind: CodeActionKind.SurroundWith, title: localize('codeAction.widget.id.surround', 'Surround With'), icon: 'surround-with'},
            {kind: CodeActionKind.Source, title: localize('codeAction.widget.id.source', 'Source Action'), icon: 'symbol-file'},
            uncategorizedCodeActionGroup(localize),
        ];
    }

    public static function toMenuItems(inputCodeActions:Array<CodeActionItem>, showHeaders:Bool, keybindingResolver:(action:CodeAction) -> Null<ResolvedKeybinding>, ?localize:(key:String, message:String) -> String):Array<IActionListItem> {
        if (localize == null) {
            localize = (key, message) -> message;
        }
        if (!showHeaders) {
            final uncategorized = uncategorizedCodeActionGroup(localize);
            return [for (action in inputCodeActions) ({
                kind: ActionListItemKind.Action,
                item: action,
                group: uncategorized,
                disabled: action.action.disabled != null && action.action.disabled.length > 0,
                label: action.action.disabled != null && action.action.disabled.length > 0 ? action.action.disabled : action.action.title,
                canPreview: action.action.edit != null && action.action.edit.edits.length > 0,
            } : IActionListItem)];
        }

        // Group code actions
        final menuEntries = [for (group in codeActionGroups(localize)) {group: group, actions: ([] : Array<CodeActionItem>)}];

        for (action in inputCodeActions) {
            final kind = action.action.kind != null && action.action.kind.length > 0 ? new HierarchicalKind(action.action.kind) : HierarchicalKind.None;
            for (menuEntry in menuEntries) {
                if (menuEntry.group.kind.contains(kind)) {
                    menuEntry.actions.push(action);
                    break;
                }
            }
        }

        final allMenuItems:Array<IActionListItem> = [];
        for (menuEntry in menuEntries) {
            if (menuEntry.actions.length > 0) {
                allMenuItems.push({kind: ActionListItemKind.Header, group: menuEntry.group});
                for (action in menuEntry.actions) {
                    final group = menuEntry.group;
                    allMenuItems.push({
                        kind: ActionListItemKind.Action,
                        item: action,
                        group: action.action.isAI == true ? {title: group.title, kind: group.kind, icon: 'sparkle'} : group,
                        label: action.action.title,
                        disabled: action.action.disabled != null && action.action.disabled.length > 0,
                        keybinding: keybindingResolver(action.action),
                    });
                }
            }
        }
        return allMenuItems;
    }

}

/**
 * What the action list reports (Monaco's `IActionListDelegate`).
 */
typedef ActionListDelegate = {
    final onSelect:(action:CodeActionItem, preview:Bool) -> Void;
    final onHide:(didCancel:Bool) -> Void;
    final onFocus:(action:Null<CodeActionItem>) -> Void;
}

/**
 * Shows the code actions of an editor in the Glaze kit's `PopupMenu`
 * (Monaco's action widget service): the groups as labels, the actions with
 * the icon of their group (Monaco's lightbulb for quick fixes), their
 * keybinding, disabled actions with the reason. The menu takes the focus,
 * gives it back to the editor when it closes, and is drawn above
 * everything, anchored below the given point.
 */
class CodeActionWidget implements IOverlayWidget implements IDisposable {

    public static inline final ID = 'editor.contrib.codeActionWidget';

    final editor:ICodeEditor;

    var items:Null<Array<IActionListItem>> = null;
    var delegate:Null<ActionListDelegate> = null;
    var anchor:Null<Bounds> = null;
    var menu:Null<Entity<PopupMenu>> = null;

    /**
     * The window bounds of the menu as last placed (null before).
     */
    public var menuBounds(default, null):Null<Bounds> = null;
    var subscription:Null<Subscription> = null;
    var selected:Bool = false;

    public function new(editor:ICodeEditor) {
        this.editor = editor;
        editor.addOverlayWidget(this);
    }

    public var isVisible(get, never):Bool;
    function get_isVisible():Bool {
        return items != null;
    }

    /**
     * The items shown (tests).
     */
    public function getItems():Null<Array<IActionListItem>> {
        return items;
    }

    public function show(items:Array<IActionListItem>, delegate:ActionListDelegate, anchor:Null<Bounds>):Void {
        hide(false);
        this.items = items;
        this.delegate = delegate;
        this.anchor = anchor;
        this.selected = false;
        editor.layoutOverlayWidget(this);
    }

    /**
     * Runs the action of an item as if it was clicked (tests, keyboard).
     */
    public function select(index:Int):Void {
        final items = this.items;
        final delegate = this.delegate;
        if (items == null || delegate == null || index < 0 || index >= items.length) {
            return;
        }
        final item = items[index];
        if (item.kind != ActionListItemKind.Action || item.disabled == true || item.item == null) {
            return;
        }
        selected = true;
        delegate.onSelect(item.item, false);
    }

    public function hide(didCancel:Bool = true):Void {
        if (items == null) {
            return;
        }
        final delegate = this.delegate;
        items = null;
        this.delegate = null;
        menu = null;
        menuBounds = null;
        if (subscription != null) {
            subscription.dispose();
            subscription = null;
        }
        if (delegate != null) {
            delegate.onHide(didCancel);
        }
        editor.layoutOverlayWidget(this);
    }

    public function dispose():Void {
        items = null;
        delegate = null;
        menu = null;
        if (subscription != null) {
            subscription.dispose();
            subscription = null;
        }
        editor.removeOverlayWidget(this);
    }

    public function getId():String {
        return ID;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    function iconOf(item:IActionListItem):Null<String> {
        if (item.group.icon != null) {
            return item.group.icon;
        }
        // Monaco's quick fix rows show the lightbulb
        if (item.group.kind.equals(CodeActionKind.QuickFix)) {
            return item.item != null && item.item.action.isPreferred == true ? 'lightbulb-autofix' : 'lightbulb';
        }
        return null;
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        final items = this.items;
        final anchor = this.anchor;
        if (items == null || anchor == null) {
            return null;
        }
        // `overflowWidgetsBounds: 'editor'`: placed and capped inside the editor
        final page = EditorWidgets.overflowPage(editor);
        var menu = this.menu;
        if (menu == null) {
            final view = EditorWidgets.viewOf(editor);
            final editorFocus = view != null ? view.focusHandle : null;
            menu = PopupMenu.build(window, cx, (menu, window, cx) -> {
                if (editorFocus != null) {
                    menu.actionContext(editorFocus);
                }
                var first = true;
                for (index in 0...items.length) {
                    final item = items[index];
                    if (item.kind == ActionListItemKind.Header) {
                        if (!first) {
                            menu.separator();
                        }
                        menu.label(item.group.title);
                        first = false;
                        continue;
                    }
                    first = false;
                    final label = item.label != null ? item.label : '';
                    final entry = PopupMenuItem.create(label)
                        .disabled(item.disabled == true)
                        .onClick((_:ClickEvent, _:Window, _:App) -> select(index));
                    final codicon = iconOf(item);
                    if (codicon != null) {
                        entry.icon(Icon.empty().data(SymbolIcons.codiconSvg(codicon)));
                    }
                    menu.item(entry);
                }
                if (page != null) {
                    // the kit's cap (half the window, at most 450 pixels) with
                    // the editor for the window, and the room on the larger
                    // side (less the menu's border and padding)
                    final room = cityscape.view.ContentWidgetPositioner.maxHeightInPageWithPreferences(anchor, page) - 10;
                    menu.scrollable(true).maxH(px(Math.max(0, Math.min(Math.min(450, page.size.height * 0.5), room))));
                }
                return menu.minW(160);
            });
            this.menu = menu;
            final built = menu;
            cx.defer(_ -> {
                built.read(cx).focusHandle.focus(window, cx);
            });
            subscription = window.subscribe(built, DismissEvent, cx, (_, _, window, _) -> {
                if (this.menu == built) {
                    this.hide(!selected);
                }
            });
        }
        if (page != null) {
            final positioner = new cityscape.view.ContentWidgetPositioner({
                primary: anchor,
                secondary: null,
                editor: EditorWidgets.editorBounds(editor),
                typicalFullwidthCharacterWidth: 0,
                page: page
            }, false)
                .preferences([cityscape.view.ContentWidgetPositioner.ContentWidgetPositionPreference.BELOW, cityscape.view.ContentWidgetPositioner.ContentWidgetPositionPreference.ABOVE])
                .onPlacement(placement -> menuBounds = placement.bounds)
                .child(menu);
            return deferred(positioner).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY).intoAnyElement();
        }
        return EditorWidgets.popup(anchor, Placement.Bottom, menu, resolved -> menuBounds = resolved.bounds);
    }

}
