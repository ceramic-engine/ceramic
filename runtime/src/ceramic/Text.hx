package ceramic;

import ceramic.BitmapFont;
import ceramic.Assets;
import ceramic.Shortcuts.*;

#if (haxe_ver < 4)
using unifill.Unifill;
#end

using ceramic.Extensions;
using StringTools;

/** A visual to layout and display text.
    Works with UTF-8 strings. */
@editable({ implicitSize: true })
class Text extends Visual {
    
    @event function glyphQuadsChange();

    public var glyphQuads(default,null):Array<GlyphQuad> = [];

    public var numLines(get,null):Int = 1;
    function get_numLines():Int {
        if (contentDirty) computeContent();
        return this.numLines;
    }

    @editable
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

    @editable({ multiline: true })
    public var content(default, set):String = '';
    function set_content(content:String):String {
        Assert.assert(content != null, 'Text.content should not be null');
        if (this.content == content) return content;
        contentDirty = true;
        this.content = content;
        return content;
    }

    @editable
    public var pointSize(default, set):Float = 20;
    function set_pointSize(pointSize:Float):Float {
        if (this.pointSize == pointSize) return pointSize;
        contentDirty = true;
        this.pointSize = pointSize;
        return pointSize;
    }

    @editable
    public var lineHeight(default, set):Float = 1.0;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        contentDirty = true;
        this.lineHeight = lineHeight;
        return lineHeight;
    }

    @editable
    public var letterSpacing(default, set):Float = 0.0;
    function set_letterSpacing(letterSpacing:Float):Float {
        if (this.letterSpacing == letterSpacing) return letterSpacing;
        contentDirty = true;
        this.letterSpacing = letterSpacing;
        return letterSpacing;
    }

    @editable
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

    @editable
    public var align(default, set):TextAlign = LEFT;
    function set_align(align:TextAlign):TextAlign {
        if (this.align == align) return align;
        contentDirty = true;
        this.align = align;
        return align;
    }

    /** If set to `true`, text will be displayed with line breaks
        as needed so that it fits in the requested width. */
    @editable
    public var fitWidth(default, set):Float = -1;
    function set_fitWidth(fitWidth:Float):Float {
        if (this.fitWidth == fitWidth) return fitWidth;
        this.fitWidth = fitWidth;
        contentDirty = true;
        return fitWidth;
    }

    @editable
    public var maxLineDiff(default, set):Float = -1;
    function set_maxLineDiff(maxLineDiff:Float):Float {
        if (this.maxLineDiff == maxLineDiff) return maxLineDiff;
        this.maxLineDiff = maxLineDiff;
        if (fitWidth != -1) contentDirty = true;
        return maxLineDiff;
    }

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

    function scaleWidth(targetWidth:Float):Void {
        // Only adjust scaleX to match requested width
        if (_height == targetWidth) return;
        scaleX = targetWidth / _width;
        matrixDirty = true;
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }

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
        var hasSpaceInLine = false;
        var wasWhiteSpace = false;
        var numCharsBeforeLine = 0;
        var addTrailingSpace = false;

        var scaledPreRenderedSize = Std.int(preRenderedSize * screen.texturesDensity);
        var usePrerenderedSize = scaledPreRenderedSize > 0 && font.msdf && !font.needsToPreRenderAtSize(scaledPreRenderedSize);

        var content = this.content;
        if (content == '' || content.endsWith("\n")) {
            addTrailingSpace = true;
            content += ' ';
        }
        #if (haxe_ver >= 4)
        var len = content.length;
        #else
        var len = content.uLength();
        #end
        
        while (i < len) {

            prevChar = char;
            prevCode = code;
            
            #if (haxe_ver >= 4)
            char = content.charAt(i);   
            code = char.charCodeAt(0);
            #else
            char = content.uCharAt(i);
            code = char.uCharCodeAt(0);
            #end

            isLineBreak = (char == "\n");
            isWhiteSpace = (char == ' ');

            if (!hasSpaceInLine && isWhiteSpace) hasSpaceInLine = true;

            if (isLineBreak || isWhiteSpace || i == len - 1) {
                if (!justDidBreakToFit && fitWidth >= 0 && xVisible > 1 && xVisible > fitWidth - 1 && hasSpaceInLine) {
                    justDidBreakToFit = true;
                    // Rewind last word because it doesn't fit
                    while (i > 0) {
                        i--;
                        #if (haxe_ver >= 4)
                        char = content.charAt(i);
                        code = char.charCodeAt(0);
                        #else
                        char = content.uCharAt(i);
                        code = char.uCharCodeAt(0);
                        #end
                        if (i > 0) {
                            #if (haxe_ver >= 4)
                            prevChar = content.charAt(i - 1);
                            prevCode = prevChar.charCodeAt(0);
                            #else
                            prevChar = content.uCharAt(i - 1);
                            prevCode = prevChar.uCharCodeAt(0);
                            #end
                            glyph = font.chars.get(prevCode);
                        } else {
                            prevChar = null;
                            prevCode = -1;
                            glyph = null;
                        }
                        if (prevChar != null) {
                            x -= font.kerning(prevCode, code) * sizeFactor;
                        }
                        if (glyph != null) {
                            x -= glyph.xAdvance * sizeFactor + letterSpacing;
                            usedQuads--;
                            lineQuads[lineQuads.length-1].pop();
                        }
                        if (char == ' ') {
                            char = "\n";
                            #if (haxe_ver >= 4)
                            code = char.charCodeAt(0);
                            #else
                            code = char.uCharCodeAt(0);
                            #end
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
                hasSpaceInLine = false;
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
            quad.visible = true;
            quad.transparent = false;
            quad.posInLine = i - numCharsBeforeLine;
            quad.line = lineQuads.length - 1;
            quad.texture = usePrerenderedSize ? font.preRenderedPages.get(scaledPreRenderedSize).get(glyph.page) : font.pages.get(glyph.page);
            quad.shader = !usePrerenderedSize && font.pageShaders != null ? font.pageShaders.get(glyph.page) : null;
            quad.color = color;
            quad.depth = depth;
            quad.blending = blending;
            quad.glyphX = x;
            quad.glyphY = y;
            quad.glyphAdvance = glyph.xAdvance * sizeFactor + letterSpacing;
            quad.glyph = glyph;
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
            quad.anchor(0, 0);
            quad.pos(x + glyph.xOffset * sizeFactor, y + glyph.yOffset * sizeFactor);
            quad.size(glyph.width * sizeFactor, glyph.height * sizeFactor);

            xVisible = x + Math.max(
                (glyph.xOffset + glyph.width) * sizeFactor,
                glyph.xAdvance * sizeFactor
            );
            
            x += glyph.xAdvance * sizeFactor + letterSpacing;
            lineQuads[lineQuads.length-1].push(quad);

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
        this.width = maxLineWidth;
        this.height = (lineWidths.length - 1) * lineHeight * font.lineHeight * sizeFactor + font.lineHeight * sizeFactor;

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

    /** Get the line number matching the given `y` position.
        `y` is relative this `Text` visual. */
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

    /** Get the character index position relative to `line` at the requested `x` value.
        `x` is relative this `Text` visual. */
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

    /** Get the _global_ character index from the given `line` and `posInLine` index position relative to `line` */
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

        #if (haxe_ver >= 4)
        return content.length;
        #else
        return content.uLength();
        #end

    }

    /** Get an `x` position from the given character `index`.
        `x` is relative to this `Text` visual. */
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

    /** Get the line number (starting from zero) of the character at the given `index` */
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

    /** Get a character index position relative to its line from its _global_ `index` position. */
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
