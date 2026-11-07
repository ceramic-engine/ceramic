// Ported from gpui-kit 0.8.1: crates/story/src/stories/list_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.Action;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.DragMoveEvent;
import gpui.ElementId;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.RenderOnce;
import gpui.ScrollStrategy;
import gpui.Subscription;
import gpui.Task;
import gpui.Unit;
import gpui.Window;
import gpui.base.IndexPath;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.label.Label;
import gpui.component.list.List;
import gpui.component.list.ListDelegate.ListDelegateBase;
import gpui.component.list.ListDelegate.ListDelegateItem;
import gpui.component.list.ListItem;
import gpui.component.list.ListState;
import gpui.component.theme.Theme;
import story.Fake;
import story.Story;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

using gpui.base.StyledExt;
using gpui.component.ThemeStyled;

@:action(namespace = list_story) class SelectedCompany implements Action {}

@:action(namespace = list_story) class ToggleSelectable implements Action {}

@:action(namespace = list_story) class ToggleSearchable implements Action {}

@:action(namespace = list_story) class ToggleLoading implements Action {}

@:action(namespace = list_story) class ToggleLazyLoad implements Action {}

@:action(namespace = list_story) class ToggleDraggable implements Action {}

@:action(namespace = list_story) class GoToTop implements Action {}

@:action(namespace = list_story) class GoToSelected implements Action {}

@:action(namespace = list_story) class GoToRow implements Action {}

@:action(namespace = list_story) class GoToBottom implements Action {}

class Company {

    public var name:String = '';
    public var industry:String = '';
    public var lastDone:Float = 0.;
    public var prevClose:Float = 0.;

    public var changePercent:Float = 0.;
    public var changePercentStr:String = '';
    public var lastDoneStr:String = '';
    public var prevCloseStr:String = '';

    public function new() {}

    public function prepare():Company {
        changePercent = (lastDone - prevClose) / prevClose;
        changePercentStr = fixed2(changePercent) + '%';
        lastDoneStr = fixed2(lastDone);
        prevCloseStr = fixed2(prevClose);
        return this;
    }

    /** Rust `format!("{:.2}", value)`. */
    public static function fixed2(value:Float):String {
        if (Math.isNaN(value)) return 'NaN';
        if (!Math.isFinite(value)) return value > 0 ? 'inf' : '-inf';
        final negative = value < 0 || (value == 0 && 1 / value < 0);
        final cents = Math.fround(Math.abs(value) * 100);
        final whole = Math.ffloor(cents / 100);
        final frac = Std.int(cents - whole * 100);
        return (negative ? '-' : '') + Std.string(whole) + '.' + (frac < 10 ? '0' : '') + frac;
    }

}

/** Where the dragged item will be inserted relative to the drop target row. */
enum DropPosition {
    Before;
    After;
}

class DropPositionTools {

    /** The insertion gap index (0..=len) this position resolves to for `row`. */
    public static function gap(self:DropPosition, row:Int):Int {
        return switch self {
            case Before: row;
            case After: row + 1;
        }
    }

}

class DragCompany extends Model implements Render {

    public final ix:IndexPath;

    public final name:String;

    public function new(ix:IndexPath, name:String) {
        super();
        this.ix = ix;
        this.name = name;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return div()
            .px2()
            .py1()
            .textSm()
            .bg(theme.accent)
            .textColor(theme.accentForeground)
            .rounded(theme.radius)
            .shadowMd()
            .child(name);
    }

}

class CompanyListItem implements ListDelegateItem {

    var base:ListItem;
    final company:Company;
    var selected:Bool;
    var dropPosition:Null<DropPosition> = null;

    public function new(id:ElementId, company:Company, selected:Bool) {
        this.company = company;
        this.base = new ListItem(id).selected(selected);
        this.selected = selected;
    }

    /**
     * Make this item draggable for reordering, by using the interactivity of
     * the inner `ListItem`.
     */
    public function draggable(ix:IndexPath, dropPosition:Null<DropPosition>, onDragStart:(App) -> Void,
            onDragMove:(DragMoveEvent<DragCompany>, Window, App) -> Void, onDrop:(DragCompany, Window, App) -> Void):CompanyListItem {
        final name = company.name;
        this.dropPosition = dropPosition;
        base.base
            .onDrag(ix, (ix, _, _, cx) -> {
                onDragStart(cx);
                return (cx.newEntity((_:Context<DragCompany>) -> new DragCompany(ix, name)) : AnyView);
            })
            .onDragMove(DragCompany, onDragMove)
            .onDrop(DragCompany, onDrop);
        return this;
    }

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function setSecondarySelected(selected:Bool):Void {
        base.setSecondarySelected(selected);
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final textColor = selected ? theme.accentForeground : theme.foreground;

        final trendColor = if (company.changePercent > 0.0) theme.green else if (company.changePercent < 0.0) theme.red else theme.foreground;

        final row = hFlex()
            .itemsCenter()
            .justifyBetween()
            .gap2()
            .textColor(textColor);
        if (dropPosition != null && cx.hasActiveDrag()) {
            final line = div()
                .absolute()
                .left0()
                .right0()
                .h(px(2.))
                .roundedFullStyle(cx)
                .bg(theme.blue);

            row.child(switch dropPosition {
                case Before: line.top(px(-5.));
                case After: line.bottom(px(-5.));
            });
        }

        return base
            .px2()
            .py1()
            .overflowXHidden()
            .border1()
            .rounded(theme.radius)
            .child(row
                .child(hFlex().gap2().child(vFlex()
                    .gap1()
                    .maxW(px(500.))
                    .overflowXHidden()
                    .flexNowrap()
                    .child(new Label(company.name).whitespaceNowrap())))
                .child(hFlex()
                    .gap2()
                    .itemsCenter()
                    .justifyEnd()
                    .child(div()
                        .w(px(65.))
                        .textColor(textColor)
                        .child(company.lastDoneStr))
                    .child(hFlex().w(px(65.)).justifyEnd().child(div()
                        .rounded(theme.radius)
                        .whitespaceNowrap()
                        .textSize(px(12.))
                        .px1()
                        .textColor(trendColor)
                        .child(company.changePercentStr)))));
    }

}

class CompanyListDelegate extends ListDelegateBase {

    public final industries:Array<String> = [];
    public var companies:Array<Company> = [];
    public final matchedCompanies:Array<Array<Company>> = [];
    public var selectedIndex:Null<IndexPath> = null;
    public var confirmedIndex:Null<IndexPath> = null;
    public var query:String = '';
    public var loadingValue:Bool = false;
    public var eof:Bool = false;
    public var lazyLoad:Bool = false;
    public var draggableValue:Bool = false;
    public var dropTarget:Null<{ix:IndexPath, position:DropPosition}> = null;

    public function new() {}

    public function prepare(query:String):Void {
        this.query = query;
        for (companies in matchedCompanies) {
            companies.resize(0);
        }
        final lower = query.toLowerCase();
        final found = [for (company in companies) if (company.name.toLowerCase().indexOf(lower) >= 0) company];
        for (company in found) {
            final ix = industries.indexOf(company.industry);
            if (ix >= 0) {
                matchedCompanies[ix].push(company);
            } else {
                industries.push(company.industry);
                matchedCompanies.push([company]);
            }
        }
    }

    public function extendMore(len:Int):Void {
        for (_ in 0...len) companies.push(randomCompany());
        prepare(query);
    }

    public function selectedCompany():Null<Company> {
        if (selectedIndex == null) {
            return null;
        }
        final ix = selectedIndex;
        final section = ix.section < matchedCompanies.length ? matchedCompanies[ix.section] : null;
        return section != null && ix.row < section.length ? section[ix.row] : null;
    }

    /** Record the pending drop target row, returns true if it changed. */
    public function updateDropTarget(ix:IndexPath, position:Null<DropPosition>):Bool {
        if (position != null) {
            if (dropTarget == null || !dropTarget.ix.equals(ix) || dropTarget.position != position) {
                dropTarget = {ix: ix, position: position};
                return true;
            }
            return false;
        }
        if (dropTarget != null && dropTarget.ix.equals(ix)) {
            dropTarget = null;
            return true;
        }
        return false;
    }

    /** Move the company at `from` to before or after the company at `to`. */
    public function moveCompany(from:IndexPath, to:IndexPath, position:DropPosition):Void {
        dropTarget = null;
        if (from.equals(to)) {
            return;
        }

        final fromCompanies = from.section < matchedCompanies.length ? matchedCompanies[from.section] : null;
        if (fromCompanies == null || from.row >= fromCompanies.length) {
            return;
        }
        final company = fromCompanies.splice(from.row, 1)[0];

        var row = DropPositionTools.gap(position, to.row);
        if (from.section == to.section && from.row < row) {
            row -= 1;
        }

        if (to.section < matchedCompanies.length) {
            final companies = matchedCompanies[to.section];
            final row = row < companies.length ? row : companies.length;
            companies.insert(row, company);
            selectedIndex = new IndexPath(row).withSection(to.section);
        }
    }

    override public function sectionsCount(_:App):Int {
        return industries.length;
    }

    public function itemsCount(section:Int, _:App):Int {
        if (section == 0 || section == 2 || section == 3) {
            // Return some empty sections for testing.
            return 0;
        }

        return matchedCompanies[section].length;
    }

    override public function performSearch(query:String, _:Window, _:Context<ListState<Dynamic>>):Task<Unit> {
        prepare(query);
        return Task.ready(Unit.unit);
    }

    override public function confirm(secondary:Bool, window:Window, cx:Context<ListState<Dynamic>>):Void {
        trace('Confirmed with secondary: $secondary');
        window.dispatchAction(new SelectedCompany(), cx.app);
    }

    public function setSelectedIndex(ix:Null<IndexPath>, _:Window, cx:Context<ListState<Dynamic>>):Void {
        selectedIndex = ix;
        cx.notify();
    }

    override public function setRightClickedIndex(ix:Null<IndexPath>, _:Window, _:Context<ListState<Dynamic>>):Void {
        trace('right_clicked_index: ${ix == null ? 'None' : 'Some($ix)'}');
    }

    override public function renderSectionHeader(section:Int, _:Window, cx:Context<ListState<Dynamic>>):Null<IntoElement> {
        if (section >= industries.length) {
            return null;
        }
        final industry = industries[section];

        return hFlex()
            .pb1()
            .px2()
            .gap2()
            .textSm()
            .textColor(Theme.global(cx.app).mutedForeground)
            .child(new Icon(IconName.Folder))
            .child(industry)
            .child('(section: $section)');
    }

    override public function renderSectionFooter(section:Int, _:Window, cx:Context<ListState<Dynamic>>):Null<IntoElement> {
        if (section >= industries.length) {
            return null;
        }

        return div()
            .pt1()
            .pb5()
            .px2()
            .textXs()
            .textColor(Theme.global(cx.app).mutedForeground)
            .child('Total ${matchedCompanies[section].length} items in section.');
    }

    public function renderItem(ix:IndexPath, _:Window, cx:Context<ListState<Dynamic>>):Null<ListDelegateItem> {
        final selected = (selectedIndex != null && ix.equals(selectedIndex)) || (confirmedIndex != null && ix.equals(confirmedIndex));
        final companies = matchedCompanies[ix.section];
        if (ix.row >= companies.length) {
            return null;
        }
        final item = new CompanyListItem(ix.toElementId(), companies[ix.row], selected);
        if (!draggableValue) {
            return item;
        }

        // Normalize the pending drop target to an insertion gap, so the
        // indicator renders at the same edge no matter which of the two
        // rows around the gap the cursor is over.
        final count = companies.length;
        var dropPosition:Null<DropPosition> = null;
        if (dropTarget != null && dropTarget.ix.section == ix.section) {
            final gap = DropPositionTools.gap(dropTarget.position, dropTarget.ix.row);
            if (gap == ix.row) {
                dropPosition = Before;
            } else if (gap == count && ix.row + 1 == count) {
                dropPosition = After;
            }
        }

        final state = cx.weakEntity();
        return item.draggable(ix, dropPosition,
            // A drag may end without a drop (e.g. released outside the
            // list), clear the stale drop target when a new one starts.
            cx -> {
                if (state.isUpgradable()) state.update(cx, (this_:ListState<Dynamic>, cx) -> {
                    final delegate:CompanyListDelegate = cast this_.delegateMut();
                    if (delegate.dropTarget != null) {
                        delegate.dropTarget = null;
                        cx.notify();
                    }
                });
            }, cx.listener((this_:ListState<Dynamic>, e:DragMoveEvent<DragCompany>, _, cx) -> {
                final bounds = e.bounds;
                final from = e.drag(cx.app).ix;
                var position:Null<DropPosition> = null;
                if (bounds.contains(e.event.position)) {
                    final p:DropPosition = e.event.position.y < bounds.center().y ? Before : After;

                    // Gaps adjacent to the dragged row are no-op moves.
                    final gap = DropPositionTools.gap(p, ix.row);
                    if (!(from.section == ix.section && (gap == from.row || gap == from.row + 1))) {
                        position = p;
                    }
                }

                final delegate:CompanyListDelegate = cast this_.delegateMut();
                if (delegate.updateDropTarget(ix, position)) {
                    cx.notify();
                }
            }), cx.listener((this_:ListState<Dynamic>, drag:DragCompany, _, cx) -> {
                final delegate:CompanyListDelegate = cast this_.delegateMut();
                final target = delegate.dropTarget;
                if (target == null || !target.ix.equals(ix)) {
                    return;
                }

                delegate.moveCompany(drag.ix, ix, target.position);
                cx.notify();
            }));
    }

    override public function loading(_:App):Bool {
        return loadingValue;
    }

    override public function hasMore(_:App):Bool {
        if (loadingValue) {
            return false;
        }

        return !eof;
    }

    override public function loadMoreThreshold():Int {
        return 150;
    }

    override public function loadMore(window:Window, cx:Context<ListState<Dynamic>>):Void {
        if (!lazyLoad) {
            return;
        }

        cx.spawn((view, acx) -> {
            // Simulate network request, delay 1s to load data.
            return acx.backgroundExecutor().timer(1.).then(_ -> {
                if (!view.isUpgradable()) return;
                view.update(acx, (view:ListState<Dynamic>, cx) -> {
                    final delegate:CompanyListDelegate = cast view.delegateMut();
                    final query = delegate.query;
                    delegate.extendMore(200);
                    delegate.performSearch(query, window, cx);
                    delegate.eof = delegate.companies.length >= 6000;
                });
            });
        }).detach();
    }

    public static function randomCompany():Company {
        final lastDone = Fake.float(0.0, 999.0);
        final prevClose = lastDone * Fake.float(-0.1, 0.1);

        final company = new Company();
        company.name = Fake.companyName();
        company.industry = Fake.industry();
        company.lastDone = lastDone;
        company.prevClose = prevClose;
        return company.prepare();
    }

}

class ListStory extends Model implements Story {

    final focusHandleValue:FocusHandle;
    final companyList:Entity<ListState<CompanyListDelegate>>;
    var selectedCompanyValue:Null<Company>;
    var selectable:Bool;
    var searchable:Bool;
    final subscriptions:Array<Subscription>;

    public static function title():String {
        return 'List';
    }

    public static function description():String {
        return 'A list displays a series of items.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ListStory> {
        return cx.newEntity((cx:Context<ListStory>) -> new ListStory(window, cx));
    }

    function new(window:Window, cx:Context<ListStory>) {
        super();
        final delegate = new CompanyListDelegate();
        delegate.selectedIndex = IndexPath.defaultValue();
        delegate.extendMore(100);

        companyList = cx.newEntity((cx:Context<ListState<CompanyListDelegate>>) -> new ListState(delegate, window, cx).searchable(true));

        subscriptions = [
            cx.subscribe(companyList, ListEvent, (_, _, ev, _) -> switch ev {
                case Select(ix): trace('List Selected: $ix');
                case Confirm(ix): trace('List Confirmed: $ix');
                case Cancel: trace('List Cancelled');
            }),
        ];

        // Spawn a background to random refresh the list
        cx.spawn((this_, acx) -> {
            if (this_.isUpgradable()) this_.update(acx, (this_:ListStory, cx) -> {
                this_.companyList.update(cx, (picker, _) -> {
                    final delegate = picker.delegateMut();
                    delegate.companies = [for (company in delegate.companies) {
                        final newCompany = CompanyListDelegate.randomCompany();
                        newCompany.name = company.name;
                        newCompany.industry = company.industry;
                        newCompany;
                    }];
                    delegate.prepare('');
                });
                cx.notify();
            });
            return Task.done();
        }).detach();

        focusHandleValue = cx.focusHandle();
        searchable = true;
        selectable = true;
        selectedCompanyValue = null;
    }

    function selectedCompany(_:SelectedCompany, _:Window, cx:Context<ListStory>):Void {
        final picker = companyList.read(cx.app);
        final company = picker.delegate().selectedCompany();
        if (company != null) {
            selectedCompanyValue = company;
        }
    }

    function toggleSelectable(selectable:Bool, _:Window, cx:Context<ListStory>):Void {
        this.selectable = selectable;
        companyList.update(cx, (list, cx) -> list.setSelectable(this.selectable, cx));
    }

    function toggleSearchable(searchable:Bool, _:Window, cx:Context<ListStory>):Void {
        this.searchable = searchable;
        companyList.update(cx, (list, cx) -> list.setSearchable(this.searchable, cx));
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandleValue;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<ListStory> = cast cx;
        final theme = Theme.global(cx.app);
        final lazyLoad = companyList.read(cx.app).delegate().lazyLoad;
        final draggable = companyList.read(cx.app).delegate().draggableValue;
        final selectable = this.selectable;
        final searchable = this.searchable;
        final loading = companyList.read(cx.app).delegate().loadingValue;

        return vFlex()
            .trackFocus(focusHandleValue)
            .onAction(SelectedCompany, self.listener((this_:ListStory, action:SelectedCompany, window, cx) -> this_.selectedCompany(action, window, cx)))
            .onAction(ToggleSelectable, self.listener((this_:ListStory, _:ToggleSelectable, window, cx) -> {
                this_.toggleSelectable(!this_.selectable, window, cx);
            }))
            .onAction(ToggleSearchable, self.listener((this_:ListStory, _:ToggleSearchable, window, cx) -> {
                this_.toggleSearchable(!this_.searchable, window, cx);
            }))
            .onAction(ToggleLoading, self.listener((this_:ListStory, _:ToggleLoading, _, cx) -> {
                this_.companyList.update(cx, (list, cx) -> {
                    list.delegateMut().loadingValue = !list.delegate().loadingValue;
                    cx.notify();
                });
            }))
            .onAction(ToggleLazyLoad, self.listener((this_:ListStory, _:ToggleLazyLoad, _, cx) -> {
                this_.companyList.update(cx, (list, cx) -> {
                    list.delegateMut().lazyLoad = !list.delegate().lazyLoad;
                    cx.notify();
                });
            }))
            .onAction(ToggleDraggable, self.listener((this_:ListStory, _:ToggleDraggable, _, cx) -> {
                this_.companyList.update(cx, (list, cx) -> {
                    list.delegateMut().draggableValue = !list.delegate().draggableValue;
                    cx.notify();
                });
            }))
            .onAction(GoToTop, self.listener((this_:ListStory, _:GoToTop, window, cx) -> {
                this_.companyList.update(cx, (list, cx) -> {
                    list.scrollToItem(IndexPath.defaultValue(), ScrollStrategy.Top, window, cx);
                });
            }))
            .onAction(GoToSelected, self.listener((this_:ListStory, _:GoToSelected, window, cx) -> {
                this_.companyList.update(cx, (list, cx) -> {
                    list.scrollToSelectedItem(window, cx);
                });
            }))
            .onAction(GoToRow, self.listener((this_:ListStory, _:GoToRow, window, cx) -> {
                this_.companyList.update(cx, (list, cx) -> {
                    list.scrollToItem(new IndexPath(1).withSection(5), ScrollStrategy.Center, window, cx);
                });
            }))
            .onAction(GoToBottom, self.listener((this_:ListStory, _:GoToBottom, window, cx) -> {
                this_.companyList.update(cx, (list, cx) -> {
                    var lastSection = list.delegate().sectionsCount(cx.app) - 1;
                    if (lastSection < 0) lastSection = 0;
                    var lastRow = list.delegate().itemsCount(lastSection, cx.app) - 1;
                    if (lastRow < 0) lastRow = 0;
                    list.scrollToItem(IndexPath.defaultValue().withSection(lastSection).withRow(lastRow), ScrollStrategy.Top, window, cx);
                });
            }))
            .sizeFull()
            .gap4()
            .child(storyToolbarGroup()
                .dropdownChild(new Button('go-to').label('Go To'), (menu, _, _) -> menu
                    .menu('Top', new GoToTop())
                    .menu('Selected', new GoToSelected())
                    .menu('Section 5, Row 1', new GoToRow())
                    .menu('Bottom', new GoToBottom()))
                .dropdownChild(new Button('list-options').label('Options'), (menu, _, _) -> menu
                    .menuWithCheck('Selectable', selectable, new ToggleSelectable())
                    .menuWithCheck('Searchable', searchable, new ToggleSearchable())
                    .menuWithCheck('Loading', loading, new ToggleLoading())
                    .menuWithCheck('Lazy Load', lazyLoad, new ToggleLazyLoad())
                    .menuWithCheck('Draggable', draggable, new ToggleDraggable())))
            .child(new List(companyList)
                .p(px(8.))
                .flex1()
                .wFull()
                .border1()
                .borderColor(theme.border)
                .rounded(theme.radius));
    }

}
