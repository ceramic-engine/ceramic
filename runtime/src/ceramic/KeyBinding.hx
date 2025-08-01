package ceramic;

import ceramic.Shortcuts.*;

/**
 * Represents a keyboard shortcut binding that triggers when a specific key combination is pressed.
 * 
 * KeyBinding monitors keyboard input and triggers an event when its assigned
 * key combination is activated. It supports modifier keys (Shift, Cmd/Ctrl)
 * combined with regular keys, and handles platform-specific differences
 * (e.g., Cmd on macOS vs Ctrl on Windows/Linux).
 * 
 * Note: KeyBinding instances are typically created and managed by KeyBindings,
 * not instantiated directly.
 * 
 * @see KeyBindings
 * @see KeyAcceleratorItem
 */
@:allow(ceramic.KeyBindings)
class KeyBinding extends Entity {

/// Events

    /**
     * Triggered when the key combination is pressed.
     * The event fires once when all keys in the combination are pressed together.
     * @event trigger
     */
    @event function trigger();

/// Internal properties

    /**
     * The key combination that triggers this binding.
     * Read-only array of KeyAcceleratorItem elements that must all be pressed together.
     */
    public var accelerator(default, null):ReadOnlyArray<KeyAcceleratorItem>;

    /**
     * The parent KeyBindings instance that manages this binding.
     * Null if this binding is not part of a KeyBindings collection.
     */
    public var bindings(default, null):KeyBindings = null;

    var pressedItems:Array<Int> = [];

    var matches:Bool = false;

    var leftShiftPressed:Bool = false;

    var rightShiftPressed:Bool = false;

    var disableIfShiftPressed:Bool = false;

    #if web
    var cmdPressed:Int = 0;
    var ctrlPressed:Int = 0;
    #end

/// Lifecycle

    private function new(accelerator:Array<KeyAcceleratorItem>, ?bindings:KeyBindings #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        this.accelerator = cast [].concat(accelerator);
        this.bindings = bindings;

        bindKeyboardEvents();

    }

/// Helpers

    /**
     * Forces all keys to be considered released.
     * Useful for resetting the binding state when the window loses focus
     * or when switching between different input contexts.
     */
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

    function bindScanCode(scanCode:ScanCode, itemIndex:Int):Void {

        input.onKeyDown(this, function(key:Key) {

            #if web
            if (scanCode == ScanCode.LMETA || scanCode == ScanCode.RMETA) {
                cmdPressed++;
            }
            else if (scanCode == ScanCode.LCTRL || scanCode == ScanCode.RCTRL) {
                ctrlPressed++;
            }
            #end

            if (key.scanCode == scanCode) {
                if (input.scanJustPressed(key.scanCode, bindings) #if web || pressedItems[itemIndex] == 0 #end) {
                    pressedItems[itemIndex]++;

                    checkStatus();

                    #if web
                    if ((cmdPressed > 0 || ctrlPressed > 0) && scanCode != ScanCode.LMETA && scanCode != ScanCode.RMETA && scanCode != ScanCode.LCTRL && scanCode != ScanCode.RCTRL && scanCode != ScanCode.LSHIFT && scanCode != ScanCode.RSHIFT) {
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

        input.onKeyUp(this, function(key:Key) {

            #if web
            if (scanCode == ScanCode.LMETA || scanCode == ScanCode.RMETA) {
                cmdPressed--;

                if (cmdPressed == 0 && ctrlPressed == 0) {
                    for (i in 0...pressedItems.length) {
                        pressedItems[itemIndex] = 0;
                    }

                    checkStatus();
                    return;
                }
            }
            else if (scanCode == ScanCode.LCTRL || scanCode == ScanCode.RCTRL) {
                ctrlPressed--;

                if (cmdPressed == 0 && ctrlPressed == 0) {
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

    function bindKeyCode(keyCode:KeyCode, itemIndex:Int):Void {

        input.onKeyDown(this, function(key:Key) {

            if (key.keyCode == keyCode) {
                if (input.scanJustPressed(key.scanCode, bindings) #if web || pressedItems[itemIndex] == 0 #end) {
                    pressedItems[itemIndex]++;

                    checkStatus();

                    #if web
                    if ((cmdPressed > 0 || ctrlPressed > 0) && keyCode != KeyCode.LMETA && keyCode != KeyCode.RMETA && keyCode != KeyCode.LCTRL && keyCode != KeyCode.RCTRL && keyCode != KeyCode.LSHIFT && keyCode != KeyCode.RSHIFT) {
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

        input.onKeyUp(this, function(key:Key) {

            if (key.keyCode == keyCode) {
                if (pressedItems[itemIndex] > 0)
                    pressedItems[itemIndex]--;

                checkStatus();
            }

        });

    }

    function bindShift() {

        input.onKeyDown(this, function(key:Key) {

            if (key.scanCode == ScanCode.LSHIFT) {
                leftShiftPressed = true;
            }
            else if (key.scanCode == ScanCode.RSHIFT) {
                rightShiftPressed = true;
            }

        });

        input.onKeyUp(this, function(key:Key) {

            if (key.scanCode == ScanCode.LSHIFT) {
                leftShiftPressed = false;
            }
            else if (key.scanCode == ScanCode.RSHIFT) {
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
