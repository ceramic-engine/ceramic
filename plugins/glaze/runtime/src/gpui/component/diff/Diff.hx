// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.Axis;
import gpui.ClickEvent;
import gpui.ClipboardItem;
import gpui.Context;
import gpui.Div;
import gpui.ElementId;
import gpui.Entity;
import gpui.Font;
import gpui.HighlightStyle;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.ListOffset;
import gpui.MouseButton;
import gpui.OperatingSystem;
import gpui.Pixels;
import gpui.Point;
import gpui.Range;
import gpui.RenderOnce;
import gpui.SpringMath;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.TextRun;
import gpui.Window;
import gpui.base.ScrollBounce;
import gpui.base.ScrollableMask;
import gpui.base.Scrollbar;
import gpui.base.input.InputActions.Copy;
import gpui.base.input.InputActions.SelectAll;
import gpui.component.I18n;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.diff.DiffActions;
import gpui.component.diff.DiffDecoration.Decorations;
import gpui.component.diff.DiffDecoration.GutterMarkers;
import gpui.component.diff.DiffState.DisplayRow;
import gpui.component.diff.DiffState.FoldExpansion;
import gpui.component.diff.DiffState.LayoutKey;
import gpui.component.diff.DiffState.SelectedLines;
import gpui.component.diff.DiffState.SelectedLinesTools;
import gpui.component.diff.Presentation.DiffStyledRange;
import gpui.component.diff.Presentation.FilePresentation;
import gpui.component.diff.Selection.CodeText;
import gpui.component.diff.Selection.SelectionGeometry;
import gpui.component.diff.Selection.SelectionLayer;
import gpui.component.highlighter.HighlightTheme.HighlightThemeResolver;
import gpui.component.theme.ActiveTheme;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.hFlex;
import gpui.base.Prelude.vFlex;

using gpui.base.Observe;
using gpui.base.StyledExt;

typedef FileRenderer = (DiffFile, Window, App) -> IntoElement;

typedef AnnotationRenderer = (DiffAnnotation, Window, App) -> IntoElement;

typedef MarkerRenderer = (DiffGutterMarker, Window, App) -> IntoElement;

typedef RangeHandler = (DiffLineRange, Window, App) -> Void;

typedef ClickHandler = (DiffLinePosition, ClickEvent, Window, App) -> Void;

typedef HoverHandler = (Null<DiffLinePosition>, Window, App) -> Void;

@:allow(gpui.component.diff)
private class HeaderSlots {

    var content:Null<FileRenderer> = null;
    var prefix:Null<FileRenderer> = null;
    var titleSuffix:Null<FileRenderer> = null;
    var suffix:Null<FileRenderer> = null;

    function new() {}

}

@:allow(gpui.component.diff)
private class Annotations {

    final items:Array<DiffAnnotation> = [];

    /** Indices into `items` by line position key. */
    final lines:Map<String, Array<Int>> = new Map();

    /** Indices into `items` by file path. */
    final files:Map<String, Array<Int>> = new Map();

    function new() {}

}

/**
 * A themed readonly code-review surface in split or unified mode.
 *
 * All files of the supplied state share one virtualized list, each
 * introduced by its header. The component owns its scrolling, so give it a
 * bounded height. Long lines scroll horizontally unless `softWrap` is set;
 * file headers and review annotations are explicit slots, and application
 * commands remain owned by the application.
 */
class Diff implements RenderOnce implements Styled {

    public static inline final CONTEXT:String = DiffActions.CONTEXT;

    final state:Entity<DiffState>;

    final diffStyle:StyleRefinement = new StyleRefinement();

    var _lineNumber:Bool = true;
    var _syntaxHighlight:Bool = true;
    var _headerVisible:Bool = true;
    var _hoverHighlight:DiffHoverHighlight = DiffHoverHighlight.None;
    var _hunkSeparator:DiffHunkSeparator = Metadata;
    var _changeIndicator:DiffChangeIndicator = Signs;
    var _changeBackground:Bool = true;
    var _softWrap:Bool = false;
    final header:HeaderSlots = new HeaderSlots();
    var _annotations:Annotations = new Annotations();
    var annotationContent:Null<AnnotationRenderer> = null;
    var _decorations:Decorations = @:privateAccess new Decorations([]);
    var _gutterMarkers:GutterMarkers = @:privateAccess new GutterMarkers([]);
    var gutterMarkerContent:Null<MarkerRenderer> = null;
    var _onAddAnnotation:Null<RangeHandler> = null;
    var _onLineClick:Null<ClickHandler> = null;
    var _onLineHover:Null<HoverHandler> = null;

    public function new(state:Entity<DiffState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return diffStyle;
    }

    /** Shows the original and modified line-number lanes. Default is true. */
    public function lineNumber(value:Bool):Diff {
        _lineNumber = value;
        return this;
    }

    /** Emphasizes syntax once the state has prepared it. Default is true. */
    public function syntaxHighlight(value:Bool):Diff {
        _syntaxHighlight = value;
        return this;
    }

    /** Shows a header above each file. Default is true. */
    public function headerVisible(visible:Bool):Diff {
        _headerVisible = visible;
        return this;
    }

    /** Emphasizes the line, its number, or both under the pointer. Default is none. */
    public function hoverHighlight(highlight:DiffHoverHighlight):Diff {
        _hoverHighlight = highlight;
        return this;
    }

    /** Marks the start of each hunk. Default is `DiffHunkSeparator.Metadata`. */
    public function hunkSeparator(separator:DiffHunkSeparator):Diff {
        _hunkSeparator = separator;
        return this;
    }

    /** Marks changed lines beside the code. Default is `DiffChangeIndicator.Signs`. */
    public function changeIndicator(indicator:DiffChangeIndicator):Diff {
        _changeIndicator = indicator;
        return this;
    }

    /** Tints changed lines. Default is true. Inline changes stay emphasized. */
    public function changeBackground(value:Bool):Diff {
        _changeBackground = value;
        return this;
    }

    /**
     * Wraps long lines at the column width instead of scrolling
     * horizontally. Default is false.
     */
    public function softWrap(value:Bool):Diff {
        _softWrap = value;
        return this;
    }

    /**
     * Supplies annotations with stable identities and targets.
     *
     * Rows re-measure when annotations are added, removed or replaced, and
     * whenever they are visible, so annotation content may change height freely.
     */
    public function annotations(annotations:Iterable<DiffAnnotation>):Diff {
        final index = new Annotations();
        gpui.util.Iterables.append(index.items, annotations);
        for (ix in 0...index.items.length) {
            final annotation = index.items[ix];
            final position = annotation.position();
            final map = position != null ? index.lines : index.files;
            final key = position != null ? position.key() : annotation.path();
            var list = map.get(key);
            if (list == null) {
                list = [];
                map.set(key, list);
            }
            list.push(ix);
        }
        _annotations = index;
        return this;
    }

    /** Renders each supplied annotation. Application state and commands stay with the owner. */
    public function renderAnnotation(render:AnnotationRenderer):Diff {
        annotationContent = render;
        return this;
    }

    /**
     * Supplies line backgrounds that mark source ranges, such as diagnostics
     * or references, without changing the selection.
     */
    public function decorations(decorations:Iterable<DiffDecoration>):Diff {
        _decorations = @:privateAccess new Decorations(decorations);
        return this;
    }

    /**
     * Supplies markers for the marker lane, shown once both markers and
     * `renderGutterMarker` are set. The lane holds one marker per line; when
     * several target the same line, the first supplied is shown.
     */
    public function gutterMarkers(markers:Iterable<DiffGutterMarker>):Diff {
        _gutterMarkers = @:privateAccess new GutterMarkers(markers);
        return this;
    }

    /**
     * Renders each gutter marker within a lane one row high and wide.
     *
     * Return a focusable control such as a small ghost button labeled with
     * `DiffGutterMarker.label`, so the marker works with the pointer and
     * keyboard. Presses inside the lane do not start a selection.
     */
    public function renderGutterMarker(render:MarkerRenderer):Diff {
        gutterMarkerContent = render;
        return this;
    }

    /**
     * Replaces the content of each file header, keeping its shell, separator
     * and collapse control.
     */
    public function renderHeader(render:FileRenderer):Diff {
        header.content = render;
        return this;
    }

    /** Inserts content before the path in the default header. */
    public function renderHeaderPrefix(render:FileRenderer):Diff {
        header.prefix = render;
        return this;
    }

    /** Inserts compact content immediately after the path in the default header. */
    public function renderHeaderTitleSuffix(render:FileRenderer):Diff {
        header.titleSuffix = render;
        return this;
    }

    /** Inserts trailing content after the change statistics in the default header. */
    public function renderHeaderSuffix(render:FileRenderer):Diff {
        header.suffix = render;
        return this;
    }

    /** Compatibility alias for `renderAnnotation`. */
    public function annotationContentWith(render:AnnotationRenderer):Diff {
        return renderAnnotation(render);
    }

    /** Compatibility alias for `renderHeader`. */
    public function headerWith(render:FileRenderer):Diff {
        return renderHeader(render);
    }

    /** Compatibility alias for `renderHeaderPrefix`. */
    public function headerPrefix(render:FileRenderer):Diff {
        return renderHeaderPrefix(render);
    }

    /** Compatibility alias for `renderHeaderTitleSuffix`. */
    public function headerTitleSuffix(render:FileRenderer):Diff {
        return renderHeaderTitleSuffix(render);
    }

    /** Compatibility alias for `renderHeaderSuffix`. */
    public function headerSuffix(render:FileRenderer):Diff {
        return renderHeaderSuffix(render);
    }

    /**
     * Shows an add button beside the hovered line and at the end of the
     * selected lines. The handler receives the selected range when the line
     * is part of it, or that line alone.
     */
    public function onAddAnnotation(handler:RangeHandler):Diff {
        _onAddAnnotation = handler;
        return this;
    }

    /** Handles a click on a line's code, outside a text-selection drag. */
    public function onLineClick(handler:ClickHandler):Diff {
        _onLineClick = handler;
        return this;
    }

    /** Reports the line under the pointer, or null when the pointer leaves it. */
    public function onLineHover(handler:HoverHandler):Diff {
        _onLineHover = handler;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final props = this;
        return state.update(cx, (state, cx) -> renderDiff(props, state, window, cx));
    }

    static inline function f32(v:Float):Float {
        return SpringMath.f32(v);
    }

    static function renderDiff(props:Diff, state:DiffState, window:Window, cx:Context<DiffState>):AnyElement {
        final theme = ActiveTheme.theme(cx);
        state.setWindow(window.id);
        state.ensurePresentation(cx);
        final rem:Float = window.remSize();
        final fontSize = f32(rem * f32(f32(theme.monoFontSize) / 16.));
        final fontFamily = theme.monoFontFamily;
        final rowHeight = f32(fontSize * f32(1.6));
        var digits = 1;
        var anyFile = false;
        for (file in state.files()) {
            if (!anyFile || file.lineNumberDigits() > digits)
                digits = file.lineNumberDigits();
            anyFile = true;
        }
        final gutterWidth = props._lineNumber ? f32(f32(f32(fontSize * f32(0.7)) * digits) + rem) : 0.;
        final mode = state.mode();
        final softWrap = props._softWrap;
        final markerLane = !props._gutterMarkers.isEmpty() && props.gutterMarkerContent != null;
        final laneWidth = markerLane ? rowHeight : 0.;
        final layout = @:privateAccess new LayoutKey(rem, fontSize, fontFamily, mode, props._lineNumber, markerLane, softWrap);
        if (state.updateLayout(layout, rowHeight)) {
            // Wrapped rows take the viewport width instead of their longest line.
            final width = softWrap ? 0. : measureCodeWidth(state.files(), fontSize, fontFamily, gutterWidth, laneWidth, mode, window, cx.app);
            state.setContentWidth(width);
        }
        state.syncAnnotations(props._annotations.items);
        final contentWidth = state.contentWidth() > state.viewport().width ? state.contentWidth() : state.viewport().width;
        final columnWidth = mode == Split ? f32(contentWidth / 2.) : contentWidth;
        final code = new CodePresentation();
        code.files = state.files().copy();
        code.presentations = state.presentations().copy();
        code.mode = mode;
        code.contentWidth = contentWidth;
        code.columnWidth = columnWidth;
        code.fontSize = fontSize;
        code.rowHeight = rowHeight;
        code.gutterWidth = gutterWidth;
        code.rem = rem;
        code.expansionLines = state.expansionLines();
        code.lineNumber = props._lineNumber;
        code.syntaxHighlight = props._syntaxHighlight;
        code.headerVisible = props._headerVisible;
        code.hoverHighlight = props._hoverHighlight;
        code.hunkSeparator = props._hunkSeparator;
        code.changeIndicator = props._changeIndicator;
        code.changeBackground = props._changeBackground;
        code.softWrap = softWrap;
        code.header = props.header;
        code.annotations = props._annotations;
        code.annotationContent = props.annotationContent;
        code.decorations = props._decorations;
        code.gutterMarkers = props._gutterMarkers;
        code.gutterMarkerContent = markerLane ? props.gutterMarkerContent : null;
        code.laneWidth = laneWidth;
        code.onAddAnnotation = props._onAddAnnotation;
        code.onLineClick = props._onLineClick;
        code.onLineHover = props._onLineHover;
        code.selection = state.selection();
        code.selectedLines = state.selectedLines();
        code.selected = state.selectedSpan();
        code.geometry = state.geometry();
        code.state = cx.entity();
        final rows = state.rows();
        final scrollbar = state.list();
        final horizontal = state.horizontalScroll();
        final hasRows = rows.length > 0;
        // Rust labels the body for accessibility (`Diff.Viewer`); the port has
        // no accessibility tree.
        final body = div()
            .id('diff-body')
            .relative()
            .minH0()
            .minW0()
            .flex1()
            .child(new SelectionLayer(div()
                .id('diff-horizontal')
                .sizeFull()
                // Preserve offset tracking and clipping without GPUI's
                // single-axis wheel remapping. The sibling mask owns X input.
                .when(!softWrap, d -> d.overflowXHidden())
                .trackScroll(horizontal)
                .child(new ScrollBounce('diff-bounce', scrollbar, list(scrollbar, (ix, window, cx) -> {
                    final row = rows[ix];
                    return div()
                        .id(ElementId.NamedInteger('diff-file', DiffState.DisplayRowTools.file(row)))
                        .wFull()
                        .child(renderRow(row, code, window, cx));
                })
                    .w(px(contentWidth))
                    .hFull()))
                .intoAnyElement(), scrollbar, horizontal, state.selection(), state.geometry()))
            .when(hasRows && !softWrap, d -> d.child(new ScrollableMask(Axis.Horizontal, horizontal).id('diff-horizontal-wheel')))
            .when(hasRows, d -> {
                d.child(Scrollbar.vertical(scrollbar));
                if (!softWrap)
                    d.child(Scrollbar.horizontal(horizontal));
                return d;
            })
            // A line-number drag may finish anywhere, including outside the body.
            .onMouseUp(MouseButton.Left, cx.listener((this_:DiffState, _, _, cx:Context<DiffState>) -> this_.endLineSelection(cx)))
            .onMouseUpOut(MouseButton.Left, cx.listener((this_:DiffState, _, _, cx:Context<DiffState>) -> this_.endLineSelection(cx)))
            .onAction(ScrollUp, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.list().scrollBy(-f32(window.remSize() * 1.5));
                cx.notify();
            }))
            .onAction(ScrollDown, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.list().scrollBy(f32(window.remSize() * 1.5));
                cx.notify();
            }))
            .onAction(ScrollLeft, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                final offset = this_.horizontalScroll().offset();
                this_.horizontalScroll().setOffset(new Point(f32(offset.x + f32(window.remSize() * 3.)), offset.y));
                cx.notify();
            }))
            .onAction(ScrollRight, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                final offset = this_.horizontalScroll().offset();
                this_.horizontalScroll().setOffset(new Point(f32(offset.x - f32(window.remSize() * 3.)), offset.y));
                cx.notify();
            }))
            .onAction(PageUp, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.list().scrollBy(-f32(this_.viewport().height * f32(0.9)));
                cx.notify();
            }))
            .onAction(PageDown, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.list().scrollBy(f32(this_.viewport().height * f32(0.9)));
                cx.notify();
            }))
            .onAction(First, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.list().scrollTo(new ListOffset());
                cx.notify();
            }))
            .onAction(Last, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.list().scrollToEnd();
                cx.notify();
            }))
            .onAction(ExtendUp, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.keyboardSelect(-1, true, window, cx);
            }))
            .onAction(ExtendDown, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                this_.keyboardSelect(1, true, window, cx);
            }))
            .onAction(SelectAll, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (bodyFocused(this_, window, cx))
                    this_.selectAll(window, cx);
            }))
            .onAction(Copy, cx.listener((this_:DiffState, _, window:Window, cx:Context<DiffState>) -> {
                if (!bodyFocused(this_, window, cx))
                    return;
                final text = this_.selectedText(cx.app);
                if (text.length == 0)
                    cx.propagate();
                else
                    cx.app.writeToClipboard(ClipboardItem.newString(text));
            }))
            .child(canvas((bounds, _, cx) -> {
                final entity = code.state;
                entity.update(cx, (state:DiffState, cx:Context<DiffState>) -> {
                    // Runs after the list's prepaint, which drops every row
                    // height when its width changes.
                    final rehinted = state.keepRowHeightHint();
                    // The estimate shapes the widest candidates only; grow to
                    // fit any wider line once it is painted.
                    final painted = if (softWrap) {
                        0.;
                    }
                    else {
                        codeWidth(state.geometry().paintedWidth(), gutterWidth, laneWidth, rem, mode);
                    }
                    if (state.recordPaint(bounds.size, painted) || rehinted)
                        cx.notify();
                });
                return null;
            }, (_, _, _, _) -> {}).absolute().sizeFull())
            .testSupport()
            .trackFocus(state.focusHandleOf())
            .keyContext(CONTEXT);
        return vFlex()
            .id(ElementId.NamedInteger('diff', cx.entityId()))
            .sizeFull()
            .minW0()
            .minH0()
            .bg(theme.background)
            .textColor(theme.foreground)
            .textSm()
            .border1()
            .borderColor(theme.border)
            .child(body)
            .refineStyle(props.diffStyle)
            .intoAnyElement();
    }

    static function bodyFocused(state:DiffState, window:Window, cx:Context<DiffState>):Bool {
        if (state.focusHandleOf().isFocused(window))
            return true;
        cx.propagate();
        return false;
    }

    /** Total row width for code of `width` in the current mode. */
    static function codeWidth(width:Float, gutterWidth:Float, laneWidth:Float, rem:Float, mode:DiffMode):Float {
        if (mode == Split)
            return f32(f32(f32(f32(width + gutterWidth) + laneWidth) + f32(rem * 2.)) * 2.);
        return f32(f32(f32(width + f32(gutterWidth * 2.)) + laneWidth) + f32(rem * 2.));
    }

    /**
     * Estimates content width from the lines widest in display cells, then
     * shapes those candidates with the code font for resolved geometry.
     */
    static function measureCodeWidth(files:Array<DiffFile>, fontSize:Float, family:String, gutterWidth:Float, laneWidth:Float, mode:DiffMode,
            window:Window, cx:App):Float {
        // Glyph widths vary within a font, so shape several candidates rather
        // than trusting the single widest by cell count.
        final CANDIDATES = 8;
        final candidates:Array<{cells:Int, text:String}> = [];
        for (file in files) {
            for (side in [DiffSide.Original, DiffSide.Modified]) {
                for (line in file.lines(side)) {
                    final cells = UnicodeWidth.width(line.display());
                    if (candidates.length == CANDIDATES && candidates[candidates.length - 1].cells >= cells)
                        continue;
                    var ix = 0;
                    while (ix < candidates.length && candidates[ix].cells >= cells)
                        ix++;
                    candidates.insert(ix, {cells: cells, text: line.display()});
                    if (candidates.length > CANDIDATES)
                        candidates.resize(CANDIDATES);
                }
            }
        }
        final font = new Font(family);
        final foreground = ActiveTheme.theme(cx).foreground;
        var width = 0.;
        for (candidate in candidates) {
            final text = candidate.text;
            final shaped = window.textSystem().shapeLine(text, fontSize, [new TextRun(gpui.util.Utf8.byteLength(text), font, foreground)]);
            final w = shaped.width();
            if (w > width)
                width = w;
        }
        return codeWidth(width, gutterWidth, laneWidth, window.remSize(), mode);
    }

    static function renderRow(row:DisplayRow, code:CodePresentation, window:Window, cx:App):AnyElement {
        return switch (row) {
            case File(file): renderFileHeader(file, code, window, cx);
            case Notice(file): renderNotice(code.files[file], cx);
            case Hunk(file, hunk): renderHunkSeparator(file, hunk, code, cx);
            case Fold(file, pairs): renderFold(file, pairs, code, cx);
            case Conflict(file, conflict, part): renderConflict(file, conflict, part, code, cx);
            case Code(file, original, modified, changed):
                if (code.mode == Split && !code.files[file].isSingleColumn()) {
                    hFlex()
                        .itemsStretch()
                        .wFull()
                        .child(renderCell(file, Original, original, modified, changed, code, window, cx))
                        .child(renderCell(file, Modified, modified, original, changed, code, window, cx))
                        .intoAnyElement();
                }
                else {
                    final side:DiffSide = modified != null ? Modified : Original;
                    final ix:Int = modified != null ? modified : original;
                    renderUnifiedCell(file, side, ix, original, modified, changed, code, window, cx);
                }
        }
    }

    static function renderHunkSeparator(file:Int, hunk:Int, code:CodePresentation, cx:App):AnyElement {
        final theme = ActiveTheme.theme(cx);
        final hunks = code.files[file].hunks();
        final row = hFlex()
            .wFull()
            .px3()
            .bg(theme.muted.opacity(0.35))
            .textXs()
            .textColor(theme.mutedForeground);
        return switch (code.hunkSeparator) {
            case Metadata:
                row.h6().child(hunks[hunk].label()).intoAnyElement();
            case LineInfo:
                final hidden = hunks[hunk].hiddenLinesBefore(hunk > 0 ? hunks[hunk - 1] : null);
                if (hidden == 0)
                    div().intoAnyElement();
                else
                    row.h6().child(I18n.t('Diff.HiddenLines', {count: hidden})).intoAnyElement();
            case Simple:
                row.h1().intoAnyElement();
        }
    }

    static function renderFold(file:Int, pairs:Range, code:CodePresentation, cx:App):AnyElement {
        final theme = ActiveTheme.theme(cx);
        final document = code.files[file];
        // A fold bordering the hunk start has no source above it, and one
        // bordering the hunk end has none below; offer only the meaningful sides.
        var hunk = new Range(0, document.pairs().length);
        for (h in document.hunks()) {
            if (h.pairs().contains(pairs.start)) {
                hunk = h.pairs();
                break;
            }
        }
        final lines = code.expansionLines;
        final partial = pairs.len() > lines;
        function expand(id:ElementId, expansion:FoldExpansion):Button {
            final state = code.state;
            return new Button(id).ghost().xsmall().wAuto().textColor(theme.mutedForeground).onClick((_, _, cx) -> {
                state.update(cx, (state:DiffState, cx:Context<DiffState>) -> state.expandFold(file, pairs, expansion, cx));
            });
        }
        final row = hFlex()
            .wFull()
            .h6()
            .px2()
            .gap1()
            .bg(theme.muted.opacity(0.35));
        if (partial && pairs.start > hunk.start)
            row.child(expand(ElementId.NamedInteger('expand-down', pairs.start), Down).icon(IconName.ArrowDown)
                .accessibilityLabel(I18n.t('Diff.ExpandBelow', {count: lines})));
        if (partial && pairs.end < hunk.end)
            row.child(expand(ElementId.NamedInteger('expand-up', pairs.start), Up).icon(IconName.ArrowUp)
                .accessibilityLabel(I18n.t('Diff.ExpandAbove', {count: lines})));
        row.child(expand(ElementId.NamedInteger('expand', pairs.start), All).icon(partial ? IconName.ChevronsUpDown : IconName.ChevronDown)
            .label(I18n.t('Diff.UnchangedLines', {count: pairs.len()}))
            .accessibilityLabel(I18n.t('Diff.ExpandLines', {count: pairs.len()})));
        return row.intoAnyElement();
    }

    /**
     * The heading of one part of a conflict, with the resolution commands on
     * the current part; a resolved conflict shows its choice and Undo instead.
     */
    static function renderConflict(file:Int, ix:Int, part:ConflictPart, code:CodePresentation, cx:App):AnyElement {
        final theme = ActiveTheme.theme(cx);
        final document = code.files[file];
        final conflict = document.conflicts()[ix];
        final resolution = code.state.read(cx).conflictResolution(document.path(), ix);
        function choose(id:String, label:String, resolution:Null<DiffConflictResolution>):Button {
            final state = code.state;
            return new Button(ElementId.NamedInteger(id, ix)).ghost().xsmall().wAuto().label(label).onClick((_, _, cx) -> {
                state.update(cx, (state:DiffState, cx:Context<DiffState>) -> state.chooseConflict(file, ix, resolution, cx));
            });
        }
        final row = hFlex()
            .wFull()
            .h6()
            .px3()
            .gap2()
            .textXs()
            .textColor(theme.mutedForeground)
            .bg(conflictTint(part, cx).opacity(0.25));
        if (resolution != null) {
            final label = switch (resolution) {
                case Current: I18n.t('Diff.AcceptedCurrent');
                case Incoming: I18n.t('Diff.AcceptedIncoming');
                default: I18n.t('Diff.AcceptedBoth');
            }
            return row.bg(theme.muted.opacity(0.35))
                .child(label)
                .child(choose('undo-resolution', I18n.t('Diff.UndoResolution'), null))
                .intoAnyElement();
        }
        final title = switch (part) {
            case Current: I18n.t('Diff.CurrentChange');
            case Base: I18n.t('Diff.BaseChange');
            case Incoming: I18n.t('Diff.IncomingChange');
        }
        final label = @:privateAccess conflict.label(part);
        row.child(div().fontMedium().child(title));
        if (label.length > 0)
            row.child(label);
        if (part == Current) {
            row.child(div().flex1())
                .child(choose('accept-current', I18n.t('Diff.AcceptCurrent'), DiffConflictResolution.Current))
                .child(choose('accept-incoming', I18n.t('Diff.AcceptIncoming'), DiffConflictResolution.Incoming))
                .child(choose('accept-both', I18n.t('Diff.AcceptBoth'), DiffConflictResolution.Both));
        }
        return row.intoAnyElement();
    }

    /** The color that marks lines of a conflict part. */
    static function conflictTint(part:Null<ConflictPart>, cx:App):Hsla {
        final theme = ActiveTheme.theme(cx);
        return if (part == ConflictPart.Current) {
            theme.success;
        }
        else if (part == ConflictPart.Incoming) {
            theme.info;
        }
        else {
            theme.mutedForeground;
        }
    }

    static function renderFileHeader(file:Int, code:CodePresentation, window:Window, cx:App):AnyElement {
        if (!code.headerVisible)
            return div().children(fileAnnotations(file, code, window, cx)).intoAnyElement();
        final theme = ActiveTheme.theme(cx);
        final document = code.files[file];
        final foreground = theme.mutedForeground;
        final border = theme.border;
        final collapsed = code.state.read(cx).isFileCollapsed(document.path());
        final content:IntoElement = if (code.header.content != null) {
            code.header.content(document, window, cx);
        }
        else {
            final old = document.originalPath();
            final newPath = document.modifiedPath();
            final name = old != null && newPath != null && old != newPath ? '$old → $newPath' : document.path();
            function slot(render:Null<FileRenderer>):Null<IntoElement> {
                return render != null ? render(document, window, cx) : null;
            }
            final prefix = slot(code.header.prefix);
            final titleSuffix = slot(code.header.titleSuffix);
            final suffix = slot(code.header.suffix);
            final status = switch (document.status()) {
                case Added: I18n.t('Diff.AddedFile');
                case Deleted: I18n.t('Diff.DeletedFile');
                case Renamed: I18n.t('Diff.RenamedFile');
                case Copied: I18n.t('Diff.CopiedFile');
                case Conflicted: I18n.t('Diff.ConflictedFile');
                default: null;
            }
            final statistics = !document.isSingleColumn();
            final title = hFlex()
                .minW0()
                .flex1()
                .gap2()
                .child(div().minW0().truncate().fontMedium().child(name));
            if (titleSuffix != null)
                title.child(div().flexShrink0().child(titleSuffix));
            final row = hFlex()
                .wFull()
                .minW0()
                .gap2();
            if (prefix != null)
                row.child(prefix);
            row.child(title);
            if (statistics)
                row.child(div().textXs().textColor(foreground).child('+' + document.additions() + ' −' + document.deletions()));
            if (status != null)
                row.child(div().textXs().textColor(foreground).child(status));
            if (suffix != null)
                row.child(suffix);
            row;
        }
        final state = code.state;
        final name = document.path();
        return vFlex()
            .id('file-header')
            .wFull()
            .when(file > 0, d -> d.borderT1())
            .borderB1()
            .borderColor(border)
            .child(hFlex()
                .wFull()
                .minW0()
                .pl1()
                .pr3()
                .py1()
                .gap1()
                .child(new Button('collapse-file').ghost()
                    .xsmall()
                    .icon(collapsed ? IconName.ChevronRight : IconName.ChevronDown)
                    .accessibilityLabel(collapsed ? I18n.t('Diff.ExpandFile', {name: name}) : I18n.t('Diff.CollapseFile', {name: name}))
                    .onClick((_, _, cx) -> state.update(cx, (state:DiffState, cx:Context<DiffState>) -> state.toggleFileCollapsed(file, cx))))
                .child(div().flex1().minW0().child(content)))
            .children(fileAnnotations(file, code, window, cx))
            .intoAnyElement();
    }

    static function fileAnnotations(file:Int, code:CodePresentation, window:Window, cx:App):Array<IntoElement> {
        final path = code.files[file].path();
        final ixs = code.annotations.files.get(path);
        return annotationElements(ixs != null ? ixs : [], code, window, cx);
    }

    /** Summarizes a file without source rows: binary, metadata-only or empty. */
    static function renderNotice(file:DiffFile, cx:App):AnyElement {
        final theme = ActiveTheme.theme(cx);
        final message = if (!file.hasChanges()) {
            I18n.t('Diff.NoChanges');
        }
        else if (file.isBinary()) {
            I18n.t('Diff.BinaryChanges');
        }
        else if (file.extendedHeaders().length > 0) {
            I18n.t('Diff.NoTextChanges');
        }
        else {
            I18n.t('Diff.EmptyFile');
        }
        return vFlex()
            .wFull()
            .px3()
            .py2()
            .gap1()
            .textXs()
            .textColor(theme.mutedForeground)
            .children([for (line in file.extendedHeaders()) (div().child(line) : IntoElement)])
            .child(div().textSm().child(message))
            .intoAnyElement();
    }

    static function renderGutter(file:Int, side:DiffSide, ix:Null<Int>, code:CodePresentation, cx:App):AnyElement {
        final theme = ActiveTheme.theme(cx);
        final hover = code.hoverHighlight == LineNumber || code.hoverHighlight == Both;
        final gutter = div()
            .id(side == Original ? 'old-gutter' : 'new-gutter')
            .flexShrink0()
            .w(code.gutterWidth)
            .pr1()
            .when(hover, d -> d.hover(s -> s.bg(theme.listHover)));
        if (ix != null) {
            final position = code.position(file, side, ix);
            final state = code.state;
            // A plain hit target: line numbers need no button chrome or state.
            // Rust exposes it as a button labeled `Diff.SelectLine`; the port
            // has no accessibility tree.
            gutter.child(div()
                .id(ElementId.NamedInteger('line', ix))
                .testSupport()
                .wFull()
                .h(code.rowHeight)
                .px1()
                .flex()
                .itemsCenter()
                .justifyEnd()
                .textSize(code.fontSize)
                .textColor(theme.mutedForeground)
                .hover(s -> s.textColor(theme.foreground))
                .child(Std.string(position.line()))
                .onMouseDown(MouseButton.Left, (event, window, cx) -> {
                    state.update(cx, (state:DiffState, cx:Context<DiffState>) -> state.beginLineSelection(position, event.modifiers.shift, window, cx));
                })
                .onMouseMove((event, _, cx) -> {
                    if (event.pressedButton == MouseButton.Left)
                        state.update(cx, (state:DiffState, cx:Context<DiffState>) -> state.dragLineSelection(position, cx));
                }));
        }
        return gutter.intoAnyElement();
    }

    static function sideLabel(side:DiffSide):String {
        return side == Original ? I18n.t('Diff.Original') : I18n.t('Diff.Modified');
    }

    static function renderCell(file:Int, side:DiffSide, ix:Null<Int>, otherIx:Null<Int>, changed:Bool, code:CodePresentation, window:Window,
            cx:App):AnyElement {
        final theme = ActiveTheme.theme(cx);
        final cell = vFlex()
            .w(code.columnWidth)
            .minW0()
            .flexShrink0()
            .when(side == Original, d -> d.borderR1().borderColor(theme.border))
            .when(ix == null, d -> d.bg(theme.muted.opacity(0.3)).child(div().h(code.rowHeight)));
        if (ix == null)
            return cell.intoAnyElement();
        return cell.id(ElementId.NamedInteger(side == Original ? 'old' : 'new', ix))
            .child(codeLine(file, side, ix, changed, code, [{side: side, ix: ix}], window, cx))
            .children(lineExtras(file, side, ix, otherIx, changed, code, window, cx))
            .intoAnyElement();
    }

    static function renderUnifiedCell(file:Int, side:DiffSide, ix:Int, original:Null<Int>, modified:Null<Int>, changed:Bool, code:CodePresentation,
            window:Window, cx:App):AnyElement {
        final singleColumn = code.files[file].isSingleColumn();
        final counterpart = code.files[file].lines(side)[ix].counterpart();
        final otherIx = side == Original ? modified : original;
        final extras = lineExtras(file, side, ix, counterpart, changed, code, window, cx);
        if (!changed && otherIx != null) {
            for (e in lineAnnotations(file, side.other(), otherIx, code, window, cx))
                extras.push(e);
        }
        final gutters:Array<{side:DiffSide, ix:Null<Int>}> = singleColumn ? [{side: Modified, ix: modified}] : [
            {side: Original, ix: original},
            {side: Modified, ix: modified}
        ];
        return vFlex()
            .w(singleColumn ? code.contentWidth : code.columnWidth)
            .id(ElementId.NamedInteger(side == Original ? 'old' : 'new', ix))
            .child(codeLine(file, side, ix, changed, code, gutters, window, cx))
            .children(extras)
            .intoAnyElement();
    }

    /** Syntax colors with inline-change and selection emphasis layered over them. */
    static function lineHighlights(file:Int, side:DiffSide, ix:Int, changed:Bool, selected:Bool, status:Hsla, code:CodePresentation,
            cx:App):Array<DiffStyledRange> {
        final theme = ActiveTheme.theme(cx);
        final line = code.files[file].lines(side)[ix];
        final presentation = file < code.presentations.length ? code.presentations[file] : null;
        final highlights = presentation != null && code.syntaxHighlight ? presentation.syntaxHighlights(line, side, ix,
            new HighlightThemeResolver(theme.highlightTheme)) : [];
        if (changed && presentation != null) {
            for (range in presentation.inlineChanges(line, side, ix)) {
                final style = new HighlightStyle();
                style.backgroundColor = status.opacity(0.3);
                highlights.push(new DiffStyledRange(range, style));
            }
        }
        if (selected) {
            final style = new HighlightStyle();
            style.backgroundColor = theme.selection;
            highlights.push(new DiffStyledRange(new Range(0, line.displayLen()), style));
        }
        return highlights;
    }

    /** The add-annotation button, shown on hover and at the end of the selection. */
    static function addAnnotationButton(file:Int, side:DiffSide, ix:Int, left:Float, code:CodePresentation, cx:App):Null<AnyElement> {
        final handler = code.onAddAnnotation;
        if (handler == null)
            return null;
        final theme = ActiveTheme.theme(cx);
        final position = code.position(file, side, ix);
        final range = code.selectedLines != null && code.isSelected(file, side, ix) ? code.selectedLines : new DiffLineRange(position.path(), side,
            position.line(), position.line());
        final atSelectionEnd = code.selected != null && SelectedLinesTools.isLast(code.selected, code.files, file, side, ix);
        // Rust exposes it as a button labeled `Diff.AddAnnotation`; the port
        // has no accessibility tree.
        return div()
            .id(ElementId.NamedInteger('add-annotation', ix))
            .testSupport()
            .absolute()
            .top0()
            .left(px(left))
            .size(code.rowHeight)
            .flex()
            .itemsCenter()
            .justifyCenter()
            .rounded(theme.radius)
            .bg(theme.primary)
            .textColor(theme.primaryForeground)
            .when(!atSelectionEnd, d -> d.opacity(0.).groupHover('diff-line', s -> s.opacity(1.)))
            .child(new Icon(IconName.Plus).xsmall())
            .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation())
            .onClick((_, window, cx) -> handler(range, window, cx))
            .intoAnyElement();
    }

    static function codeLine(file:Int, side:DiffSide, ix:Int, changed:Bool, code:CodePresentation, gutters:Array<{side:DiffSide, ix:Null<Int>}>,
            window:Window, cx:App):AnyElement {
        final theme = ActiveTheme.theme(cx);
        final document = code.files[file];
        final line = document.lines(side)[ix];
        var conflictPart:Null<ConflictPart> = null;
        if (document.status() == Conflicted && changed) {
            for (conflict in document.conflicts()) {
                if (@:privateAccess conflict.sourceLines().contains(ix)) {
                    conflictPart = @:privateAccess conflict.partOf(ix);
                    break;
                }
            }
        }
        final status = if (conflictPart != null) {
            conflictTint(conflictPart, cx);
        }
        else if (side == Original) {
            theme.danger;
        }
        else {
            theme.success;
        }
        var selected = code.isSelected(file, side, ix);
        if (!selected && code.mode == Unified && !changed) {
            for (gutter in gutters) {
                if (gutter.ix != null && code.isSelected(file, gutter.side, gutter.ix)) {
                    selected = true;
                    break;
                }
            }
        }
        final highlights = lineHighlights(file, side, ix, changed, selected, status, code, cx);
        // An unchanged Unified row shows one source line for both sides;
        // follow the side a text selection started on so its offsets stay
        // consistent.
        var textSide = side;
        var textIx = ix;
        if (code.mode == Unified && !changed) {
            final selectedRange = Selection.selectedSourceRange(code.selection, cx);
            if (selectedRange != null && selectedRange.file == file && selectedRange.side != side && line.counterpart() != null) {
                textSide = selectedRange.side;
                textIx = line.counterpart();
            }
        }
        final position = code.position(file, textSide, textIx);
        final sourceLine = document.lines(textSide)[textIx];
        // Wrapped text must be one run to break across the column; unwrapped
        // long lines stay chunked to bound shaping and selection projection.
        final ranges = code.softWrap ? [new Range(0, sourceLine.displayLen())] : sourceLine.chunkRanges();
        // A block container gives wrapped text a definite width to break at.
        final text = div();
        if (code.softWrap)
            text.wFull();
        else
            text.flex().flexRow().flexShrink0();
        for (chunkIx in 0...ranges.length)
            text.child(new CodeText(ElementId.NamedInteger('code', chunkIx), document, file, textSide, textIx, ranges[chunkIx], highlights.copy(),
                code.selection, code.geometry));
        var gutterCount = 0;
        for (gutter in gutters)
            gutterCount++;
        final guttersWidth = code.lineNumber ? f32(code.gutterWidth * gutterCount) : 0.;
        final indicator = switch (code.changeIndicator) {
            case Signs:
                div()
                    .w4()
                    .flexShrink0()
                    .textColor(changed ? status : theme.mutedForeground)
                    .child(!(changed && conflictPart == null) ? ' ' : (side == Original ? '−' : '+'));
            case Bars:
                div().w4().hFull().flexShrink0().when(changed, d -> d.child(div().w(px(3.)).hFull().bg(status)));
            case None:
                div().w2().flexShrink0();
        }
        final hoverLine = code.hoverHighlight == Line || code.hoverHighlight == Both;
        final addButton = addAnnotationButton(file, side, ix, f32(f32(guttersWidth + code.laneWidth) + f32(code.rem / 2.)), code, cx);
        // Unified rows of unchanged lines carry both sides; either may be targeted.
        final positions = [for (gutter in gutters) if (gutter.ix != null) code.position(file, gutter.side, gutter.ix)];
        var decoration:Null<Hsla> = null;
        if (!selected) {
            for (p in positions) {
                final found = @:privateAccess code.decorations.at(p);
                if (found != null) {
                    decoration = found.background() != null ? found.background() : theme.warning.opacity(0.2);
                    break;
                }
            }
        }
        var markerLane:Null<Div> = null;
        if (code.gutterMarkerContent != null) {
            final render = code.gutterMarkerContent;
            var marker:Null<DiffGutterMarker> = null;
            for (p in positions) {
                marker = @:privateAccess code.gutterMarkers.at(p);
                if (marker != null)
                    break;
            }
            markerLane = div()
                .id('marker-lane')
                .flexShrink0()
                .size(code.rowHeight)
                .flex()
                .itemsCenter()
                .justifyCenter()
                // Keep presses on a marker from starting a text or line selection.
                .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation());
            if (marker != null)
                markerLane.child(render(marker, window, cx));
        }
        final row = hFlex()
            .id('line-row')
            .group('diff-line')
            .relative()
            .wFull()
            .px2();
        if (code.softWrap)
            row.minH(code.rowHeight).itemsStart().whitespaceNormal();
        else
            row.h(code.rowHeight).whitespaceNowrap();
        row.fontFamily(theme.monoFontFamily)
            .textSize(code.fontSize)
            .lineHeight(code.rowHeight)
            .when(changed && code.changeBackground, d -> d.bg(status.opacity(0.12)));
        // An overlay, so the change background shows through a translucent fill.
        if (decoration != null)
            row.child(div().absolute().inset0().bg(decoration));
        row.when(selected, d -> d.bg(theme.selection))
            .when(hoverLine && !selected, d -> d.hover(s -> s.bg(theme.listHover)));
        if (code.onLineHover != null) {
            final handler = code.onLineHover;
            row.onHover((hovered, window, cx) -> handler(hovered ? position : null, window, cx));
        }
        if (code.lineNumber) {
            for (gutter in gutters)
                row.child(renderGutter(file, gutter.side, gutter.ix, code, cx));
        }
        if (markerLane != null)
            row.child(markerLane);
        row.child(indicator);
        // Rust labels the source for accessibility (its text, and
        // `Diff.RemovedLine`, `Diff.AddedLine` or `Diff.SourceLine`); the port
        // has no accessibility tree.
        final source = div().id('source').testSupport();
        if (code.softWrap)
            source.flex1().minW0();
        else
            source.flexShrink0();
        if (code.onLineClick != null) {
            final handler = code.onLineClick;
            source.onClick((event, window, cx) -> {
                // A drag selects text; only a stationary press is a click.
                switch (event) {
                    case Mouse(mouse):
                        final dx = mouse.up.position.x - mouse.down.position.x;
                        final dy = mouse.up.position.y - mouse.down.position.y;
                        if (Math.abs(dx) > 3. || Math.abs(dy) > 3.)
                            return;
                    default:
                }
                handler(position, event, window, cx);
            });
        }
        source.child(text);
        row.child(source);
        if (addButton != null)
            row.child(addButton);
        return row.intoAnyElement();
    }

    static function lineExtras(file:Int, side:DiffSide, ix:Int, otherIx:Null<Int>, changed:Bool, code:CodePresentation, window:Window,
            cx:App):Array<IntoElement> {
        final theme = ActiveTheme.theme(cx);
        final extras:Array<IntoElement> = [];
        final document = code.files[file];
        final line = document.lines(side)[ix];
        final ending = lineEnding(document, side, line);
        final endingOnly = changed && hasLineEndingChange(document, side, ix, otherIx);
        if (ending.length == 0 || endingOnly) {
            final label = ending.length == 0 ? I18n.t('Diff.NoNewline') : '\\ ' + (ending == '\r\n' ? 'CRLF' : 'LF');
            extras.push(div()
                .h6()
                .px3()
                .textXs()
                .textColor(theme.mutedForeground)
                .child(label));
        }
        for (e in lineAnnotations(file, side, ix, code, window, cx))
            extras.push(e);
        return extras;
    }

    /** The line ending of a line (`&source[content_end..source.end]`). */
    static function lineEnding(document:DiffFile, side:DiffSide, line:SourceLine):String {
        final full = line.sourceText(document.source(side));
        return full.substr(line.text().length);
    }

    static function lineAnnotations(file:Int, side:DiffSide, ix:Int, code:CodePresentation, window:Window, cx:App):Array<IntoElement> {
        final position = code.position(file, side, ix);
        final ixs = code.annotations.lines.get(position.key());
        return annotationElements(ixs != null ? ixs : [], code, window, cx);
    }

    static function annotationElements(ixs:Array<Int>, code:CodePresentation, window:Window, cx:App):Array<IntoElement> {
        final render = code.annotationContent;
        if (render == null)
            return [];
        final theme = ActiveTheme.theme(cx);
        return [
            for (ix in ixs) {
                final annotation = code.annotations.items[ix];
                (div()
                    .id(annotation.id())
                    .wFull()
                    .px3()
                    .py3()
                    .borderT1()
                    .borderB1()
                    .borderColor(theme.border)
                    .bg(theme.muted.opacity(0.18))
                    .child(render(annotation, window, cx)) : IntoElement);
            }
        ];
    }

    static function hasLineEndingChange(file:DiffFile, side:DiffSide, ix:Int, counterpart:Null<Int>):Bool {
        if (counterpart == null)
            return false;
        final otherSide = side.other();
        final line = file.lines(side)[ix];
        final other = file.lines(otherSide)[counterpart];
        return line.text() == other.text() && lineEnding(file, side, line) != lineEnding(file, otherSide, other);
    }

}

/**
 * Everything a row needs to render, shared by the rows of one frame.
 */
@:allow(gpui.component.diff)
private class CodePresentation {

    var files:Array<DiffFile>;
    var presentations:Array<Null<FilePresentation>>;
    var mode:DiffMode;
    var contentWidth:Pixels;
    var columnWidth:Pixels;
    var fontSize:Pixels;
    var rowHeight:Pixels;
    var gutterWidth:Pixels;
    var rem:Pixels;
    var expansionLines:Int;
    var lineNumber:Bool;
    var syntaxHighlight:Bool;
    var headerVisible:Bool;
    var hoverHighlight:DiffHoverHighlight;
    var hunkSeparator:DiffHunkSeparator;
    var changeIndicator:DiffChangeIndicator;
    var changeBackground:Bool;
    var softWrap:Bool;
    var header:HeaderSlots;
    var annotations:Annotations;
    var annotationContent:Null<AnnotationRenderer>;
    var decorations:Decorations;
    var gutterMarkers:GutterMarkers;

    /** Set only while the marker lane is shown. */
    var gutterMarkerContent:Null<MarkerRenderer>;

    var laneWidth:Pixels;
    var onAddAnnotation:Null<RangeHandler>;
    var onLineClick:Null<ClickHandler>;
    var onLineHover:Null<HoverHandler>;
    var selection:gpui.base.TextSelectionHandle;
    var selectedLines:Null<DiffLineRange>;
    var selected:Null<SelectedLines>;
    var geometry:SelectionGeometry;
    var state:Entity<DiffState>;

    function new() {}

    function position(file:Int, side:DiffSide, ix:Int):DiffLinePosition {
        final document = files[file];
        return new DiffLinePosition(document.path(), side, document.lineNumber(side, ix));
    }

    function isSelected(file:Int, side:DiffSide, ix:Int):Bool {
        return selected != null && SelectedLinesTools.contains(selected, files, file, side, ix);
    }

}
