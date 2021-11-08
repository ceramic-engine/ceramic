package elements;

import tracker.Model;

class PendingChoice extends Model {

    public var title:String;

    public var message:String;

    public var choices:Array<String>;

    public var cancelable:Bool;

    public var width:Float;

    public var height:Float;

    public var callback:(index:Int, text:String)->Void;

    public function new(title:String, message:String, choices:Array<String>, cancelable:Bool = false, width:Float = -1, height:Float = -1, callback:(index:Int, text:String)->Void) {

        super();

        this.title = title;
        this.message = message;
        this.choices = choices;
        this.callback = callback;
        this.cancelable = cancelable;
        this.width = width;
        this.height = height;

    }

    override function destroy() {

        this.title = null;
        this.message = null;
        this.choices = null;
        this.callback = null;

        super.destroy();

    }

}
