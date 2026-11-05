package notifications.linc;

/**
 * Native system notifications (see `linc_notifications.h`), used by
 * `backend.notifications.NotificationsNative` on macOS, Linux and Windows.
 */
@:keep
#if !display
@:build(notifications.linc.Linc.touch())
@:build(notifications.linc.Linc.xml())
#end
@:include('linc_notifications.h')
extern class LincNotifications {

    @:native('::linc::notifications::available')
    static function available():Bool;

    @:native('::linc::notifications::setAppIdentity')
    static function setAppIdentity(identifier:String, name:String):Void;

    @:native('::linc::notifications::start')
    static function start():Bool;

    @:native('::linc::notifications::readAuthorization')
    static function readAuthorization():Void;

    @:native('::linc::notifications::requestAuthorization')
    static function requestAuthorization():Void;

    @:native('::linc::notifications::show')
    static function show(tag:String, title:String, body:String, actionIds:Array<String>, actionLabels:Array<String>):Void;

    @:native('::linc::notifications::dismiss')
    static function dismiss(tag:String):Void;

    @:native('::linc::notifications::poll')
    static function poll():Void;

    @:native('::linc::notifications::nextEvent')
    static function nextEvent():Int;

    @:native('::linc::notifications::eventTag')
    static function eventTag():String;

    @:native('::linc::notifications::eventActionId')
    static function eventActionId():Null<String>;

    @:native('::linc::notifications::eventAuthorization')
    static function eventAuthorization():Int;

    /** The state of the native side (tests): never posts nor asks the user. */
    @:native('::linc::notifications::describe')
    static function describe():String;

    /** Builds the request `show` would post (registering its category) and describes it, without posting (tests). */
    @:native('::linc::notifications::describeRequest')
    static function describeRequest(tag:String, title:String, body:String, actionIds:Array<String>, actionLabels:Array<String>):String;

    /** The categories registered in the system, read back (tests; waits up to `timeoutMs`). */
    @:native('::linc::notifications::describeCategories')
    static function describeCategories(timeoutMs:Int):String;

    /** Reads the authorization synchronously (tests; -1 after `timeoutMs`). Never asks the user. */
    @:native('::linc::notifications::readAuthorizationNow')
    static function readAuthorizationNow(timeoutMs:Int):Int;

    /** Queues a response like the platform does, delivered by the next poll (tests; `actionId` null for the body). */
    @:native('::linc::notifications::simulateResponse')
    static function simulateResponse(tag:String, actionId:Null<String>):Void;

}
