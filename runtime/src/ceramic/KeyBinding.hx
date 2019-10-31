package ceramic;

import ceramic.Shortcuts.*;

@:allow(ceramic.KeyBindings)
class KeyBinding extends Entity {

/// Events

    @event function trigger();

/// Internal properties

    var accelerator:ImmutableArray<KeyAcceleratorItem>;

    var pressedItems:Array<Int> = [];

    var matches:Bool = false;

/// Lifecycle

    private function new(accelerator:Array<KeyAcceleratorItem>) {

        super();
        
        this.accelerator = cast [].concat(accelerator);

        bindKeyboardEvents();

    } //new

/// Internal

    function bindKeyboardEvents():Void {
        
        for (i in 0...accelerator.length) {
            pressedItems.push(0);
            var item = accelerator.unsafeGet(i);

            switch (item) {

                case SHIFT:
                    bindScanCode(ScanCode.LSHIFT, i);
                    bindScanCode(ScanCode.RSHIFT, i);

                case CMD_OR_CTRL:
                    #if mac
                    bindScanCode(ScanCode.LMETA, i);
                    bindScanCode(ScanCode.RMETA, i);
                    #else
                    bindScanCode(ScanCode.LCTRL, i);
                    bindScanCode(ScanCode.RCTRL, i);
                    #end

                case SCAN(scanCode):
                    bindScanCode(scanCode, i);

                case KEY(keyCode):
                    bindKeyCode(keyCode, i);
            }
        }

    } //bindKeyboardEvents

    function bindScanCode(scanCode:Int, itemIndex:Int):Void {

        app.onKeyDown(this, function(key:Key) {

            if (key.scanCode == scanCode) {
                if (app.isKeyJustPressed(key)) {
                    pressedItems[itemIndex]++;

                    checkStatus();
                }
            }

        });

        app.onKeyUp(this, function(key:Key) {

            if (key.scanCode == scanCode) {
                pressedItems[itemIndex]--;

                checkStatus();
            }

        });

    } //bindScanCode

    function bindKeyCode(keyCode:Int, itemIndex:Int):Void {

        app.onKeyDown(this, function(key:Key) {

            if (key.keyCode == keyCode) {
                if (app.isKeyJustPressed(key)) {
                    pressedItems[itemIndex]++;

                    checkStatus();
                }
            }


        });

        app.onKeyUp(this, function(key:Key) {

            if (key.keyCode == keyCode) {
                pressedItems[itemIndex]--;

                checkStatus();
            }

        });

    } //bindKeyCode

    function checkStatus() {

        var canTrigger = !matches;
        var doesMatch = true;

        for (i in 0...pressedItems.length) {
            if (pressedItems[i] <= 0) {
                // One item or more is not pressed
                doesMatch = false;
                break;
            }
        }

        if (doesMatch) {
            matches = true;
            if (canTrigger) {
                // Trigger only if not matching before
                emitTrigger();
            }
        }
        else {
            matches = false;
        }

    } //checkStatus

} //KeyBinding
