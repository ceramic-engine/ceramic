package ceramic;

@:structInit
class SpineMontageSettings<T> {

    /** The animation configs composing this montage */
    public var animations:Null<Dynamic<SpineMontageAnimation<T>>> = null;

    /** The default config used for every animation in this montage */
    public var defaults:Null<SpineMontageDefaults> = null;

    /** If provided, will create and configure a spine object with the given settings. */
    public var spine:Null<SpineMontageSpineSettings> = null;

    /** The starting animation to play */
    public var start:Null<T> = null;

}
