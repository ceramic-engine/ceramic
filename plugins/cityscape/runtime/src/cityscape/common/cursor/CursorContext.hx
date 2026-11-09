// Ported from vscode src/vs/editor/common/cursor/cursorContext.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.common.CursorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.ViewModel.ICoordinatesConverter;

class CursorContext {

    public final model:ITextModel;
    public final viewModel:ICursorSimpleModel;
    public final coordinatesConverter:ICoordinatesConverter;
    public final cursorConfig:CursorConfiguration;

    public function new(model:ITextModel, viewModel:ICursorSimpleModel, coordinatesConverter:ICoordinatesConverter, cursorConfig:CursorConfiguration) {
        this.model = model;
        this.viewModel = viewModel;
        this.coordinatesConverter = coordinatesConverter;
        this.cursorConfig = cursorConfig;
    }

}
