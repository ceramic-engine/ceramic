// Ported from vscode src/vs/platform/markers/common/markerService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.markers.common;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.platform.markers.common.Markers;

/**
 * Resources are keyed by their string form (Monaco's `ResourceMap`).
 */
private class DoubleResourceMap<V> {

    final _byResource = new Map<String, Map<String, V>>();
    final _byOwner = new Map<String, Map<String, V>>();
    /** insertion order of the owners, for `values()` */
    final _owners:Array<String> = [];

    public function new() {}

    public function set(resource:Uri, owner:String, value:V):Void {
        final key = resource.toString();
        var ownerMap = this._byResource.get(key);
        if (ownerMap == null) {
            ownerMap = new Map();
            this._byResource.set(key, ownerMap);
        }
        ownerMap.set(owner, value);

        var resourceMap = this._byOwner.get(owner);
        if (resourceMap == null) {
            resourceMap = new Map();
            this._byOwner.set(owner, resourceMap);
            this._owners.push(owner);
        }
        resourceMap.set(key, value);
    }

    public function get(resource:Uri, owner:String):Null<V> {
        final ownerMap = this._byResource.get(resource.toString());
        return ownerMap != null ? ownerMap.get(owner) : null;
    }

    public function delete(resource:Uri, owner:String):Bool {
        final key = resource.toString();
        var removedA = false;
        var removedB = false;
        final ownerMap = this._byResource.get(key);
        if (ownerMap != null) {
            removedA = ownerMap.remove(owner);
        }
        final resourceMap = this._byOwner.get(owner);
        if (resourceMap != null) {
            removedB = resourceMap.remove(key);
        }
        if (removedA != removedB) {
            throw 'illegal state';
        }
        return removedA && removedB;
    }

    public function valuesOfOwner(owner:String):Array<V> {
        final map = this._byOwner.get(owner);
        return map == null ? [] : [for (v in map) v];
    }

    public function valuesOfResource(resource:Uri):Array<V> {
        final map = this._byResource.get(resource.toString());
        return map == null ? [] : [for (v in map) v];
    }

    public function values():Array<V> {
        final result:Array<V> = [];
        for (owner in _owners) {
            final map = this._byOwner.get(owner);
            if (map != null) {
                for (v in map) {
                    result.push(v);
                }
            }
        }
        return result;
    }

}

/**
 * Monaco's marker service, one per `Cityscape` context.
 *
 * `onMarkerChanged` fires at once with the changed resources of each change
 * (Monaco delays the event to the next tick and merges the changes of a
 * tick).
 */
class MarkerService implements IMarkerService {

    final _onMarkerChanged = new Emitter<Array<Uri>>();
    public var onMarkerChanged(get, never):Event<Array<Uri>>;
    function get_onMarkerChanged():Event<Array<Uri>> {
        return _onMarkerChanged.event;
    }

    final _data = new DoubleResourceMap<Array<IMarker>>();

    public function new() {}

    public function dispose():Void {
        this._onMarkerChanged.dispose();
    }

    public function getStatistics():MarkerStatistics {
        final result:MarkerStatistics = {errors: 0, warnings: 0, infos: 0, unknowns: 0};
        for (markers in this._data.values()) {
            for (marker in markers) {
                // TODO this is a hack (Monaco skips the in-memory resources)
                if (marker.resource.scheme == 'inmemory') {
                    continue;
                }
                if (marker.severity == MarkerSeverity.Error) {
                    result.errors += 1;
                }
                else if (marker.severity == MarkerSeverity.Warning) {
                    result.warnings += 1;
                }
                else if (marker.severity == MarkerSeverity.Info) {
                    result.infos += 1;
                }
                else {
                    result.unknowns += 1;
                }
            }
        }
        return result;
    }

    public function remove(owner:String, resources:Array<Uri>):Void {
        if (resources == null) {
            return;
        }
        for (resource in resources) {
            this.changeOne(owner, resource, []);
        }
    }

    public function changeOne(owner:String, resource:Uri, markerData:Array<IMarkerData>):Void {

        if (markerData == null || markerData.length == 0) {
            // remove marker for this (owner,resource)-tuple
            final removed = this._data.delete(resource, owner);
            if (removed) {
                this._onMarkerChanged.fire([resource]);
            }

        }
        else {
            // insert marker for this (owner,resource)-tuple
            final markers:Array<IMarker> = [];
            for (data in markerData) {
                final marker = MarkerService._toMarker(owner, resource, data);
                if (marker != null) {
                    markers.push(marker);
                }
            }
            this._data.set(resource, owner, markers);
            this._onMarkerChanged.fire([resource]);
        }
    }

    static function _toMarker(owner:String, resource:Uri, data:IMarkerData):Null<IMarker> {
        if (data.message == null || data.message.length == 0) {
            return null;
        }

        // santize data
        var startLineNumber = data.startLineNumber;
        var startColumn = data.startColumn;
        var endLineNumber = data.endLineNumber;
        var endColumn = data.endColumn;
        startLineNumber = startLineNumber > 0 ? startLineNumber : 1;
        startColumn = startColumn > 0 ? startColumn : 1;
        endLineNumber = endLineNumber >= startLineNumber ? endLineNumber : startLineNumber;
        endColumn = endColumn > 0 ? endColumn : startColumn;

        final marker = new IMarker(owner, resource);
        marker.code = data.code;
        marker.severity = data.severity;
        marker.message = data.message;
        marker.source = data.source;
        marker.startLineNumber = startLineNumber;
        marker.startColumn = startColumn;
        marker.endLineNumber = endLineNumber;
        marker.endColumn = endColumn;
        marker.modelVersionId = data.modelVersionId;
        marker.relatedInformation = data.relatedInformation;
        marker.tags = data.tags;
        return marker;
    }

    public function changeAll(owner:String, data:Array<IResourceMarker>):Void {
        final changes:Array<Uri> = [];

        // remove old marker
        final existing = this._data.valuesOfOwner(owner);
        for (data in existing) {
            final first = data.length > 0 ? data[0] : null;
            if (first != null) {
                changes.push(first.resource);
                this._data.delete(first.resource, owner);
            }
        }

        // add new markers
        if (data != null && data.length > 0) {

            // group by resource
            final groups = new Map<String, Array<IMarker>>();
            final order:Array<Uri> = [];
            for (entry in data) {
                final resource = entry.resource;
                final marker = MarkerService._toMarker(owner, resource, entry.marker);
                if (marker == null) {
                    // filter bad markers
                    continue;
                }
                final key = resource.toString();
                final array = groups.get(key);
                if (array == null) {
                    groups.set(key, [marker]);
                    order.push(resource);
                    changes.push(resource);
                }
                else {
                    array.push(marker);
                }
            }

            // insert all
            for (resource in order) {
                this._data.set(resource, owner, groups.get(resource.toString()));
            }
        }

        if (changes.length > 0) {
            this._onMarkerChanged.fire(changes);
        }
    }

    public function read(?filter:IMarkerReadFilter):Array<IMarker> {
        if (filter == null) {
            filter = {};
        }

        final owner = filter.owner;
        final resource = filter.resource;
        final severities = filter.severities;
        var take = filter.take;

        if (take == null || take < 0) {
            take = -1;
        }

        if (owner != null && owner.length > 0 && resource != null) {
            // exactly one owner AND resource
            final data = this._data.get(resource, owner);
            if (data == null) {
                return [];
            }
            else {
                final result:Array<IMarker> = [];
                for (marker in data) {
                    if (MarkerService._accept(marker, severities)) {
                        result.push(marker);
                        if (take > 0 && result.length == take) {
                            break;
                        }
                    }
                }
                return result;
            }

        }
        else if ((owner == null || owner.length == 0) && resource == null) {
            // all
            final result:Array<IMarker> = [];
            for (markers in this._data.values()) {
                for (data in markers) {
                    if (MarkerService._accept(data, severities)) {
                        result.push(data);
                        if (take > 0 && result.length == take) {
                            return result;
                        }
                    }
                }
            }
            return result;

        }
        else {
            // of one resource OR owner
            final iterable = resource != null ? this._data.valuesOfResource(resource) : this._data.valuesOfOwner(owner);
            final result:Array<IMarker> = [];
            for (markers in iterable) {
                for (data in markers) {
                    if (MarkerService._accept(data, severities)) {
                        result.push(data);
                        if (take > 0 && result.length == take) {
                            return result;
                        }
                    }
                }
            }
            return result;
        }
    }

    static function _accept(marker:IMarker, severities:Null<Int>):Bool {
        return severities == null || (severities & marker.severity) == marker.severity;
    }

}
