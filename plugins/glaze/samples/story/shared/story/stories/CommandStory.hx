// Ported from gpui-kit 0.8.1: crates/story/src/stories/command_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.Action;
import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Keystroke;
import glaze.Model;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.command.Command;
import glaze.kit.command.CommandItem;
import glaze.kit.command.CommandState;
import glaze.kit.kbd.Kbd;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.WindowExt;

@:action(namespace = command_story) class OpenProfile implements Action {}
@:action(namespace = command_story) class OpenBilling implements Action {}
@:action(namespace = command_story) class OpenSettings implements Action {}
@:action(namespace = command_story) class GoHome implements Action {}
@:action(namespace = command_story) class OpenInbox implements Action {}
@:action(namespace = command_story) class OpenDocuments implements Action {}
@:action(namespace = command_story) class OpenFolders implements Action {}
@:action(namespace = command_story) class NewFile implements Action {}
@:action(namespace = command_story) class CopyItem implements Action {}
@:action(namespace = command_story) class DeleteItem implements Action {}

/** Rust `type Stock = (&str, &str, &str, f32)`. */
typedef Stock = {symbol:String, name:String, price:String, change:Float};

class CommandStory extends Model implements Story {

    static inline final COMMAND_CONTEXT = 'Command';

    /**
     * The stock universe the search panel queries.
     *
     * Stands in for whatever a real application would go and fetch.
     */
    static final STOCKS:Array<Stock> = [
        {symbol: 'AAPL.US', name: 'Apple Inc.', price: '228.52', change: 1.24},
        {symbol: 'NVDA.US', name: 'NVIDIA Corporation', price: '134.81', change: -0.62},
        {symbol: 'TSLA.US', name: 'Tesla, Inc.', price: '251.44', change: 3.18},
        {symbol: 'MSFT.US', name: 'Microsoft Corporation', price: '428.02', change: 0.41},
        {symbol: 'AMZN.US', name: 'Amazon.com, Inc.', price: '186.33', change: -1.07},
        {symbol: '700.HK', name: 'Tencent Holdings Ltd.', price: '412.60', change: 0.87},
        {symbol: '9988.HK', name: 'Alibaba Group Holding Ltd.', price: '82.15', change: -2.31},
        {symbol: '3690.HK', name: 'Meituan', price: '128.90', change: 1.66},
        {symbol: '600519.SH', name: 'Kweichow Moutai Co., Ltd.', price: '1482.00', change: -0.34},
        {symbol: '000858.SZ', name: 'Wuliangye Yibin Co., Ltd.', price: '142.77', change: 0.19},
    ];

    final focusHandle:FocusHandle;

    final inlineState:Entity<CommandState>;

    final dialog:Entity<CommandState>;

    final quickActionsState:Entity<CommandState>;

    final scrollableState:Entity<CommandState>;

    final variableRowsState:Entity<CommandState>;

    final search:Entity<CommandState>;

    var stockEntries:Array<CommandEntry>;

    var stockResults:Array<Stock>;

    /**
     * Rust holds the search task, so that a query arriving while the last one
     * is in flight cancels it: the port bumps a generation instead.
     */
    var searchGeneration:Int = 0;

    var searchPending:Bool = false;

    var lastCommand:Null<String>;

    public static function title():String {
        return 'Command';
    }

    public static function description():String {
        return 'A searchable list of commands and quick actions.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<CommandStory> {
        return cx.newEntity((cx:Context<CommandStory>) -> new CommandStory(window, cx));
    }

    /**
     * The palette used by the inline and dialog examples: two groups of commands,
     * one of them disabled, the second group carrying shortcut hints.
     */
    static function suggestions():Array<CommandEntry> {
        return [
            Group(new CommandGroup()
                .label('Suggestions')
                .item(new CommandItem().label('Calendar').icon(IconName.Calendar))
                .item(new CommandItem()
                    .label('Search Emoji')
                    .icon(IconName.Search)
                    .checked(true)
                    .keywords(['smile', 'icon']))
                .item(new CommandItem()
                    .label('Calculator')
                    .icon(IconName.Frame)
                    .disabled(true))),
            Separator,
            Group(new CommandGroup()
                .label('Settings')
                .item(new CommandItem().label('Profile').icon(IconName.User).action(new OpenProfile()))
                .item(new CommandItem().label('Billing').icon(IconName.CircleUser).action(new OpenBilling()))
                .item(new CommandItem().label('Settings').icon(IconName.Settings).action(new OpenSettings()))),
        ];
    }

    static function scrollable():Array<CommandEntry> {
        return [
            Group(new CommandGroup()
                .label('Navigation')
                .item(new CommandItem().label('Home').icon(IconName.LayoutDashboard).action(new GoHome()))
                .item(new CommandItem().label('Inbox').icon(IconName.Inbox).action(new OpenInbox()))
                .item(new CommandItem().label('Documents').icon(IconName.File).action(new OpenDocuments()))
                .item(new CommandItem().label('Folders').icon(IconName.Folder).action(new OpenFolders()))),
            Separator,
            Group(new CommandGroup()
                .label('Actions')
                .item(new CommandItem().label('New File').icon(IconName.Plus).action(new NewFile()))
                .item(new CommandItem().label('Copy').icon(IconName.Copy).action(new CopyItem()))
                .item(new CommandItem().label('Delete').icon(IconName.Delete).action(new DeleteItem()))),
            Separator,
            Group(new CommandGroup()
                .label('Account')
                .item(new CommandItem().label('Profile').icon(IconName.User))
                .item(new CommandItem().label('Notifications').icon(IconName.Bell))
                .item(new CommandItem().label('Help & Support').icon(IconName.Info))),
            Separator,
            Group(new CommandGroup()
                .label('Tools')
                .item(new CommandItem().label('Palette').icon(IconName.Palette))
                .item(new CommandItem().label('Terminal').icon(IconName.SquareTerminal))
                .item(new CommandItem().label('Globe').icon(IconName.Globe))),
        ];
    }

    /**
     * Actions that can be navigated without a search field, such as a compact
     * context menu.
     */
    static function quickActions():Array<CommandItem> {
        return [
            new CommandItem().label('New File').icon(IconName.Plus),
            new CommandItem().label('Duplicate').icon(IconName.Copy),
            new CommandItem().label('Move to Trash').icon(IconName.Delete),
        ];
    }

    /**
     * Two custom rows with different intrinsic heights. The Command list measures
     * each flattened row, so both retain their own height while virtualized.
     */
    static function variableRows():Array<CommandItem> {
        return [
            new CommandItem().label('small-row').child((_, _) -> hFlex()
                .wFull()
                .py1()
                .child(div().textSm().child('Compact custom row'))),
            new CommandItem().label('large-row').child((_, cx) -> vFlex()
                .wFull()
                .py4()
                .gap1()
                .child(div().textSm().child('Expanded custom row'))
                .child(div()
                    .textXs()
                    .textColor(Theme.global(cx).mutedForeground)
                    .child('Its extra detail gives this row a different height.'))),
        ];
    }

    static function keyHint(keys:Array<String>, label:String):IntoElement {
        return hFlex()
            .gap1()
            .itemsCenter()
            .children([for (key in keys) (Kbd.component(Keystroke.parse(key)) : IntoElement)])
            .child(label);
    }

    function new(window:Window, cx:Context<CommandStory>) {
        super();
        final isMac = Lib.isMacos();
        cx.app.bindKeys([
            new KeyBinding(isMac ? 'cmd-p' : 'ctrl-p', new OpenProfile(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-b' : 'ctrl-b', new OpenBilling(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-s' : 'ctrl-s', new OpenSettings(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-h' : 'ctrl-h', new GoHome(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-i' : 'ctrl-i', new OpenInbox(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-d' : 'ctrl-d', new OpenDocuments(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-f' : 'ctrl-f', new OpenFolders(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-n' : 'ctrl-n', new NewFile(), COMMAND_CONTEXT),
            new KeyBinding(isMac ? 'cmd-c' : 'ctrl-c', new CopyItem(), COMMAND_CONTEXT),
            new KeyBinding('backspace', new DeleteItem(), COMMAND_CONTEXT),
        ]);

        inlineState = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));
        dialog = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));
        quickActionsState = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));
        scrollableState = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));
        variableRowsState = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));
        search = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));

        focusHandle = cx.focusHandle();
        stockEntries = popularEntries();
        stockResults = STOCKS.slice(0, 5);
        lastCommand = null;
    }

    function onCommandConfirm(index:IndexPath, cx:Context<CommandStory>):Void {
        lastCommand = 'section ${index.section}, row ${index.row}';
        cx.notify();
    }

    function onDialogConfirm(index:IndexPath, window:Window, cx:Context<CommandStory>):Void {
        onCommandConfirm(index, cx);
        window.closeDialog(cx.app);
    }

    function cancelSearchTask():Void {
        searchGeneration++;
        searchPending = false;
    }

    /**
     * Open the stock search as a dialog, starting from an empty query.
     *
     * The palette keeps a fixed height so that results arriving, and the
     * query being narrowed, do not make the dialog jump around.
     */
    function openStockSearch(window:Window, cx:Context<CommandStory>):Void {
        cancelSearchTask();
        stockEntries = popularEntries();
        stockResults = STOCKS.slice(0, 5);
        search.update(cx, (search, cx) -> {
            search.setQuery('', window, cx);
            search.setLoading(false, window, cx);
        });

        final search = this.search;
        final story = cx.weakEntity();
        var focusOnMount = true;
        window.openDialog(cx.app, (dialog, _, _) -> {
            final closeOwner = story;
            return dialog
                .closeButton(false)
                .p0()
                .onClose((_, window, cx) -> {
                    final owner = closeOwner.upgrade();
                    if (owner != null) owner.update(cx, (story, cx) -> story.cancelStockSearch(window, cx));
                })
                .content((content, window, cx) -> {
                    if (focusOnMount) {
                        focusOnMount = false;
                        window.defer(cx, (window, cx) -> {
                            search.read(cx).focusHandle(cx).focus(window, cx);
                        });
                    }
                    final owner = story.upgrade();
                    final entries = owner != null ? stockEntriesForRender(owner.read(cx).stockEntries) : [];
                    final theme = Theme.global(cx);
                    return content.child(Lib.withCommandEntries(Command.component(search)
                        .bordered(false)
                        .rounded(theme.radiusLg)
                        .placeholder('Search stocks...')
                        .empty((_, _, cx) -> vFlex()
                            .wFull()
                            .itemsCenter()
                            .gap2()
                            .py6()
                            .textSm()
                            .textColor(Theme.global(cx).mutedForeground)
                            .child(Icon.component(IconName.Search).size8())
                            .child('No stock found.'))
                        .minH(px(320.))
                        .maxH(px(320.))
                        .onQuery((query, window, cx) -> {
                            final owner = story.upgrade();
                            if (owner != null) owner.update(cx, (story, cx) -> story.onStockQuery(query, window, cx));
                        })
                        .onConfirm((index, window, cx) -> {
                            final owner = story.upgrade();
                            if (owner != null) owner.update(cx, (story, cx) -> story.onStockConfirm(index, window, cx));
                        }), entries));
                });
        });
    }

    /**
     * Answer the search panel's queries the way a remote search would: spin
     * the field, wait, then replace the entries with the results.
     */
    function onStockQuery(query:String, window:Window, cx:Context<CommandStory>):Void {
        final query = StringTools.trim(query).toLowerCase();
        final search = this.search;
        if (query == '') {
            // Nothing typed is not the same as nothing found: fall back to the
            // list people would otherwise have to search for.
            cancelSearchTask();
            stockEntries = popularEntries();
            stockResults = STOCKS.slice(0, 5);
            window.defer(cx.app, (window, cx) -> {
                search.update(cx, (state, cx) -> state.setLoading(false, window, cx));
            });
            cx.notify();
            return;
        }

        window.defer(cx.app, (window, cx) -> {
            search.update(cx, (state, cx) -> state.setLoading(true, window, cx));
        });

        searchGeneration++;
        searchPending = true;
        final generation = searchGeneration;
        cx.spawn((story, acx) -> acx.backgroundExecutor().timer(0.4).then(_ -> {
            // The round trip a real search would spend on the network.
            final results = [for (stock in STOCKS) if (stock.symbol.toLowerCase().indexOf(query) >= 0 || stock.name.toLowerCase().indexOf(query) >= 0) stock];
            final entries = [for (stock in results) CommandEntry.Item(stockItem(stock))];

            final owner = story.upgrade();
            if (owner == null) return;
            owner.update(acx, (story, cx) -> {
                if (story.searchGeneration != generation || !story.searchPending) return;
                search.update(cx, (state, cx) -> state.setLoading(false, window, cx));
                story.stockEntries = entries;
                story.stockResults = results;
                story.searchPending = false;
                cx.notify();
            });
        }));
    }

    function onStockConfirm(index:IndexPath, window:Window, cx:Context<CommandStory>):Void {
        final stock = index.section == 0 && index.row < stockResults.length ? stockResults[index.row] : null;
        if (stock == null) {
            return;
        }
        final symbol = stock.symbol;
        cancelStockSearch(window, cx);
        lastCommand = symbol;
        cx.notify();
        window.closeDialog(cx.app);
    }

    function cancelStockSearch(window:Window, cx:Context<CommandStory>):Void {
        cancelSearchTask();
        search.update(cx, (search, cx) -> search.setLoading(false, window, cx));
        cx.notify();
    }

    /** What the panel shows before anything has been typed. */
    static function popularEntries():Array<CommandEntry> {
        return [Group(new CommandGroup()
            .label('Popular')
            .withItems([for (stock in STOCKS.slice(0, 5)) stockItem(stock)]))];
    }

    /**
     * `Command` consumes its entries when rendered. Rebuild the stock rows from
     * the owner-held result identities so a dialog redraw never drains the owner.
     */
    static function stockEntriesForRender(entries:Array<CommandEntry>):Array<CommandEntry> {
        return [for (entry in entries) entry.clone()];
    }

    /** Rust `format!("{:+.2}%", change)`. */
    static function formatChange(change:Float):String {
        final sign = change < 0 ? '-' : '+';
        final abs = Math.abs(change);
        final cents = Math.round(abs * 100);
        final whole = Std.int(cents / 100);
        final frac = cents % 100;
        return sign + whole + '.' + (frac < 10 ? '0' : '') + frac + '%';
    }

    /** A two-line search result: symbol and name on the left, quote on the right. */
    static function stockItem(stock:Stock):CommandItem {
        return new CommandItem()
            .label(stock.name)
            .keywords([stock.symbol])
            .child((_, cx) -> {
                final theme = Theme.global(cx);
                final changeColor = stock.change < 0. ? theme.chartBearish : theme.chartBullish;

                return hFlex()
                    .wFull()
                    .gap3()
                    .itemsCenter()
                    .justifyBetween()
                    .child(vFlex()
                        .gap0p5()
                        .child(div().textSm().child(stock.symbol))
                        .child(div()
                            .textXs()
                            .textColor(theme.mutedForeground)
                            .child(stock.name)))
                    .child(vFlex()
                        .gap0p5()
                        .itemsEnd()
                        .child(div().textSm().child(stock.price))
                        .child(div()
                            .textXs()
                            .textColor(changeColor)
                            .child(formatChange(stock.change))));
            });
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<CommandStory> = cast cx;
        final dialogState = dialog;
        final owner = self.weakEntity();
        final confirm = (index:IndexPath, cx:App) -> {
            final story = owner.upgrade();
            if (story != null) story.update(cx, (story, cx) -> story.onCommandConfirm(index, cx));
        };

        final column = vFlex()
            .wFull()
            .gap6()
            .child(section('Inline')
                .description('A palette rendered in place, with groups, icons and shortcuts.')
                .child(Lib.withCommandEntries(Command.component(inlineState)
                    .w(px(380.))
                    .onConfirm((indexPath, _, cx) -> confirm(indexPath, cx)), suggestions())))
            .child(section('Dialog')
                .description('A dialog palette with its search field focused, a live match count and key hints.')
                .child(Button.component('open-command-dialog')
                    .outline()
                    .label('Open Menu')
                    .onClick(self.listener((_, _, window, cx:Context<CommandStory>) -> {
                        final command = dialogState;
                        final owner = cx.weakEntity();
                        var focusOnMount = true;
                        window.openDialog(cx.app, (dialog, _, _) -> dialog.closeButton(false).p0().content((content, window, cx) -> {
                            if (focusOnMount) {
                                focusOnMount = false;
                                window.defer(cx, (window, cx) -> {
                                    command.read(cx).focusHandle(cx).focus(window, cx);
                                });
                            }
                            // Cancel intentionally has no local close callback:
                            // the propagated action belongs to Dialog.
                            return content.child(Lib.withCommandEntries(Command.component(command)
                                .bordered(false)
                                .rounded(Theme.global(cx).radiusLg)
                                .placeholder('Type a command or search...')
                                .onConfirm((indexPath, window, cx) -> {
                                    final story = owner.upgrade();
                                    if (story != null) story.update(cx, (story, cx) -> story.onDialogConfirm(indexPath, window, cx));
                                })
                                .header((state, _, cx) -> hFlex()
                                    .justifyBetween()
                                    .px3()
                                    .py2()
                                    .borderB1()
                                    .borderColor(Theme.global(cx).border)
                                    .textSm()
                                    .child('Commands')
                                    .child('${state.matchedCount()} matches'))
                                .footer((_, _, cx) -> hFlex()
                                    .gap3()
                                    .itemsCenter()
                                    .flexWrap()
                                    .px3()
                                    .py2()
                                    .borderT1()
                                    .borderColor(Theme.global(cx).border)
                                    .textXs()
                                    .textColor(Theme.global(cx).mutedForeground)
                                    .child(keyHint(['up', 'down'], 'Navigate'))
                                    .child(keyHint(['enter'], 'Select'))
                                    .child(keyHint(['escape'], 'Close'))), suggestions()));
                        }));
                    }))))
            .child(section('Quick actions')
                .description('A no-search palette focused on arrow-key navigation.')
                .child(Command.component(quickActionsState)
                    .searchable(false)
                    .items(quickActions())
                    .w(px(380.))
                    .onConfirm((indexPath, _, cx) -> confirm(indexPath, cx))))
            .child(section('Scrollable')
                .description('More commands than fit, capped at 220px.')
                .child(Lib.withCommandEntries(Command.component(scrollableState)
                    .maxH(px(220.))
                    .w(px(380.))
                    .onConfirm((indexPath, _, cx) -> confirm(indexPath, cx)), scrollable())))
            .child(section('Variable-height rows')
                .description('Each custom row keeps its own intrinsic height while the list remains virtualized.')
                .child(Command.component(variableRowsState)
                    .items(variableRows())
                    .w(px(380.))
                    .onConfirm((indexPath, _, cx) -> confirm(indexPath, cx))))
            .child(section('Search panel')
                .description('A palette used as a search panel whose custom filter checks symbols '
                    + 'before company names \u2014 try "a", "hk" or "tesla".')
                .child(Button.component('open-stock-search')
                    .outline()
                    .label('Search Stocks')
                    .onClick(self.listener((story:CommandStory, _, window, cx) -> {
                        story.openStockSearch(window, cx);
                    }))));
        if (lastCommand != null) {
            column.child(section('Last confirmed')
                .description('The value reported by the last on_confirm callback.')
                .child(lastCommand));
        }
        return column;
    }

}
