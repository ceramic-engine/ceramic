package ceramic;

using StringTools;

/**
 * A view that displays text with automatic sizing and alignment options.
 * 
 * TextView wraps a Text visual and provides additional layout features:
 * - Automatic size computation based on text content
 * - Vertical and horizontal alignment within the view bounds
 * - Text wrapping with fitWidth support
 * - Padding support for text positioning
 * - Special centering option for single-line text
 * 
 * This is the preferred way to display text within UI layouts as it
 * properly integrates with the View sizing system.
 * 
 * ```haxe
 * var label = new TextView();
 * label.content = "Hello World";
 * label.font = myFont;
 * label.textColor = Color.WHITE;
 * label.align = CENTER;
 * label.verticalAlign = CENTER;
 * label.viewSize(200, 50); // Text centered in 200x50 area
 * ```
 * 
 * @see Text The underlying text visual
 * @see View The base view class
 */
class TextView extends View {

    /**
     * The underlying Text visual that renders the actual text.
     * This is automatically created and managed by the TextView.
     */
    public var text(default,null):Text;

    /**
     * Vertical alignment of the text within the view bounds.
     * - TOP: Align to top edge (plus padding)
     * - CENTER: Center vertically
     * - BOTTOM: Align to bottom edge (minus padding)
     * Default: TOP
     */
    public var verticalAlign(default,set):LayoutAlign = TOP;
    function set_verticalAlign(verticalAlign:LayoutAlign):LayoutAlign {
        if (this.verticalAlign == verticalAlign) return verticalAlign;
        this.verticalAlign = verticalAlign;
        layoutDirty = true;
        return verticalAlign;
    }

    /**
     * The bitmap font used to render the text.
     * Changing the font will trigger a layout update.
     */
    public var font(get,set):BitmapFont;
    inline function get_font():BitmapFont return text.font;
    function set_font(font:BitmapFont):BitmapFont {
        if (this.font == font) return font;
        text.font = font;
        layoutDirty = true;
        return font;
    }

    /**
     * Pre-rendered font size for performance optimization.
     * See Text.preRenderedSize for details.
     */
    public var preRenderedSize(get,set):Int;
    inline function get_preRenderedSize():Int return text.preRenderedSize;
    function set_preRenderedSize(preRenderedSize:Int):Int {
        if (this.preRenderedSize == preRenderedSize) return preRenderedSize;
        text.preRenderedSize = preRenderedSize;
        layoutDirty = true;
        return preRenderedSize;
    }

    /**
     * The color of the text.
     * This is a convenience property that maps to text.color.
     */
    public var textColor(get,set):Color;
    inline function get_textColor():Color return text.color;
    function set_textColor(textColor:Color):Color {
        if (this.textColor == textColor) return textColor;
        text.color = textColor;
        return textColor;
    }

    /**
     * The alpha transparency of the text (0.0 to 1.0).
     * This is a convenience property that maps to text.alpha.
     */
    public var textAlpha(get,set):Float;
    inline function get_textAlpha():Float return text.alpha;
    function set_textAlpha(textAlpha:Float):Float {
        if (this.textAlpha == textAlpha) return textAlpha;
        text.alpha = textAlpha;
        return textAlpha;
    }

    /**
     * The text content to display.
     * Supports multiline text with \n line breaks.
     * Setting this will trigger a layout update.
     */
    public var content(get,set):String;
    inline function get_content():String return text.content;
    function set_content(content:String):String {
        if (this.content == content) return content;
        text.content = content;
        layoutDirty = true;
        return content;
    }

    /**
     * The point size of the text.
     * This scales the font size relative to the font's native size.
     * Setting this will trigger a layout update.
     */
    public var pointSize(get,set):Float;
    inline function get_pointSize():Float return text.pointSize;
    function set_pointSize(pointSize:Float):Float {
        if (this.pointSize == pointSize) return pointSize;
        text.pointSize = pointSize;
        layoutDirty = true;
        return pointSize;
    }

    /**
     * Minimum height for the view.
     * The view will not be smaller than this height even if the text is shorter.
     * Default: 0
     */
    public var minHeight(default,set):Float = 0;
    function set_minHeight(minHeight:Float):Float {
        if (this.minHeight == minHeight) return minHeight;
        this.minHeight = minHeight;
        layoutDirty = true;
        return minHeight;
    }

    /**
     * Line height multiplier for text spacing.
     * Values > 1.0 increase space between lines.
     * Values < 1.0 decrease space between lines.
     */
    public var lineHeight(get,set):Float;
    inline function get_lineHeight():Float return text.lineHeight;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        text.lineHeight = lineHeight;
        layoutDirty = true;
        return lineHeight;
    }

    /**
     * Additional spacing between letters in pixels.
     * Positive values increase spacing, negative values decrease it.
     */
    public var letterSpacing(get,set):Float;
    inline function get_letterSpacing():Float return text.letterSpacing;
    function set_letterSpacing(letterSpacing:Float):Float {
        if (this.letterSpacing == letterSpacing) return letterSpacing;
        text.letterSpacing = letterSpacing;
        layoutDirty = true;
        return letterSpacing;
    }

    /**
     * Horizontal text alignment within the view.
     * - LEFT: Align text to the left
     * - CENTER: Center text horizontally
     * - RIGHT: Align text to the right
     */
    public var align(get,set):TextAlign;
    inline function get_align():TextAlign return text.align;
    function set_align(align:TextAlign):TextAlign {
        if (this.align == align) return align;
        text.align = align;
        layoutDirty = true;
        return align;
    }

    /**
     * If true, automatically centers the text horizontally when it's only one line.
     * This overrides the align property for single-line text.
     * Useful for buttons or labels that should center short text.
     * Default: false
     */
    public var centerIfOneLine(default,set):Bool = false;
    function set_centerIfOneLine(centerIfOneLine:Bool):Bool {
        if (this.centerIfOneLine == centerIfOneLine) return centerIfOneLine;
        this.centerIfOneLine = centerIfOneLine;
        layoutDirty = true;
        return centerIfOneLine;
    }

    /**
     * Maximum line width difference ratio for text wrapping.
     * Controls how evenly lines are distributed when wrapping.
     * See Text.maxLineDiff for details.
     */
    public var maxLineDiff(get,set):Float;
    inline function get_maxLineDiff():Float return text.maxLineDiff;
    function set_maxLineDiff(maxLineDiff:Float):Float {
        if (this.maxLineDiff == maxLineDiff) return maxLineDiff;
        text.maxLineDiff = maxLineDiff;
        layoutDirty = true;
        return maxLineDiff;
    }

    /**
     * If true, disables automatic text wrapping based on view width.
     * The text will render on a single line unless it contains explicit line breaks.
     * Default: false
     */
    public var noFitWidth(default,set):Bool = false;
    function set_noFitWidth(noFitWidth:Bool):Bool {
        if (this.noFitWidth == noFitWidth) return noFitWidth;
        this.noFitWidth = noFitWidth;
        layoutDirty = true;
        return noFitWidth;
    }

    /**
     * Create a new TextView.
     * Automatically creates the underlying Text visual with sensible defaults.
     */
    public function new() {

        super();

        text = new Text();
        text.maxLineDiff = 0.75;
        add(text);

        transparent = true;

    }

    /**
     * Compute the size of the view based on text content.
     * This method automatically sizes the view to fit the text,
     * respecting any explicit width/height constraints.
     */
    override function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool) {

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.info('$this.computeSize($parentWidth $parentHeight $layoutMask $persist) $paddingTop $paddingRight $paddingBottom $paddingLeft');
        ceramic.Shortcuts.log.pushIndent();
        #end

        super.computeSize(parentWidth, parentHeight, layoutMask, persist);

        var computedWidth = computedSize.computedWidth;
        var computedHeight = computedSize.computedHeight;

        var shouldComputeWidth = false;
        var shouldComputeHeight = false;

        var hasExplicitWidth = !ViewSize.isAuto(viewWidth);

        if (!hasExplicitWidth) {
            shouldComputeWidth = true;
        }

        if (ViewSize.isAuto(viewHeight)) {
            shouldComputeHeight = true;
        }

        if (shouldComputeHeight || shouldComputeWidth) {
            // Compute size from text
            if (!noFitWidth && computedWidth > 0) {
                if (hasExplicitWidth) {
                    text.fitWidth = computedWidth - paddingLeft - paddingRight;
                }
                else {
                    text.fitWidth = computedWidth;
                }
            }
            else {
                text.fitWidth = -1;
            }

            var textWidth = text.width;
            var textHeight = text.height;
            if (shouldComputeHeight) {
                computedHeight = textHeight;
            }
            if (shouldComputeWidth) {
                computedWidth = textWidth;
            }
        }
        else {
            // Still update fitWidth value in other cases
            if (!noFitWidth && hasExplicitWidth && computedWidth > 0) {
                text.fitWidth = computedWidth - paddingLeft - paddingRight;
            }
            else {
                text.fitWidth = -1;
            }
        }

        // Force fixed width if not flexible
        if (!layoutMask.canIncreaseWidth()) {
            if (computedWidth > parentWidth) {
                computedWidth = parentWidth;
            }
        }
        if (!layoutMask.canDecreaseWidth()) {
            if (computedWidth < parentWidth) {
                computedWidth = parentWidth;
            }
        }

        // Force fixed height if not flexible
        if (!layoutMask.canIncreaseHeight()) {
            if (computedHeight > parentHeight) {
                computedHeight = parentHeight;
            }
        }
        if (!layoutMask.canDecreaseHeight()) {
            if (computedHeight < parentHeight) {
                computedHeight = parentHeight;
            }
        }

        // Add padding
        if (shouldComputeWidth) {
            computedWidth += paddingLeft + paddingRight;
        }
        if (shouldComputeHeight) {
            computedHeight += paddingTop + paddingBottom;
        }

        // Minimum height
        if (computedHeight < minHeight) {
            computedHeight = minHeight;
        }

        // Round
        computedWidth = Math.round(computedWidth);
        computedHeight = Math.round(computedHeight);

        if (persist) {
            final computedSize = persistComputedSize(parentWidth, parentHeight, layoutMask, computedWidth, computedHeight);
            computedSize.computedFitWidth = text.fitWidth;
        }
        else {
            assignComputedSize(computedWidth, computedHeight);
        }

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.popIndent();
        ceramic.Shortcuts.log.info('/$this $computedWidth $computedHeight ${text.fitWidth}');
        #end

    }

    /**
     * Position the text within the view based on alignment settings.
     * Handles all combinations of vertical and horizontal alignment,
     * taking padding into account.
     */
    override function layout() {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, width);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, height);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, width);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, height);

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.debug('$this.layout() $width $height $paddingTop $paddingRight $paddingBottom $paddingLeft');
        ceramic.Shortcuts.log.pushIndent();
        #end

        // Match text fit width with persisted computed width, if any
        if (computedSize != null && computedSize.computedFitWidth != ComputedViewSize.NO_SIZE) {
            text.fitWidth = computedSize.computedFitWidth;
        }
        else {
            text.fitWidth = -1;
        }

        switch [verticalAlign, text.align] {
            case [TOP, LEFT]:
                text.anchor(0, 0);
                text.pos(
                    paddingLeft,
                    paddingTop
                );
            case [TOP, RIGHT]:
                text.anchor(1, 0);
                text.pos(
                    width - paddingRight,
                    paddingTop
                );
            case [TOP, CENTER]:
                text.anchor(0.5, 0);
                text.pos(
                    width * 0.5 + paddingLeft - paddingRight,
                    paddingTop
                );
            case [CENTER | LEFT | RIGHT, LEFT]:
                text.anchor(0, 0.5);
                text.pos(
                    paddingLeft,
                    height * 0.5 + paddingTop - paddingBottom
                );
            case [CENTER | LEFT | RIGHT, RIGHT]:
                text.anchor(1, 0.5);
                text.pos(
                    width - paddingRight,
                    height * 0.5 + paddingTop - paddingBottom
                );
            case [CENTER | LEFT | RIGHT, CENTER]:
                text.anchor(0.5, 0.5);
                text.pos(
                    width * 0.5 + paddingLeft - paddingRight,
                    height * 0.5 + paddingTop - paddingBottom
                );
            case [BOTTOM, LEFT]:
                text.anchor(0, 1);
                text.pos(
                    paddingLeft,
                    height - paddingBottom
                );
            case [BOTTOM, RIGHT]:
                text.anchor(1, 1);
                text.pos(
                    width - paddingRight,
                    height - paddingBottom
                );
            case [BOTTOM, CENTER]:
                text.anchor(0.5, 1);
                text.pos(
                    width * 0.5 + paddingLeft - paddingRight,
                    height - paddingBottom
                );
        }

        if (centerIfOneLine && text.numLines == 1) {
            text.anchorX = 0.5;
            text.x = width * 0.5 + paddingLeft - paddingRight;
        }

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.popIndent();
        #end

    }

}
