// Ported from gpui-kit 0.8.1: crates/story/src/stories/data_table_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-019 (CSV export on the web, as a browser download). See docs/DEVIATIONS.md.
package story.stories;

import glaze.Action;
import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Div;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Font;
import glaze.FontWeight;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.Range;
import glaze.Subscription;
import glaze.Task;
import glaze.TextAlign;
import glaze.TextRun;
import glaze.Window;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.kit.spinner.Spinner;
import glaze.kit.table.Column;
import glaze.kit.table.DataTable;
import glaze.kit.table.TableDelegate.TableDelegateBase;
import glaze.kit.table.TableState;
import glaze.kit.theme.Theme;
import story.Fake;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;

@:action(namespace = data_table_story, noJson)
class ChangeSize implements Action {
    public final value:Size;
}

@:action(namespace = data_table_story, noJson)
class ChangeHeaderRowHeight implements Action {
    public final value:Null<Pixels>;
}

@:action(namespace = data_table_story, noJson)
class ChangeRows implements Action {
    public final value:Int;
}

@:action(namespace = data_table_story, noJson)
class ChangeExtraColumns implements Action {
    public final value:Int;
}

@:action(namespace = data_table_story, noJson)
class OpenDetail implements Action {
    public final value:Int;
}

enum ToggleTableOptionKind {
    LoopSelection;
    ColumnResize;
    ColumnOrder;
    Sortable;
    ColumnSelection;
    RowSelection;
    CellSelection;
    RowHeader;
    FixedColumn;
    Striped;
    Loading;
    LazyLoad;
    RefreshData;
    GroupHeaders;
}

/** Rust `enum ToggleTableOption` (an action). */
@:action(namespace = data_table_story, noJson)
class ToggleTableOption implements Action {
    public final value:ToggleTableOptionKind;
}

@:action(namespace = data_table_story, noJson) class ClearTableSelection implements Action {}

enum GoToTablePositionKind {
    Top;
    Bottom;
    Cell53;
    Cell107;
}

/** Rust `enum GoToTablePosition` (an action). */
@:action(namespace = data_table_story, noJson)
class GoToTablePosition implements Action {
    public final value:GoToTablePositionKind;
}

private class Counter {

    public var symbol:String = '';
    public var market:String = '';
    public var name:String = '';

    public function new() {}

    static var allCounters:Null<Array<Counter>> = null;

    static function all():Array<Counter> {
        if (allCounters == null) {
            final parsed:Array<{symbol:String, market:String, name:String}> = haxe.Json.parse(story.Include.str('counters.json'));
            allCounters = [for (c in parsed) {
                final counter = new Counter();
                counter.symbol = c.symbol;
                counter.market = c.market;
                counter.name = c.name;
                counter;
            }];
        }
        return allCounters;
    }

    public static function random():Counter {
        final counters = all();
        final ix = Fake.index(counters.length);
        return counters[ix].clone();
    }

    public function clone():Counter {
        final counter = new Counter();
        counter.symbol = symbol;
        counter.market = market;
        counter.name = name;
        return counter;
    }

    /**
     * The symbol carrying its market, e.g. `AAPL.US`.
     *
     * Hong Kong symbols already ship the suffix (`0700.HK`), so appending the
     * market again would read `0700.HK.HK`.
     */
    public function symbolCode():String {
        return symbol.indexOf('.') >= 0 ? symbol : '$symbol.$market';
    }

}

private class Stock {

    public var id:Int = 0;
    public var counter:Counter = new Counter();
    public var price:Float = 0.;
    public var change:Float = 0.;
    public var changePercent:Float = 0.;
    public var volume:Float = 0.;
    public var turnover:Float = 0.;
    public var marketCap:Float = 0.;
    public var ttm:Float = 0.;
    public var fiveMinsRanking:Float = 0.;
    public var th60DaysRanking:Float = 0.;
    public var yearChangePercent:Float = 0.;
    public var bid:Float = 0.;
    public var bidVolume:Float = 0.;
    public var ask:Float = 0.;
    public var askVolume:Float = 0.;
    public var open:Float = 0.;
    public var prevClose:Float = 0.;
    public var high:Float = 0.;
    public var low:Float = 0.;
    public var turnoverRate:Float = 0.;
    public var riseRate:Float = 0.;
    public var amplitude:Float = 0.;
    public var peStatus:Float = 0.;
    public var pbStatus:Float = 0.;
    public var volumeRatio:Float = 0.;
    public var bidAskRatio:Float = 0.;
    public var latestPreClose:Float = 0.;
    public var latestPostClose:Float = 0.;
    public var preMarketCap:Float = 0.;
    public var preMarketPercent:Float = 0.;
    public var preMarketChange:Float = 0.;
    public var postMarketCap:Float = 0.;
    public var postMarketPercent:Float = 0.;
    public var postMarketChange:Float = 0.;
    public var floatCap:Float = 0.;
    /** Rust `i64`, kept in a `Float` (exact up to 2^53). */
    public var shares:Float = 0.;
    public var sharesFloat:Float = 0.;
    public var day5Ranking:Float = 0.;
    public var day10Ranking:Float = 0.;
    public var day30Ranking:Float = 0.;
    public var day120Ranking:Float = 0.;
    public var day250Ranking:Float = 0.;

    public function new() {}

    public function clone():Stock {
        final stock = Type.createEmptyInstance(Stock);
        for (field in Type.getInstanceFields(Stock)) {
            final value = Reflect.field(this, field);
            if (!Reflect.isFunction(value)) Reflect.setField(stock, field, value);
        }
        stock.counter = counter.clone();
        return stock;
    }

    /** Ticks the quote, keeping the fields consistent with the new price. */
    public function randomUpdate():Void {
        changePercent = Fake.float(-0.1, 0.1);
        price = Fake.float(5.0, 999.0);
        change = price * changePercent;
        prevClose = price - change;
        volume = Fake.float(1e4, 5e7);
        turnover = volume * price;
        marketCap = price * shares;
        ttm = Fake.float(5.0, 80.0);
        fiveMinsRanking = fiveMinsRanking * (1.0 + Fake.float(-0.2, 0.2));
        bid = price * (1.0 - Fake.float(0.0, 0.01));
        bidVolume = Fake.float(100.0, 5e4);
        ask = price * (1.0 + Fake.float(0.0, 0.01));
        askVolume = Fake.float(100.0, 5e4);
        bidAskRatio = bidVolume / askVolume;
        volumeRatio = Fake.float(0.0, 3.0);
        high = price * (1.0 + Fake.float(0.0, 0.08));
        low = price * (1.0 - Fake.float(0.0, 0.08));
    }

}

class StockTableDelegate extends TableDelegateBase {

    static var incrementId:Int = 0;

    static inline final POOL_SIZE:Int = 512;

    public var stocks:Array<Stock>;
    public final columns:Array<Column>;
    /** Number of extra "Column N" columns appended after the built-in columns. */
    public var extraColumnsCount:Int = 0;
    public var size:Size = Medium;
    public var loadingValue:Bool = false;
    public var lazyLoad:Bool = false;
    public var fullLoading:Bool = false;
    public var showGroupHeaders:Bool = true;
    public var clickedRow:Null<Int> = null;
    public var eof:Bool = false;
    public var visibleRows:Range = new Range(0, 0);
    public var visibleCols:Range = new Range(0, 0);

    var loadTask:Task<Dynamic> = Task.done();

    /** Rust `format!("{:.N}", value)`. */
    public static function fixed(value:Float, decimals:Int):String {
        if (Math.isNaN(value)) return 'NaN';
        if (!Math.isFinite(value)) return value > 0 ? 'inf' : '-inf';
        final negative = value < 0;
        final scale = Math.pow(10, decimals);
        final scaled = Math.fround(Math.abs(value) * scale);
        final whole = Math.ffloor(scaled / scale);
        var result = floatToString(whole);
        if (decimals > 0) {
            final frac = Std.string(Std.int(scaled - whole * scale));
            result += '.' + StringTools.lpad(frac, '0', decimals);
        }
        return (negative && scaled != 0 ? '-' : '') + result;
    }

    /** Rust `format!("{:+.N}", value)`. */
    public static function signed(value:Float, decimals:Int):String {
        final text = fixed(value, decimals);
        return StringTools.startsWith(text, '-') ? text : '+' + text;
    }

    /** Rust `f64::to_string` of a whole value (no exponent). */
    public static function floatToString(value:Float):String {
        if (Math.abs(value) < 1e15) return Std.string(Std.int(value / 1) == value ? Std.int(value) : value);
        return Std.string(value);
    }

    /** Rust `value.floor().to_string()`. */
    static function floorString(value:Float):String {
        final f = Math.ffloor(value);
        return f == 0 && value < 0 ? '-0' : wholeString(f);
    }

    static function wholeString(f:Float):String {
        final negative = f < 0;
        var a = Math.abs(f);
        if (a < 2147483648.) return (negative ? '-' : '') + Std.string(Std.int(a));
        final digits = new StringBuf();
        final out:Array<String> = [];
        while (a >= 1) {
            final d = Std.int(a - Math.ffloor(a / 10) * 10);
            out.unshift(Std.string(d));
            a = Math.ffloor(a / 10);
        }
        digits.add(negative ? '-' : '');
        digits.add(out.join(''));
        return digits.toString();
    }

    /**
     * Formats a large number with a compact unit, e.g. `1.24B`, so wide
     * columns stay readable.
     */
    public static function compact(val:Float):String {
        for (unit in [{scale: 1e12, unit: 'T'}, {scale: 1e9, unit: 'B'}, {scale: 1e6, unit: 'M'}, {scale: 1e3, unit: 'K'}]) {
            if (Math.abs(val) >= unit.scale) return fixed(val / unit.scale, 2) + unit.unit;
        }
        return fixed(val, 2);
    }

    /** Restarts ids from zero and builds a fresh set of rows. */
    public static function regenerateStocks(size:Int):Array<Stock> {
        incrementId = 0;
        return randomStocks(size);
    }

    public static function randomStocks(size:Int):Array<Stock> {
        // Incremental ID with size.
        final start = incrementId;
        incrementId += size + 1;

        // Drawing all 40-odd fields per row is slow for a million rows. Draw a
        // pool of fully random rows instead and clone from it, still giving
        // every row its own id and counter so no two rows read alike on screen.
        if (size > POOL_SIZE * 2) {
            final pool = randomStocksExact(0, POOL_SIZE);
            return [for (id in start...start + size) {
                final stock = pool[(id - start) % POOL_SIZE].clone();
                stock.id = id;
                stock.counter = Counter.random();
                stock;
            }];
        }

        return randomStocksExact(start, size);
    }

    /**
     * Builds `size` rows of randomized quotes.
     *
     * The fields of one row hang together the way a real quote does: the
     * change is the percentage applied to the price, the previous close sits a
     * change away from it, and the bid, ask, open, high and low stay within a
     * day's range of it. A table of unrelated numbers reads as noise.
     */
    static function randomStocksExact(start:Int, size:Int):Array<Stock> {
        return [for (id in start...start + size) {
            final price = Fake.float(5.0, 999.0);
            final changePercent = Fake.float(-0.1, 0.1);
            final change = price * changePercent;
            final shares = Math.ffloor(Fake.float(1000000, 3000000000));
            final volume = Fake.float(1e4, 5e7);

            final stock = new Stock();
            stock.id = id;
            stock.counter = Counter.random();
            stock.price = price;
            stock.change = change;
            stock.changePercent = changePercent;
            stock.volume = volume;
            stock.turnover = volume * price;
            stock.marketCap = price * shares;
            stock.ttm = Fake.float(5.0, 80.0);
            stock.fiveMinsRanking = Fake.float(0.0, 1000.0);
            stock.th60DaysRanking = Fake.float(0.0, 1000.0);
            stock.yearChangePercent = Fake.float(-1.0, 1.0);
            stock.bid = price * (1.0 - Fake.float(0.0, 0.01));
            stock.bidVolume = Fake.float(100.0, 5e4);
            stock.ask = price * (1.0 + Fake.float(0.0, 0.01));
            stock.askVolume = Fake.float(100.0, 5e4);
            stock.open = price * (1.0 + Fake.float(-0.05, 0.05));
            stock.prevClose = price - change;
            stock.high = price * (1.0 + Fake.float(0.0, 0.08));
            stock.low = price * (1.0 - Fake.float(0.0, 0.08));
            stock.turnoverRate = Fake.float(0.0, 0.2);
            stock.riseRate = Fake.float(0.0, 1.0);
            stock.amplitude = Fake.float(0.0, 0.15);
            stock.peStatus = Fake.float(5.0, 60.0);
            stock.pbStatus = Fake.float(0.5, 12.0);
            stock.volumeRatio = Fake.float(0.0, 3.0);
            stock.bidAskRatio = Fake.float(0.0, 3.0);
            stock.latestPreClose = price * (1.0 + Fake.float(-0.03, 0.03));
            stock.latestPostClose = price * (1.0 + Fake.float(-0.03, 0.03));
            stock.preMarketCap = price * shares;
            stock.preMarketPercent = Fake.float(-0.05, 0.05);
            stock.preMarketChange = price * Fake.float(-0.05, 0.05);
            stock.postMarketCap = price * shares;
            stock.postMarketPercent = Fake.float(-0.05, 0.05);
            stock.postMarketChange = price * Fake.float(-0.05, 0.05);
            stock.floatCap = price * shares * Fake.float(0.3, 1.0);
            stock.shares = shares;
            stock.sharesFloat = Math.ffloor(shares * Fake.float(0.3, 1.0));
            stock.day5Ranking = Fake.float(0.0, 1000.0);
            stock.day10Ranking = Fake.float(0.0, 1000.0);
            stock.day30Ranking = Fake.float(0.0, 1000.0);
            stock.day120Ranking = Fake.float(0.0, 1000.0);
            stock.day250Ranking = Fake.float(0.0, 1000.0);
            stock;
        }];
    }

    public function new(size:Int) {
        stocks = randomStocks(size);
        columns = [
            new Column('id', 'ID')
                .withWidth(60.)
                .withFixed(Left)
                .withResizable(true)
                .withMinWidth(40.)
                .withMaxWidth(100.),
            new Column('market', 'Market')
                .withWidth(60.)
                .withFixed(Left)
                .withResizable(true)
                .withMinWidth(50.),
            new Column('name', 'Name')
                .withWidth(180.)
                .withFixed(Left)
                .withMaxWidth(300.),
            new Column('symbol', 'Symbol')
                .withWidth(100.)
                .withFixed(Left)
                .sortable(),
            new Column('price', 'Price').sortable().textRight().p0(),
            new Column('change', 'Chg').sortable().textRight().p0(),
            new Column('change_percent', 'Chg%')
                .sortable()
                .textRight()
                .p0(),
            new Column('volume', 'Volume').textRight().p0(),
            new Column('turnover', 'Turnover').textRight().p0(),
            new Column('market_cap', 'Market Cap').textRight().p0(),
            new Column('ttm', 'TTM').textRight().p0(),
            new Column('five_mins_ranking', '5m Ranking')
                .textRight()
                .p0(),
            new Column('th60_days_ranking', '60d Ranking').textRight(),
            new Column('year_change_percent', 'Year Chg%').textRight(),
            new Column('bid', 'Bid').textRight().p0(),
            new Column('bid_volume', 'Bid Vol').textRight().p0(),
            new Column('ask', 'Ask').textRight().p0(),
            new Column('ask_volume', 'Ask Vol').textRight().p0(),
            new Column('open', 'Open').textRight().p0(),
            new Column('prev_close', 'Prev Close').textRight().p0(),
            new Column('high', 'High').textRight().p0(),
            new Column('low', 'Low').textRight().p0(),
            new Column('turnover_rate', 'Turnover Rate').textRight(),
            new Column('rise_rate', 'Rise Rate').textRight(),
            new Column('amplitude', 'Amplitude').textRight(),
            new Column('pe_status', 'P/E').textRight(),
            new Column('pb_status', 'P/B').textRight(),
            new Column('volume_ratio', 'Volume Ratio')
                .textRight()
                .p0(),
            new Column('bid_ask_ratio', 'Bid Ask Ratio')
                .textRight()
                .p0(),
            new Column('latest_pre_close', 'Latest Pre Close').textRight(),
            new Column('latest_post_close', 'Latest Post Close').textRight(),
            new Column('pre_market_cap', 'Pre Mkt Cap').textRight(),
            new Column('pre_market_percent', 'Pre Mkt%').textRight(),
            new Column('pre_market_change', 'Pre Mkt Chg').textRight(),
            new Column('post_market_cap', 'Post Mkt Cap').textRight(),
            new Column('post_market_percent', 'Post Mkt%').textRight(),
            new Column('post_market_change', 'Post Mkt Chg').textRight(),
            new Column('float_cap', 'Float Cap').textRight(),
            new Column('shares', 'Shares').textRight(),
            new Column('shares_float', 'Float Shares').textRight(),
            new Column('day_5_ranking', '5d Ranking').textRight(),
            new Column('day_10_ranking', '10d Ranking').textRight(),
            new Column('day_30_ranking', '30d Ranking').textRight(),
            new Column('day_120_ranking', '120d Ranking').textRight(),
            new Column('day_250_ranking', '250d Ranking').textRight(),
        ];
    }

    public function setStocks(stocks:Array<Stock>):Void {
        eof = stocks.length <= 50;
        this.stocks = stocks;
        loadingValue = false;
        fullLoading = false;
    }

    /**
     * The frame shared by the value cells: it fills the row and follows the
     * column alignment.
     *
     * Columns that carry their own padding (`Column.p0`) leave it to the cell,
     * so the frame supplies it for them.
     */
    function valueCell(col:Column):Div {
        final cell = div()
            .hFull()
            .hFlex()
            .itemsCenter();
        if (col.paddings != null) cell.tableCellSize(size);
        if (col.align == TextAlign.Right) cell.justifyEnd();
        return cell;
    }

    /**
     * Returns the (foreground, background) colors for a change value.
     *
     * A rise is green and a fall is red, both taken from the theme. Unchanged
     * values keep the default cell colors.
     */
    static function changeColors(val:Float, cx:App):Null<{foreground:Hsla, background:Hsla}> {
        final theme = Theme.global(cx);
        if (val > 0.) return {foreground: theme.green, background: theme.greenLight};
        if (val < 0.) return {foreground: theme.red, background: theme.redLight};
        return null;
    }

    /** A percentage, tinted over the whole cell as ticker tables do. */
    function renderPercent(col:Column, val:Float, text:String, cx:App):AnyElement {
        final cell = valueCell(col);
        final colors = changeColors(val, cx);
        if (colors != null) cell.textColor(colors.foreground).bg(colors.background.alpha(0.05));
        return cell.child(text).intoAnyElement();
    }

    /** A signed change, colored by its direction. */
    function renderChange(col:Column, val:Float, text:String, cx:App):AnyElement {
        final cell = valueCell(col);
        final colors = changeColors(val, cx);
        if (colors != null) cell.textColor(colors.foreground);
        return cell.child(text).intoAnyElement();
    }

    public function columnsCount(_:App):Int {
        return columns.length + extraColumnsCount;
    }

    public function rowsCount(_:App):Int {
        return stocks.length;
    }

    public function column(colIx:Int, _:App):Column {
        if (colIx < columns.length) {
            return columns[colIx].clone();
        }
        final n = colIx - columns.length + 1;
        return new Column('extra_$n', 'Column $n');
    }

    /**
     * Measures the heading and the text every row draws in the column, so a
     * double-click on a resize handle fits the column to its widest text.
     */
    override public function fitColumn(colIx:Int, window:Window, cx:Context<TableState<Dynamic>>):Null<Pixels> {
        // Use the same size refinement as the cells and header. Custom pixel
        // sizes keep the story's inherited `text_sm`.
        final refined = div().tableCellSize(size).style().text.fontSize;
        final fontSize:Pixels = refined != null ? refined.toPixels(window.remSize()) : rems(0.875).toPixels(window.remSize());
        final baseFont = window.textStyle().font();
        baseFont.family = Theme.global(cx.app).fontFamily;

        final col = column(colIx, cx.app);
        function measure(text:String, weight:FontWeight):Pixels {
            final font = new Font(baseFont.family, baseFont.features, baseFont.fallbacks, weight, baseFont.style);
            final run = new TextRun(glaze.util.Utf8.byteLength(text), font, new Hsla(0, 0, 0, 0));
            return window.textSystem().shapeLine(text, fontSize, [run]).width();
        }

        // The table draws the sort icon at 0.75rem with 2 px of padding on each
        // side. It is counted even while sorting is off, which only leaves room.
        final sortIcon:Pixels = col.sort != null ? rems(0.75).toPixels(window.remSize()) + 4. : 0.;
        final headerPadding:Pixels = col.paddings == null ? 0. : Math.max(size.tableCellPadding().right - col.paddings.right, 0.);
        var widest:Pixels = measure(col.name, FontWeight.NORMAL) + sortIcon + headerPadding;
        for (stock in stocks) {
            final cell = formatCell(stock, col.key);
            if (cell == null) continue;
            final w = measure(cell.text, cell.weight);
            if (w > widest) widest = w;
        }

        // A column that dropped its own padding gets the size's back from its
        // cells and header (see `valueCell`).
        final padding:Pixels = col.paddings != null ? {
            final p = size.tableCellPadding();
            p.left + p.right;
        } : 0.;
        return widest + padding;
    }

    override public function groupHeaders(cx:App):Null<Array<Array<ColumnGroup>>> {
        if (!showGroupHeaders) {
            return null;
        }
        // Both rows must span every column, and the lower row subdivides the
        // upper one, so each group lines up with the columns it names.
        final trailing = columnsCount(cx) - columns.length;

        return [
            [
                new ColumnGroup('Stock', 4),
                new ColumnGroup('Market Data', 10),
                new ColumnGroup('Quotes', 8),
                new ColumnGroup('Stats', 7),
                new ColumnGroup('Extended Hours', 8),
                new ColumnGroup('Shares & Rankings', 8 + trailing),
            ],
            [
                new ColumnGroup('Identity', 4),
                new ColumnGroup('Price & Change', 3),
                new ColumnGroup('Turnover', 4),
                new ColumnGroup('Momentum', 3),
                new ColumnGroup('Order Book', 4),
                new ColumnGroup('Session', 4),
                new ColumnGroup('Activity', 3),
                new ColumnGroup('Valuation', 2),
                new ColumnGroup('Ratios', 2),
                new ColumnGroup('Pre & Post Market', 8),
                new ColumnGroup('Shares', 3),
                new ColumnGroup('Rankings', 5 + trailing),
            ],
        ];
    }

    override public function renderTh(colIx:Int, _:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        final col = column(colIx, cx.app);

        final th = div();
        // Same rule as the cells: supply the padding only for the columns
        // that dropped their own, so a header lines up with its column.
        if (col.paddings != null) th.tableCellSize(size);
        if (col.align == TextAlign.Center) th.hFlex().wFull().justifyCenter();
        if (col.align == TextAlign.Right) th.hFlex().wFull().justifyEnd();
        return th.child(col.name);
    }

    override public function contextMenu(rowIx:Int, menu:PopupMenu, _window:Window, _:Context<TableState<Dynamic>>):PopupMenu {
        return menu.menu('Selected Row: $rowIx', new OpenDetail(rowIx))
            .separator()
            .menu('Size 48px', new ChangeSize(Size(px(48.))))
            .menu('Size Large', new ChangeSize(Large))
            .menu('Size Medium', new ChangeSize(Medium))
            .menu('Size Small', new ChangeSize(Small))
            .menu('Size XSmall', new ChangeSize(XSmall));
    }

    override public function renderTr(rowIx:Int, _:Window, cx:Context<TableState<Dynamic>>):Div {
        return div()
            .id(rowIx)
            .onClick(cx.listener((table:TableState<Dynamic>, ev:ClickEvent, _window, cx) -> {
                trace('You have clicked row with secondary: ${ev.modifiers().secondary()}');

                final delegate:StockTableDelegate = cast table.delegateMut();
                delegate.clickedRow = rowIx;
                cx.notify();
            }));
    }

    override public function cellLabel(rowIx:Int, colIx:Int, _:App):Null<String> {
        if (rowIx >= stocks.length || colIx >= columns.length) return null;
        final cell = formatCell(stocks[rowIx], columns[colIx].key);
        return cell != null ? cell.text : '--';
    }

    public function renderTd(rowIx:Int, colIx:Int, _:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        final theme = Theme.global(cx.app);
        final stock = stocks[rowIx];
        if (colIx >= columns.length) {
            return div().child('--').intoAnyElement();
        }
        final col = columns[colIx];

        final cell = formatCell(stock, col.key);
        if (cell == null) {
            return valueCell(col)
                .textColor(theme.mutedForeground)
                .child('--')
                .intoAnyElement();
        }
        final text = cell.text;

        return switch col.key {
            case 'id':
                final el = valueCell(col).textColor(theme.mutedForeground);
                if (col.align == TextAlign.Center) el.justifyCenter();
                el.child(text).intoAnyElement();
            case 'market':
                valueCell(col)
                    .textColor(stock.counter.market == 'US' ? theme.blue : theme.magenta)
                    .child(text)
                    .intoAnyElement();
            case 'name':
                valueCell(col)
                    .child(div().truncate().child(text))
                    .intoAnyElement();
            case 'change': renderChange(col, stock.change, text, cx.app);
            case 'pre_market_change': renderChange(col, stock.preMarketChange, text, cx.app);
            case 'post_market_change': renderChange(col, stock.postMarketChange, text, cx.app);
            case 'change_percent': renderPercent(col, stock.changePercent, text, cx.app);
            case 'year_change_percent': renderPercent(col, stock.yearChangePercent, text, cx.app);
            case 'pre_market_percent': renderPercent(col, stock.preMarketPercent, text, cx.app);
            case 'post_market_percent': renderPercent(col, stock.postMarketPercent, text, cx.app);
            case _:
                valueCell(col)
                    .fontWeight(cell.weight)
                    .child(text)
                    .intoAnyElement();
        }
    }

    override public function moveColumn(colIx:Int, toIx:Int, _:Window, _:Context<TableState<Dynamic>>):Void {
        final col = columns.splice(colIx, 1)[0];
        columns.insert(toIx, col);
    }

    override public function performSort(colIx:Int, sort:ColumnSort, _:Window, _:Context<TableState<Dynamic>>):Void {
        if (colIx >= columns.length) return;
        final byId = (a:Stock, b:Stock) -> a.id - b.id;
        switch columns[colIx].key {
            case 'id':
                stocks.sort(sort == Descending ? (a, b) -> b.id - a.id : byId);
            case 'symbol':
                stocks.sort(sort == Descending ? (a, b) -> compareStrings(b.counter.symbol, a.counter.symbol) : byId);
            case 'change' | 'change_percent':
                stocks.sort(sort == Descending ? (a, b) -> b.change < a.change ? -1 : (b.change > a.change ? 1 : 0) : byId);
            case _:
        }
    }

    static function compareStrings(a:String, b:String):Int {
        return a < b ? -1 : (a > b ? 1 : 0);
    }

    override public function loading(_:App):Bool {
        return fullLoading;
    }

    override public function hasMore(_:App):Bool {
        if (!lazyLoad) {
            return false;
        }
        if (loadingValue) {
            return false;
        }

        return !eof;
    }

    override public function loadMoreThreshold():Int {
        return 150;
    }

    override public function loadMore(_:Window, cx:Context<TableState<Dynamic>>):Void {
        if (!lazyLoad) {
            return;
        }

        loadingValue = true;

        loadTask = cx.spawn((view, acx) -> {
            // Simulate network request, delay 1s to load data.
            return acx.backgroundExecutor().timer(1.).then(_ -> {
                if (!view.isUpgradable()) return;
                view.update(acx, (view:TableState<Dynamic>, _) -> {
                    final delegate:StockTableDelegate = cast view.delegateMut();
                    delegate.stocks = delegate.stocks.concat(randomStocks(200));
                    delegate.loadingValue = false;
                    delegate.eof = delegate.stocks.length >= 6000;
                });
            });
        });
    }

    override public function visibleRowsChanged(visibleRange:Range, _:Window, _:Context<TableState<Dynamic>>):Void {
        visibleRows = visibleRange;
    }

    override public function visibleColumnsChanged(visibleRange:Range, _:Window, _:Context<TableState<Dynamic>>):Void {
        visibleCols = visibleRange;
    }

    override public function cellText(rowIx:Int, colIx:Int, _:App):String {
        if (rowIx >= stocks.length || colIx >= columns.length) return '';
        final stock = stocks[rowIx];

        return switch columns[colIx].key {
            case 'id': Std.string(stock.id);
            case 'market': stock.counter.market;
            case 'symbol': stock.counter.symbolCode();
            case 'name': stock.counter.name;
            case 'price': fixed(stock.price, 3);
            case 'change': fixed(stock.change, 3);
            case 'change_percent': fixed(stock.changePercent * 100., 2) + '%';
            case 'volume': fixed(stock.volume, 3);
            case 'turnover': fixed(stock.turnover, 3);
            case 'market_cap': fixed(stock.marketCap, 3);
            case 'ttm': fixed(stock.ttm, 3);
            case 'five_mins_ranking': fixed(stock.fiveMinsRanking, 3);
            case 'th60_days_ranking': floorString(stock.th60DaysRanking);
            case 'year_change_percent': fixed(stock.yearChangePercent * 100., 2) + '%';
            case 'bid': fixed(stock.bid, 3);
            case 'bid_volume': fixed(stock.bidVolume, 3);
            case 'ask': fixed(stock.ask, 3);
            case 'ask_volume': fixed(stock.askVolume, 3);
            case 'open': fixed(stock.open, 3);
            case 'prev_close': fixed(stock.prevClose, 3);
            case 'high': fixed(stock.high, 3);
            case 'low': fixed(stock.low, 3);
            case 'turnover_rate': fixed(stock.turnoverRate * 100., 0);
            case 'rise_rate': fixed(stock.riseRate * 100., 0);
            case 'amplitude': fixed(stock.amplitude * 100., 0);
            case 'pe_status': floorString(stock.peStatus);
            case 'pb_status': floorString(stock.pbStatus);
            case 'volume_ratio': fixed(stock.volumeRatio, 3);
            case 'bid_ask_ratio': fixed(stock.bidAskRatio, 3);
            case 'latest_pre_close': floorString(stock.latestPreClose);
            case 'latest_post_close': floorString(stock.latestPostClose);
            case 'pre_market_cap': floorString(stock.preMarketCap);
            case 'pre_market_percent': fixed(stock.preMarketPercent * 100., 2) + '%';
            case 'pre_market_change': floorString(stock.preMarketChange);
            case 'post_market_cap': floorString(stock.postMarketCap);
            case 'post_market_percent': fixed(stock.postMarketPercent * 100., 2) + '%';
            case 'post_market_change': floorString(stock.postMarketChange);
            case 'float_cap': floorString(stock.floatCap);
            case 'shares': wholeString(stock.shares);
            case 'shares_float': wholeString(stock.sharesFloat);
            case 'day_5_ranking': floorString(stock.day5Ranking);
            case 'day_10_ranking': floorString(stock.day10Ranking);
            case 'day_30_ranking': floorString(stock.day30Ranking);
            case 'day_120_ranking': floorString(stock.day120Ranking);
            case 'day_250_ranking': floorString(stock.day250Ranking);
            case _: '';
        }
    }

    /**
     * The text `renderTd` draws for `stock` in the column `key`, with its
     * weight, or null for a column it has no value for.
     *
     * `fitColumn` measures the same text, so a column fits what is drawn.
     */
    public static function formatCell(stock:Stock, key:String):Null<{text:String, weight:FontWeight}> {
        final text = switch key {
            case 'id': Std.string(stock.id);
            case 'market': stock.counter.market;
            case 'symbol': return {text: stock.counter.symbolCode(), weight: FontWeight.MEDIUM};
            case 'name': stock.counter.name;
            case 'price': return {text: fixed(stock.price, 2), weight: FontWeight.SEMIBOLD};
            case 'change': signed(stock.change, 2);
            case 'change_percent': signed(stock.changePercent * 100., 2) + '%';
            case 'volume': compact(stock.volume);
            case 'turnover': compact(stock.turnover);
            case 'market_cap': compact(stock.marketCap);
            case 'ttm': compact(stock.ttm);
            case 'five_mins_ranking': fixed(stock.fiveMinsRanking, 0);
            case 'th60_days_ranking': fixed(stock.th60DaysRanking, 0);
            case 'year_change_percent': signed(stock.yearChangePercent * 100., 2) + '%';
            case 'bid': fixed(stock.bid, 2);
            case 'bid_volume': compact(stock.bidVolume);
            case 'ask': fixed(stock.ask, 2);
            case 'ask_volume': compact(stock.askVolume);
            case 'open': fixed(stock.open, 2);
            case 'prev_close': fixed(stock.prevClose, 2);
            case 'high': fixed(stock.high, 2);
            case 'low': fixed(stock.low, 2);
            case 'turnover_rate': fixed(stock.turnoverRate * 100., 2) + '%';
            case 'rise_rate': fixed(stock.riseRate * 100., 2) + '%';
            case 'amplitude': fixed(stock.amplitude * 100., 2) + '%';
            case 'pe_status': fixed(stock.peStatus, 2);
            case 'pb_status': fixed(stock.pbStatus, 2);
            case 'volume_ratio': fixed(stock.volumeRatio, 2);
            case 'bid_ask_ratio': fixed(stock.bidAskRatio, 2);
            case 'latest_pre_close': fixed(stock.latestPreClose, 2);
            case 'latest_post_close': fixed(stock.latestPostClose, 2);
            case 'pre_market_cap': compact(stock.preMarketCap);
            case 'pre_market_percent': signed(stock.preMarketPercent * 100., 2) + '%';
            case 'pre_market_change': signed(stock.preMarketChange, 2);
            case 'post_market_cap': compact(stock.postMarketCap);
            case 'post_market_percent': signed(stock.postMarketPercent * 100., 2) + '%';
            case 'post_market_change': signed(stock.postMarketChange, 2);
            case 'float_cap': compact(stock.floatCap);
            case 'shares': compact(stock.shares);
            case 'shares_float': compact(stock.sharesFloat);
            case 'day_5_ranking': fixed(stock.day5Ranking, 0);
            case 'day_10_ranking': fixed(stock.day10Ranking, 0);
            case 'day_30_ranking': fixed(stock.day30Ranking, 0);
            case 'day_120_ranking': fixed(stock.day120Ranking, 0);
            case 'day_250_ranking': fixed(stock.day250Ranking, 0);
            case _: return null;
        }
        return {text: text, weight: FontWeight.NORMAL};
    }

}

class DataTableStory extends Model implements Story {

    final table:Entity<TableState<StockTableDelegate>>;
    var stripe:Bool;
    var refreshData:Bool;
    var size:Size;
    var headerRowHeight:Null<Pixels>;

    final subscriptions:Array<Subscription>;
    final loadTask:Task<Dynamic>;
    var loadRowsTask:Task<Dynamic>;

    public static function title():String {
        return 'DataTable';
    }

    public static function description():String {
        return 'A complex data table with selection, sorting, column moving, and loading more.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function closable():Bool {
        return false;
    }

    public static function view(window:Window, cx:App):Entity<DataTableStory> {
        return cx.newEntity((cx:Context<DataTableStory>) -> new DataTableStory(window, cx));
    }

    public function focusHandle(cx:App):FocusHandle {
        return table.read(cx).focusHandle(cx);
    }

    function new(window:Window, cx:Context<DataTableStory>) {
        super();
        final delegate = new StockTableDelegate(5000);
        table = cx.newEntity((cx:Context<TableState<StockTableDelegate>>) -> new TableState(delegate, window, cx));

        subscriptions = [cx.subscribeIn(table, TableEvent, window, (this_:DataTableStory, _, event, _, _) -> this_.onTableEvent(event))];

        loadTask = cx.spawn((this_, acx) -> tick(this_, acx));

        stripe = false;
        refreshData = false;
        size = Medium;
        headerRowHeight = null;
        loadRowsTask = Task.done();
    }

    /** One step of the Rust `loop`: wait 33ms, refresh the head of the table. */
    static function tick(this_:glaze.WeakEntity<DataTableStory>, acx:glaze.AsyncApp):Task<Dynamic> {
        return acx.backgroundExecutor().timer(0.033).then(_ -> {
            if (!this_.isUpgradable()) return;
            this_.update(acx, (this_:DataTableStory, cx) -> {
                if (!this_.refreshData) {
                    return;
                }

                this_.table.update(cx, (table, _) -> {
                    // Only walk the head of the table. It paints a few dozen
                    // rows at a time, so ticking every row of the million-row
                    // example would stall the frame for nothing on screen.
                    final maxRefreshRows = 2000;
                    final stocks = table.delegateMut().stocks;
                    for (i in 0...(stocks.length < maxRefreshRows ? stocks.length : maxRefreshRows)) {
                        final n = 3 + Fake.index(7);
                        // update 30% of the stocks
                        if (i % n == 0) {
                            stocks[i].randomUpdate();
                        }
                    }
                });
                cx.notify();
            });
            tick(this_, acx);
        });
    }

    function toggleLoopSelection(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.loopSelectionValue = checked;
            cx.notify();
        });
    }

    function toggleColResize(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.colResizableValue = checked;
            cx.notify();
        });
    }

    function toggleColOrder(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.colMovableValue = checked;
            cx.notify();
        });
    }

    function toggleColSort(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.sortableValue = checked;
            cx.notify();
        });
    }

    function toggleColFixed(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.colFixed = checked;
            cx.notify();
        });
    }

    function toggleColSelection(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.colSelectableValue = checked;
            cx.notify();
        });
    }

    function toggleRowSelection(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.rowSelectableValue = checked;
            cx.notify();
        });
    }

    function toggleCellSelection(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.cellSelectableValue = checked;
            cx.notify();
        });
    }

    function toggleRowHeader(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.rowHeaderValue = checked;
            cx.notify();
        });
    }

    function toggleStripe(checked:Bool, cx:Context<DataTableStory>):Void {
        stripe = checked;
        cx.notify();
    }

    function onChangeSize(a:ChangeSize, cx:Context<DataTableStory>):Void {
        size = a.value;
        table.update(cx, (table, cx) -> {
            table.delegateMut().size = a.value;
            cx.notify();
        });
        cx.notify();
    }

    function onChangeHeaderRowHeight(a:ChangeHeaderRowHeight, cx:Context<DataTableStory>):Void {
        headerRowHeight = a.value;
        cx.notify();
    }

    function toggleRefreshData(checked:Bool, cx:Context<DataTableStory>):Void {
        refreshData = checked;
        cx.notify();
    }

    function toggleGroupHeaders(checked:Bool, cx:Context<DataTableStory>):Void {
        table.update(cx, (table, cx) -> {
            table.delegateMut().showGroupHeaders = checked;
            table.refreshHeaderLayout(cx);
        });
    }

    function onTableEvent(event:TableEvent):Void {
        switch event {
            case ColumnWidthsChanged(colWidths):
                trace('Column widths changed: $colWidths');
            case SelectColumn(ix):
                trace('Select col: $ix');
            case SelectCell(rowIx, colIx):
                trace('Select cell: row=$rowIx, col=$colIx');
            case DoubleClickedCell(rowIx, colIx):
                trace('Double clicked cell: row=$rowIx, col=$colIx');
            case DoubleClickedRow(ix):
                trace('Double clicked row: $ix');
            case SelectRow(ix):
                trace('Select row: $ix');
            case MoveColumn(originIdx, targetIdx):
                trace('Move col index: $originIdx -> $targetIdx');
            case RightClickedRow(ix):
                trace('Right clicked row: ${ix == null ? 'None' : 'Some($ix)'}');
            case RightClickedCell(rowIx, colIx):
                trace('Right clicked cell: row=$rowIx, col=$colIx');
            case ClearSelection:
                trace('Selection cleared');
        }
    }

    function dumpCsv(_:ClickEvent, _:Window, cx:Context<DataTableStory>):Void {
        final downloadDir = downloadDir();
        if (downloadDir == null) {
            trace('Failed to get download directory');
            return;
        }

        final receiver = cx.app.promptForNewPath(downloadDir, 'export.csv');
        final table = this.table;
        final app = cx.app;
        // Rust `receiver.await.ok()`: a prompt that failed counts as cancelled
        receiver.catchError(_ -> null).then(path -> {
            if (path == null) {
                trace('CSV export cancelled by user');
                return;
            }

            try {
                writeCsv(table, path, app);
                trace('CSV exported successfully');
            } catch (error:haxe.Exception) {
                trace('Failed to export CSV: ${error.message}');
            }
        }).detach();
    }

    /**
     * Rust `write_csv`: the headers, then the rows read in batches of
     * `CSV_EXPORT_BATCH_ROWS` with `dump_range`, written with the `csv`
     * crate's defaults (comma, `\n` line ends, fields quoted only when
     * needed). The text is written with Ceramic's `Files` (native targets,
     * node and Electron; in a browser, the download path of the save prompt
     * starts a download, initial port deviation DEV-019).
     */
    static function writeCsv(table:Entity<TableState<StockTableDelegate>>, path:String, cx:App):Void {
        final state = table.read(cx);
        final headers = state.headers(cx);
        final rowsCount = state.delegate().rowsCount(cx);

        final csv = new StringBuf();
        writeCsvRecord(csv, headers);
        var start = 0;
        while (start < rowsCount) {
            final end = start + CSV_EXPORT_BATCH_ROWS < rowsCount ? start + CSV_EXPORT_BATCH_ROWS : rowsCount;
            for (row in table.read(cx).dumpRange(new Range(start, end), cx).rows) {
                writeCsvRecord(csv, row);
            }
            start = end;
        }
        ceramic.Files.saveContent(path, csv.toString());
    }

    /** Rust `CSV_EXPORT_BATCH_ROWS`. */
    static inline final CSV_EXPORT_BATCH_ROWS = 2000;

    /**
     * One record as the `csv` crate writes it by default (`QuoteStyle::Necessary`):
     * a field is quoted when it holds a comma, a quote or a line break (quotes
     * doubled), and a record made of one empty field is written as `""`.
     */
    public static function writeCsvRecord(out:StringBuf, fields:Array<String>):Void {
        if (fields.length == 1 && fields[0].length == 0) {
            out.add('""\n');
            return;
        }
        for (i in 0...fields.length) {
            if (i > 0) out.add(',');
            final field = fields[i];
            if (field.indexOf(',') != -1 || field.indexOf('"') != -1 || field.indexOf('\n') != -1 || field.indexOf('\r') != -1) {
                out.add('"');
                out.add(StringTools.replace(field, '"', '""'));
                out.add('"');
            } else {
                out.add(field);
            }
        }
        out.add('\n');
    }

    /**
     * Rust `dirs::download_dir()`: the user's Downloads folder (the XDG
     * download folder on Linux when set), or `null` where there is none (the
     * web, like the wasm build).
     */
    static function downloadDir():Null<String> {
        #if web
        // Initial port deviation DEV-019: Rust has no download directory on
        // wasm and stops here. The browser chooses where downloads go, so any
        // folder will do: the save prompt gives a download path whose write
        // starts a browser download (Ceramic `BrowserFiles`).
        return '';
        #else
        final xdg = ceramic.Platform.getEnv('XDG_DOWNLOAD_DIR');
        if (xdg != null && xdg.length > 0) return xdg;
        var home = ceramic.Platform.getEnv('HOME');
        if (home == null || home.length == 0) home = ceramic.Platform.getEnv('USERPROFILE');
        if (home == null || home.length == 0) return null;
        return haxe.io.Path.join([home, 'Downloads']);
        #end
    }

    /** Rust `{:?}` of a `Size`. */
    static function debugSize(size:Size):String {
        return switch size {
            case XSmall: 'XSmall';
            case Small: 'Small';
            case Medium: 'Medium';
            case Large: 'Large';
            case Size(px): 'Size(${pixelsString(px)})';
        }
    }

    /** Rust `Pixels` Display (`48px`). */
    static function pixelsString(value:Pixels):String {
        final f:Float = value;
        return (f == Math.ffloor(f) && Math.abs(f) < 1e15 ? Std.string(Std.int(f)) : Std.string(f)) + 'px';
    }

    static function sizeEquals(a:Size, b:Size):Bool {
        return a.equals(b);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<DataTableStory> = cast cx;
        final theme = Theme.global(cx.app);
        final table = this.table.read(cx.app);
        final delegate = table.delegate();
        final rowsCount = delegate.rowsCount(cx.app);
        final columnsCount = delegate.columnsCount(cx.app);
        final size = this.size;
        final headerRowHeight = this.headerRowHeight;
        final loopSelection = table.loopSelectionValue;
        final colResizable = table.colResizableValue;
        final colMovable = table.colMovableValue;
        final sortable = table.sortableValue;
        final colSelectable = table.colSelectableValue;
        final rowSelectable = table.rowSelectableValue;
        final cellSelectable = table.cellSelectableValue;
        final rowHeader = table.rowHeaderValue;
        final colFixed = table.colFixed;
        final striped = stripe;
        final fullLoading = delegate.fullLoading;
        final lazyLoad = delegate.lazyLoad;
        final refreshData = this.refreshData;
        final showGroupHeaders = delegate.showGroupHeaders;
        final extraColumnsCount = delegate.extraColumnsCount;

        final dataTable = DataTable.component(this.table).withSize(size);
        if (headerRowHeight != null) dataTable.headerRowHeight(headerRowHeight);
        dataTable.stripe(stripe);

        final status = hFlex()
            .itemsCenter()
            .justifyEnd()
            .gap2();
        if (delegate.loadingValue) status.child(Spinner.component().xsmall());
        status.child('Current · rows ${delegate.visibleRows.start}..${delegate.visibleRows.end} · columns ${delegate.visibleCols.start}..${delegate.visibleCols.end}');
        final selectedCell = table.selectedCell();
        if (selectedCell != null) status.child('· cell ${selectedCell.row}:${selectedCell.col}');
        if (delegate.eof) status.child('· complete');

        return vFlex()
            .onAction(ChangeSize, self.listener((this_:DataTableStory, a:ChangeSize, _, cx) -> this_.onChangeSize(a, cx)))
            .onAction(ChangeHeaderRowHeight, self.listener((this_:DataTableStory, a:ChangeHeaderRowHeight, _, cx) -> this_.onChangeHeaderRowHeight(a, cx)))
            .onAction(ChangeRows, self.listener((this_:DataTableStory, action:ChangeRows, _, cx) -> {
                if (action.value == this_.table.read(cx.app).delegate().stocks.length) {
                    return;
                }

                // Building the largest example allocates a lot. Show the
                // loading state, build later, and swap the rows in when they
                // land.
                final size = action.value;
                this_.table.update(cx, (table, cx) -> {
                    table.delegateMut().fullLoading = true;
                    cx.notify();
                });
                this_.loadRowsTask = cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(0.).then(_ -> {
                    final stocks = StockTableDelegate.regenerateStocks(size);
                    if (!this_.isUpgradable()) return;
                    this_.update(acx, (this_:DataTableStory, cx) -> {
                        this_.table.update(cx, (table, cx) -> {
                            table.delegateMut().setStocks(stocks);
                            table.refresh(cx);
                        });
                        cx.notify();
                    });
                }));
            }))
            .onAction(ChangeExtraColumns, self.listener((this_:DataTableStory, action:ChangeExtraColumns, _, cx) -> {
                this_.table.update(cx, (table, cx) -> {
                    table.delegateMut().extraColumnsCount = action.value;
                    table.refresh(cx);
                });
                cx.notify();
            }))
            .onAction(ClearTableSelection, self.listener((this_:DataTableStory, _:ClearTableSelection, _, cx) -> {
                this_.table.update(cx, (table, cx) -> table.clearSelection(cx));
            }))
            .onAction(GoToTablePosition, self.listener((this_:DataTableStory, action:GoToTablePosition, _, cx) -> {
                this_.table.update(cx, (table, cx) -> switch action.value {
                    case Top: table.scrollToRow(0, cx);
                    case Bottom: table.scrollToRow(table.delegate().rowsCount(cx.app) - 1, cx);
                    case Cell53: table.setSelectedCell(5, 3, cx);
                    case Cell107: table.setSelectedCell(10, 7, cx);
                });
            }))
            .onAction(ToggleTableOption, self.listener((this_:DataTableStory, action:ToggleTableOption, _, cx) -> {
                final state = this_.table.read(cx.app);
                switch action.value {
                    case LoopSelection: this_.toggleLoopSelection(!state.loopSelectionValue, cx);
                    case ColumnResize: this_.toggleColResize(!state.colResizableValue, cx);
                    case ColumnOrder: this_.toggleColOrder(!state.colMovableValue, cx);
                    case Sortable: this_.toggleColSort(!state.sortableValue, cx);
                    case ColumnSelection: this_.toggleColSelection(!state.colSelectableValue, cx);
                    case RowSelection: this_.toggleRowSelection(!state.rowSelectableValue, cx);
                    case CellSelection: this_.toggleCellSelection(!state.cellSelectableValue, cx);
                    case RowHeader: this_.toggleRowHeader(!state.rowHeaderValue, cx);
                    case FixedColumn: this_.toggleColFixed(!state.colFixed, cx);
                    case Striped: this_.toggleStripe(!this_.stripe, cx);
                    case Loading:
                        this_.table.update(cx, (table, cx) -> {
                            table.delegateMut().fullLoading = !table.delegate().fullLoading;
                            cx.notify();
                        });
                    case LazyLoad:
                        this_.table.update(cx, (table, cx) -> {
                            table.delegateMut().lazyLoad = !table.delegate().lazyLoad;
                            cx.notify();
                        });
                    case RefreshData: this_.toggleRefreshData(!this_.refreshData, cx);
                    case GroupHeaders: this_.toggleGroupHeaders(!state.delegate().showGroupHeaders, cx);
                }
            }))
            .sizeFull()
            .textSm()
            .gap4()
            .child(storyToolbarGroup()
                .dropdownChild(Button.component('size').label('Size: ${debugSize(this.size)}'), (menu, _, _) -> menu
                    .menuWithCheck('48px', sizeEquals(size, Size(px(48.))), new ChangeSize(Size(px(48.))))
                    .menuWithCheck('Large', sizeEquals(size, Large), new ChangeSize(Large))
                    .menuWithCheck('Medium', sizeEquals(size, Medium), new ChangeSize(Medium))
                    .menuWithCheck('Small', sizeEquals(size, Small), new ChangeSize(Small))
                    .menuWithCheck('XSmall', sizeEquals(size, XSmall), new ChangeSize(XSmall)))
                .dropdownChild(Button.component('header-row-height')
                    .label('Header Row Height: ${headerRowHeight == null ? 'Default' : pixelsString(headerRowHeight)}'), (menu, _, _) -> menu
                    .menuWithCheck('Default', headerRowHeight == null, new ChangeHeaderRowHeight(null))
                    .menuWithCheck('40px', headerRowHeight != null && headerRowHeight == px(40.), new ChangeHeaderRowHeight(px(40.)))
                    .menuWithCheck('48px', headerRowHeight != null && headerRowHeight == px(48.), new ChangeHeaderRowHeight(px(48.))))
                .dropdownChild(Button.component('rows').label('Rows: $rowsCount'), (menu, _, _) -> menu
                    .menuWithCheck('100', rowsCount == 100, new ChangeRows(100))
                    .menuWithCheck('500', rowsCount == 500, new ChangeRows(500))
                    .menuWithCheck('5,000', rowsCount == 5000, new ChangeRows(5000))
                    .menuWithCheck('10,000', rowsCount == 10000, new ChangeRows(10000))
                    .menuWithCheck('1,000,000', rowsCount == 1000000, new ChangeRows(1000000)))
                .dropdownChild(Button.component('extra-columns').label('Extra Columns: $extraColumnsCount'), (menu, _, _) -> menu
                    .menuWithCheck('None', extraColumnsCount == 0, new ChangeExtraColumns(0))
                    .menuWithCheck('4', extraColumnsCount == 4, new ChangeExtraColumns(4))
                    .menuWithCheck('8', extraColumnsCount == 8, new ChangeExtraColumns(8))
                    .menuWithCheck('16', extraColumnsCount == 16, new ChangeExtraColumns(16))
                    .menuWithCheck('32', extraColumnsCount == 32, new ChangeExtraColumns(32)))
                .dropdownChild(Button.component('table-options').label('Options'), (menu, _, _) -> menu
                    .menuWithCheck('Loop Selection', loopSelection, new ToggleTableOption(LoopSelection))
                    .menuWithCheck('Column Resize', colResizable, new ToggleTableOption(ColumnResize))
                    .menuWithCheck('Column Order', colMovable, new ToggleTableOption(ColumnOrder))
                    .menuWithCheck('Sortable', sortable, new ToggleTableOption(Sortable))
                    .menuWithCheck('Column Selectable', colSelectable, new ToggleTableOption(ColumnSelection))
                    .menuWithCheck('Row Selectable', rowSelectable, new ToggleTableOption(RowSelection))
                    .menuWithCheck('Cell Selectable', cellSelectable, new ToggleTableOption(CellSelection))
                    .menuWithCheck('Row Header', rowHeader, new ToggleTableOption(RowHeader))
                    .menuWithCheck('Fixed Column', colFixed, new ToggleTableOption(FixedColumn))
                    .separator()
                    .menuWithCheck('Striped Rows', striped, new ToggleTableOption(Striped))
                    .menuWithCheck('Loading', fullLoading, new ToggleTableOption(Loading))
                    .menuWithCheck('Lazy Load', lazyLoad, new ToggleTableOption(LazyLoad))
                    .menuWithCheck('Refresh Data', refreshData, new ToggleTableOption(RefreshData))
                    .menuWithCheck('Group Headers', showGroupHeaders, new ToggleTableOption(GroupHeaders))
                    .separator()
                    .menu('Clear Selection', new ClearTableSelection()))
                .dropdownChild(Button.component('go-to').label('Go To'), (menu, _, _) -> menu
                    .menu('Top', new GoToTablePosition(Top))
                    .menu('Bottom', new GoToTablePosition(Bottom))
                    .separator()
                    .menu('Cell 5:3', new GoToTablePosition(Cell53))
                    .menu('Cell 10:7', new GoToTablePosition(Cell107)))
                .child(Button.component('dump-csv')
                    .label('Export CSV')
                    .onClick(self.listener((this_:DataTableStory, e:ClickEvent, window, cx) -> this_.dumpCsv(e, window, cx)))))
            .child(vFlex()
                .minH0()
                .flex1()
                .child(dataTable)
                .child(hFlex()
                    .wFull()
                    .minH9()
                    .itemsCenter()
                    .justifyBetween()
                    .gap3()
                    .px3()
                    .bg(theme.muted.opacity(0.35))
                    .textXs()
                    .textColor(theme.mutedForeground)
                    .child('Total · $rowsCount rows · $columnsCount columns')
                    .child(status)));
    }

}
