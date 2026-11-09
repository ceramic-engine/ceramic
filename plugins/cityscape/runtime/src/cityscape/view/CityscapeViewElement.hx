// New code for Cityscape (not a port): the Glaze element painting a
// Cityscape view, in place of Monaco's DOM view parts (viewLines,
// lineNumbers, glyphMargin, linesDecorations, marginDecorations,
// currentLineHighlight, decorations, selections, viewCursors, indentGuides,
// rulers, overviewRuler).
package cityscape.view;

import cityscape.common.DecorationStyle.IDecorationStyle;
import cityscape.common.ViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.view.CityscapeView.RenderedViewLine;
import cityscape.view.DecorationStyleResolver;
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
        v.layoutTo(bounds, window.scaleFactor());
        final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        window.setCursorStyle(CursorStyle.IBeam, hitbox);
    }

    static inline function fillRect(window:Window, x:Float, y:Float, w:Float, h:Float, color:Hsla, ?radii:Corners):Void {
        if (w <= 0 || h <= 0 || color == null) {
            return;
        }
        final q = fill(new Bounds(new Point(x, y), new Size(w, h)), color);
        if (radii != null) {
            q.cornerRadii = radii;
        }
        window.paintQuad(q);
    }

    static function strokeRect(window:Window, x:Float, y:Float, w:Float, h:Float, color:Hsla, width:Float, ?radii:Corners):Void {
        if (w <= 0 || h <= 0 || color == null) {
            return;
        }
        final q = quad(new Bounds(new Point(x, y), new Size(w, h)), radii != null ? radii : Corners.all(0), transparentBlack(), Edges.all(width), color, glaze.scene.BorderStyle.Solid);
        window.paintQuad(q);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final v = view.read(cx);
        final viewModel = v.viewModel;
        final theme = v.theme;
        final options = v.configuration.options;
        final background = theme.getColor('editor.background');
        fillRect(window, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, background != null ? background : new Hsla(0, 0, 0.12, 1));
        if (viewModel == null) {
            return;
        }

        final focused = v.focusHandle.isFocused(window);
        window.handleInput(v.focusHandle, new ElementInputHandler(bounds, view), cx);

        final layoutInfo = options.get(EditorOption.layoutInfo);
        final lineHeight:Float = options.get(EditorOption.lineHeight);
        final fontInfo = options.get(EditorOption.fontInfo);
        final viewLayout = viewModel.viewLayout;
        final scrollTop = viewLayout.getCurrentScrollTop();
        final scrollLeft = viewLayout.getCurrentScrollLeft();

        final partial = viewLayout.getLinesViewportData();
        final startLine = partial.startLineNumber;
        final endLine = partial.endLineNumber;
        viewModel.setViewport(startLine, endLine, partial.centeredLineNumber);
        v.visibleLinesRendered(startLine, endLine);
        final visibleRange = new Range(startLine, viewModel.getLineMinColumn(startLine), endLine, viewModel.getLineMaxColumn(endLine));

        final originX = bounds.origin.x;
        final originY = bounds.origin.y;
        final contentX = originX + layoutInfo.contentLeft - scrollLeft;
        inline function lineTop(lineNumber:Int):Float {
            return originY + viewLayout.getVerticalOffsetForLineNumber(lineNumber) - scrollTop;
        }

        // Render the visible lines (shaping only what changed)
        final lines:Array<RenderedViewLine> = [];
        for (lineNumber in startLine...endLine + 1) {
            lines.push(v.renderViewLine(lineNumber, visibleRange));
        }

        final selections = viewModel.getViewSelections();
        final decorations = viewModel.getDecorationsInViewport(visibleRange);

        // Primary cursor (model) line, for the line highlight and the active line number
        final primaryModel = viewModel.getSelection().getPosition();
        // [loreline] the view line that draws the number of the cursor's model line
        final activeNumberViewLine = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(primaryModel.lineNumber, 1)).lineNumber;

        // --- content area
        final contentBounds = new Bounds(new Point(originX + layoutInfo.contentLeft, originY), new Size(Math.max(0, bounds.size.width - layoutInfo.contentLeft), bounds.size.height));
        window.pushContentMask(new ContentMask(contentBounds));

        // Current line highlight (Monaco's currentLineHighlight)
        final renderLineHighlight = options.get(EditorOption.renderLineHighlight);
        final showHighlight = renderLineHighlight != 'none' && renderLineHighlight != 'gutter' && (focused || !options.get(EditorOption.renderLineHighlightOnlyWhenFocus));
        final highlightBackground = theme.getColor('editor.lineHighlightBackground');
        final highlightBorder = theme.getColor('editor.lineHighlightBorder');
        if (showHighlight) {
            for (s in selections) {
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
        for (d in decorations) {
            final opts = d.options;
            final lineStyles = v.resolver.combinedStyle(opts.isWholeLine == true ? opts.className : null, opts.lineStyle);
            final boxStyles = v.resolver.combinedStyle(opts.isWholeLine == true ? null : opts.className, opts.style);
            if (lineStyles != null) {
                for (ln in Std.int(Math.max(startLine, d.range.startLineNumber))...Std.int(Math.min(endLine, d.range.endLineNumber)) + 1) {
                    for (st in lineStyles) {
                        final box = v.resolver.resolveBox(st);
                        if (box != null && box.background != null) {
                            fillRect(window, contentBounds.origin.x, lineTop(ln), contentBounds.size.width, lineHeight, box.background);
                        }
                    }
                }
            }
            if (boxStyles != null && !d.range.isEmpty()) {
                for (ln in Std.int(Math.max(startLine, d.range.startLineNumber))...Std.int(Math.min(endLine, d.range.endLineNumber)) + 1) {
                    final line = lines[ln - startLine];
                    final startColumn = (ln == d.range.startLineNumber ? d.range.startColumn : line.minColumn);
                    final endColumn = (ln == d.range.endLineNumber ? d.range.endColumn : line.maxColumn);
                    final x1 = line.columnToX(startColumn);
                    var x2 = line.columnToX(endColumn);
                    if (ln != d.range.endLineNumber) {
                        x2 += fontInfo.spaceWidth;
                    }
                    for (st in boxStyles) {
                        final box = v.resolver.resolveBox(st);
                        if (box != null) {
                            paintBox(window, box, contentX + x1, lineTop(ln), x2 - x1, lineHeight, line, true, true);
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
                final x1 = line.layout.xForIndex(line.offsets.utf16ToByte(line.runs.partStarts[p]));
                final x2 = line.layout.xForIndex(line.offsets.utf16ToByte(line.runs.partEnds[q - 1]));
                paintBox(window, box, contentX + x1, y, x2 - x1, lineHeight, line, true, true);
                p = q;
            }
        }

        // Selections (Monaco's selections view part, rounded corners)
        final selectionColor = theme.getColor(focused ? 'editor.selectionBackground' : 'editor.inactiveSelectionBackground');
        final rounded = options.get(EditorOption.roundedSelection);
        if (selectionColor != null) {
            for (s in selections) {
                if (s.isEmpty()) {
                    continue;
                }
                final from = Std.int(Math.max(startLine, s.startLineNumber));
                final to = Std.int(Math.min(endLine, s.endLineNumber));
                final xs:Array<Float> = [];
                final xe:Array<Float> = [];
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
                    fillRect(window, contentX + xs[k], lineTop(ln), xe[k] - xs[k], lineHeight, selectionColor, new Corners(tl, tr, br, bl));
                }
            }
        }

        // Indent guides (hook: active guides and bracket pair guides come with step 4)
        final guideColor = theme.getColor('editorIndentGuide.background1');
        if (guideColor != null) {
            final guides = viewModel.getLinesIndentGuides(startLine, endLine);
            final tabSize = viewModel.model.getOptions().tabSize;
            final indentWidth = tabSize * fontInfo.spaceWidth;
            for (i in 0...guides.length) {
                final y = lineTop(startLine + i);
                for (level in 1...guides[i]) {
                    fillRect(window, Math.round(contentX + level * indentWidth), y, 1, lineHeight, guideColor);
                }
            }
        }

        // Rulers
        final rulerColor = theme.getColor('editorRuler.foreground');
        for (ruler in options.get(EditorOption.rulers)) {
            final color = ruler.color != null ? ViewTheme.parseColor(ruler.color) : rulerColor;
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
        var ellipsisRuns:Null<Array<glaze.DecorationRun>> = null;
        for (i in 0...lines.length) {
            final line = lines[i];
            final names = line.runs.partClassNames;
            for (p in 0...names.length) {
                if (names[p].indexOf('inline-folded') == -1) {
                    continue;
                }
                final ellipsis = v.foldedEllipsisLayout();
                if (ellipsisRuns == null) {
                    final color = theme.getColor('editor.foldPlaceholderForeground');
                    ellipsisRuns = [new glaze.DecorationRun(ellipsis.len, color != null ? color : new Hsla(0, 0, 0.5, 1), null, null, null)];
                }
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
            for (s in selections) {
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

        window.popContentMask();

        // --- margin (gutter)
        final gutterWidth = layoutInfo.contentLeft;
        if (gutterWidth > 0) {
            window.pushContentMask(new ContentMask(new Bounds(new Point(originX, originY), new Size(gutterWidth, bounds.size.height))));
            final gutterBackground = theme.getColor('editorGutter.background');
            if (gutterBackground != null) {
                fillRect(window, originX, originY, gutterWidth, bounds.size.height, gutterBackground);
            }
            // margin decorations (`marginClassName`, `marginStyle`, whole margin width)
            for (d in decorations) {
                final opts = d.options;
                final marginStyles = v.resolver.combinedStyle(opts.marginClassName, opts.marginStyle);
                final glyphStyles = v.resolver.combinedStyle(opts.glyphMarginClassName, opts.glyphMarginStyle);
                final linesStyles = v.resolver.combinedStyle(opts.linesDecorationsClassName, opts.linesDecorationsStyle);
                for (ln in Std.int(Math.max(startLine, d.range.startLineNumber))...Std.int(Math.min(endLine, d.range.endLineNumber)) + 1) {
                    final y = lineTop(ln);
                    if (marginStyles != null) {
                        for (st in marginStyles) {
                            final box = v.resolver.resolveBox(st);
                            if (box != null) {
                                paintBox(window, box, originX, y, gutterWidth, lineHeight, null, false, false);
                            }
                        }
                    }
                    if (glyphStyles != null && layoutInfo.glyphMarginWidth > 0) {
                        for (st in glyphStyles) {
                            final box = v.resolver.resolveBox(st);
                            if (box != null) {
                                paintBox(window, box, originX + layoutInfo.glyphMarginLeft + 2, y + 2, Math.min(layoutInfo.glyphMarginWidth, lineHeight) - 4, lineHeight - 4, null, false, false);
                            }
                        }
                    }
                    if (linesStyles != null) {
                        for (st in linesStyles) {
                            final box = v.resolver.resolveBox(st);
                            if (box != null) {
                                paintBox(window, box, originX + layoutInfo.decorationsLeft, y, Math.max(2, layoutInfo.decorationsWidth - 16), lineHeight, null, false, false);
                            }
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
                final numberFont = v.measurements.resolveEditorFont(fontInfo.fontFamily, EditorFontMeasurements.parseFontWeight(fontInfo.fontWeight), false, EditorFontMeasurements.parseFontFeatureSettings(fontInfo.fontFeatureSettings));
                final lineCount = viewModel.model.getLineCount();
                for (ln in startLine...endLine + 1) {
                    final modelPosition = viewModel.coordinatesConverter.convertViewPositionToModelPosition(new Position(ln, viewModel.getLineMinColumn(ln)));
                    final isFirstViewLine = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(modelPosition.lineNumber, 1)).lineNumber == ln;
                    if (!isFirstViewLine) {
                        continue;
                    }
                    final modelLineNumber = modelPosition.lineNumber;
                    var label:String;
                    if (lineNumbers.renderFn != null) {
                        label = lineNumbers.renderFn(modelLineNumber);
                    } else if (lineNumbers.renderType == RenderLineNumbersType.Relative) {
                        final diff = Std.int(Math.abs(primaryModel.lineNumber - modelLineNumber));
                        label = diff == 0 ? '' + modelLineNumber : '' + diff;
                    } else if (lineNumbers.renderType == RenderLineNumbersType.Interval) {
                        label = (primaryModel.lineNumber == modelLineNumber || modelLineNumber % 10 == 0 || modelLineNumber == lineCount) ? '' + modelLineNumber : '';
                    } else {
                        label = '' + modelLineNumber;
                    }
                    if (label.length == 0) {
                        continue;
                    }
                    var color = (ln == activeNumberViewLine) ? (activeColor != null ? activeColor : numberColor) : numberColor;
                    // `lineNumberClassName` / `lineNumberStyle` decorations
                    for (d in decorations) {
                        if (d.range.startLineNumber <= ln && d.range.endLineNumber >= ln) {
                            final styles = v.resolver.combinedStyle(d.options.lineNumberClassName, d.options.lineNumberStyle);
                            if (styles != null) {
                                for (st in styles) {
                                    final c = v.resolver.resolveColor(st.color);
                                    if (c != null) {
                                        color = c;
                                    }
                                }
                            }
                        }
                    }
                    final shaped = textSystem.shapeLine(label, fontInfo.fontSize, [new glaze.TextRun(glaze.util.Utf8.byteLength(label), numberFont, color)]);
                    final labelWidth:Float = shaped.width();
                    final x:Float = originX + layoutInfo.lineNumbersLeft + layoutInfo.lineNumbersWidth - labelWidth;
                    shaped.paint(new Point(x, lineTop(ln)), lineHeight, TextAlign.Left, null, numberPainter);
                }
            }
            window.popContentMask();
        }

        // --- overview ruler (marks of decorations and cursors, under the kit scrollbar)
        final rulerWidth = layoutInfo.verticalScrollbarWidth;
        if (rulerWidth > 0 && options.get(EditorOption.overviewRulerLanes) > 0) {
            final rulerX = originX + bounds.size.width - rulerWidth;
            final rulerHeight = bounds.size.height;
            final scrollHeight = Math.max(1, viewLayout.getScrollHeight());
            final border = theme.getColor('editorOverviewRuler.border');
            if (border != null && options.get(EditorOption.overviewRulerBorder)) {
                fillRect(window, rulerX, originY, 1, rulerHeight, border);
            }
            final groups = viewModel.getAllOverviewRulerDecorations(theme.editorTheme);
            for (group in groups) {
                final color = theme.resolveDecorationColor(group.color);
                final data = group.data;
                var k = 0;
                while (k + 2 < data.length + 0) {
                    final lane = Std.int(data[k]);
                    final from = viewLayout.getVerticalOffsetForLineNumber(Std.int(data[k + 1])) / scrollHeight * rulerHeight;
                    final to = (viewLayout.getVerticalOffsetForLineNumber(Std.int(data[k + 2])) + lineHeight) / scrollHeight * rulerHeight;
                    final laneWidth = rulerWidth / 3;
                    final laneX = (lane & 1) != 0 ? 0 : ((lane & 2) != 0 ? laneWidth : laneWidth * 2);
                    final laneW = lane == 7 ? rulerWidth : laneWidth;
                    if (color != null) {
                        fillRect(window, rulerX + (lane == 7 ? 0 : laneX), originY + from, laneW, Math.max(2, to - from), color);
                    }
                    k += 3;
                }
            }
            if (!options.get(EditorOption.hideCursorInOverviewRuler)) {
                final cursorColor = theme.getColor('editorCursor.foreground');
                for (s in selections) {
                    final y = viewLayout.getVerticalOffsetForLineNumber(s.positionLineNumber) / scrollHeight * rulerHeight;
                    fillRect(window, rulerX, originY + y, rulerWidth, 2, cursorColor != null ? cursorColor.opacity(0.6) : null);
                }
            }
        }

        v.trimRenderCache(startLine, endLine);
    }

    /**
     * Monaco's folding codicons in the line decorations (folding.css): a
     * chevron right for a collapsed range (always shown), a chevron down for
     * an expanded one, shown when the mouse is over the gutter
     * (`showFoldingControls: 'mouseover'`) or always (`alwaysShowFoldIcons`,
     * `'always'`). Drawn with the chevrons of the kit's icons, colored by
     * `editorGutter.foldingControlForeground`.
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
            // `font-size: 140%; margin-left: 2px`, centered in the line
            // decorations (the kit's chevrons are drawn smaller in their
            // box than the codicons: the box is grown to match)
            final size = Math.min(lineHeight, Math.round(fontSize * 1.4 * 1.2));
            final centerX = originX + decorationsLeft + 2 + decorationsWidth / 2;
            final centerY = linesOriginY + v.viewModel.viewLayout.getVerticalOffsetForLineNumber(ln) + lineHeight / 2;
            final icon = collapsed ? glaze.kit.IconName.ChevronRight : glaze.kit.IconName.ChevronDown;
            final path = glaze.kit.Icon.resolveIconPath(icon.path(), cx);
            // The kit's icon (or the one the kit theme maps it to); its
            // embedded SVG when the app did not add the kit's icons to its
            // asset source (an app without the kit's `init`)
            final data = path == icon.path() ? embeddedIcon(icon) : null;
            try {
                window.paintSvg(new Bounds(new Point(centerX - size / 2, centerY - size / 2), new Size(size, size)), path, data, null, color, cx);
            }
            catch (e:Dynamic) {
                // no icon assets: nothing drawn
            }
        }
    }

    static var _embeddedIcons:Null<Map<String, haxe.io.Bytes>> = null;

    /**
     * The SVG of a kit icon, embedded in the code (immutable, shared).
     */
    static function embeddedIcon(icon:glaze.kit.IconName):Null<haxe.io.Bytes> {
        if (_embeddedIcons == null) {
            _embeddedIcons = new Map();
        }
        final key = icon.path();
        var data = _embeddedIcons.get(key);
        if (data == null) {
            final index = glaze.kit.IconName.ALL.indexOf(icon);
            if (index == -1) {
                return null;
            }
            data = haxe.io.Bytes.ofString(@:privateAccess glaze.kit.IconName.embeddedSvgs()[index]);
            _embeddedIcons.set(key, data);
        }
        return data;
    }

    /**
     * A decoration box (background, border, radius, vertical padding around
     * the font's content area when `line` is given).
     */
    static function paintBox(window:Window, box:ResolvedBox, x:Float, lineY:Float, width:Float, lineHeight:Float, line:Null<RenderedViewLine>, roundLeft:Bool, roundRight:Bool):Void {
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
        final radii = new Corners(roundLeft ? r : 0, roundRight ? r : 0, roundRight ? r : 0, roundLeft ? r : 0);
        if (box.background != null) {
            fillRect(window, x, y, width, h, box.background, radii);
        }
        if (box.borderColor != null && box.borderWidth > 0) {
            strokeRect(window, x, y, width, h, box.borderColor, box.borderWidth, radii);
        }
    }

}
