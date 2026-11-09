// Ported from vscode src/vs/platform/markers/common/markers.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.markers.common;

import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Uri;

typedef IRelatedInformation = {
    var resource:Uri;
    var message:String;
    var startLineNumber:Int;
    var startColumn:Int;
    var endLineNumber:Int;
    var endColumn:Int;
}

enum abstract MarkerTag(Int) from Int to Int {
    var Unnecessary = 1;
    var Deprecated = 2;
}

enum abstract MarkerSeverity(Int) from Int to Int {
    var Hint = 1;
    var Info = 2;
    var Warning = 4;
    var Error = 8;
}

/**
 * Monaco's `MarkerSeverity` namespace. The display strings are Monaco's
 * English texts.
 */
class MarkerSeverityUtils {

    public static function compare(a:MarkerSeverity, b:MarkerSeverity):Int {
        return b - a;
    }

    public static function toString(a:MarkerSeverity):String {
        return switch (a) {
            case MarkerSeverity.Error: 'Error';
            case MarkerSeverity.Warning: 'Warning';
            case MarkerSeverity.Info: 'Info';
            case _: '';
        };
    }

}

/**
 * A structure defining a problem/warning/etc. `code` is a string or
 * `{value:String, target:Uri}`.
 */
typedef IMarkerData = {
    @:optional var code:Any;
    var severity:MarkerSeverity;
    var message:String;
    @:optional var source:String;
    var startLineNumber:Int;
    var startColumn:Int;
    var endLineNumber:Int;
    var endColumn:Int;
    @:optional var modelVersionId:Int;
    @:optional var relatedInformation:Array<IRelatedInformation>;
    @:optional var tags:Array<MarkerTag>;
}

typedef IResourceMarker = {
    var resource:Uri;
    var marker:IMarkerData;
}

/**
 * A marker. A class here (Monaco's interface): the marker decorations
 * compare markers by identity and update the start column of whole line
 * markers.
 */
class IMarker {
    public var owner:String;
    public var resource:Uri;
    public var severity:MarkerSeverity;
    public var code:Any;
    public var message:String;
    public var source:Null<String>;
    public var startLineNumber:Int;
    public var startColumn:Int;
    public var endLineNumber:Int;
    public var endColumn:Int;
    public var modelVersionId:Null<Int>;
    public var relatedInformation:Null<Array<IRelatedInformation>>;
    public var tags:Null<Array<MarkerTag>>;

    public function new(owner:String, resource:Uri) {
        this.owner = owner;
        this.resource = resource;
    }
}

typedef MarkerStatistics = {
    var errors:Int;
    var warnings:Int;
    var infos:Int;
    var unknowns:Int;
}

typedef IMarkerReadFilter = {
    @:optional var owner:String;
    @:optional var resource:Uri;
    @:optional var severities:Int;
    @:optional var take:Int;
}

interface IMarkerService {
    function getStatistics():MarkerStatistics;
    function changeOne(owner:String, resource:Uri, markers:Array<IMarkerData>):Void;
    function changeAll(owner:String, data:Array<IResourceMarker>):Void;
    function remove(owner:String, resources:Array<Uri>):Void;
    function read(?filter:IMarkerReadFilter):Array<IMarker>;
    var onMarkerChanged(get, never):Event<Array<Uri>>;
}

/**
 * Monaco's `IMarkerData` namespace.
 */
class IMarkerDataUtils {

    static inline final emptyString = '';

    public static function makeKey(markerData:IMarkerData):String {
        return makeKeyOptionalMessage(markerData, true);
    }

    static function escape(s:String):String {
        // String.replace with a string replaces the first occurrence only
        final i = s.indexOf('¦');
        return i < 0 ? s : s.substr(0, i) + '\\¦' + s.substr(i + 1);
    }

    public static function makeKeyOptionalMessage(markerData:IMarkerData, useMessage:Bool):String {
        final result:Array<String> = [emptyString];
        if (markerData.source != null && markerData.source.length > 0) {
            result.push(escape(markerData.source));
        }
        else {
            result.push(emptyString);
        }
        if (JsValues.truthy(markerData.code)) {
            if (JsValues.isString(markerData.code)) {
                result.push(escape(markerData.code));
            }
            else {
                result.push(escape(JsValues.field(markerData.code, 'value')));
            }
        }
        else {
            result.push(emptyString);
        }
        // null or undefined from dynamic data (an Int on static targets)
        final severity:Dynamic = markerData.severity;
        if (severity != null) {
            result.push(MarkerSeverityUtils.toString(markerData.severity));
        }
        else {
            result.push(emptyString);
        }

        // Modifed to not include the message as part of the marker key to work around
        // https://github.com/microsoft/vscode/issues/77475
        if (markerData.message != null && markerData.message.length > 0 && useMessage) {
            result.push(escape(markerData.message));
        }
        else {
            result.push(emptyString);
        }
        result.push(Std.string(markerData.startLineNumber));
        result.push(Std.string(markerData.startColumn));
        result.push(Std.string(markerData.endLineNumber));
        result.push(Std.string(markerData.endColumn));
        result.push(emptyString);
        return result.join('¦');
    }

}
