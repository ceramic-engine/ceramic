# Keyboard shortcuts

You can bind keyboard shortcuts with `ceramic.KeyBindings` utility.

```haxe
var keyBindings = new KeyBindings();

keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_C)], function() {
    // Pressed COPY shortcut
});

keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_V)], function() {
    // Pressed PASTE shortcut
});
```
