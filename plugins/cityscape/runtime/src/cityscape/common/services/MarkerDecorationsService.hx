// Ported from vscode src/vs/editor/common/services/markerDecorationsService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.Model;
import cityscape.common.core.EditorColorRegistry;
import cityscape.common.core.Range;
import cityscape.common.model.IntervalTree.ClassName;
import cityscape.platform.markers.common.Markers;
import cityscape.platform.theme.common.ThemeService;

/**
 * Renders the markers of the models as decorations (squiggles and overview
 * ruler marks), one per marker, for the models of the model service and the
 * models shown by an editor of the context (`ensureModel`: Monaco only
 * decorates the models of its model service).
 */
class MarkerDecorationsService extends Disposable {

    final _onDidChangeMarker:Emitter<ITextModel>;
    public final onDidChangeMarker:Event<ITextModel>;

    final _markerDecorations = new Map<String, MarkerDecorations>();
    final _markerService:IMarkerService;

    public function new(modelService:ModelService, markerService:IMarkerService) {
        super();
        this._onDidChangeMarker = this._register(new Emitter<ITextModel>());
        this.onDidChangeMarker = this._onDidChangeMarker.event;
        this._markerService = markerService;
        for (model in modelService.getModels()) {
            this._onModelAdded(model);
        }
        this._register(modelService.onModelAdded(m -> this._onModelAdded(m)));
        this._register(modelService.onModelRemoved(m -> this._onModelRemoved(m)));
        this._register(this._markerService.onMarkerChanged(r -> this._handleMarkerChange(r)));
    }

    override public function dispose():Void {
        super.dispose();
        for (value in this._markerDecorations) {
            value.dispose();
        }
        this._markerDecorations.clear();
    }

    /**
     * Decorates the markers of `model` (an editor shows it) until it is
     * disposed, when it is not a model of the model service.
     */
    public function ensureModel(model:ITextModel):Void {
        if (this._markerDecorations.exists(model.uri.toString()) || model.isDisposed()) {
            return;
        }
        this._onModelAdded(model);
        final markerDecorations = this._markerDecorations.get(model.uri.toString());
        markerDecorations.disposeListener = model.onWillDispose(() -> this._onModelRemoved(model));
    }

    public function getMarker(uri:Uri, decoration:IModelDecoration):Null<IMarker> {
        final markerDecorations = this._markerDecorations.get(uri.toString());
        return markerDecorations != null ? markerDecorations.getMarker(decoration) : null;
    }

    public function getLiveMarkers(uri:Uri):Array<{range:Range, marker:IMarker}> {
        final markerDecorations = this._markerDecorations.get(uri.toString());
        return markerDecorations != null ? markerDecorations.getMarkers() : [];
    }

    function _handleMarkerChange(changedResources:Array<Uri>):Void {
        for (resource in changedResources) {
            final markerDecorations = this._markerDecorations.get(resource.toString());
            if (markerDecorations != null) {
                this._updateDecorations(markerDecorations);
            }
        }
    }

    function _onModelAdded(model:ITextModel):Void {
        final markerDecorations = new MarkerDecorations(model);
        this._markerDecorations.set(model.uri.toString(), markerDecorations);
        this._updateDecorations(markerDecorations);
    }

    function _onModelRemoved(model:ITextModel):Void {
        final key = model.uri.toString();
        final markerDecorations = this._markerDecorations.get(key);
        if (markerDecorations != null && markerDecorations.model == model) {
            markerDecorations.dispose();
            this._markerDecorations.remove(key);
        }

        // clean up markers for internal, transient models
        if (model.uri.scheme == 'inmemory'
            || model.uri.scheme == 'internal'
            || model.uri.scheme == 'vscode') {
            if (this._markerService != null) {
                for (marker in this._markerService.read({resource: model.uri})) {
                    this._markerService.remove(marker.owner, [model.uri]);
                }
            }
        }
    }

    function _updateDecorations(markerDecorations:MarkerDecorations):Void {
        // Limit to the first 500 errors/warnings
        final markers = this._markerService.read({resource: markerDecorations.model.uri, take: 500});
        if (markerDecorations.update(markers)) {
            this._onDidChangeMarker.fire(markerDecorations.model);
        }
    }

}

class MarkerDecorations implements IDisposable {

    /** marker to decoration id, in insertion order (Monaco's `BidirectionalMap`) */
    final _markers:Array<IMarker> = [];
    final _ids:Array<String> = [];

    public final model:ITextModel;

    @:allow(cityscape.common.services.MarkerDecorationsService)
    var disposeListener:Null<IDisposable> = null;

    public function new(model:ITextModel) {
        this.model = model;
    }

    public function dispose():Void {
        if (disposeListener != null) {
            disposeListener.dispose();
            disposeListener = null;
        }
        if (!this.model.isDisposed()) {
            this.model.deltaDecorations(this._ids.copy(), []);
        }
        this._markers.resize(0);
        this._ids.resize(0);
    }

    public function update(markers:Array<IMarker>):Bool {

        // We use the fact that marker instances are not recreated when different owners
        // update. So we can compare references to find out what changed since the last update.
        final added:Array<IMarker> = [];
        final removed:Array<IMarker> = [];
        for (marker in markers) {
            if (this._markers.indexOf(marker) < 0 && added.indexOf(marker) < 0) {
                added.push(marker);
            }
        }
        for (marker in this._markers) {
            if (markers.indexOf(marker) < 0) {
                removed.push(marker);
            }
        }

        if (added.length == 0 && removed.length == 0) {
            return false;
        }

        final oldIds:Array<String> = [for (marker in removed) this._ids[this._markers.indexOf(marker)]];
        final newDecorations:Array<IModelDeltaDecoration> = [for (marker in added) {
            range: this._createDecorationRange(this.model, marker),
            options: this._createDecorationOption(marker)
        }];

        final ids = this.model.deltaDecorations(oldIds, newDecorations);
        for (removedMarker in removed) {
            final index = this._markers.indexOf(removedMarker);
            this._markers.splice(index, 1);
            this._ids.splice(index, 1);
        }
        for (index in 0...ids.length) {
            this._markers.push(added[index]);
            this._ids.push(ids[index]);
        }
        return true;
    }

    public function getMarker(decoration:IModelDecoration):Null<IMarker> {
        final index = this._ids.indexOf(decoration.id);
        return index >= 0 ? this._markers[index] : null;
    }

    public function getMarkers():Array<{range:Range, marker:IMarker}> {
        final res:Array<{range:Range, marker:IMarker}> = [];
        for (i in 0...this._ids.length) {
            final range = this.model.getDecorationRange(this._ids[i]);
            if (range != null) {
                res.push({range: range, marker: this._markers[i]});
            }
        }
        return res;
    }

    function _createDecorationRange(model:ITextModel, rawMarker:IMarker):Range {

        var ret = new Range(rawMarker.startLineNumber, rawMarker.startColumn, rawMarker.endLineNumber, rawMarker.endColumn);

        if (rawMarker.severity == MarkerSeverity.Hint && !this._hasMarkerTag(rawMarker, MarkerTag.Unnecessary) && !this._hasMarkerTag(rawMarker, MarkerTag.Deprecated)) {
            // * never render hints on multiple lines
            // * make enough space for three dots
            ret = ret.setEndPosition(ret.startLineNumber, ret.startColumn + 2);
        }

        ret = model.validateRange(ret);

        if (ret.isEmpty()) {
            var maxColumn = model.getLineLastNonWhitespaceColumn(ret.startLineNumber);
            if (maxColumn == 0) {
                maxColumn = model.getLineMaxColumn(ret.startLineNumber);
            }
            if (maxColumn == 1 || ret.endColumn >= maxColumn) {
                // empty line or behind eol
                // keep the range as is, it will be rendered 1ch wide
                return ret;
            }

            final word = model.getWordAtPosition(ret.getStartPosition());
            if (word != null) {
                ret = new Range(ret.startLineNumber, word.startColumn, ret.endLineNumber, word.endColumn);
            }
        }
        else if (rawMarker.endColumn == 2147483647 && rawMarker.startColumn == 1 && ret.startLineNumber == ret.endLineNumber) {
            // Monaco tests `Number.MAX_VALUE`: the largest Int here
            final minColumn = model.getLineFirstNonWhitespaceColumn(rawMarker.startLineNumber);
            if (minColumn < ret.endColumn) {
                ret = new Range(ret.startLineNumber, minColumn, ret.endLineNumber, ret.endColumn);
                rawMarker.startColumn = minColumn;
            }
        }
        return ret;
    }

    function _createDecorationOption(marker:IMarker):IModelDecorationOptions {

        var className:Null<String> = null;
        var color:Null<DecorationColor> = null;
        var zIndex:Int;
        var inlineClassName:Null<String> = null;
        var minimap:Null<IModelDecorationMinimapOptions> = null;

        switch (marker.severity) {
            case MarkerSeverity.Hint:
                if (this._hasMarkerTag(marker, MarkerTag.Deprecated)) {
                    className = null;
                }
                else if (this._hasMarkerTag(marker, MarkerTag.Unnecessary)) {
                    className = ClassName.EditorUnnecessaryDecoration;
                }
                else {
                    className = ClassName.EditorHintDecoration;
                }
                zIndex = 0;
            case MarkerSeverity.Info:
                className = ClassName.EditorInfoDecoration;
                color = ThemeService.themeColorFromId(EditorColorRegistry.overviewRulerInfo);
                zIndex = 10;
                minimap = {
                    color: ThemeService.themeColorFromId('minimap.infoHighlight'),
                    position: MinimapPosition.Inline
                };
            case MarkerSeverity.Warning:
                className = ClassName.EditorWarningDecoration;
                color = ThemeService.themeColorFromId(EditorColorRegistry.overviewRulerWarning);
                zIndex = 20;
                minimap = {
                    color: ThemeService.themeColorFromId('minimap.warningHighlight'),
                    position: MinimapPosition.Inline
                };
            case _:
                className = ClassName.EditorErrorDecoration;
                color = ThemeService.themeColorFromId(EditorColorRegistry.overviewRulerError);
                zIndex = 30;
                minimap = {
                    color: ThemeService.themeColorFromId('minimap.errorHighlight'),
                    position: MinimapPosition.Inline
                };
        }

        if (marker.tags != null) {
            if (marker.tags.indexOf(MarkerTag.Unnecessary) != -1) {
                inlineClassName = ClassName.EditorUnnecessaryInlineDecoration;
            }
            if (marker.tags.indexOf(MarkerTag.Deprecated) != -1) {
                inlineClassName = ClassName.EditorDeprecatedInlineDecoration;
            }
        }

        return {
            description: 'marker-decoration',
            stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
            className: className,
            showIfCollapsed: true,
            overviewRuler: {
                color: color,
                position: OverviewRulerLane.Right
            },
            minimap: minimap,
            zIndex: zIndex,
            inlineClassName: inlineClassName,
        };
    }

    function _hasMarkerTag(marker:IMarker, tag:MarkerTag):Bool {
        if (marker.tags != null) {
            return marker.tags.indexOf(tag) >= 0;
        }
        return false;
    }

}
