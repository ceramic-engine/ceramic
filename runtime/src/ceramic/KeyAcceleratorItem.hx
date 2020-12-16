package ceramic;

import ceramic.ScanCode;
import ceramic.KeyCode;

enum KeyAcceleratorItem {

    SHIFT;

    CMD_OR_CTRL;

    SCAN(scanCode:ScanCode);

    KEY(keyCode:KeyCode);

}
