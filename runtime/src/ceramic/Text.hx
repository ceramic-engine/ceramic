package ceramic;

import ceramic.BitmapFont;
import ceramic.Shortcuts.*;

using StringTools;
using ceramic.Extensions;

/**
 * A visual to layout and display text.
 * Works with UTF-8 strings.
 */
class Text extends Visual {

    /**
     * Event fired when the glyph quads change.
     */
    @event function glyphQuadsChange();

    /**
     * Array of glyph quads used to render the text.
     * Each quad represents a single character glyph.
     */
    public var glyphQuads(default,null):Array<GlyphQuad> = [];

    /**
     * The number of lines in the rendered text.
     */
    public var numLines(get,null):Int = 1;
    function get_numLines():Int {
        if (contentDirty) computeContent();
        return this.numLines;
    }

    /**
     * The color of the text.
     * Default is white.
     */
    public var color(default, set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color == color) return color;
        this.color = color;

        // Ensure text glyphs have the requested color
        if (glyphQuads != null) {
            for (i in 0...glyphQuads.length) {
                var quad = glyphQuads.unsafeGet(i);
                quad.color = color;
            }
        }

        return color;
    }

    override function set_roundTranslation(roundTranslation:Int):Int {
        if (this.roundTranslation == roundTranslation) return roundTranslation;
        contentDirty = true;
        this.roundTranslation = roundTranslation;
        return roundTranslation;
    }

    /**
     * The text content to display.
     * Must not be null.
     */
    public var content(default, set):String = '';
    function set_content(content:String):String {
        Assert.assert(content != null, 'Text.content should not be null');
        if (this.content == content) return content;
        contentDirty = true;
        this.content = content;
        return content;
    }

    /**
     * The font size in points.
     * Default is 20.
     */
    public var pointSize(default, set):Float = 20;
    function set_pointSize(pointSize:Float):Float {
        if (this.pointSize == pointSize) return pointSize;
        contentDirty = true;
        this.pointSize = pointSize;
        return pointSize;
    }

    /**
     * The line height multiplier.
     * 1.0 means default line height, 2.0 means double line height, etc.
     * Default is 1.0.
     */
    public var lineHeight(default, set):Float = 1.0;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        contentDirty = true;
        this.lineHeight = lineHeight;
        return lineHeight;
    }

    /**
     * Additional spacing between letters in pixels.
     * Default is 0.0.
     */
    public var letterSpacing(default, set):Float = 0.0;
    function set_letterSpacing(letterSpacing:Float):Float {
        if (this.letterSpacing == letterSpacing) return letterSpacing;
        contentDirty = true;
        this.letterSpacing = letterSpacing;
        return letterSpacing;
    }

    /**
     * The bitmap font used to render the text.
     * If null, the default font will be used.
     */
    public var font(default, set):BitmapFont;
    function set_font(font:BitmapFont):BitmapFont {

        if (font == null) {
            font = app.defaultFont;
        }

        if (this.font == font) return font;

        // Unbind previous font destroy event
        if (this.font != null) {
            this.font.offDestroy(fontDestroyed);
            if (this.font.asset != null) this.font.asset.release();
        }

        contentDirty = true;
        this.font = font;

        if (this.font != null) {
            // Ensure we remove the font if it gets destroyed
            this.font.onDestroy(this, fontDestroyed);
            if (this.font.asset != null) this.font.asset.retain();
        }

        return font;
    }

    /**
     * X coordinate for text clipping.
     * Set to -1 to disable clipping on this axis.
     */
    public var clipTextX(default,set):Float = -1;
    function set_clipTextX(clipTextX:Float):Float {
        if (this.clipTextX == clipTextX) return clipTextX;
        this.clipTextX = clipTextX;
        contentDirty = true;
        return clipTextX;
    }

    /**
     * Y coordinate for text clipping.
     * Set to -1 to disable clipping on this axis.
     */
    public var clipTextY(default,set):Float = -1;
    function set_clipTextY(clipTextY:Float):Float {
        if (this.clipTextY == clipTextY) return clipTextY;
        this.clipTextY = clipTextY;
        contentDirty = true;
        return clipTextY;
    }

    /**
     * Width for text clipping.
     * Set to -1 to disable clipping on this axis.
     */
    public var clipTextWidth(default,set):Float = -1;
    function set_clipTextWidth(clipTextWidth:Float):Float {
        if (this.clipTextWidth == clipTextWidth) return clipTextWidth;
        this.clipTextWidth = clipTextWidth;
        contentDirty = true;
        return clipTextWidth;
    }

    /**
     * Height for text clipping.
     * Set to -1 to disable clipping on this axis.
     */
    public var clipTextHeight(default,set):Float = -1;
    function set_clipTextHeight(clipTextHeight:Float):Float {
        if (this.clipTextHeight == clipTextHeight) return clipTextHeight;
        this.clipTextHeight = clipTextHeight;
        contentDirty = true;
        return clipTextHeight;
    }

    /**
     * Set text clipping bounds.
     *
     * @param x The x coordinate of the clipping rectangle
     * @param y The y coordinate of the clipping rectangle
     * @param width The width of the clipping rectangle
     * @param height The height of the clipping rectangle
     */
    public function clipText(x:Float, y:Float, width:Float, height:Float):Void {
        clipTextX = x;
        clipTextY = y;
        clipTextWidth = width;
        clipTextHeight = height;
    }

    /**
     * Pre-rendered size for MSDF fonts.
     * Set to -1 to disable pre-rendering.
     * When set to a positive value, the font will be pre-rendered at this size, which
     * can be useful to improve performances and reduce draw calls in some situations.
     */
    public var preRenderedSize(default, set):Int = -1;
    function set_preRenderedSize(preRenderedSize:Int):Int {
        if (this.preRenderedSize == preRenderedSize) return preRenderedSize;
        contentDirty = true;
        if (this.preRenderedSize <= 0 && preRenderedSize > 0) {
            screen.onTexturesDensityChange(this, handleTexturesDensityChange);
        }
        if (this.preRenderedSize > 0 && preRenderedSize <= 0) {
            screen.offTexturesDensityChange(handleTexturesDensityChange);
        }
        this.preRenderedSize = preRenderedSize;
        return preRenderedSize;
    }

    function handleTexturesDensityChange(_, _):Void {
        contentDirty = true;
    }

    /**
     * Text alignment (LEFT, CENTER, or RIGHT).
     * Default is LEFT.
     */
    public var align(default, set):TextAlign = LEFT;
    function set_align(align:TextAlign):TextAlign {
        if (this.align == align) return align;
        contentDirty = true;
        this.align = align;
        return align;
    }

    /**
     * If set to `true`, text will be displayed with line breaks
     * as needed so that it fits in the requested width.
     */
    public var fitWidth(default, set):Float = -1;
    function set_fitWidth(fitWidth:Float):Float {
        if (this.fitWidth == fitWidth) return fitWidth;
        this.fitWidth = fitWidth;
        contentDirty = true;
        return fitWidth;
    }

    /**
     * Maximum difference in line widths when using fitWidth.
     * Set to -1 to disable line balancing.
     * When set, the text will try to balance line widths to be more uniform.
     */
    public var maxLineDiff(default, set):Float = -1;
    function set_maxLineDiff(maxLineDiff:Float):Float {
        if (this.maxLineDiff == maxLineDiff) return maxLineDiff;
        this.maxLineDiff = maxLineDiff;
        if (fitWidth != -1) contentDirty = true;
        return maxLineDiff;
    }

    /**
     * If provided, will be called for each glyph to display, giving the chance
     * to override the character code to display.
     * This can be used for example to display password-like fields, when used with `EditText` component:
     *
     * ```haxe
     * var text = new Text();
     * text.glyphCode = (_, _) -> '*'.code;
     * text.content = 'Som2 pas!wOrd';
     * ```
     */
    public var glyphCode:(charCode:Int, pos:Int)->Int = null;

/// Overrides

    override function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;

        // Ensure text glyphs have the requested depth
        if (glyphQuads != null) {
            for (i in 0...glyphQuads.length) {
                var quad = glyphQuads.unsafeGet(i);
                quad.depth = depth;
            }
        }

        return super.set_depth(depth);
    }

    override function get_width():Float {
        if (contentDirty) computeContent();
        return super.get_width();
    }

    /**
     * Scale the text width to match the target width.
     * Only adjusts scaleX to match the requested width.
     *
     * @param targetWidth The desired width
     */
    function scaleWidth(targetWidth:Float):Void {
        // Only adjust scaleX to match requested width
        if (_width == targetWidth) return;
        scaleX = targetWidth / _width;
        matrixDirty = true;
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }

    /**
     * Scale the text height to match the target height.
     * Only adjusts scaleY to match the requested height.
     *
     * @param targetHeight The desired height
     */
    function scaleHeight(targetHeight:Float):Void {
        // Only adjust scaleY to match requested height
        if (_height == targetHeight) return;
        scaleY = targetHeight / _height;
        matrixDirty = true;
    }

    override function set_blending(blending:Blending):Blending {
        if (this.blending == blending) return blending;
        this.blending = blending;
        if (glyphQuads != null) {
            for (i in 0...glyphQuads.length) {
                var quad = glyphQuads.unsafeGet(i);
                quad.blending = blending;
            }
        }
        return blending;
    }

/// Lifecycle

    override public function new() {

        super();

        // Default font
        font = app.defaultFont;

    }

    override function destroy() {

        super.destroy();

        if (glyphQuads != null) {
            for (i in 0...glyphQuads.length) {
                glyphQuads[i].destroy();
            }
            glyphQuads = null;
        }

    }

/// Display

    /**
     * Compute and layout the text content.
     * This method recalculates all glyph positions and updates the visual size.
     */
    override function computeContent() {

        if (font == null) {
            width = 0;
            height = 0;
            contentDirty = false;
            return;
        }

        numLines = computeGlyphQuads(fitWidth, maxLineDiff);

        contentDirty = false;
        matrixDirty = true;

        var scaledPreRenderedSize = Std.int(preRenderedSize * screen.texturesDensity);
        if (scaledPreRenderedSize > 0 && font.msdf && font.needsToPreRenderAtSize(scaledPreRenderedSize)) {
            font.preRenderAtSize(scaledPreRenderedSize, () -> {
                contentDirty = true;
            });
        }

        emitGlyphQuadsChange();

    }

    /**
     * Compute glyph quads for rendering.
     *
     * @param fitWidth The width to fit text into (-1 for no fitting)
     * @param maxLineDiff The maximum difference in line widths for balancing
     * @param fixedNumLines Fixed number of lines to use (-1 for automatic)
     * @return The number of lines in the laid out text
     */
    function computeGlyphQuads(fitWidth:Float, maxLineDiff:Float, fixedNumLines:Int = -1) {

        var x = 0.0;
        var y = 0.0;
        var xVisible = 0.0;
        var sizeFactor = pointSize / font.pointSize;
        var char = null;
        var code = -1;
        var prevChar = null;
        var prevCode = -1;
        var i = 0;
        var glyph:BitmapFontCharacter = null;
        var lineWidths:Array<Float> = [];
        var lineQuads:Array<Array<Quad>> = [[]];
        var usedQuads = 0;
        var isLineBreak = false;
        var isWhiteSpace = false;
        var justDidBreakToFit = false;
        var hasSpaceInLine = 0;
        var wasWhiteSpace = false;
        var numCharsBeforeLine = 0;
        var addTrailingSpace = false;

        var quadX:Float = 0;
        var quadY:Float = 0;
        var quadWidth:Float = 0;
        var quadHeight:Float = 0;

        var quadClip = 0;
        var hasClipping = false;
        if (clipTextX != -1 && clipTextY != -1 && clipTextWidth != -1 && clipTextHeight != -1) {
            hasClipping = true;
        }

        var scaledPreRenderedSize = Std.int(preRenderedSize * screen.texturesDensity);
        var usePrerenderedSize = scaledPreRenderedSize > 0 && font.msdf && !font.needsToPreRenderAtSize(scaledPreRenderedSize);

        var content = this.content;
        if (content == '' || (content.length > 0 && content.charAt(content.length - 1) == "\n")) {
            addTrailingSpace = true;
            content += ' ';
        }
        if (glyphCode != null) {
            var newContent = new StringBuf();
            for (i in 0...content.length) {
                final code = content.charCodeAt(i);
                newContent.addChar(glyphCode(code, i));
            }
            content = newContent.toString();
        }
        var len = content.length;

        while (i < len && usedQuads < len * 2) {

            prevChar = char;
            prevCode = code;

            char = content.charAt(i);
            code = char.charCodeAt(0);

            isLineBreak = (char == "\n");
            isWhiteSpace = (char == ' ');

            if (isWhiteSpace) hasSpaceInLine++;

            if (isLineBreak || isWhiteSpace || i == len - 1) {
                if (!justDidBreakToFit && fitWidth >= 0 && xVisible > 1 && xVisible > fitWidth - 1 && hasSpaceInLine > 0) {
                    justDidBreakToFit = true;
                    hasSpaceInLine--;

                    // Rewind last word because it doesn't fit
                    while (i > 0) {
                        i--;
                        char = content.charAt(i);
                        code = char.charCodeAt(0);
                        if (i > 0) {
                            prevChar = content.charAt(i - 1);
                            prevCode = prevChar.charCodeAt(0);
                        } else {
                            prevChar = null;
                            prevCode = -1;
                        }
                        glyph = font.chars.get(code);
                        if (prevChar != null) {
                            x -= font.kerning(prevCode, code) * sizeFactor;
                        }
                        if (glyph != null) {
                            x -= glyph.xAdvance * sizeFactor + letterSpacing;
                        }
                        if (lineQuads[lineQuads.length-1].length > 0) {
                            usedQuads--;
                            lineQuads[lineQuads.length-1].pop();
                        }
                        else {
                            break;
                        }
                        if (char == ' ') {
                            char = "\n";
                            glyph = font.chars.get("\n".code);
                            code = char.charCodeAt(0);
                            hasSpaceInLine--;
                            isLineBreak = true;
                            isWhiteSpace = false;
                            break;
                        }
                    }
                }
                else {
                    justDidBreakToFit = false;
                }
            }

            if (isLineBreak) {
                hasSpaceInLine = 0;
                prevChar = null;
                prevCode = -1;
                i++;
                numCharsBeforeLine = i;
                y += lineHeight * font.lineHeight * sizeFactor;
                lineWidths.push(x + (glyph != null ? (glyph.xOffset + glyph.width - glyph.xAdvance) * sizeFactor - letterSpacing : 0));
                lineQuads.push([]);
                x = 0;
                xVisible = 0;
                continue;
            }

            glyph = font.chars.get(code);
            if (glyph == null) {
                i++;
                continue;
            }

            if (prevChar != null) {
                x += font.kerning(prevCode, code) * sizeFactor;
            }

            // Compute quad position and size
            quadX = x + glyph.xOffset * sizeFactor;
            quadY = y + glyph.yOffset * sizeFactor;
            quadWidth = glyph.width * sizeFactor;
            quadHeight = glyph.height * sizeFactor;

            quadClip = 0;
            if (hasClipping) {
                if (quadX >= clipTextX + clipTextWidth) {
                    quadClip = 2;
                }
                else if (quadX + quadWidth < clipTextX) {
                    quadClip = 2;
                }
                else if (quadY >= clipTextY + clipTextHeight) {
                    quadClip = 2;
                }
                else if (quadY + quadHeight < clipTextY) {
                    quadClip = 2;
                }
                else if (clipTextX > quadX && clipTextX <= quadX + quadWidth) {
                    quadClip = 1;
                }
                else if (clipTextY > quadY && clipTextY <= quadY + quadHeight) {
                    quadClip = 1;
                }
                else if (clipTextX + clipTextWidth > quadX && clipTextX + clipTextWidth <= quadX + quadWidth) {
                    quadClip = 1;
                }
                else if (clipTextY + clipTextHeight > quadY && clipTextY + clipTextHeight <= quadY + quadHeight) {
                    quadClip = 1;
                }
            }

            // Reuse or create quad
            var quad:GlyphQuad = usedQuads < glyphQuads.length ? glyphQuads[usedQuads] : null;
            if (quad == null) {
                quad = new GlyphQuad();
                quad.inheritAlpha = true;
                glyphQuads.push(quad);
                add(quad);
            }
            usedQuads++;

            quad.char = char;
            quad.code = code;
            quad.index = i;
            quad.visible = quadClip != 2;
            quad.transparent = false;
            quad.posInLine = i - numCharsBeforeLine;
            quad.line = lineQuads.length - 1;
            quad.texture = usePrerenderedSize ? font.preRenderedPages.get(scaledPreRenderedSize).get(glyph.page) : font.pages.get(glyph.page);
            quad.roundTranslation = (roundTranslation >= 0 ? roundTranslation : quad.texture != null && quad.texture.filter == NEAREST ? 1 : 0);
            quad.shader = !usePrerenderedSize && font.pageShaders != null ? font.pageShaders.get(glyph.page) : null;
            quad.color = color;
            quad.depth = depth;
            quad.blending = blending;
            quad.glyphX = x;
            quad.glyphY = y;
            quad.glyphAdvance = glyph.xAdvance * sizeFactor + letterSpacing;
            quad.glyph = glyph;
            if (quadClip == 1) {
                var clippedQuadX = Math.max(clipTextX, quadX);
                var clippedQuadY = Math.max(clipTextY, quadY);
                var clippedQuadWidth = Math.min(clipTextX + clipTextWidth, quadX + quadWidth) - clippedQuadX;
                var clippedQuadHeight = Math.min(clipTextY + clipTextHeight, quadY + quadHeight) - clippedQuadY;

                var clippedFrameX:Float;
                var clippedFrameY:Float;
                var clippedFrameWidth:Float;
                var clippedFrameHeight:Float;
                if (usePrerenderedSize) {
                    var originalTexture = font.pages.get(glyph.page);
                    clippedFrameX = glyph.x * quad.texture.width / originalTexture.width;
                    clippedFrameY = glyph.y * quad.texture.height / originalTexture.height;
                    clippedFrameWidth = glyph.width * quad.texture.width / originalTexture.width;
                    clippedFrameHeight = glyph.height * quad.texture.height / originalTexture.height;
                }
                else {
                    clippedFrameX = glyph.x / quad.texture.density;
                    clippedFrameY = glyph.y / quad.texture.density;
                    clippedFrameWidth = glyph.width / quad.texture.density;
                    clippedFrameHeight = glyph.height / quad.texture.density;
                }

                var clippedFrameXOffset = (clippedQuadX - quadX) * clippedFrameWidth / quadWidth;
                clippedFrameX += clippedFrameXOffset;
                clippedFrameWidth -= clippedFrameXOffset + (quadX + quadWidth - clippedQuadX - clippedQuadWidth) * clippedFrameWidth / quadWidth;

                var clippedFrameYOffset = (clippedQuadY - quadY) * clippedFrameHeight / quadHeight;
                clippedFrameY += clippedFrameYOffset;
                clippedFrameHeight -= clippedFrameYOffset + (quadY + quadHeight - clippedQuadY - clippedQuadHeight) * clippedFrameHeight / quadHeight;

                quad.frame(
                    clippedFrameX,
                    clippedFrameY,
                    clippedFrameWidth,
                    clippedFrameHeight
                );
                quad.pos(clippedQuadX, clippedQuadY);
                quad.size(clippedQuadWidth, clippedQuadHeight);
            }
            else {
                if (usePrerenderedSize) {
                    var originalTexture = font.pages.get(glyph.page);
                    quad.frame(
                        glyph.x * quad.texture.width / originalTexture.width,
                        glyph.y * quad.texture.height / originalTexture.height,
                        glyph.width * quad.texture.width / originalTexture.width,
                        glyph.height * quad.texture.height / originalTexture.height
                    );
                }
                else {
                    quad.frame(
                        glyph.x / quad.texture.density,
                        glyph.y / quad.texture.density,
                        glyph.width / quad.texture.density,
                        glyph.height / quad.texture.density
                    );
                }
                quad.pos(quadX, quadY);
                quad.size(quadWidth, quadHeight);
            }
            quad.anchor(0, 0);
            lineQuads[lineQuads.length-1].push(quad);

            xVisible = x + Math.max(
                (glyph.xOffset + glyph.width) * sizeFactor,
                glyph.xAdvance * sizeFactor
            );

            x += glyph.xAdvance * sizeFactor + letterSpacing;

            i++;

        }

        if (x > 0) {
            lineWidths.push(x);
        }

        // If we added a trailing space, ensure it doesn't add any width
        if (addTrailingSpace && usedQuads > 0) {

            var lastQuad = glyphQuads[usedQuads-1];
            var lastLineWidth = lineWidths[lineWidths.length-1];

            lastLineWidth -= lastQuad.glyphAdvance;
            lineWidths[lineWidths.length-1] = lastLineWidth;

            lastQuad.glyphAdvance = 0;
            lastQuad.visible = false;
        }

        // Remove unused quads
        while (usedQuads < glyphQuads.length) {
            var quad = glyphQuads.pop();
            quad.destroy();
        }

        // Compute width/height from content
        var maxLineWidth = 0.0;
        for (i in 0...lineWidths.length) {
            var lineWidth = lineWidths.unsafeGet(i);
            maxLineWidth = Math.max(lineWidth, maxLineWidth);
        }
        this.width = Math.round(maxLineWidth * 1000) / 1000;
        this.height = Math.round(((lineWidths.length - 1) * lineHeight * font.lineHeight * sizeFactor + font.lineHeight * sizeFactor) * 1000) / 1000;

        // Align quads as requested
        switch (align) {
            case CENTER:
                for (i in 0...lineWidths.length) {
                    var diffX = (maxLineWidth - lineWidths.unsafeGet(i)) * 0.5;
                    var quads = lineQuads.unsafeGet(i);
                    for (j in 0...quads.length) {
                        var quad = quads.unsafeGet(j);
                        quad.x += diffX;
                    }
                }
            case RIGHT:
                for (i in 0...lineWidths.length) {
                    var diffX = maxLineWidth - lineWidths.unsafeGet(i);
                    var quads = lineQuads.unsafeGet(i);
                    for (j in 0...quads.length) {
                        var quad = quads.unsafeGet(j);
                        quad.x += diffX;
                    }
                }
            default:
        }

        if ((fixedNumLines == -1 || fixedNumLines == lineWidths.length) && fitWidth > 0 && maxLineDiff != -1 && fitWidth > pointSize) {
            // Check if lines have similar sizes
            var lineDiff = 0.0;
            var maxLineDiffValue = this.fitWidth * maxLineDiff;
            for (i in 0...lineWidths.length) {
                for (j in 0...lineWidths.length) {
                    var newDiff = lineWidths[i] - lineWidths[j];
                    if (newDiff < 0) newDiff = -newDiff;
                    if (newDiff > lineDiff) lineDiff = newDiff;
                    if (lineDiff > maxLineDiffValue) {
                        break;
                    }
                }
            }

            if (lineDiff > maxLineDiffValue) {
                var numLines = computeGlyphQuads(fitWidth - pointSize, maxLineDiff, lineWidths.length);
                if (numLines > lineWidths.length) {
                    // Restore previous state
                    computeGlyphQuads(fitWidth, -1, lineWidths.length);
                }
            }
        }

        return lineWidths.length;

    }

/// Helpers

    /**
     * Get the line number matching the given y position.
     *
     * @param y The y position relative to this Text visual
     * @return The line number (0-based)
     */
    public function lineForYPosition(y:Float):Int {

        if (contentDirty) computeContent();

        var computedLineHeight = lineHeight * font.lineHeight * pointSize / font.pointSize;
        var maxLine = 0;

        if (computedLineHeight <= 0) return 0;

        var glyphQuads = this.glyphQuads;
        if (glyphQuads.length > 0) {
            maxLine = glyphQuads[glyphQuads.length-1].line;
        }

        var line = Math.floor(y / computedLineHeight);
        if (line < 0) line = 0;
        if (line > maxLine) line = maxLine;

        return line;

    }

    /**
     * Get the character index position relative to a line at the requested x value.
     *
     * @param line The line number (0-based)
     * @param x The x position relative to this Text visual
     * @return The character position within the line
     */
    public function posInLineForX(line:Int, x:Float):Int {

        if (contentDirty) computeContent();

        var glyphQuads = this.glyphQuads;
        var pos:Int = 0;

        if (glyphQuads.length == 0 || x == 0) return pos;

        for (i in 0...glyphQuads.length) {
            var glyphQuad = glyphQuads.unsafeGet(i);
            if (glyphQuad.line == line) {
                if (glyphQuad.glyphX >= x) return pos;
                else if (glyphQuad.glyphX + glyphQuad.glyphAdvance >= x) {
                    var distanceAfter = glyphQuad.glyphX + glyphQuad.glyphAdvance - x;
                    var distanceBefore = x - glyphQuad.glyphX;
                    if (distanceBefore <= distanceAfter) {
                        return pos;
                    }
                }
                pos++;
            }
            else if (glyphQuad.line > line) {
                break;
            }
        }

        return pos;

    }

    /**
     * Get the global character index from the given line and position within that line.
     *
     * @param line The line number (0-based)
     * @param posInLine The position within the line
     * @return The global character index in the content string
     */
    public function indexForPosInLine(line:Int, posInLine:Int):Int {

        if (contentDirty) computeContent();

        var glyphQuads = this.glyphQuads;
        if (glyphQuads.length == 0) return 0;

        for (i in 0...glyphQuads.length) {
            var glyphQuad = glyphQuads.unsafeGet(i);
            if (glyphQuad.line == line && glyphQuad.posInLine >= posInLine) {
                return glyphQuad.index + posInLine - glyphQuad.posInLine;
            }
            else if (glyphQuad.line > line) {
                return glyphQuad.index - glyphQuad.posInLine - (glyphQuad.line - line);
            }
        }

        return content.length;

    }

    /**
     * Get an x position from the given character index.
     *
     * @param index The global character index in the content string
     * @return The x position relative to this Text visual
     */
    public function xPositionAtIndex(index:Int):Float {

        if (contentDirty) computeContent();

        var glyphQuads = this.glyphQuads;

        if (glyphQuads.length == 0) return 0;

        for (i in 0...glyphQuads.length) {
            var glyphQuad = glyphQuads.unsafeGet(i);
            if (glyphQuad.index >= index) {
                if (glyphQuad.glyphX == 0 && glyphQuad.index > index) {
                    if (i >= 1) {
                        var glyphQuadBefore = glyphQuads[i-1];
                        return glyphQuadBefore.glyphX + glyphQuadBefore.glyphAdvance;
                    }
                    else {
                        return 0;
                    }
                }
                else {
                    return glyphQuad.glyphX;
                }
            }
        }

        var lastGlyphQuad = glyphQuads[glyphQuads.length-1];
        return lastGlyphQuad.glyphX + lastGlyphQuad.glyphAdvance;

        return 0;

    }

    /**
     * Get the line number of the character at the given index.
     *
     * @param index The global character index in the content string
     * @return The line number (0-based)
     */
    public function lineForIndex(index:Int):Int {

        if (contentDirty) computeContent();

        var glyphQuads = this.glyphQuads;
        if (glyphQuads.length == 0) return 0;

        for (i in 0...glyphQuads.length) {
            var glyphQuad = glyphQuads.unsafeGet(i);
            if (glyphQuad.index >= index) {
                if (glyphQuad.posInLine > index - glyphQuad.index) {
                    var currentLineIndex = glyphQuad.index - glyphQuad.posInLine;
                    var line = glyphQuad.line;
                    while (currentLineIndex > index) {
                        currentLineIndex--;
                        line--;
                    }
                    return line;
                }
                else {
                    return glyphQuad.line;
                }
            }
        }

        return glyphQuads[glyphQuads.length-1].line;

    }

    /**
     * Get a character index position relative to its line from its global index position.
     *
     * @param index The global character index in the content string
     * @return The position within the line
     */
    public function posInLineForIndex(index:Int):Int {

        if (contentDirty) computeContent();

        var glyphQuads = this.glyphQuads;
        if (glyphQuads.length == 0) return 0;

        var computedTargetLine = false;
        var targetLine = -1;

        for (i in 0...glyphQuads.length) {
            var glyphQuad = glyphQuads.unsafeGet(i);
            if (glyphQuad.index >= index) {
                var pos = glyphQuad.posInLine + index - glyphQuad.index;
                if (pos < 0) {
                    var j = i - 1;
                    while (j >= 0) {
                        var glyphQuadBefore = glyphQuads.unsafeGet(j);
                        if (!computedTargetLine) {
                            computedTargetLine = true;
                            targetLine = lineForIndex(index);
                        }
                        if (glyphQuadBefore.line == targetLine) {
                            pos = glyphQuadBefore.posInLine + index - glyphQuadBefore.index;
                            return pos;
                        }
                        else if (glyphQuadBefore.line < targetLine) {
                            return 0;
                        }
                        j--;
                    }
                }
                return pos >= 0 ? pos : 0;
            }
        }

        return 0;

    }

/// Font destroyed

    /**
     * Internal callback when the font is destroyed.
     * Resets the font to the default font.
     */
    function fontDestroyed(_) {

        // Remove font (and set default one) because it has been destroyed
        this.font = app.defaultFont;

    }

/// Print

    override function toString():String {

        if (id != null) {
            return 'Text($id $content)';
        } else {
            return 'Text($content)';
        }

    }

}
