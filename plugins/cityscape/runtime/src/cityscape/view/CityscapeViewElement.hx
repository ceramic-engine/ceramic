// New code for Cityscape (not a port): the Glaze element painting a
// Cityscape view, in place of Monaco's DOM view parts (viewLines,
// lineNumbers, glyphMargin, linesDecorations, marginDecorations,
// currentLineHighlight, decorations, selections, viewCursors, indentGuides,
// rulers, overviewRuler).
package cityscape.view;

import cityscape.common.DecorationStyle.IDecorationStyle;
import cityscape.common.ViewModel;
import cityscape.common.viewModel.ViewModelImpl.ViewModel as ViewModelClass;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.view.CityscapeView.RenderedViewLine;
import cityscape.view.DecorationStyleResolver;
import cityscape.view.viewParts.indentGuides.IndentGuides;
import glaze.App;
import glaze.Bounds;
import glaze.ContentMask;
import glaze.Corners;
import glaze.CursorStyle;
import glaze.Edges;
import glaze.Element;
import glaze.ElementInputHandler;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.HitboxBehavior;
import glaze.LineLayout;
import glaze.Hsla;
import glaze.LayoutId;
import glaze.Length;
import glaze.LinePaint;
import glaze.Point;
import glaze.Size;
import glaze.Style;
import glaze.TextAlign;
import glaze.Window;

import glaze.Prelude.*;

using glaze.LengthTools;

/**
 * Paints the visible view lines of a `CityscapeView`, sized by the flex
 * layout of its parent (AUDIT B.13). Lines are shaped once and kept in the
 * view's cache; colors and decorations are painted over the shaped layouts.
 */
class CityscapeViewElement extends Element {

    final view:Entity<CityscapeView>;

    /** The hitbox of the text area, inserted in prepaint, its cursor set in paint. */
    var hitbox:Null<glaze.Hitbox> = null;

    /**
     * The hitbox of the overview ruler (null when it is off): Monaco's
     * ruler canvas has the editor's default (arrow) mouse cursor, the
     * text cursor (I-beam) is the view lines' own (`cursor: text`).
     */
    var rulerHitbox:Null<glaze.Hitbox> = null;

    /**
     * The hitbox of the margin (glyph margin, line numbers, line
     * decorations; null without a margin): Monaco's margin has the default
     * (arrow) mouse cursor, line numbers included (lineNumbers.css
     * `cursor: default`), not the text cursor of the view lines.
     */
    var gutterHitbox:Null<glaze.Hitbox> = null;

    /**
     * The hitboxes of the folding controls of the visible lines (folding.css
     * `.codicon-folding-* { cursor: pointer }`), with the pointing hand.
     */
    final foldingHitboxes:Array<glaze.Hitbox> = [];

    /**
     * The hitboxes of the `⋯` of the folded lines (folding.css
     * `.inline-folded:after { cursor: pointer }`), with the pointing hand.
     */
    final foldedEllipsisHitboxes:Array<glaze.Hitbox> = [];

    public function new(view:Entity<CityscapeView>) {
        this.view = view;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));
        style.flexGrow = 1.0;
        return window.requestLayout(style, [], cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final v = view.read(cx);
        v.layoutTo(bounds, window.scaleFactor(), window);
        v.refreshMouseTargetAfterScroll(window);
        hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        insertGutterHitboxes(v, bounds, window);
        insertFoldedEllipsisHitboxes(v, bounds, window);
        final rulerBounds = overviewRulerBounds(v, bounds);
        rulerHitbox = rulerBounds != null ? window.insertHitbox(rulerBounds, HitboxBehavior.Normal) : null;
    }

    /**
     * The hitboxes of the margin and of its folding controls (their mouse
     * cursors are set in paint). Monaco renders each folding control as a
     * line decoration (`.cldr`, linesDecorations.ts: `left` and `width` of
     * the line decorations, the height of the line) with the codicon
     * classes, whose `margin-left: 2px` (folding.css) moves its box right,
     * in the margin.
     */
    function insertGutterHitboxes(v:CityscapeView, bounds:Bounds, window:Window):Void {
        foldingHitboxes.resize(0);
        final options = v.configuration.options;
        final layoutInfo = options.get(EditorOption.layoutInfo);
        final gutterWidth = Math.min(layoutInfo.contentLeft, bounds.size.width);
        if (gutterWidth <= 0) {
            gutterHitbox = null;
            return;
        }
        gutterHitbox = window.insertHitbox(new Bounds(bounds.origin, new Size(gutterWidth, bounds.size.height)), HitboxBehavior.Normal);
        final viewModel = v.viewModel;
        final left = bounds.origin.x + layoutInfo.decorationsLeft + 2;
        final right = bounds.origin.x + gutterWidth;
        if (viewModel == null || right <= left) {
            return;
        }
        final viewLayout = viewModel.viewLayout;
        final state = v.paintState;
        final partial = state.viewport;
        viewLayout.getLinesViewportRange(partial);
        final startLine = partial.startLineNumber;
        final endLine = partial.endLineNumber;
        final decorations = viewModel.getDecorationsInViewport(state.queryRange(viewModel, v.paintGeneration, startLine, endLine));
        final lineHeight:Float = options.get(EditorOption.lineHeight);
        final top = bounds.origin.y;
        final bottom = top + bounds.size.height;
        final linesTop = top - viewLayout.getCurrentScrollTop();
        for (i in 0...decorations.length) {
            final d = decorations[i];
            final first = d.options.firstLineDecorationClassName;
            final lines = d.options.linesDecorationsClassName;
            final onFirst = first != null && first.indexOf('codicon-folding-') != -1;
            final onLines = lines != null && lines.indexOf('codicon-folding-') != -1;
            if (!onFirst && !onLines) {
                continue;
            }
            final from = Std.int(Math.max(startLine, d.range.startLineNumber));
            final to = Std.int(Math.min(endLine, onLines ? d.range.endLineNumber : d.range.startLineNumber));
            for (ln in from...to + 1) {
                final y = linesTop + viewLayout.getVerticalOffsetForLineNumber(ln);
                final y0 = Math.max(y, top);
                final y1 = Math.min(y + lineHeight, bottom);
                if (y1 > y0) {
                    foldingHitboxes.push(window.insertHitbox(new Bounds(new Point(left, y0), new Size(right - left, y1 - y0)), HitboxBehavior.Normal));
                }
            }
        }
    }

    /**
     * The hitboxes of the `⋯` drawn after the first line of each folded
     * range in view (folding.css `.inline-folded:after`: `display: inline`,
     * `margin: 0.1em 0.2em 0 0.2em`). The box of the pseudo element is the
     * width of the glyph, after its left margin, by the content area of the
     * font (its ascent and descent, not the line height), where the browser
     * shows its pointer; measured on the real Monaco 0.52.2. The line is
     * rendered here like in paint (cached: paint reuses it).
     */
    function insertFoldedEllipsisHitboxes(v:CityscapeView, bounds:Bounds, window:Window):Void {
        foldedEllipsisHitboxes.resize(0);
        final viewModel = v.viewModel;
        if (viewModel == null) {
            return;
        }
        final options = v.configuration.options;
        final layoutInfo = options.get(EditorOption.layoutInfo);
        final viewLayout = viewModel.viewLayout;
        final state = v.paintState;
        final partial = state.viewport;
        viewLayout.getLinesViewportRange(partial);
        final startLine = partial.startLineNumber;
        final endLine = partial.endLineNumber;
        final visibleRange = state.queryRange(viewModel, v.paintGeneration, startLine, endLine);
        final decorations = viewModel.getDecorationsInViewport(visibleRange);
        var ellipsis:Null<LineLayout> = null;
        final lineHeight:Float = options.get(EditorOption.lineHeight);
        final fontSize:Float = options.get(EditorOption.fontInfo).fontSize;
        final contentLeft = bounds.origin.x + layoutInfo.contentLeft;
        final contentX = contentLeft - viewLayout.getCurrentScrollLeft();
        final right = bounds.origin.x + bounds.size.width - layoutInfo.verticalScrollbarWidth;
        final top = bounds.origin.y;
        final bottom = top + bounds.size.height;
        final linesTop = top - viewLayout.getCurrentScrollTop();
        for (i in 0...decorations.length) {
            final d = decorations[i];
            final after = d.options.afterContentClassName;
            if (after == null || after.indexOf('inline-folded') == -1) {
                continue;
            }
            final from = Std.int(Math.max(startLine, d.range.startLineNumber));
            final to = Std.int(Math.min(endLine, d.range.endLineNumber));
            if (from <= to && ellipsis == null) {
                // the visible lines tokenized first, as in paint (a no-op
                // there then), so the line rendered here is the one painted
                v.visibleLinesRendered(startLine, endLine);
                ellipsis = v.foldedEllipsisLayout();
            }
            for (ln in from...to + 1) {
                final line = v.renderViewLine(ln, visibleRange);
                final names = line.runs.partClassNames;
                for (p in 0...names.length) {
                    if (names[p].indexOf('inline-folded') == -1) {
                        continue;
                    }
                    final left = contentX + line.layout.xForIndex(line.offsets.utf16ToByte(line.runs.partStarts[p])) + fontSize * 0.2;
                    final x0 = Math.max(left, contentLeft);
                    final ellipsisWidth:Float = ellipsis.width;
                    final x1 = Math.min(left + ellipsisWidth, right);
                    final textHeight:Float = (ellipsis.ascent : Float) + (ellipsis.descent : Float);
                    final y = linesTop + viewLayout.getVerticalOffsetForLineNumber(ln) + (lineHeight - textHeight) / 2;
                    final y0 = Math.max(y, top);
                    final y1 = Math.min(y + textHeight, bottom);
                    if (x1 > x0 && y1 > y0) {
                        foldedEllipsisHitboxes.push(window.insertHitbox(new Bounds(new Point(x0, y0), new Size(x1 - x0, y1 - y0)), HitboxBehavior.Normal));
                    }
                    break;
                }
            }
        }
    }

    static final NO_RADII = new Corners(0, 0, 0, 0);

    /**
     * A filled rectangle through the window's scratch quad and
     * `paintQuadAt` (a solid background: no `PaintQuad`, `Bounds`,
     * `Background` or color stops allocated).
     */
    static function fillRect(window:Window, x:Float, y:Float, w:Float, h:Float, color:Hsla, ?radii:Corners):Void {
        if (w <= 0 || h <= 0 || color == null) {
            return;
        }
        final q = window.scratchPaintQuad();
        q.cornerRadii = radii != null ? radii : NO_RADII;
        q.setSolidBackground(color.h, color.s, color.l, color.a);
        window.paintQuadAt(q, x, y, w, h);
    }

    static function strokeRect(window:Window, x:Float, y:Float, w:Float, h:Float, color:Hsla, width:Float, ?radii:Corners):Void {
        if (w <= 0 || h <= 0 || color == null) {
            return;
        }
        final q = window.scratchPaintQuad();
        q.cornerRadii = radii != null ? radii : NO_RADII;
        // `quad(..., transparentBlack(), Edges.all(width), color, Solid)`
        q.setSolidBackground(0, 0, 0, 0);
        q.setBorderWidths(width, width, width, width);
        q.setBorderColor(color.h, color.s, color.l, color.a);
        q.borderStyle = glaze.scene.BorderStyle.Solid;
        window.paintQuadAt(q, x, y, w, h);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        // A paint phase call (GPUI's `set_cursor_style`): recorded with the
        // paint of the view, so a view reused from the cache keeps it
        final v = view.read(cx);
        final hitbox = this.hitbox;
        final dragCursor = v.zoneDragCursor;
        if (hitbox != null && dragCursor != null) {
            // a drag started on a view zone (a hidden region bar edge): its
            // cursor over the whole editor (Monaco's
            // `.monaco-editor.draggingUnchangedRegion *`), and the moves
            // and the mouse up anywhere in the window reach the editor
            // (Monaco's window listeners); over the editor its own listeners
            // deliver them
            window.setCursorStyle(dragCursor, hitbox);
            final entity = view;
            window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
                if (phase == Bubble && !hitbox.isHovered(window)) {
                    entity.read(cx).handleMouseMove(cast event, window, cx);
                }
            });
            window.onMouseEvent(MouseUp, (event, phase, window, cx) -> {
                if (phase == Bubble && !hitbox.isHovered(window)) {
                    entity.read(cx).handleMouseUp(cast event, window, cx);
                }
            });
        }
        else if (hitbox != null) {
            if (v.isMouseDown()) {
                // a drag started in the editor (a selection, a drag of the
                // selection): the moves and the mouse up anywhere in the
                // window reach the editor, like Monaco's
                // `GlobalEditorPointerMoveMonitor` (mouseHandler.ts:459);
                // over the editor its own listeners deliver them
                final entity = view;
                window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
                    if (phase == Bubble && !hitbox.isHovered(window)) {
                        entity.read(cx).handleMouseMove(cast event, window, cx);
                    }
                });
                window.onMouseEvent(MouseUp, (event, phase, window, cx) -> {
                    if (phase == Bubble && !hitbox.isHovered(window)) {
                        entity.read(cx).handleMouseUp(cast event, window, cx);
                    }
                });
            }
            // the pointer of a link or widget, else Monaco's `mouseStyle`
            // (the drag and drop of the selection sets `default` and `copy`)
            final mouseStyle:String = v.configuration.options.get(EditorOption.mouseStyle);
            // (a view zone under the mouse: its cursor, the arrow by default)
            final zoneCursor = v.zoneMouseCursor;
            window.setCursorStyle(v.mouseCursor != null ? v.mouseCursor : (mouseStyle == 'default' ? CursorStyle.Arrow : (mouseStyle == 'copy' ? CursorStyle.DragCopy : (zoneCursor != null ? zoneCursor : CursorStyle.IBeam))), hitbox);
        }
        final gutterHitbox = this.gutterHitbox;
        if (gutterHitbox != null) {
            window.setCursorStyle(dragCursor != null ? dragCursor : (v.zoneMouseCursor != null ? v.zoneMouseCursor : CursorStyle.Arrow), gutterHitbox);
            for (i in 0...foldingHitboxes.length) {
                window.setCursorStyle(CursorStyle.PointingHand, foldingHitboxes[i]);
            }
        }
        for (i in 0...foldedEllipsisHitboxes.length) {
            window.setCursorStyle(CursorStyle.PointingHand, foldedEllipsisHitboxes[i]);
        }
        final rulerHitbox = this.rulerHitbox;
        if (rulerHitbox != null) {
            window.setCursorStyle(CursorStyle.Arrow, rulerHitbox);
        }
        final viewModel = v.viewModel;
        final theme = v.theme;
        final options = v.configuration.options;
        final state = v.paintState;
        final background = theme.getColor('editor.background');
        fillRect(window, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, background != null ? background : DEFAULT_BACKGROUND);
        if (viewModel == null) {
            return;
        }

        v.syncFocus(window, cx);
        final focused = v.focusHandle.isFocused(window);
        window.handleInput(v.focusHandle, state.inputHandlerFor(bounds, view), cx);

        final layoutInfo = options.get(EditorOption.layoutInfo);
        final lineHeight:Float = options.get(EditorOption.lineHeight);
        final fontInfo = options.get(EditorOption.fontInfo);
        final viewLayout = viewModel.viewLayout;
        final scrollTop = viewLayout.getCurrentScrollTop();
        final scrollLeft = viewLayout.getCurrentScrollLeft();

        final partial = state.viewport;
        viewLayout.getLinesViewportRange(partial);
        final startLine = partial.startLineNumber;
        final endLine = partial.endLineNumber;
        viewModel.setViewport(startLine, endLine, partial.centeredLineNumber);
        v.visibleLinesRendered(startLine, endLine);
        // The range of the decorations and of the rendering data: the visible
        // lines rounded to blocks of lines, so that it stays the same (with
        // the decorations of the view model cached for it) while scrolling
        // within the blocks; everything below clamps to the visible lines
        final visibleRange = state.queryRange(viewModel, v.paintGeneration, startLine, endLine);

        final originX = bounds.origin.x;
        final originY = bounds.origin.y;
        final contentX = originX + layoutInfo.contentLeft - scrollLeft;
        inline function lineTop(lineNumber:Int):Float {
            return originY + viewLayout.getVerticalOffsetForLineNumber(lineNumber) - scrollTop;
        }

        // Render the visible lines (shaping only what changed)
        final lines = state.lines;
        lines.resize(0);
        for (lineNumber in startLine...endLine + 1) {
            lines.push(v.renderViewLine(lineNumber, visibleRange));
        }

        state.updateSelections(v, viewModel, v.paintGeneration);
        final selections = state.selections;
        final decorations = viewModel.getDecorationsInViewport(visibleRange);

        // Primary cursor (model) line, for the line highlight and the active line number
        final primaryModelLineNumber = state.primaryModelLineNumber;
        // [loreline] the view line that draws the number of the cursor's model line
        final activeNumberViewLine = state.activeNumberViewLine;

        // --- content area
        final contentMask = state.contentMask(originX + layoutInfo.contentLeft, originY, Math.max(0, bounds.size.width - layoutInfo.contentLeft), bounds.size.height);
        final contentBounds = contentMask.bounds;
        window.pushContentMask(contentMask);

        // View zones (Monaco's ViewZones view part), painted by their zones
        final viewZones = v.widget.getViewZones();
        final zoneWhitespaces = viewZones != null ? viewLayout.getWhitespaceViewportData() : null;
        if (viewZones != null && zoneWhitespaces.length > 0) {
            viewZones.paintZones(window, cx, zoneWhitespaces, contentBounds.origin.x, contentBounds.size.width, originY - scrollTop, false);
            viewZones.notifyTops(zoneWhitespaces, scrollTop);
        }

        // Current line highlight (Monaco's currentLineHighlight)
        final renderLineHighlight = options.get(EditorOption.renderLineHighlight);
        final showHighlight = renderLineHighlight != 'none' && renderLineHighlight != 'gutter' && (focused || !options.get(EditorOption.renderLineHighlightOnlyWhenFocus));
        final highlightBackground = theme.getColor('editor.lineHighlightBackground');
        final highlightBorder = theme.getColor('editor.lineHighlightBorder');
        if (showHighlight) {
            for (i in 0...selections.length) {
                final s = selections[i];
                if (!s.isEmpty()) {
                    continue;
                }
                final ln = s.positionLineNumber;
                if (ln < startLine || ln > endLine) {
                    continue;
                }
                final y = lineTop(ln);
                if (highlightBackground != null) {
                    fillRect(window, contentBounds.origin.x, y, contentBounds.size.width, lineHeight, highlightBackground);
                } else if (highlightBorder != null) {
                    strokeRect(window, contentBounds.origin.x, y, contentBounds.size.width, lineHeight, highlightBorder, 2);
                }
            }
        }

        // Decorations painted behind the text: whole line styles and `className` / `style` boxes
        for (i in 0...decorations.length) {
            final d = decorations[i];
            final opts = d.options;
            final range = d.range;
            if (range.endLineNumber < startLine || range.startLineNumber > endLine) {
                continue;
            }
            final styles = v.resolver.paintStylesOf(opts);
            final lineBoxes = styles.lineBoxes;
            final boxStyles = styles.boxStyles;
            if (lineBoxes != null) {
                for (ln in Std.int(Math.max(startLine, range.startLineNumber))...Std.int(Math.min(endLine, range.endLineNumber)) + 1) {
                    for (k in 0...lineBoxes.length) {
                        final box = lineBoxes[k];
                        if (box != null && box.background != null) {
                            fillRect(window, contentBounds.origin.x, lineTop(ln), contentBounds.size.width, lineHeight, box.background);
                        }
                    }
                }
            }
            // Snippets (step 7): an empty range whose box has a minimum width (snippet tab stops)
            if (boxStyles != null && range.isEmpty() && opts.showIfCollapsed != true && range.startLineNumber >= startLine && range.startLineNumber <= endLine) {
                for (st in boxStyles) {
                    if (st.minWidth == null) {
                        continue;
                    }
                    final box = v.resolver.resolveBox(st);
                    if (box != null && box.minWidth > 0) {
                        final line = lines[range.startLineNumber - startLine];
                        final x = line.columnToX(range.startColumn);
                        paintBox(window, state, box, contentX + x - box.minWidth / 2, lineTop(range.startLineNumber), box.minWidth, lineHeight, line, true, true);
                    }
                }
            }
            if (boxStyles != null && (!range.isEmpty() || opts.showIfCollapsed == true)) {
                final boxes = styles.boxBoxes;
                final underlineColors = styles.boxUnderlineColors;
                for (ln in Std.int(Math.max(startLine, range.startLineNumber))...Std.int(Math.min(endLine, range.endLineNumber)) + 1) {
                    final line = lines[ln - startLine];
                    final startColumn = (ln == range.startLineNumber ? range.startColumn : line.minColumn);
                    final endColumn = (ln == range.endLineNumber ? range.endColumn : line.maxColumn);
                    final x1 = line.columnToX(startColumn);
                    var x2 = line.columnToX(endColumn);
                    if (ln != range.endLineNumber) {
                        x2 += fontInfo.spaceWidth;
                    }
                    if (x2 <= x1) {
                        // an empty range shown when collapsed: one character wide (Monaco's 1ch)
                        x2 = x1 + fontInfo.typicalHalfwidthCharacterWidth;
                    }
                    for (k in 0...boxStyles.length) {
                        final box = boxes[k];
                        if (box != null && !range.isEmpty()) {
                            paintBox(window, state, box, contentX + x1, lineTop(ln), x2 - x1, lineHeight, line, true, true);
                        }
                        // The squiggles of Monaco's `squiggly-*` decorations
                        // (its CSS draws them at the bottom of the line box)
                        final underline = boxStyles[k].underline;
                        if (underline != null) {
                            final color = underlineColors[k];
                            if (color != null) {
                                final thickness:Float = underline.thickness != null ? underline.thickness : 1;
                                final wavy = underline.wavy == true;
                                final y = lineTop(ln) + lineHeight - (wavy ? thickness * 3 : thickness);
                                window.paintUnderline(new Point(contentX + x1, y), x2 - x1, new glaze.UnderlineStyle(thickness, color, wavy));
                            }
                        }
                    }
                }
            }
        }

        // Inline decoration boxes (typed `inlineStyle` backgrounds, joined into one shape per run)
        for (i in 0...lines.length) {
            final line = lines[i];
            final y = lineTop(startLine + i);
            var p = 0;
            final parts = line.runs.partStarts.length;
            while (p < parts) {
                final box = line.partStyles[p].box;
                if (box == null || (box.background == null && box.borderColor == null)) {
                    p++;
                    continue;
                }
                var q = p + 1;
                if (box.join) {
                    while (q < parts && box.equals(line.partStyles[q].box)) {
                        q++;
                    }
                }
                // the box bounds include the horizontal padding of the parts (inlay hints, cs7-rest-inlay)
                final x1 = line.partBoxStarts != null ? line.partBoxStarts[p] : line.layout.xForIndex(line.offsets.utf16ToByte(line.runs.partStarts[p]));
                final x2 = line.partBoxEnds != null ? line.partBoxEnds[q - 1] : line.layout.xForIndex(line.offsets.utf16ToByte(line.runs.partEnds[q - 1]));
                paintBox(window, state, box, contentX + x1, y, x2 - x1, lineHeight, line, true, true);
                p = q;
            }
        }

        // Selections (Monaco's selections view part, rounded corners)
        final selectionColor = theme.getColor(focused ? 'editor.selectionBackground' : 'editor.inactiveSelectionBackground');
        final rounded = options.get(EditorOption.roundedSelection);
        if (selectionColor != null) {
            final xs = state.selectionStarts;
            final xe = state.selectionEnds;
            for (i in 0...selections.length) {
                final s = selections[i];
                if (s.isEmpty()) {
                    continue;
                }
                final from = Std.int(Math.max(startLine, s.startLineNumber));
                final to = Std.int(Math.min(endLine, s.endLineNumber));
                xs.resize(0);
                xe.resize(0);
                for (ln in from...to + 1) {
                    final line = lines[ln - startLine];
                    final startColumn = (ln == s.startLineNumber ? s.startColumn : line.minColumn);
                    final endColumn = (ln == s.endLineNumber ? s.endColumn : line.maxColumn);
                    var x1 = line.columnToX(startColumn);
                    var x2 = line.columnToX(endColumn);
                    if (ln != s.endLineNumber) {
                        // the line break is selected
                        x2 += fontInfo.typicalHalfwidthCharacterWidth;
                    }
                    xs.push(x1);
                    xe.push(x2);
                }
                for (k in 0...xs.length) {
                    final ln = from + k;
                    final radius = rounded ? 3.0 : 0.0;
                    final hasPrev = k > 0;
                    final hasNext = k + 1 < xs.length;
                    final tl = (!hasPrev || xs[k - 1] > xs[k]) ? radius : 0;
                    final tr = (!hasPrev || xe[k - 1] < xe[k]) ? radius : 0;
                    final bl = (!hasNext || xs[k + 1] > xs[k]) ? radius : 0;
                    final br = (!hasNext || xe[k + 1] < xe[k]) ? radius : 0;
                    fillRect(window, contentX + xs[k], lineTop(ln), xe[k] - xs[k], lineHeight, selectionColor, state.corners(tl, tr, br, bl));
                }
            }
        }

        // Indent guides and bracket pair guides (Monaco's IndentGuidesOverlay)
        final guidesOptions = options.get(EditorOption.guides);
        if (guidesOptions.indentation || !cityscape.base.common.JsValues.strictEquals(guidesOptions.bracketPairs, false)) {
            final wrappingInfo = options.get(EditorOption.wrappingInfo);
            final maxIndentLeft = wrappingInfo.wrappingColumn == -1 ? -1 : (wrappingInfo.wrappingColumn * fontInfo.typicalHalfwidthCharacterWidth);
            final scrollWidth = viewLayout.getScrollWidth();
            final guides = state.guides(viewModel, guidesOptions, v.paintGeneration, startLine, Std.int(Math.min(endLine + 1, viewModel.getLineCount())));
            final guideColors = v.guideColors;
            final spaceWidth = fontInfo.spaceWidth;
            for (i in 0...lines.length) {
                final lineGuides = guides[i];
                if (lineGuides == null || lineGuides.length == 0) {
                    continue;
                }
                final line = lines[i];
                final y = lineTop(startLine + i);
                final leftOffset = line.columnToX(1);
                for (g in 0...lineGuides.length) {
                    final guide = lineGuides[g];
                    final left = guide.column == -1
                        ? leftOffset + (guide.visibleColumn - 1) * spaceWidth
                        : line.columnToX(guide.column);
                    if (left > scrollWidth || (maxIndentLeft > 0 && left > maxIndentLeft)) {
                        break;
                    }
                    final color = guideColors.colorOf(guideColors.styleOf(guide.className));
                    if (color == null) {
                        continue;
                    }
                    final x = Math.round(contentX + left);
                    if (guide.horizontalLine != null) {
                        final right = guide.horizontalLine.endColumn <= line.maxColumn ? line.columnToX(guide.horizontalLine.endColumn) : left + spaceWidth;
                        final width = right - left;
                        // `horizontal-top` (border-top) or `horizontal-bottom` (border-bottom)
                        fillRect(window, x, guide.horizontalLine.top ? y : y + lineHeight - 1, width, 1, color);
                    }
                    else {
                        // `vertical`: `box-shadow: 1px 0 0 0 color inset`
                        fillRect(window, x, y, 1, lineHeight, color);
                    }
                }
            }
        }

        // Rulers
        final rulerColor = theme.getColor('editorRuler.foreground');
        final rulers = options.get(EditorOption.rulers);
        for (r in 0...rulers.length) {
            final ruler = rulers[r];
            final color = ruler.color != null ? state.parsedColor(ruler.color) : rulerColor;
            if (color != null) {
                fillRect(window, Math.round(contentX + ruler.column * fontInfo.typicalHalfwidthCharacterWidth), originY, 1, bounds.size.height, color);
            }
        }

        // Text
        final painter = window.textPainter();
        for (i in 0...lines.length) {
            final line = lines[i];
            if (line.layout.len == 0) {
                continue;
            }
            LinePaint.paintLineAligned(new Point(contentX, lineTop(startLine + i)), line.layout, lineHeight, TextAlign.Left, line.layout.width, line.decorationRuns, null, painter, null);
        }

        // The `⋯` after the first line of a folded range (folding.css
        // `.inline-folded:after`)
        for (i in 0...lines.length) {
            final line = lines[i];
            final names = line.runs.partClassNames;
            for (p in 0...names.length) {
                if (names[p].indexOf('inline-folded') == -1) {
                    continue;
                }
                final ellipsis = v.foldedEllipsisLayout();
                final ellipsisRuns = state.ellipsisRuns(ellipsis.len, theme.getColor('editor.foldPlaceholderForeground'));
                final x = contentX + line.layout.xForIndex(line.offsets.utf16ToByte(line.runs.partStarts[p])) + fontInfo.fontSize * 0.2;
                LinePaint.paintLineAligned(new Point(x, lineTop(startLine + i)), ellipsis, lineHeight, TextAlign.Left, ellipsis.width, ellipsisRuns, null, painter, null);
                break;
            }
        }

        // Cursors (Monaco's viewCursors: line, block, underline styles, blink)
        if (focused && v.cursorVisible) {
            final cursorColor = theme.getColor('editorCursor.foreground');
            final cursorStyle = options.get(EditorOption.cursorStyle);
            var cursorWidth:Float = options.get(EditorOption.cursorWidth);
            if (cursorWidth <= 0) {
                cursorWidth = 2;
            }
            for (i in 0...selections.length) {
                final s = selections[i];
                final ln = s.positionLineNumber;
                if (ln < startLine || ln > endLine) {
                    continue;
                }
                final line = lines[ln - startLine];
                final x = contentX + line.columnToX(s.positionColumn);
                final nextX = contentX + line.columnToX(s.positionColumn + 1);
                final charWidth = Math.max(fontInfo.typicalHalfwidthCharacterWidth, nextX - x);
                final y = lineTop(ln);
                switch (cursorStyle) {
                    case TextEditorCursorStyle.Block:
                        fillRect(window, x, y, charWidth, lineHeight, cursorColor);
                    case TextEditorCursorStyle.BlockOutline:
                        strokeRect(window, x, y, charWidth, lineHeight, cursorColor, 1);
                    case TextEditorCursorStyle.Underline:
                        fillRect(window, x, y + lineHeight - 2, charWidth, 2, cursorColor);
                    case TextEditorCursorStyle.UnderlineThin:
                        fillRect(window, x, y + lineHeight - 1, charWidth, 1, cursorColor);
                    case TextEditorCursorStyle.LineThin:
                        fillRect(window, x, y, 1, lineHeight, cursorColor);
                    case _:
                        fillRect(window, x, y, cursorWidth, lineHeight, cursorColor);
                }
            }
        }

        // The target of a drag of the selection (dnd.css `.dnd-target`: a
        // 2 px dotted right border on an empty range)
        for (i in 0...decorations.length) {
            final d = decorations[i];
            if (d.options.className != cityscape.contrib.dnd.view.Dnd.DragAndDropController.DECORATION_CLASS) {
                continue;
            }
            final ln = d.range.startLineNumber;
            if (ln < startLine || ln > endLine) {
                continue;
            }
            final line = lines[ln - startLine];
            final x = contentX + line.columnToX(d.range.startColumn);
            final color = switch (theme.editorTheme.type) {
                case cityscape.platform.theme.common.Theme.ColorScheme.DARK: DND_TARGET_DARK;
                case cityscape.platform.theme.common.Theme.ColorScheme.HIGH_CONTRAST_DARK: DND_TARGET_HC_DARK;
                case _: DND_TARGET_LIGHT;
            }
            final top = lineTop(ln);
            var y = 0.0;
            while (y < lineHeight) {
                fillRect(window, x, top + y, 2, Math.min(2, lineHeight - y), color);
                y += 4;
            }
        }

        // The track of the vertical scrollbar (Cityscape's `scrollbar.trackColor`,
        // `editor.background` by default): opaque over the text and the whole
        // line backgrounds, under the shadows, the overview ruler and the thumb
        final trackWidth = scrollbarTrackWidth(options);
        if (trackWidth > 0) {
            final trackColor = scrollbarTrackColor(state, options, background != null ? background : DEFAULT_BACKGROUND);
            if (trackColor.a > 0) {
                fillRect(window, originX + bounds.size.width - trackWidth, originY, trackWidth, bounds.size.height, trackColor);
            }
        }

        // The shadows of Monaco's scrollable element (`scrollbar.useShadows`,
        // scrollbars.css): 3 px at the top of the text area when it is
        // scrolled down, at its left when it is scrolled right, above the
        // text (the sticky scroll widget covers the top one)
        if ((scrollTop > 0 || scrollLeft > 0) && options.get(EditorOption.scrollbar).useShadows) {
            final shadowColor = theme.getColor('scrollbar.shadow');
            if (shadowColor != null && shadowColor.a > 0) {
                state.paintScrollShadows(window, originX + layoutInfo.contentLeft, originY, bounds.size.width - layoutInfo.contentLeft, bounds.size.height, scrollTop > 0, scrollLeft > 0, shadowColor);
            }
        }

        window.popContentMask();

        // --- margin (gutter)
        final gutterWidth = layoutInfo.contentLeft;
        if (gutterWidth > 0) {
            window.pushContentMask(state.gutterMask(originX, originY, gutterWidth, bounds.size.height));
            final gutterBackground = theme.getColor('editorGutter.background');
            if (gutterBackground != null) {
                fillRect(window, originX, originY, gutterWidth, bounds.size.height, gutterBackground);
            }
            if (viewZones != null && zoneWhitespaces.length > 0) {
                viewZones.paintZones(window, cx, zoneWhitespaces, originX, gutterWidth, originY - scrollTop, true);
            }
            // margin decorations (`marginClassName`, `marginStyle`, whole margin width)
            for (i in 0...decorations.length) {
                final d = decorations[i];
                final range = d.range;
                if (range.endLineNumber < startLine || range.startLineNumber > endLine) {
                    continue;
                }
                final styles = v.resolver.paintStylesOf(d.options);
                final marginBoxes = styles.marginBoxes;
                final glyphBoxes = styles.glyphBoxes;
                final linesBoxes = styles.linesBoxes;
                // The `insert-sign` / `delete-sign` codicons of the diff editor
                final linesClass = d.options.linesDecorationsClassName;
                final diffSign = linesClass != null && linesClass.indexOf('codicon-diff-') != -1;
                if (marginBoxes == null && glyphBoxes == null && linesBoxes == null && !diffSign) {
                    continue;
                }
                for (ln in Std.int(Math.max(startLine, range.startLineNumber))...Std.int(Math.min(endLine, range.endLineNumber)) + 1) {
                    final y = lineTop(ln);
                    if (marginBoxes != null) {
                        for (k in 0...marginBoxes.length) {
                            final box = marginBoxes[k];
                            if (box != null) {
                                paintBox(window, state, box, originX, y, gutterWidth, lineHeight, null, false, false);
                            }
                        }
                    }
                    if (glyphBoxes != null && layoutInfo.glyphMarginWidth > 0) {
                        for (k in 0...glyphBoxes.length) {
                            final box = glyphBoxes[k];
                            if (box != null) {
                                paintBox(window, state, box, originX + layoutInfo.glyphMarginLeft + 2, y + 2, Math.min(layoutInfo.glyphMarginWidth, lineHeight) - 4, lineHeight - 4, null, false, false);
                            }
                        }
                    }
                    if (linesBoxes != null) {
                        for (k in 0...linesBoxes.length) {
                            final box = linesBoxes[k];
                            if (box != null) {
                                paintBox(window, state, box, originX + layoutInfo.decorationsLeft, y, Math.max(2, layoutInfo.decorationsWidth - 16), lineHeight, null, false, false);
                            }
                        }
                    }
                    if (diffSign) {
                        final signColor = theme.getColor('editor.foreground');
                        if (signColor != null) {
                            Codicons.paintDiffSign(window, cx, originX + layoutInfo.decorationsLeft, y, lineHeight, linesClass.indexOf('codicon-diff-insert') != -1, signColor.opacity(0.7));
                        }
                    }
                }
            }
            // folding controls (the chevrons of the `firstLineDecorationClassName`
            // codicons of the folding decorations)
            paintFoldingControls(window, cx, v, decorations, startLine, endLine, originX, originY - scrollTop, layoutInfo.decorationsLeft, layoutInfo.decorationsWidth, lineHeight, fontInfo.fontSize);
            // line numbers
            final lineNumbers = options.get(EditorOption.lineNumbers);
            if (lineNumbers.renderType != RenderLineNumbersType.Off && layoutInfo.lineNumbersWidth > 0) {
                final numberColor = theme.getColor('editorLineNumber.foreground');
                final activeColor = theme.getColor('editorLineNumber.activeForeground');
                final textSystem = window.textSystem();
                // A painter for the gutter's content mask (it keeps the mask of its creation)
                final numberPainter = window.textPainter();
                final numberFont = state.numberFont(v, fontInfo, textSystem.textSystem.fontGeneration);
                final lineCount = viewModel.model.getLineCount();
                final coordinates = viewModel.coordinatesConverter;
                for (ln in startLine...endLine + 1) {
                    final line = lines[ln - startLine];
                    if (line.modelLineNumber == -1) {
                        final modelPosition = coordinates.convertViewPositionToModelPosition(new Position(ln, viewModel.getLineMinColumn(ln)));
                        line.modelLineNumber = modelPosition.lineNumber;
                        line.isFirstViewLine = coordinates.convertModelPositionToViewPosition(new Position(modelPosition.lineNumber, 1)).lineNumber == ln;
                    }
                    if (!line.isFirstViewLine) {
                        continue;
                    }
                    final modelLineNumber = line.modelLineNumber;
                    // `null`: the plain number (built only when its label is not cached)
                    var label:Null<String> = null;
                    if (lineNumbers.renderFn != null) {
                        label = lineNumbers.renderFn(modelLineNumber);
                    } else if (lineNumbers.renderType == RenderLineNumbersType.Relative) {
                        final diff = Std.int(Math.abs(primaryModelLineNumber - modelLineNumber));
                        label = diff == 0 ? '' + modelLineNumber : '' + diff;
                    } else if (lineNumbers.renderType == RenderLineNumbersType.Interval) {
                        label = (primaryModelLineNumber == modelLineNumber || modelLineNumber % 10 == 0 || modelLineNumber == lineCount) ? null : '';
                    }
                    if (label != null && label.length == 0) {
                        continue;
                    }
                    var color = (ln == activeNumberViewLine) ? (activeColor != null ? activeColor : numberColor) : numberColor;
                    // `lineNumberClassName` / `lineNumberStyle` decorations
                    for (k in 0...decorations.length) {
                        final d = decorations[k];
                        if (d.range.startLineNumber <= ln && d.range.endLineNumber >= ln) {
                            final colors = v.resolver.paintStylesOf(d.options).lineNumberColors;
                            if (colors != null) {
                                for (c in 0...colors.length) {
                                    final c = colors[c];
                                    if (c != null) {
                                        color = c;
                                    }
                                }
                            }
                        }
                    }
                    final shaped = state.lineNumberLabel(textSystem, modelLineNumber, label, fontInfo.fontSize, numberFont, color);
                    final labelWidth:Float = shaped.width();
                    final x:Float = originX + layoutInfo.lineNumbersLeft + layoutInfo.lineNumbersWidth - labelWidth;
                    shaped.paint(new Point(x, lineTop(ln)), lineHeight, TextAlign.Left, null, numberPainter);
                }
                state.trimLineNumberLabels(startLine, endLine);
            }
            window.popContentMask();
        }

        // --- overview ruler (marks of decorations and cursors, under the kit
        // scrollbar, or beside it with `overviewRulerPosition: 'beside'`)
        final rulerBounds = overviewRulerBounds(v, bounds);
        if (rulerBounds != null) {
            paintOverviewRuler(window, v, state, selections, rulerBounds.origin.x, rulerBounds.origin.y, rulerBounds.size.width, rulerBounds.size.height, lineHeight);
        }

        v.trimRenderCache(startLine, endLine);
    }

    /**
     * The width of the scrollbar track at the right of the editor (the
     * Cityscape option `scrollbar.trackColor`): the vertical scrollbar's
     * band of the layout (`verticalScrollbarWidth`), and the overview ruler
     * with the gap when it is beside the scrollbar
     * (`overviewRulerPosition: 'beside'`, like loreline-monaco's style
     * sheet, which gives the moved ruler the track's background).
     */
    public static function scrollbarTrackWidth(options:cityscape.common.config.EditorOptions.IComputedEditorOptions):Float {
        final layoutInfo = options.get(EditorOption.layoutInfo);
        final scrollbarWidth = layoutInfo.verticalScrollbarWidth;
        if (scrollbarWidth <= 0) {
            return 0;
        }
        final rulerRight = cityscape.common.config.EditorViewOptions.OverviewRulerPlacement.right(options);
        final ruler = layoutInfo.overviewRuler;
        if (rulerRight > 0 && ruler.width > 0 && options.get(EditorOption.overviewRulerLanes) > 0) {
            return Math.max(scrollbarWidth, rulerRight + ruler.right + ruler.width);
        }
        return scrollbarWidth;
    }

    /**
     * The color of the scrollbar track: `scrollbar.trackColor` when it is
     * a color, else `background` (the editor's).
     */
    public static function scrollbarTrackColor(state:PaintState, options:cityscape.common.config.EditorOptions.IComputedEditorOptions, background:Hsla):Hsla {
        final value = options.get(EditorOption.scrollbar).trackColor;
        if (value == null) {
            return background;
        }
        final color = state.parsedColor(value);
        return color != null ? color : background;
    }

    /**
     * Where the overview ruler is painted in the element of `bounds`
     * (`layoutInfo.overviewRuler`, moved left of the scrollbar with
     * `overviewRulerPosition: 'beside'`), null when it is off
     * (`overviewRulerLanes: 0` or no vertical scrollbar width).
     */
    public static function overviewRulerBounds(v:CityscapeView, bounds:Bounds):Null<Bounds> {
        final options = v.configuration.options;
        final position = options.get(EditorOption.layoutInfo).overviewRuler;
        if (position.width <= 0 || position.height <= 0 || options.get(EditorOption.overviewRulerLanes) <= 0) {
            return null;
        }
        final x = bounds.origin.x + bounds.size.width - cityscape.common.config.EditorViewOptions.OverviewRulerPlacement.right(options) - position.right - position.width;
        return v.paintState.rulerBoundsOf(x, bounds.origin.y + position.top, position.width, position.height);
    }

    /**
     * decorationsOverviewRuler.ts `_render`: the ruler's canvas of
     * `floor(width * pixelRatio)` by `floor(height * pixelRatio)` pixels
     * at `x, y`, painted in canvas pixels like Monaco: the background,
     * the decorations by lane (merged, at least 6 CSS px high), the cursors
     * (`editorCursor.foreground`, or the multi cursor colors, at 0.7 of
     * their alpha, 2 CSS px high, centered on the top of their line) and
     * the border on top. Monaco strokes the border with a 1 pixel line along
     * the canvas' left and top edges (`moveTo(0, 0)`, `lineTo(0, height)`,
     * `moveTo(1, 0)`, `lineTo(width, 0)`): half of the line is outside the
     * canvas, so the canvas antialiasing covers half of its first column
     * (and of its first row from the second column): painted here as one
     * pixel at half the border's alpha.
     */
    static function paintOverviewRuler(window:Window, v:CityscapeView, state:PaintState, selections:Array<Selection>, x:Float, y:Float, width:Float, height:Float, lineHeight:Float):Void {
        final options = v.configuration.options;
        final theme = v.theme;
        final viewModel = v.viewModel;
        final viewLayout = viewModel.viewLayout;
        final pixelRatio:Float = options.get(EditorOption.pixelRatio);
        final canvasWidth = Std.int(width * pixelRatio);
        final canvasHeight = Std.int(height * pixelRatio);
        if (canvasWidth <= 0 || canvasHeight <= 0) {
            return;
        }
        // a canvas pixel in CSS px
        final px = width / canvasWidth;
        final py = height / canvasHeight;
        final outerHeight = viewLayout.getScrollHeight();
        final heightRatio = canvasHeight / outerHeight;
        final minDecorationHeight = Std.int(MIN_DECORATION_HEIGHT * pixelRatio);
        final halfMinDecorationHeight = Std.int(minDecorationHeight / 2);
        state.initLanes(canvasWidth, options.get(EditorOption.overviewRulerLanes));
        final laneX = state.laneX;
        final laneW = state.laneW;
        inline function canvasRect(cx:Int, cy:Int, cw:Int, ch:Int, color:Hsla):Void {
            fillRect(window, x + cx * px, y + cy * py, cw * px, ch * py, color);
        }

        // `editorOverviewRuler.background` when the theme defines it (no
        // minimap here), else the canvas stays transparent
        final backgroundColor = theme.getColor('editorOverviewRuler.background');
        if (backgroundColor != null) {
            canvasRect(0, 0, canvasWidth, canvasHeight, backgroundColor);
        }

        final groups = state.overviewRulerGroups(viewModel, theme, v.paintGeneration);
        for (g in 0...groups.length) {
            final color = state.overviewRulerColors[g];
            final data = groups[g].data;
            final len = Std.int(data.length / 3);
            if (color == null || len == 0) {
                continue;
            }
            var prevLane = 0;
            var prevY1 = 0;
            var prevY2 = 0;
            for (i in 0...len) {
                final lane = Std.int(data[3 * i]);
                final startLineNumber = Std.int(data[3 * i + 1]);
                final endLineNumber = Std.int(data[3 * i + 2]);
                var y1 = Std.int(viewLayout.getVerticalOffsetForLineNumber(startLineNumber) * heightRatio);
                var y2 = Std.int((viewLayout.getVerticalOffsetForLineNumber(endLineNumber) + lineHeight) * heightRatio);
                final h = y2 - y1;
                if (h < minDecorationHeight) {
                    var yCenter = Std.int((y1 + y2) / 2);
                    if (yCenter < halfMinDecorationHeight) {
                        yCenter = halfMinDecorationHeight;
                    } else if (yCenter + halfMinDecorationHeight > canvasHeight) {
                        yCenter = canvasHeight - halfMinDecorationHeight;
                    }
                    y1 = yCenter - halfMinDecorationHeight;
                    y2 = yCenter + halfMinDecorationHeight;
                }
                if (y1 > prevY2 + 1 || lane != prevLane) {
                    // flush prev
                    if (i != 0) {
                        canvasRect(laneX[prevLane], prevY1, laneW[prevLane], prevY2 - prevY1, color);
                    }
                    prevLane = lane;
                    prevY1 = y1;
                    prevY2 = y2;
                } else {
                    // merge into prev
                    if (y2 > prevY2) {
                        prevY2 = y2;
                    }
                }
            }
            canvasRect(laneX[prevLane], prevY1, laneW[prevLane], prevY2 - prevY1, color);
        }

        // Draw cursors
        if (!options.get(EditorOption.hideCursorInOverviewRuler)) {
            final cursorHeight = Std.int(2 * pixelRatio);
            final halfCursorHeight = Std.int(cursorHeight / 2);
            final cursorX = laneX[7];
            final cursorW = laneW[7];
            final single = state.overviewRulerColor(PaintState.RULER_CURSOR_SINGLE, theme.getColor('editorCursor.foreground'), 0.7);
            final primary = state.overviewRulerColor(PaintState.RULER_CURSOR_PRIMARY, theme.getColor('editorMultiCursor.primary.foreground'), 0.7);
            final secondary = state.overviewRulerColor(PaintState.RULER_CURSOR_SECONDARY, theme.getColor('editorMultiCursor.secondary.foreground'), 0.7);
            state.updateCursorMarks(selections);
            final lines = state.cursorMarkLines;
            final slots = state.cursorMarkSlots;
            var prevY1 = -100;
            var prevY2 = -100;
            var prevColor:Null<Hsla> = null;
            for (i in 0...lines.length) {
                final slot = slots[i];
                final color = slot == PaintState.RULER_CURSOR_SINGLE ? single : (slot == PaintState.RULER_CURSOR_PRIMARY ? primary : secondary);
                if (color == null) {
                    continue;
                }
                var yCenter = Std.int(viewLayout.getVerticalOffsetForLineNumber(lines[i]) * heightRatio);
                if (yCenter < halfCursorHeight) {
                    yCenter = halfCursorHeight;
                } else if (yCenter + halfCursorHeight > canvasHeight) {
                    yCenter = canvasHeight - halfCursorHeight;
                }
                final y1 = yCenter - halfCursorHeight;
                final y2 = y1 + cursorHeight;
                // Monaco compares the colors' strings: equal colors of two
                // slots are one color
                if (y1 > prevY2 + 1 || prevColor == null || !color.equals(prevColor)) {
                    // flush prev
                    if (i != 0 && prevColor != null) {
                        canvasRect(cursorX, prevY1, cursorW, prevY2 - prevY1, prevColor);
                    }
                    prevY1 = y1;
                    prevY2 = y2;
                } else {
                    // merge into prev
                    if (y2 > prevY2) {
                        prevY2 = y2;
                    }
                }
                prevColor = color;
            }
            if (prevColor != null) {
                canvasRect(cursorX, prevY1, cursorW, prevY2 - prevY1, prevColor);
            }
        }

        // The border, on top of the marks
        if (options.get(EditorOption.overviewRulerBorder)) {
            final border = state.overviewRulerColor(PaintState.RULER_BORDER, theme.getColor('editorOverviewRuler.border'), 0.5);
            if (border != null) {
                canvasRect(0, 0, 1, canvasHeight, border);
                canvasRect(1, 0, canvasWidth - 1, 1, border);
            }
        }
    }

    /** decorationsOverviewRuler.ts `Constants.MIN_DECORATION_HEIGHT`. */
    static inline final MIN_DECORATION_HEIGHT = 6;

    static final DEFAULT_BACKGROUND = new Hsla(0, 0, 0.12, 1);

    // dnd.css: `border-right: 2px dotted` black (light), #AEAFAD (dark), #fff (high contrast dark)
    static final DND_TARGET_LIGHT = new Hsla(0, 0, 0, 1);
    static final DND_TARGET_DARK = rgb(0xAEAFAD).toHsla();
    static final DND_TARGET_HC_DARK = new Hsla(0, 0, 1, 1);

    /**
     * Monaco's folding codicons in the line decorations (folding.css): a
     * chevron right for a collapsed range (always shown), a chevron down for
     * an expanded one, shown when the mouse is over the gutter
     * (`showFoldingControls: 'mouseover'`) or always (`alwaysShowFoldIcons`,
     * `'always'`). Drawn from the outlines of the codicons (`Codicons`),
     * colored by `editorGutter.foldingControlForeground`.
     */
    static function paintFoldingControls(window:Window, cx:App, v:CityscapeView, decorations:Array<cityscape.common.ViewModel.ViewModelDecoration>, startLine:Int, endLine:Int, originX:Float, linesOriginY:Float, decorationsLeft:Float, decorationsWidth:Float, lineHeight:Float, fontSize:Float):Void {
        var color:Null<Hsla> = null;
        for (d in decorations) {
            final className = d.options.firstLineDecorationClassName;
            if (className == null || className.indexOf('codicon-folding-') == -1) {
                continue;
            }
            final ln = d.range.startLineNumber;
            if (ln < startLine || ln > endLine) {
                continue;
            }
            final collapsed = className.indexOf('codicon-folding-collapsed') != -1 || className.indexOf('codicon-folding-manual-collapsed') != -1;
            if (!collapsed && className.indexOf('alwaysShowFoldIcons') == -1 && !v.gutterHovered) {
                continue;
            }
            if (color == null) {
                color = v.theme.getColor('editorGutter.foldingControlForeground');
                if (color == null) {
                    color = new Hsla(0, 0, 0.77, 1);
                }
            }
            // The codicon at `font-size: 140%; margin-left: 2px`, centered in
            // the line decorations (folding.css), drawn from its outline
            final lineTop = linesOriginY + v.viewModel.viewLayout.getVerticalOffsetForLineNumber(ln);
            Codicons.paintGutterFoldingIcon(window, cx, originX + decorationsLeft, decorationsWidth, lineTop, lineHeight, fontSize, collapsed, color);
        }
    }

    /**
     * A decoration box (background, border, radius, vertical padding around
     * the font's content area when `line` is given).
     */
    static function paintBox(window:Window, state:PaintState, box:ResolvedBox, x:Float, lineY:Float, width:Float, lineHeight:Float, line:Null<RenderedViewLine>, roundLeft:Bool, roundRight:Bool):Void {
        var y = lineY;
        var h = lineHeight;
        if (line != null && (box.paddingTop != 0 || box.paddingBottom != 0)) {
            // CSS inline box: the content area (ascent + descent), centered
            // in the line, grown by the vertical padding
            final ascent:Float = line.layout.ascent;
            final descent:Float = line.layout.descent;
            final contentHeight:Float = ascent + descent;
            final top = lineY + (lineHeight - contentHeight) / 2;
            y = top - box.paddingTop;
            h = contentHeight + box.paddingTop + box.paddingBottom;
        }
        final r = box.borderRadius;
        final radii = state.corners(roundLeft ? r : 0, roundRight ? r : 0, roundRight ? r : 0, roundLeft ? r : 0);
        if (box.background != null) {
            fillRect(window, x, y, width, h, box.background, radii);
        }
        if (box.borderColor != null && box.borderWidth > 0) {
            strokeRect(window, x, y, width, h, box.borderColor, box.borderWidth, radii);
        }
    }

}

/**
 * A number of the gutter, shaped once (`PaintState.lineNumberLabel`).
 */
private class LineNumberLabel {

    public var lineNumber:Int = 0;
    /** The label given (`null`: the plain number). */
    public var label:Null<String> = null;
    public var fontSize:Float = 0;
    public var font:Null<glaze.Font> = null;
    public var color:Null<Hsla> = null;
    public var fontGeneration:Int = -1;
    public var shaped:Null<glaze.ShapedLine> = null;

    public function new() {}

}

/**
 * What the paint of a `CityscapeView` keeps from one frame to the next, so
 * that a frame where nothing but the scroll position changed allocates
 * nothing in Cityscape: the visible lines, the selections and what follows
 * from them, the decorations' query range, the guides, the overview ruler
 * marks, the shaped line numbers, the masks and the corner radii. Each part
 * is computed again when `CityscapeView.paintGeneration` changed (a view
 * event other than scrolling, or the rendered lines dropped).
 */
class PaintState {

    public final viewport = new cityscape.common.viewLayout.LinesLayout.LinesViewportRange();

    // Scrollable element shadows (kept from frame to frame)
    final topShadow:Array<glaze.BoxShadow> = [new glaze.BoxShadow(0, 6, new Hsla(0, 0, 0, 1)).withBlurRadius(6).withSpreadRadius(-6).withInset()];
    final leftShadow:Array<glaze.BoxShadow> = [new glaze.BoxShadow(6, 0, new Hsla(0, 0, 0, 1)).withBlurRadius(6).withSpreadRadius(-6).withInset()];
    var topShadowBounds:Null<Bounds> = null;
    var leftShadowBounds:Null<Bounds> = null;
    var cornerShadowBounds:Null<Bounds> = null;
    static final NO_CORNERS = Corners.all(0);

    static function boundsOf(previous:Null<Bounds>, x:Float, y:Float, w:Float, h:Float):Bounds {
        if (previous != null && previous.origin.x == x && previous.origin.y == y && previous.size.width == w && previous.size.height == h) {
            return previous;
        }
        return new Bounds(new Point(x, y), new Size(w, h));
    }

    /**
     * Monaco's scrollable element shadows (scrollbars.css), at the text
     * area of `x, y, width, height`: `.shadow.top` (3 px high from 3 px to
     * the right, `0 6px 6px -6px inset`), `.shadow.left` (3 px wide from
     * 3 px down, `6px 0 6px -6px inset`) and the corner (3 px square, the
     * left shadow when both apply, else the one that applies).
     */
    public function paintScrollShadows(window:Window, x:Float, y:Float, width:Float, height:Float, top:Bool, left:Bool, color:Hsla):Void {
        topShadow[0].color = color;
        leftShadow[0].color = color;
        if (top) {
            topShadowBounds = boundsOf(topShadowBounds, x + 3, y, Math.max(0, width), 3);
            window.paintInsetShadows(topShadowBounds, NO_CORNERS, topShadow);
        }
        if (left) {
            leftShadowBounds = boundsOf(leftShadowBounds, x, y + 3, 3, Math.max(0, height));
            window.paintInsetShadows(leftShadowBounds, NO_CORNERS, leftShadow);
        }
        cornerShadowBounds = boundsOf(cornerShadowBounds, x, y, 3, 3);
        window.paintInsetShadows(cornerShadowBounds, NO_CORNERS, left ? leftShadow : topShadow);
    }

    var rulerBounds:Null<Bounds> = null;

    /** The bounds of the overview ruler, the same object while they do not change. */
    public function rulerBoundsOf(x:Float, y:Float, w:Float, h:Float):Bounds {
        return rulerBounds = boundsOf(rulerBounds, x, y, w, h);
    }

    public final lines:Array<RenderedViewLine> = [];

    public final selectionStarts:Array<Float> = [];

    public final selectionEnds:Array<Float> = [];

    public function new() {}

    // Selections

    var selectionsGeneration:Int = -1;

    public var selections(default, null):Array<Selection> = [];

    /** The model line of the primary cursor. */
    public var primaryModelLineNumber(default, null):Int = 1;

    /** [loreline] The view line drawing the number of the primary cursor's model line. */
    public var activeNumberViewLine(default, null):Int = 1;

    /** The position of the first selection (the active guides), null without selection. */
    public var firstSelectionPosition(default, null):Null<Position> = null;

    public function updateSelections(v:CityscapeView, viewModel:ViewModelClass, generation:Int):Void {
        if (selectionsGeneration == generation) {
            return;
        }
        selectionsGeneration = generation;
        selections = v.viewSelections();
        final primaryModel = viewModel.getSelection().getPosition();
        primaryModelLineNumber = primaryModel.lineNumber;
        activeNumberViewLine = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(primaryModel.lineNumber, 1)).lineNumber;
        firstSelectionPosition = selections.length > 0 ? selections[0].getPosition() : null;
    }

    // Decorations' query range

    /** Lines of the blocks the query range is rounded to. */
    static inline final QUERY_BLOCK = 32;

    var queryGeneration:Int = -1;
    var queryStart:Int = -1;
    var queryEnd:Int = -1;
    var queryLineCount:Int = -1;
    var queryRangeValue:Null<Range> = null;

    /**
     * The range of the decorations and rendering data queries: the visible
     * lines rounded out to blocks of `QUERY_BLOCK` lines, the same object
     * while it does not change.
     */
    public function queryRange(viewModel:ViewModelClass, generation:Int, startLine:Int, endLine:Int):Range {
        final lineCount = viewModel.getLineCount();
        final start = Std.int((startLine - 1) / QUERY_BLOCK) * QUERY_BLOCK + 1;
        var end = (Std.int((endLine - 1) / QUERY_BLOCK) + 1) * QUERY_BLOCK;
        if (end > lineCount) {
            end = lineCount;
        }
        if (queryRangeValue == null || generation != queryGeneration || start != queryStart || end != queryEnd || lineCount != queryLineCount) {
            queryGeneration = generation;
            queryStart = start;
            queryEnd = end;
            queryLineCount = lineCount;
            queryRangeValue = new Range(start, viewModel.getLineMinColumn(start), end, viewModel.getLineMaxColumn(end));
        }
        return queryRangeValue;
    }

    // Guides

    var guidesGeneration:Int = -1;
    var guidesStart:Int = -1;
    var guidesEnd:Int = -1;
    var guidesOptions:Null<Dynamic> = null;
    var guidesValue:Null<Array<Array<cityscape.common.TextModelGuides.IndentGuide>>> = null;
    final guideCache = new cityscape.view.viewParts.indentGuides.IndentGuides.IndentGuideCache();

    public function guides(viewModel:ViewModelClass, options:InternalGuidesOptions, generation:Int, start:Int, end:Int):Array<Array<cityscape.common.TextModelGuides.IndentGuide>> {
        if (guidesValue == null || generation != guidesGeneration || start != guidesStart || end != guidesEnd || (options:Dynamic) != guidesOptions) {
            guidesGeneration = generation;
            guidesStart = start;
            guidesEnd = end;
            guidesOptions = options;
            // the arrays of the previous guides are filled again
            guidesValue = IndentGuides.getGuidesByLine(viewModel, options, start, end, firstSelectionPosition, guideCache, guidesValue);
        }
        return guidesValue;
    }

    // Overview ruler

    var overviewGeneration:Int = -1;
    var overviewTheme:Null<Dynamic> = null;
    var overviewGroups:Array<OverviewRulerDecorationsGroup> = [];

    /** The colors of `overviewRulerGroups`, resolved with them. */
    public final overviewRulerColors:Array<Null<Hsla>> = [];

    public function overviewRulerGroups(viewModel:ViewModelClass, theme:ViewTheme, generation:Int):Array<OverviewRulerDecorationsGroup> {
        final editorTheme = theme.editorTheme;
        if (generation != overviewGeneration || (editorTheme:Dynamic) != overviewTheme) {
            overviewGeneration = generation;
            overviewTheme = editorTheme;
            overviewGroups = viewModel.getAllOverviewRulerDecorations(editorTheme);
            overviewRulerColors.resize(0);
            for (group in overviewGroups) {
                overviewRulerColors.push(theme.resolveDecorationColor(group.color));
            }
        }
        return overviewGroups;
    }

    // The colors of the ruler (decorationsOverviewRuler.ts `Settings`):
    // `transparent(0.7)` of the cursor colors, the border at half its alpha
    // (see `paintOverviewRuler`), each kept while its source is the same
    final rulerColorSources:Array<Null<Hsla>> = [null, null, null, null];
    final rulerColorValues:Array<Null<Hsla>> = [null, null, null, null];

    /**
     * The color of slot `slot` (`RULER_CURSOR_SINGLE`, `_PRIMARY`,
     * `_SECONDARY`, `RULER_BORDER`) from `color`: `color.opacity(factor)`,
     * null for null, kept while `color` is the same.
     */
    public function overviewRulerColor(slot:Int, color:Null<Hsla>, factor:Float):Null<Hsla> {
        if (color != rulerColorSources[slot] || (color != null && rulerColorValues[slot] == null)) {
            rulerColorSources[slot] = color;
            rulerColorValues[slot] = color != null ? color.opacity(factor) : null;
        }
        return rulerColorValues[slot];
    }

    public static inline final RULER_CURSOR_SINGLE = 0;
    public static inline final RULER_CURSOR_PRIMARY = 1;
    public static inline final RULER_CURSOR_SECONDARY = 2;
    public static inline final RULER_BORDER = 3;

    // decorationsOverviewRuler.ts `_initLanes`: the lanes' left and width in
    // canvas pixels, by `OverviewRulerLane` (0 to 7)
    var lanesCanvasWidth:Int = -1;
    var lanesCount:Int = -1;
    public final laneX:Array<Int> = [0, 0, 0, 0, 0, 0, 0, 0];
    public final laneW:Array<Int> = [0, 0, 0, 0, 0, 0, 0, 0];

    public function initLanes(canvasWidth:Int, laneCount:Int):Void {
        if (canvasWidth == lanesCanvasWidth && laneCount == lanesCount) {
            return;
        }
        lanesCanvasWidth = canvasWidth;
        lanesCount = laneCount;
        final canvasLeftOffset = 1;
        final remainingWidth = canvasWidth - canvasLeftOffset;
        final x = laneX;
        final w = laneW;
        x[0] = 0;
        w[0] = 0;
        if (laneCount >= 3) {
            final leftWidth = Math.floor(remainingWidth / 3);
            final rightWidth = Math.floor(remainingWidth / 3);
            final centerWidth = remainingWidth - leftWidth - rightWidth;
            final leftOffset = canvasLeftOffset;
            final centerOffset = leftOffset + leftWidth;
            final rightOffset = leftOffset + leftWidth + centerWidth;
            x[1] = leftOffset; w[1] = leftWidth; // Left
            x[2] = centerOffset; w[2] = centerWidth; // Center
            x[3] = leftOffset; w[3] = leftWidth + centerWidth; // Left | Center
            x[4] = rightOffset; w[4] = rightWidth; // Right
            x[5] = leftOffset; w[5] = leftWidth + centerWidth + rightWidth; // Left | Right
            x[6] = centerOffset; w[6] = centerWidth + rightWidth; // Center | Right
            x[7] = leftOffset; w[7] = leftWidth + centerWidth + rightWidth; // Left | Center | Right
        } else if (laneCount == 2) {
            final leftWidth = Math.floor(remainingWidth / 2);
            final rightWidth = remainingWidth - leftWidth;
            final leftOffset = canvasLeftOffset;
            final rightOffset = leftOffset + leftWidth;
            x[1] = leftOffset; w[1] = leftWidth;
            x[2] = leftOffset; w[2] = leftWidth;
            x[3] = leftOffset; w[3] = leftWidth;
            x[4] = rightOffset; w[4] = rightWidth;
            x[5] = leftOffset; w[5] = leftWidth + rightWidth;
            x[6] = leftOffset; w[6] = leftWidth + rightWidth;
            x[7] = leftOffset; w[7] = leftWidth + rightWidth;
        } else {
            for (i in 1...8) {
                x[i] = canvasLeftOffset;
                w[i] = remainingWidth;
            }
        }
    }

    // decorationsOverviewRuler.ts `_cursorPositions`: the view line of each
    // cursor and its color slot (single, or primary for the first selection
    // and secondary for the others), sorted by position
    var cursorMarksOf:Null<Array<Selection>> = null;
    public final cursorMarkLines:Array<Int> = [];
    public final cursorMarkSlots:Array<Int> = [];
    final cursorMarkColumns:Array<Int> = [];

    public function updateCursorMarks(selections:Array<Selection>):Void {
        if (selections == cursorMarksOf) {
            return;
        }
        cursorMarksOf = selections;
        final lines = cursorMarkLines;
        final slots = cursorMarkSlots;
        final columns = cursorMarkColumns;
        lines.resize(0);
        slots.resize(0);
        columns.resize(0);
        final len = selections.length;
        for (i in 0...len) {
            final s = selections[i];
            final line = s.positionLineNumber;
            final column = s.positionColumn;
            final slot = len > 1 ? (i == 0 ? RULER_CURSOR_PRIMARY : RULER_CURSOR_SECONDARY) : RULER_CURSOR_SINGLE;
            // insertion (stable, like Array.sort) by `Position.compare`
            var k = lines.length;
            lines.push(line);
            slots.push(slot);
            columns.push(column);
            while (k > 0 && (lines[k - 1] > line || (lines[k - 1] == line && columns[k - 1] > column))) {
                lines[k] = lines[k - 1];
                slots[k] = slots[k - 1];
                columns[k] = columns[k - 1];
                k--;
            }
            lines[k] = line;
            slots[k] = slot;
            columns[k] = column;
        }
    }

    // Line numbers

    final labels:Map<Int, LineNumberLabel> = new Map();
    final labelKeys:Array<Int> = [];

    var numberFontInfo:Null<Dynamic> = null;
    var numberFontValue:Null<glaze.Font> = null;
    var numberFontGeneration:Int = -1;

    /** The font of the line numbers, kept while the font info is the same. */
    public function numberFont(v:CityscapeView, fontInfo:cityscape.common.config.FontInfo, fontGeneration:Int):glaze.Font {
        if (numberFontValue == null || (fontInfo:Dynamic) != numberFontInfo || fontGeneration != numberFontGeneration) {
            numberFontInfo = fontInfo;
            numberFontGeneration = fontGeneration;
            numberFontValue = v.measurements.resolveEditorFont(fontInfo.fontFamily, EditorFontMeasurements.parseFontWeight(fontInfo.fontWeight), false, EditorFontMeasurements.parseFontFeatureSettings(fontInfo.fontFeatureSettings));
        }
        return numberFontValue;
    }

    /**
     * The shaped number of a model line (`label`, or the plain number when
     * null), kept while its text, size, font, color and the fonts stay the
     * same.
     */
    public function lineNumberLabel(textSystem:glaze.WindowTextSystem, lineNumber:Int, label:Null<String>, fontSize:Float, font:glaze.Font, color:Hsla):glaze.ShapedLine {
        final fontGeneration = textSystem.textSystem.fontGeneration;
        var entry = labels.get(lineNumber);
        if (entry != null && entry.shaped != null && entry.lineNumber == lineNumber && entry.label == label && entry.fontSize == fontSize
            && entry.font == font && entry.color == color && entry.fontGeneration == fontGeneration) {
            return entry.shaped;
        }
        if (entry == null) {
            entry = new LineNumberLabel();
            labels.set(lineNumber, entry);
            labelKeys.push(lineNumber);
        }
        final text = label != null ? label : '' + lineNumber;
        entry.lineNumber = lineNumber;
        entry.label = label;
        entry.fontSize = fontSize;
        entry.font = font;
        entry.color = color;
        entry.fontGeneration = fontGeneration;
        entry.shaped = textSystem.shapeLine(text, fontSize, [new glaze.TextRun(glaze.util.Utf8.byteLength(text), font, color)]);
        return entry.shaped;
    }

    /** Drops the labels of the model lines far from the visible view lines. */
    public function trimLineNumberLabels(startLine:Int, endLine:Int):Void {
        // View lines and model lines differ with wrapping and folding: keep a
        // wide margin, the labels are small
        final keys = labelKeys;
        if (keys.length < (endLine - startLine + 1) * 4 + 200) {
            return;
        }
        final margin = (endLine - startLine + 1) * 2 + 100;
        var i = 0;
        while (i < keys.length) {
            final k = keys[i];
            final entry = labels.get(k);
            if (k < startLine - margin || k > endLine + margin) {
                labels.remove(k);
                keys[i] = keys[keys.length - 1];
                keys.pop();
            }
            else {
                i++;
            }
        }
    }

    // Folded ellipsis

    var ellipsisLength:Int = -1;
    var ellipsisColor:Null<Hsla> = null;
    var ellipsisRunsValue:Null<Array<glaze.DecorationRun>> = null;

    public function ellipsisRuns(length:Int, color:Null<Hsla>):Array<glaze.DecorationRun> {
        if (ellipsisRunsValue == null || length != ellipsisLength || color != ellipsisColor) {
            ellipsisLength = length;
            ellipsisColor = color;
            ellipsisRunsValue = [new glaze.DecorationRun(length, color != null ? color : new Hsla(0, 0, 0.5, 1), null, null, null)];
        }
        return ellipsisRunsValue;
    }

    // Masks, input handler, colors, corners

    var contentMaskValue:Null<ContentMask> = null;
    var gutterMaskValue:Null<ContentMask> = null;

    static function sameBounds(b:Bounds, x:Float, y:Float, w:Float, h:Float):Bool {
        return b.origin.x == x && b.origin.y == y && b.size.width == w && b.size.height == h;
    }

    public function contentMask(x:Float, y:Float, w:Float, h:Float):ContentMask {
        final mask = contentMaskValue;
        if (mask != null && sameBounds(mask.bounds, x, y, w, h)) {
            return mask;
        }
        final created = new ContentMask(new Bounds(new Point(x, y), new Size(w, h)));
        contentMaskValue = created;
        return created;
    }

    public function gutterMask(x:Float, y:Float, w:Float, h:Float):ContentMask {
        final mask = gutterMaskValue;
        if (mask != null && sameBounds(mask.bounds, x, y, w, h)) {
            return mask;
        }
        final created = new ContentMask(new Bounds(new Point(x, y), new Size(w, h)));
        gutterMaskValue = created;
        return created;
    }

    var inputHandler:Null<ElementInputHandler<CityscapeView>> = null;
    var inputHandlerBounds:Null<Bounds> = null;

    /** The input handler of the element's bounds, kept while they are the same. */
    public function inputHandlerFor(bounds:Bounds, view:Entity<CityscapeView>):ElementInputHandler<CityscapeView> {
        final handler = inputHandler;
        final previous = inputHandlerBounds;
        if (handler != null && previous != null && sameBounds(previous, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height)) {
            return handler;
        }
        final created = new ElementInputHandler(bounds, view);
        inputHandler = created;
        inputHandlerBounds = bounds;
        return created;
    }

    final parsedColors:Map<String, Null<Hsla>> = new Map();

    /** `ViewTheme.parseColor`, kept by value. */
    public function parsedColor(value:String):Null<Hsla> {
        if (parsedColors.exists(value)) {
            return parsedColors.get(value);
        }
        final color = ViewTheme.parseColor(value);
        parsedColors.set(value, color);
        return color;
    }

    final cornersValues:Array<Corners> = [];

    /** Corner radii (immutable), the same object for the same values. */
    public function corners(topLeft:Float, topRight:Float, bottomRight:Float, bottomLeft:Float):Corners {
        for (i in 0...cornersValues.length) {
            final c = cornersValues[i];
            if (c.topLeft == topLeft && c.topRight == topRight && c.bottomRight == bottomRight && c.bottomLeft == bottomLeft) {
                return c;
            }
        }
        if (cornersValues.length >= 64) {
            cornersValues.resize(0);
        }
        final created = new Corners(topLeft, topRight, bottomRight, bottomLeft);
        cornersValues.push(created);
        return created;
    }

}
