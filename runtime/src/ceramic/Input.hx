package ceramic;

/**
 * Manages all input handling for keyboard and gamepad devices.
 * 
 * The Input system provides:
 * - Keyboard input detection (key press, release, and hold states)
 * - Gamepad support (buttons, analog axes, gyroscope)
 * - Input state queries (pressed, just pressed, just released)
 * - Gamepad vibration/rumble control
 * - Integration with UI elements to prevent input conflicts
 * 
 * The system tracks three states for inputs:
 * - Just pressed: True only on the frame the input was pressed
 * - Pressed: True while the input is held down
 * - Just released: True only on the frame the input was released
 * 
 * @see Key
 * @see KeyCode
 * @see ScanCode
 * @see GamepadButton
 * @see GamepadAxis
 */
@:allow(ceramic.App)
class Input extends Entity {

    /**
     * Internal value to store gamepad state
     */
    inline static final GAMEPAD_STORAGE_SIZE:Int = 32;

    /**
     * Triggered when a key from the keyboard is being pressed.
     * This event fires repeatedly while a key is held down.
     * @param key The key being pressed, containing both keyCode and scanCode
     * @event keyDown
     */
    @event function keyDown(key:Key);
    
    /**
     * Triggered when a key from the keyboard is being released.
     * @param key The key being released, containing both keyCode and scanCode
     * @event keyUp
     */
    @event function keyUp(key:Key);

    /**
     * Triggered when text is committed while text editing is active
     * (see `startTextEditing()`): typed characters, or the final text of an IME composition.
     * Unlike `app.textInput`, the text is given as is (spaces and line breaks included).
     * @param text The committed text
     * @event textCommit
     */
    @event function textCommit(text:String);

    /**
     * Triggered when the IME composition (also called preedit or marked text) changes
     * while text editing is active (see `startTextEditing()`). The composed text is not
     * committed yet: it should be displayed (usually underlined) in place of the selection
     * until a `textCommit` event, or until a composition with an empty `text`.
     * @param text The text being composed, empty when the composition ended or was cancelled
     * @param start Cursor position (or selection start) inside the composed text, in characters
     * @param length Selection length inside the composed text, in characters
     * @event textComposition
     */
    @event function textComposition(text:String, start:Int, length:Int);

    /**
     * Triggered when a gamepad analog axis value changes.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param axis The axis that changed (e.g., LEFT_X, RIGHT_TRIGGER)
     * @param value The new axis value (-1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers)
     * @event gamepadAxis
     */
    @event function gamepadAxis(gamepadId:Int, axis:GamepadAxis, value:Float);
    
    /**
     * Triggered when a gamepad button is pressed.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param button The button being pressed
     * @event gamepadDown
     */
    @event function gamepadDown(gamepadId:Int, button:GamepadButton);
    
    /**
     * Triggered when a gamepad button is released.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param button The button being released
     * @event gamepadUp
     */
    @event function gamepadUp(gamepadId:Int, button:GamepadButton);
    
    /**
     * Triggered when gamepad gyroscope data is received.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param dx Angular velocity around X axis (radians/second)
     * @param dy Angular velocity around Y axis (radians/second)
     * @param dz Angular velocity around Z axis (radians/second)
     * @event gamepadGyro
     */
    @event function gamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float);
    
    /**
     * Triggered when a gamepad is connected and enabled.
     * @param gamepadId The ID assigned to the gamepad (0-based index)
     * @param name The name/description of the gamepad device
     * @event gamepadEnable
     */
    @event function gamepadEnable(gamepadId:Int, name:String);
    
    /**
     * Triggered when a gamepad is disconnected or disabled.
     * @param gamepadId The ID of the gamepad being disabled
     * @event gamepadDisable
     */
    @event function gamepadDisable(gamepadId:Int);

    var pressedScanCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedKeyCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedGamepadButtons:IntIntMap = new IntIntMap(16, 0.5, false);

    var gamepadAxisValues:IntFloatMap = new IntFloatMap(16, 0.5, false);

    var gamepadGyroDeltas:IntMap<Array<Float>> = new IntMap();

    var gamepadGyroKeys:Array<Int> = [];

    var gamepadNames:IntMap<String> = new IntMap();

    var gamepadLabelsById:IntIntMap = new IntIntMap();

    /**
     * Modifier keys held, as of the last key event received.
     * Useful to know the modifiers during pointer events.
     * Note that modifier changes happening while the app doesn't have focus are only
     * seen with the next key event.
     */
    public var modifiers(default, null):KeyModifiers = KeyModifiers.NONE;

    /**
     * Set to `true` by a `keyDown` listener that handled the key being
     * pressed. Reset to `false` right before each `keyDown` event. A key
     * down that is not handled can then trigger the menu bar item with the
     * same shortcut (see `screen.setMenuBar`): the app sees each keystroke
     * first, like a native window before the menus.
     */
    public var keyDownHandled:Bool = false;

    /**
     * Whether text editing is active (see `startTextEditing()`).
     */
    public var textEditing(default, null):Bool = false;

    /**
     * Whether an IME composition is in progress: a non empty `textComposition`
     * was received and not committed or cancelled yet. Key events received during
     * a composition are usually handled by the IME and should not edit the text.
     */
    public var textComposing(default, null):Bool = false;

    /**
     * Tells whether a tap at the given position (screen coordinates) lands on
     * an editable text area. Some platforms only show their virtual keyboard
     * when an editable element gets the focus from inside the user gesture
     * (mobile browsers): their backend calls this synchronously from the
     * touch release that completes a tap (released within 8 px of where it
     * started, without the visual viewport changing during the gesture),
     * before the touch events reach the app, and focuses its text editing
     * element right away when it returns `true`. Text editing should then be
     * started for that area (`startTextEditing()`), the keyboard stays hidden
     * otherwise. Backends that show the keyboard with text editing (native)
     * do not need it; Unity on iOS and Android calls it from a tap while
     * text editing is active, to show again a keyboard the user closed.
     */
    public var textEditingTapFilter:Null<(x:Float, y:Float)->Bool> = null;

    /**
     * List of currently connected gamepad IDs.
     * Updated automatically when gamepads are connected or disconnected.
     */
    public var activeGamepads:ReadOnlyArray<Int> = [];

    /**
     * Private constructor. Input is managed as a singleton through App.
     */
    private function new() {

        super();

    }

    function resetDeltas() {

        while (gamepadGyroKeys.length > 0) {
            // Last value without `pop()`, which boxes the Int it returns (`Null<Int>`) on hxcpp
            var key = gamepadGyroKeys[gamepadGyroKeys.length - 1];
            gamepadGyroKeys.resize(gamepadGyroKeys.length - 1);
            var deltas = gamepadGyroDeltas.get(key);
            if (deltas != null) {
                deltas[0] = 0;
                deltas[1] = 0;
                deltas[2] = 0;
            }
        }

    }

    #if plugin_elements

    @:plugin('elements')
    static function _elementsImFocused():Bool {

        var context = elements.Context.context;
        return (context != null && context.focusedWindow != null);

    }

    @:plugin('elements')
    inline function canEmitKeyDown(owner:tracker.Owner):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitKeyUp(owner:tracker.Owner):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitGamepadDown(owner:tracker.Owner):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitGamepadUp(owner:tracker.Owner):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    #end

/// Keyboard

    function willEmitKeyDown(key:Key):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        modifiers = key.modifiers;
        keyDownHandled = false;

        var prevScan = pressedScanCodes.get(key.scanCode);
        var prevKey = pressedKeyCodes.get(key.keyCode);

        if (prevScan == -1) {
            prevScan = 0;
            prevKey = 0;
        }

        pressedScanCodes.set(key.scanCode, prevScan + 1);
        pressedKeyCodes.set(key.keyCode, prevKey + 1);

        if (prevScan == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedScanCodes.get(key.scanCode) == 1) {
                    pressedScanCodes.set(key.scanCode, 2);
                }
                if (pressedKeyCodes.get(key.keyCode) == 1) {
                    pressedKeyCodes.set(key.keyCode, 2);
                }
            });
        }

    }

    function willEmitKeyUp(key:Key):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        modifiers = key.modifiers;

        var prevScan = pressedScanCodes.get(key.scanCode);

        if (prevScan != 0) {
            pressedScanCodes.set(key.scanCode, -1);
            pressedKeyCodes.set(key.keyCode, -1);
            // Used to differenciate "released" and "just released" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedScanCodes.get(key.scanCode) == -1) {
                    pressedScanCodes.set(key.scanCode, 0);
                }
                if (pressedKeyCodes.get(key.keyCode) == -1) {
                    pressedKeyCodes.set(key.keyCode, 0);
                }
            });
        }

    }

    function willEmitTextCommit(text:String):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        textComposing = false;

    }

    function willEmitTextComposition(text:String, start:Int, length:Int):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        textComposing = text != null && text.length > 0;

    }

/// Text editing

    /**
     * Starts receiving text from the system (keyboard and IME) through `textCommit`
     * and `textComposition` events, independently of `app.textInput`.
     *
     * Use it to implement a custom text field: the app handles the text itself,
     * while editing keys (arrows, backspace, enter...) still come from `keyDown`.
     * The area tells the system where the text is edited, so that it can place
     * the IME candidate window and avoid covering the text with a virtual keyboard.
     *
     * ```haxe
     * input.onTextCommit(this, text -> insert(text));
     * input.onTextComposition(this, (text, start, length) -> setMarkedText(text, start, length));
     * input.startTextEditing(field.x, field.y, field.width, field.height);
     * ```
     *
     * Backend support:
     * - Clay native (SDL): `SDL_StartTextInput`, composition from `SDL_EVENT_TEXT_EDITING`.
     * - Clay web: a hidden `<textarea>` gets the focus and its composition events.
     * - Unity: `Keyboard.onTextInput` and `Keyboard.onIMECompositionChange` (no selection
     *   inside the composition). On iOS and Android, `TouchScreenKeyboard` opens: the
     *   edits of its hidden field arrive as `textCommit` and as left, right, backspace
     *   and enter key events.
     * - Headless: no-op.
     *
     * @param x X position of the edited text area, in screen coordinates
     * @param y Y position of the edited text area, in screen coordinates
     * @param w Width of the edited text area
     * @param h Height of the edited text area
     */
    public function startTextEditing(x:Float = 0, y:Float = 0, w:Float = 0, h:Float = 0):Void {

        textEditing = true;
        final screen = ceramic.App.app.screen;
        final matrix = @:privateAccess screen.matrix;
        final nativeX = matrix.transformX(x, y) / screen.nativeDensity;
        final nativeY = matrix.transformY(x, y) / screen.nativeDensity;
        final nativeW = matrix.transformX(x + w, y + h) / screen.nativeDensity - nativeX;
        final nativeH = matrix.transformY(x + w, y + h) / screen.nativeDensity - nativeY;
        ceramic.App.app.backend.textInput.startTextEditing(nativeX, nativeY, nativeW, nativeH);

    }

    /**
     * Stops text editing started with `startTextEditing()`.
     * A composition in progress is cancelled.
     */
    public function stopTextEditing():Void {

        if (!textEditing) return;
        textEditing = false;
        ceramic.App.app.backend.textInput.stopTextEditing();
        if (textComposing) {
            emitTextComposition('', 0, 0);
        }

    }

    /**
     * Sets how virtual keyboards should present themselves for the edited
     * text (the attributes of the hidden editable element on the web; the
     * type, return key and autocorrection of Unity's `TouchScreenKeyboard`
     * on iOS and Android, see `ceramic.VirtualKeyboardType`). Kept until
     * changed; applies to the next and the current text editing.
     *
     * @param inputMode HTML `inputmode`: `text`, `numeric`, `decimal`, `tel`, `email`, `url`, `search`
     * @param enterKeyHint HTML `enterkeyhint` (`enter`, `done`, `go`, `next`, `previous`, `search`, `send`), or null for none
     * @param autocapitalize HTML `autocapitalize`: `off`, `words`, `sentences`, `characters`
     * @param autocorrect Whether the platform may correct the entered text
     * @param spellcheck Whether the platform may offer suggestions and spellcheck
     */
    public function setTextEditingConfiguration(inputMode:String = 'text', ?enterKeyHint:String, autocapitalize:String = 'off', autocorrect:Bool = false, spellcheck:Bool = false):Void {

        ceramic.App.app.backend.textInput.setTextEditingConfiguration(inputMode, enterKeyHint, autocapitalize, autocorrect, spellcheck);

    }

    /**
     * Called by backends with a tap position in native coordinates: converts
     * it to screen coordinates and asks `textEditingTapFilter`.
     */
    @:noCompletion public function textEditingTapTargets(nativeX:Float, nativeY:Float):Bool {

        final filter = textEditingTapFilter;
        if (filter == null) return false;
        final screen = ceramic.App.app.screen;
        final reverseMatrix = @:privateAccess screen.reverseMatrix;
        final x0 = nativeX * screen.nativeDensity;
        final y0 = nativeY * screen.nativeDensity;
        return filter(reverseMatrix.transformX(x0, y0), reverseMatrix.transformY(x0, y0));

    }

    /**
     * Updates the area of the edited text, usually when the cursor moves,
     * so that the IME candidate window follows it.
     *
     * @param x X position of the edited text area, in screen coordinates
     * @param y Y position of the edited text area, in screen coordinates
     * @param w Width of the edited text area
     * @param h Height of the edited text area
     * @param cursor Cursor position inside the area, as an offset from `x`
     */
    public function setTextEditingArea(x:Float, y:Float, w:Float, h:Float, cursor:Float = 0):Void {

        final screen = ceramic.App.app.screen;
        final matrix = @:privateAccess screen.matrix;
        final nativeX = matrix.transformX(x, y) / screen.nativeDensity;
        final nativeY = matrix.transformY(x, y) / screen.nativeDensity;
        final nativeW = matrix.transformX(x + w, y + h) / screen.nativeDensity - nativeX;
        final nativeH = matrix.transformY(x + w, y + h) / screen.nativeDensity - nativeY;
        final nativeCursor = matrix.transformX(x + cursor, y) / screen.nativeDensity - nativeX;
        ceramic.App.app.backend.textInput.setTextEditingArea(nativeX, nativeY, nativeW, nativeH, nativeCursor);

    }

    /**
     * Checks if a key is currently pressed (held down).
     * Returns true for every frame while the key is held.
     * @param keyCode The key code to check
     * @return True if the key is currently pressed
     */
    public extern inline overload function keyPressed(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyPressed(keyCode);

    }

    /**
     * Checks if a key was just pressed this frame.
     * Returns true only on the frame the key was initially pressed.
     * @param keyCode The key code to check
     * @return True if the key was just pressed this frame
     */
    public extern inline overload function keyJustPressed(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyJustPressed(keyCode);

    }

    /**
     * Checks if a key was just released this frame.
     * Returns true only on the frame the key was released.
     * @param keyCode The key code to check
     * @return True if the key was just released this frame
     */
    public extern inline overload function keyJustReleased(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyJustReleased(keyCode);

    }

    /**
     * Checks if a key is currently pressed using scan code.
     * Scan codes represent physical key positions and are layout-independent.
     * @param scanCode The scan code to check
     * @return True if the key is currently pressed
     */
    public extern inline overload function scanPressed(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanPressed(scanCode);

    }

    /**
     * Checks if a key was just pressed this frame using scan code.
     * @param scanCode The scan code to check
     * @return True if the key was just pressed this frame
     */
    public extern inline overload function scanJustPressed(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanJustPressed(scanCode);

    }

    /**
     * Checks if a key was just released this frame using scan code.
     * @param scanCode The scan code to check
     * @return True if the key was just released this frame
     */
    public extern inline overload function scanJustReleased(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanJustReleased(scanCode);

    }

    /**
     * Checks if a key is currently pressed, with UI element filtering.
     * Allows input to pass through when the owner entity has UI focus.
     * @param keyCode The key code to check
     * @param owner The entity that wants to receive input (used for UI focus filtering)
     * @return True if the key is currently pressed and the owner can receive input
     */
    public extern inline overload function keyPressed(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyPressed(keyCode);

    }

    /**
     * Checks if a key was just pressed this frame, with UI element filtering.
     * @param keyCode The key code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just pressed and the owner can receive input
     */
    public extern inline overload function keyJustPressed(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyJustPressed(keyCode);

    }

    /**
     * Checks if a key was just released this frame, with UI element filtering.
     * @param keyCode The key code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just released and the owner can receive input
     */
    public extern inline overload function keyJustReleased(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyJustReleased(keyCode);

    }

    /**
     * Checks if a key is currently pressed using scan code, with UI element filtering.
     * @param scanCode The scan code to check
     * @param owner The entity that wants to receive input
     * @return True if the key is currently pressed and the owner can receive input
     */
    public extern inline overload function scanPressed(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanPressed(scanCode);

    }

    /**
     * Checks if a key was just pressed this frame using scan code, with UI element filtering.
     * @param scanCode The scan code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just pressed and the owner can receive input
     */
    public extern inline overload function scanJustPressed(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanJustPressed(scanCode);

    }

    /**
     * Checks if a key was just released this frame using scan code, with UI element filtering.
     * @param scanCode The scan code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just released and the owner can receive input
     */
    public extern inline overload function scanJustReleased(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanJustReleased(scanCode);

    }

    function _keyPressed(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) > 0;

    }

    function _keyJustPressed(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) == 1;

    }

    function _keyJustReleased(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) == -1;

    }

    function _scanPressed(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) > 0;

    }

    function _scanJustPressed(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) == 1;

    }

    function _scanJustReleased(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) == -1;

    }

/// Gamepad

    function willEmitGamepadEnable(gamepadId:Int, name:String):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        // Reset gamepad state
        var key = gamepadId * GAMEPAD_STORAGE_SIZE;
        for (i in 0...GAMEPAD_STORAGE_SIZE) {
            var k = key + i;
            pressedGamepadButtons.set(k, 0);
            gamepadAxisValues.set(k, 0.0);
        }

        // Add gamepad to active list
        if (activeGamepads.indexOf(gamepadId) == -1) {
            activeGamepads.original.push(gamepadId);
        }

        // Keep gamepad name, and the labels printed on its buttons
        gamepadNames.set(gamepadId, name);
        gamepadLabelsById.set(gamepadId, GamepadLabels.fromGamepadName(name));

    }

    function willEmitGamepadDisable(gamepadId:Int):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        // Trigger buttons release and axis reset if needed
        var key = gamepadId * GAMEPAD_STORAGE_SIZE;
        for (i in 0...GAMEPAD_STORAGE_SIZE) {
            var k = key + i;
            var pressed = pressedGamepadButtons.get(k);
            if (pressed > 0) {
                emitGamepadUp(gamepadId, i);
            }
            var axis = gamepadAxisValues.get(k);
            if (axis != 0) {
                emitGamepadAxis(gamepadId, i, axis);
            }
        }

        // Remove gamepad from active list
        var index = activeGamepads.indexOf(gamepadId);
        if (index != -1) {
            activeGamepads.original.splice(index, 1);
        }

        // Remove gamepad name and labels
        gamepadNames.remove(gamepadId);
        gamepadLabelsById.remove(gamepadId);

    }

    function willEmitGamepadDown(gamepadId:Int, button:GamepadButton):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        var prevValue = pressedGamepadButtons.get(key);

        if (prevValue == -1) {
            prevValue = 0;
        }

        pressedGamepadButtons.set(key, prevValue + 1);

        if (prevValue == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedGamepadButtons.get(key) == 1) {
                    pressedGamepadButtons.set(key, 2);
                }
            });
        }

    }

    function willEmitGamepadUp(gamepadId:Int, button:GamepadButton):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        pressedGamepadButtons.set(key, -1);
        // Used to differenciate "released" and "just released" states
        ceramic.App.app.beginUpdateCallbacks.push(function() {
            if (pressedGamepadButtons.get(key) == -1) {
                pressedGamepadButtons.set(key, 0);
            }
        });

    }

    function willEmitGamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas == null) {
            deltas = [0, 0, 0];
            gamepadGyroDeltas.set(key, deltas);
        }
        if (gamepadGyroKeys.indexOf(key) == -1) {
            gamepadGyroKeys.push(key);
        }
        deltas[0] += dx;
        deltas[1] += dy;
        deltas[2] += dz;

    }

    /**
     * Checks if a gamepad button is currently pressed.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @return True if the button is currently pressed
     */
    public extern inline overload function gamepadPressed(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just pressed this frame.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @return True if the button was just pressed this frame
     */
    public extern inline overload function gamepadJustPressed(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadJustPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just released this frame.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @return True if the button was just released this frame
     */
    public extern inline overload function gamepadJustReleased(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadJustReleased(gamepadId, button);

    }

    /**
     * Checks if a gamepad button is currently pressed, with UI element filtering.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @param owner The entity that wants to receive input
     * @return True if the button is pressed and the owner can receive input
     */
    public extern inline overload function gamepadPressed(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just pressed this frame, with UI element filtering.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @param owner The entity that wants to receive input
     * @return True if the button was just pressed and the owner can receive input
     */
    public extern inline overload function gamepadJustPressed(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadJustPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just released this frame, with UI element filtering.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @param owner The entity that wants to receive input
     * @return True if the button was just released and the owner can receive input
     */
    public extern inline overload function gamepadJustReleased(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadJustReleased(gamepadId, button);

    }

    function _gamepadPressed(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) > 0;

    }

    function _gamepadJustPressed(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) == 1;

    }

    function _gamepadJustReleased(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) == -1;

    }

    inline function willEmitGamepadAxis(gamepadId:Int, axis:GamepadAxis, value:Float):Void {

        // Every input event requests a render (render on demand)
        ceramic.App.app.requestRender();

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + axis;
        gamepadAxisValues.set(key, value);

    }

    /**
     * Gets the current value of a gamepad analog axis.
     * @param gamepadId The ID of the gamepad to check
     * @param axis The axis to check (e.g., LEFT_X, RIGHT_TRIGGER)
     * @return The axis value (-1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers)
     */
    public function gamepadAxisValue(gamepadId:Int, axis:GamepadAxis):Float {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + axis;
        return gamepadAxisValues.get(key);

    }

    /**
     * Gets the accumulated gyroscope delta for the X axis since last frame.
     * @param gamepadId The ID of the gamepad
     * @return Angular velocity around X axis (radians/second)
     */
    public function gamepadGyroDeltaX(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[0];
        }
        return 0;

    }

    /**
     * Gets the accumulated gyroscope delta for the Y axis since last frame.
     * @param gamepadId The ID of the gamepad
     * @return Angular velocity around Y axis (radians/second)
     */
    public function gamepadGyroDeltaY(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[1];
        }
        return 0;

    }

    /**
     * Gets the accumulated gyroscope delta for the Z axis since last frame.
     * @param gamepadId The ID of the gamepad
     * @return Angular velocity around Z axis (radians/second)
     */
    public function gamepadGyroDeltaZ(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[2];
        }
        return 0;

    }

    /**
     * Starts a controller rumble.
     * @param gamepadId The id of the gamepad getting rumble
     * @param duration The duration, in seconds
     * @param lowFrequency Low frequency: value between 0 and 1
     * @param highFrequency High frequency: value between 0 and 1
     */
    public function startGamepadRumble(gamepadId:Int, duration:Float, lowFrequency:Float, highFrequency:Float) {

        ceramic.App.app.backend.input.startGamepadRumble(gamepadId, lowFrequency, highFrequency, duration);

    }

    /**
     * Stops any active rumble on the specified gamepad.
     * @param gamepadId The ID of the gamepad
     */
    public function stopGamepadRumble(gamepadId:Int) {

        ceramic.App.app.backend.input.stopGamepadRumble(gamepadId);

    }

    /**
     * Key code produced by the physical key `scanCode` with the current keyboard layout,
     * that is the key printed on it: `KEY_Z` gives `KEY_W` on an AZERTY keyboard.
     * Use `KeyCode.name()` on the result to display it. Returns `KeyCode.UNKNOWN`
     * when the backend can't tell (on web, before the layout is known and before
     * that key was pressed, if the browser has no keyboard layout API).
     * @param scanCode The physical key
     * @return The key code for the current layout, or `KeyCode.UNKNOWN`
     */
    public function keyCodeForScanCode(scanCode:ScanCode):KeyCode {

        return ceramic.App.app.backend.input.keyCodeForScanCode(scanCode);

    }

    /**
     * Gets the name/description of a connected gamepad.
     * @param gamepadId The ID of the gamepad
     * @return The gamepad name, or null if not connected
     */
    public function gamepadName(gamepadId:Int):String {

        return gamepadNames.get(gamepadId);

    }

    /**
     * The labels printed on the buttons of a connected gamepad (Xbox, PlayStation,
     * Nintendo...), resolved from its name. `GamepadButton` is positional on every backend:
     * use this to show the player the label of a button on their gamepad.
     * @param gamepadId The ID of the gamepad
     * @return The labels of the gamepad, `GENERIC` if unknown or not connected
     */
    public function gamepadLabels(gamepadId:Int):GamepadLabels {

        return gamepadLabelsById.get(gamepadId);

    }

}