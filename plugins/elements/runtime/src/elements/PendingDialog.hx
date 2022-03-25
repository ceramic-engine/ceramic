package elements;

import tracker.Model;

class PendingDialog extends Model {

    public var chosenIndex:Int = -1;

    public var canceled:Bool = false;

    public var promptPointer:StringPointer;

    public var promptPlaceholder:String;

    public var key:String;

    public var title:String;

    public var message:String;

    public var choices:Array<String>;

    public var cancelable:Bool;

    public var width:Float;

    public var height:Float;

    public var async:Bool;

    public var callback:(index:Int, text:String)->Void;

    var _promptValue:String;

    public function new(?key:String, title:String, message:String, prompt:Bool = false, ?promptPointer:StringPointer, ?promptPlaceholder:String, choices:Array<String>, cancelable:Bool = false, width:Float = -1, height:Float = -1, async:Bool, callback:(index:Int, text:String)->Void) {

        super();

        this.key = key;
        this.title = title;
        this.message = message;
        if (prompt) {
            if (promptPointer == null) {
                _promptValue = '';
                promptPointer = Im.string(_promptValue);
            }
            this.promptPointer = promptPointer;
            this.promptPlaceholder = promptPlaceholder;
        }
        this.choices = choices;
        this.async = async;
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
