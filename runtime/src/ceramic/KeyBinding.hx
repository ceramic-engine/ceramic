package ceramic;

import ceramic.Shortcuts.*;

@:allow(ceramic.KeyBindings)
class KeyBinding extends Entity {

/// Events

    @event function trigger();

/// Internal properties

    var accelerator:ReadOnlyArray<KeyAcceleratorItem>;

    var pressedItems:Array<Int> = [];

    var matches:Bool = false;

    var leftShiftPressed:Bool = false;
    
    var rightShiftPressed:Bool = false;

    var disableIfShiftPressed:Bool = false;

    #if web
    var cmdPressed:Int = 0;
    #end

/// Lifecycle

    private function new(accelerator:Array<KeyAcceleratorItem>) {

        super();
        
        this.accelerator = cast [].concat(accelerator);

        bindKeyboardEvents();

    }

/// Helpers

    @:noCompletion public function forceKeysUp():Void {

        leftShiftPressed = false;
        rightShiftPressed = false;
        for (i in 0...pressedItems.length) {
            pressedItems[i] = 0;
        }

        checkStatus();

    }

/// Internal

    function bindKeyboardEvents():Void {

        var hasShift = false;
        
        for (i in 0...accelerator.length) {
            pressedItems.push(0);
            var item = accelerator.unsafeGet(i);

            switch (item) {

                case SHIFT:
                    hasShift = true;
                    bindScanCode(ScanCode.LSHIFT, i);
                    bindScanCode(ScanCode.RSHIFT, i);

                case CMD_OR_CTRL:
                    disableIfShiftPressed = true;
                    bindScanCode(ScanCode.LMETA, i);
                    bindScanCode(ScanCode.RMETA, i);
                    bindScanCode(ScanCode.LCTRL, i);
                    bindScanCode(ScanCode.RCTRL, i);

                case SCAN(scanCode):
                    bindScanCode(scanCode, i);

                case KEY(keyCode):
                    bindKeyCode(keyCode, i);
            }
        }

        if (hasShift)
            disableIfShiftPressed = false;

        if (disableIfShiftPressed) {
            bindShift();
        }

    }

    function bindScanCode(scanCode:Int, itemIndex:Int):Void {

        app.onKeyDown(this, function(key:Key) {

            #if web
            if (scanCode == ScanCode.LMETA || scanCode == ScanCode.RMETA) {
                cmdPressed++;
            }
            #end

            if (key.scanCode == scanCode) {
                if (app.keyJustPressed(key) #if web || pressedItems[itemIndex] == 0 #end) {
                    pressedItems[itemIndex]++;

                    checkStatus();

                    #if web
                    if (cmdPressed > 0 && scanCode != ScanCode.LMETA && scanCode != ScanCode.RMETA && scanCode != ScanCode.LSHIFT && scanCode != ScanCode.RSHIFT) {
                        app.onceUpdate(this, _ -> {
                            if (pressedItems[itemIndex] > 0)
                                pressedItems[itemIndex]--;
                            
                            checkStatus();
                        });
                    }
                    #end
                }
            }

        });

        app.onKeyUp(this, function(key:Key) {

            #if web
            if (scanCode == ScanCode.LMETA || scanCode == ScanCode.RMETA) {
                cmdPressed--;

                if (cmdPressed == 0) {
                    for (i in 0...pressedItems.length) {
                        pressedItems[itemIndex] = 0;
                    }

                    checkStatus();
                    return;
                }
            }
            #end

            if (key.scanCode == scanCode) {
                if (pressedItems[itemIndex] > 0)
                    pressedItems[itemIndex]--;

                checkStatus();
            }

        });

    }

    function bindKeyCode(keyCode:Int, itemIndex:Int):Void {

        app.onKeyDown(this, function(key:Key) {

            if (key.keyCode == keyCode) {
                if (app.keyJustPressed(key) #if web || pressedItems[itemIndex] == 0 #end) {
                    pressedItems[itemIndex]++;

                    checkStatus();

                    #if web
                    if (cmdPressed > 0 && keyCode != KeyCode.LMETA && keyCode != KeyCode.RMETA && keyCode != KeyCode.LSHIFT && keyCode != KeyCode.RSHIFT) {
                        app.onceUpdate(this, _ -> {
                            if (pressedItems[itemIndex] > 0)
                                pressedItems[itemIndex]--;
                            
                            checkStatus();
                        });
                    }
                    #end
                }
            }

        });

        app.onKeyUp(this, function(key:Key) {

            if (key.keyCode == keyCode) {
                if (pressedItems[itemIndex] > 0)
                    pressedItems[itemIndex]--;

                checkStatus();
            }

        });

    }

    function bindShift() {

        app.onKeyDown(this, function(key:Key) {

            if (key.scanCode == ScanCode.LSHIFT) {
                leftShiftPressed = true;
            }
            else if (key.scanCode == ScanCode.LSHIFT) {
                rightShiftPressed = true;
            }

        });

        app.onKeyUp(this, function(key:Key) {

            if (key.scanCode == ScanCode.LSHIFT) {
                leftShiftPressed = false;
            }
            else if (key.scanCode == ScanCode.LSHIFT) {
                rightShiftPressed = false;
            }

        });

    }

    function checkStatus() {

        var canTrigger = !matches;
        var doesMatch = !disableIfShiftPressed || (!leftShiftPressed && !rightShiftPressed);

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

    }

}
