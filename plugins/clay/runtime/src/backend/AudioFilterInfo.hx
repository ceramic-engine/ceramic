package backend;

@:structInit
class AudioFilterInfo {

    public final id:Int;

    public var paramsDirty:Bool = true;

    public var worklet:ceramic.AudioFilterWorklet = null;

    public var workletClass:Class<ceramic.AudioFilterWorklet>;

    public var filter:ceramic.AudioFilter;

}
