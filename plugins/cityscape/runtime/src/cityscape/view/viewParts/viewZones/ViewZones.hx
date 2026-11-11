// Ported from vscode src/vs/editor/browser/viewParts/viewZones/viewZones.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.viewParts.viewZones;

import cityscape.base.common.Errors;
import cityscape.common.ViewEventHandler;
import cityscape.common.ViewEvents;
import cityscape.common.ViewModel;
import cityscape.common.config.EditorConfiguration.IEditorConfiguration;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.view.EditorBrowser.IViewZone;
import cityscape.view.EditorBrowser.IViewZoneChangeAccessor;

/**
 * A zone added to the editor and its whitespace.
 */
class MyViewZone {
    public final whitespaceId:String;
    public final delegate:IViewZone;
    public var isInHiddenArea:Bool;
    public var isVisible:Bool;

    public function new(whitespaceId:String, delegate:IViewZone, isInHiddenArea:Bool) {
        this.whitespaceId = whitespaceId;
        this.delegate = delegate;
        this.isInHiddenArea = isInHiddenArea;
        this.isVisible = false;
    }
}

private typedef IComputedViewZoneProps = {
    var isInHiddenArea:Bool;
    var afterViewLineNumber:Int;
    var heightInPx:Float;
    var minWidthInPx:Float;
}

/**
 * The view zones of an editor (one per view model): Monaco's `ViewZones`
 * view part without its DOM. The zones are whitespaces of the lines layout;
 * they are painted by `CityscapeViewElement` with their `paint` and
 * `paintMargin` callbacks.
 */
class ViewZones extends ViewEventHandler {

    final _viewModel:IViewModel;
    final _configuration:IEditorConfiguration;
    final _zones:Map<String, MyViewZone> = new Map();
    /**
     * The zones in the order they were added (Monaco iterates the keys of
     * an object, in insertion order).
     */
    final _zoneOrder:Array<String> = [];
    var _lineHeight:Float;

    public function new(viewModel:IViewModel, configuration:IEditorConfiguration) {
        super();
        this._viewModel = viewModel;
        this._configuration = configuration;
        this._lineHeight = configuration.options.get(EditorOption.lineHeight);
    }

    override public function dispose():Void {
        super.dispose();
        this._zones.clear();
        this._zoneOrder.resize(0);
    }

    // ---- begin view event handlers

    function _recomputeWhitespacesProps():Bool {
        final whitespaces = this._viewModel.viewLayout.getWhitespaces();
        final oldWhitespaces = new Map<String, IEditorWhitespace>();
        for (whitespace in whitespaces) {
            oldWhitespaces.set(whitespace.id, whitespace);
        }
        var hadAChange = false;
        this._viewModel.changeWhitespace((whitespaceAccessor:IWhitespaceChangeAccessor) -> {
            for (id in this._zoneOrder.copy()) {
                final zone = this._zones.get(id);
                if (zone == null) {
                    continue;
                }
                final props = this._computeWhitespaceProps(zone.delegate);
                zone.isInHiddenArea = props.isInHiddenArea;
                final oldWhitespace = oldWhitespaces.get(id);
                if (oldWhitespace != null && (oldWhitespace.afterLineNumber != props.afterViewLineNumber || oldWhitespace.height != props.heightInPx)) {
                    whitespaceAccessor.changeOneWhitespace(id, props.afterViewLineNumber, props.heightInPx);
                    this._safeCallOnComputedHeight(zone.delegate, props.heightInPx);
                    hadAChange = true;
                }
            }
        });
        return hadAChange;
    }

    override public function onConfigurationChanged(e:ViewConfigurationChangedEvent):Bool {
        this._lineHeight = this._configuration.options.get(EditorOption.lineHeight);
        if (e.hasChanged(EditorOption.lineHeight)) {
            this._recomputeWhitespacesProps();
        }
        return true;
    }

    override public function onLineMappingChanged(e:ViewLineMappingChangedEvent):Bool {
        return this._recomputeWhitespacesProps();
    }

    override public function onLinesDeleted(e:ViewLinesDeletedEvent):Bool {
        return true;
    }

    override public function onScrollChanged(e:ViewScrollChangedEvent):Bool {
        return e.scrollTopChanged || e.scrollWidthChanged;
    }

    override public function onZonesChanged(e:ViewZonesChangedEvent):Bool {
        return true;
    }

    override public function onLinesInserted(e:ViewLinesInsertedEvent):Bool {
        return true;
    }

    // ---- end view event handlers

    function _getZoneOrdinal(zone:IViewZone):Int {
        if (zone.ordinal != null) {
            return zone.ordinal;
        }
        if (zone.afterColumn != null) {
            return zone.afterColumn;
        }
        return 10000;
    }

    function _computeWhitespaceProps(zone:IViewZone):IComputedViewZoneProps {
        if (zone.afterLineNumber == 0) {
            return {
                isInHiddenArea: false,
                afterViewLineNumber: 0,
                heightInPx: this._heightInPixels(zone),
                minWidthInPx: this._minWidthInPixels(zone)
            };
        }

        final model = this._viewModel.model;
        var zoneAfterModelPosition:Position;
        if (zone.afterColumn != null) {
            zoneAfterModelPosition = model.validatePosition({
                lineNumber: zone.afterLineNumber,
                column: zone.afterColumn
            });
        }
        else {
            final validAfterLineNumber = model.validatePosition({
                lineNumber: zone.afterLineNumber,
                column: 1
            }).lineNumber;

            zoneAfterModelPosition = new Position(
                validAfterLineNumber,
                model.getLineMaxColumn(validAfterLineNumber)
            );
        }

        var zoneBeforeModelPosition:Position;
        if (zoneAfterModelPosition.column == model.getLineMaxColumn(zoneAfterModelPosition.lineNumber)) {
            zoneBeforeModelPosition = model.validatePosition({
                lineNumber: zoneAfterModelPosition.lineNumber + 1,
                column: 1
            });
        }
        else {
            zoneBeforeModelPosition = model.validatePosition({
                lineNumber: zoneAfterModelPosition.lineNumber,
                column: zoneAfterModelPosition.column + 1
            });
        }

        final viewPosition = this._viewModel.coordinatesConverter.convertModelPositionToViewPosition(zoneAfterModelPosition, zone.afterColumnAffinity, true);
        final isVisible = zone.showInHiddenAreas == true || this._viewModel.coordinatesConverter.modelPositionIsVisible(zoneBeforeModelPosition);
        return {
            isInHiddenArea: !isVisible,
            afterViewLineNumber: viewPosition.lineNumber,
            heightInPx: (isVisible ? this._heightInPixels(zone) : 0),
            minWidthInPx: this._minWidthInPixels(zone)
        };
    }

    /**
     * Runs `callback` with an accessor adding, removing and laying out
     * zones; returns whether the zones changed.
     */
    public function changeViewZones(callback:(changeAccessor:IViewZoneChangeAccessor) -> Void):Bool {
        var zonesHaveChanged = false;

        this._viewModel.changeWhitespace((whitespaceAccessor:IWhitespaceChangeAccessor) -> {
            final changeAccessor = new ViewZoneChangeAccessor(this, whitespaceAccessor);
            try {
                callback(changeAccessor);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }
            zonesHaveChanged = changeAccessor.zonesHaveChanged;
            // Invalidate changeAccessor
            changeAccessor.invalidate();
        });

        return zonesHaveChanged;
    }

    @:allow(cityscape.view.viewParts.viewZones.ViewZoneChangeAccessor)
    function _addZone(whitespaceAccessor:IWhitespaceChangeAccessor, zone:IViewZone):String {
        final props = this._computeWhitespaceProps(zone);
        final whitespaceId = whitespaceAccessor.insertWhitespace(props.afterViewLineNumber, this._getZoneOrdinal(zone), props.heightInPx, props.minWidthInPx);

        final myZone = new MyViewZone(whitespaceId, zone, props.isInHiddenArea);

        this._safeCallOnComputedHeight(myZone.delegate, props.heightInPx);

        this._zones.set(myZone.whitespaceId, myZone);
        this._zoneOrder.push(myZone.whitespaceId);
        this._addMouseReach(zone);

        this.setShouldRender();

        return myZone.whitespaceId;
    }

    /**
     * The largest `mouseReachAbove` and `mouseReachBelow` of the zones
     * (Cityscape): how far from a zone the mouse target can still be the
     * zone (`CityscapeView.hitTestViewZoneReach`).
     */
    public var maxMouseReachAbove(default, null):Float = 0;
    public var maxMouseReachBelow(default, null):Float = 0;

    function _addMouseReach(zone:IViewZone):Void {
        final above = zone.mouseReachAbove;
        if (above != null && above > this.maxMouseReachAbove) {
            this.maxMouseReachAbove = above;
        }
        final below = zone.mouseReachBelow;
        if (below != null && below > this.maxMouseReachBelow) {
            this.maxMouseReachBelow = below;
        }
    }

    function _recomputeMouseReach():Void {
        this.maxMouseReachAbove = 0;
        this.maxMouseReachBelow = 0;
        for (zone in this._zones) {
            this._addMouseReach(zone.delegate);
        }
    }

    @:allow(cityscape.view.viewParts.viewZones.ViewZoneChangeAccessor)
    function _removeZone(whitespaceAccessor:IWhitespaceChangeAccessor, id:String):Bool {
        final zone = this._zones.get(id);
        if (zone != null) {
            this._zones.remove(id);
            this._zoneOrder.remove(id);
            whitespaceAccessor.removeWhitespace(zone.whitespaceId);
            if (zone.delegate.mouseReachAbove != null || zone.delegate.mouseReachBelow != null) {
                this._recomputeMouseReach();
            }
            this.setShouldRender();
            return true;
        }

        return false;
    }

    @:allow(cityscape.view.viewParts.viewZones.ViewZoneChangeAccessor)
    function _layoutZone(whitespaceAccessor:IWhitespaceChangeAccessor, id:String):Bool {
        final zone = this._zones.get(id);
        if (zone != null) {
            final props = this._computeWhitespaceProps(zone.delegate);
            zone.isInHiddenArea = props.isInHiddenArea;
            // const newOrdinal = this._getZoneOrdinal(zone.delegate);
            whitespaceAccessor.changeOneWhitespace(zone.whitespaceId, props.afterViewLineNumber, props.heightInPx);
            // TODO@Alex: change `newOrdinal` too

            this._safeCallOnComputedHeight(zone.delegate, props.heightInPx);
            this.setShouldRender();
            return true;
        }
        return false;
    }

    public function shouldSuppressMouseDownOnViewZone(id:String):Bool {
        final zone = this._zones.get(id);
        if (zone != null) {
            return zone.delegate.suppressMouseDown == true;
        }
        return false;
    }

    /**
     * The zone of a whitespace id (null when the id is not a zone's).
     */
    public function getZone(id:String):Null<MyViewZone> {
        return this._zones.get(id);
    }

    function _heightInPixels(zone:IViewZone):Float {
        if (zone.heightInPx != null) {
            return zone.heightInPx;
        }
        if (zone.heightInLines != null) {
            return this._lineHeight * zone.heightInLines;
        }
        return this._lineHeight;
    }

    function _minWidthInPixels(zone:IViewZone):Float {
        if (zone.minWidthInPx != null) {
            return zone.minWidthInPx;
        }
        return 0;
    }

    function _safeCallOnComputedHeight(zone:IViewZone, height:Float):Void {
        final f = zone.onComputedHeight;
        if (f != null) {
            try {
                f(height);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }
        }
    }

    /**
     * Paints the visible zones (their `paint`, or `paintMargin` when
     * `margin` is true) in the area from `left` to `left + width`, each one
     * clipped to its bounds. `linesTop` is the y of the top of the lines in
     * the window (scroll position included).
     */
    public function paintZones(window:glaze.Window, cx:glaze.App, visibleWhitespaces:Array<IViewWhitespaceViewportData>, left:Float, width:Float, linesTop:Float, margin:Bool):Void {
        if (width <= 0) {
            return;
        }
        for (w in visibleWhitespaces) {
            final zone = this._zones.get(w.id);
            if (zone == null || w.height <= 0) {
                continue;
            }
            final painter = margin ? zone.delegate.paintMargin : zone.delegate.paint;
            if (painter == null) {
                continue;
            }
            final bounds = new glaze.Bounds(new glaze.Point(left, linesTop + w.verticalOffset), new glaze.Size(width, w.height));
            window.pushContentMask(new glaze.ContentMask(bounds));
            try {
                painter(window, cx, bounds);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }
            window.popContentMask();
        }
    }

    /**
     * Calls `onDomNodeTop` of the visible zones (Monaco's `render`):
     * `top` is relative to the top of the editor, scrolling included.
     */
    public function notifyTops(visibleWhitespaces:Array<IViewWhitespaceViewportData>, scrollTop:Float):Void {
        for (w in visibleWhitespaces) {
            final zone = this._zones.get(w.id);
            if (zone == null) {
                continue;
            }
            final f = zone.delegate.onDomNodeTop;
            if (f != null) {
                try {
                    f(w.verticalOffset - scrollTop);
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                }
            }
        }
    }

}

/**
 * Monaco's change accessor object literal (invalidated after the callback).
 */
private class ViewZoneChangeAccessor implements IViewZoneChangeAccessor {

    final owner:ViewZones;
    final whitespaceAccessor:IWhitespaceChangeAccessor;
    var valid:Bool = true;
    public var zonesHaveChanged(default, null):Bool = false;

    public function new(owner:ViewZones, whitespaceAccessor:IWhitespaceChangeAccessor) {
        this.owner = owner;
        this.whitespaceAccessor = whitespaceAccessor;
    }

    public function invalidate():Void {
        valid = false;
    }

    function check():Void {
        if (!valid) {
            throw 'Invalid change accessor';
        }
    }

    public function addZone(zone:IViewZone):String {
        check();
        zonesHaveChanged = true;
        return @:privateAccess owner._addZone(whitespaceAccessor, zone);
    }

    public function removeZone(id:String):Void {
        check();
        if (id == null || id.length == 0) {
            return;
        }
        zonesHaveChanged = @:privateAccess owner._removeZone(whitespaceAccessor, id) || zonesHaveChanged;
    }

    public function layoutZone(id:String):Void {
        check();
        if (id == null || id.length == 0) {
            return;
        }
        zonesHaveChanged = @:privateAccess owner._layoutZone(whitespaceAccessor, id) || zonesHaveChanged;
    }

}
