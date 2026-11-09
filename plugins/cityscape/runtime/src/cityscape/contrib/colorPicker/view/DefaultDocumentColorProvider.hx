// Ported from vscode src/vs/editor/contrib/colorPicker/browser/defaultDocumentColorProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Color;
import cityscape.common.Languages.DocumentColorProvider;
import cityscape.common.Languages.IColor;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.Languages.IColorPresentation;
import cityscape.common.Model.ITextModel;
import cityscape.common.services.EditorSimpleWorker;

/**
 * The colors of the default colors computer (`#rgb`, `rgb()`, `hsl()`...)
 * for every language, used when no other provider gives colors and the
 * `defaultColorDecorators` option is on. Monaco computes them in its editor
 * worker; here they are computed in place.
 */
class DefaultDocumentColorProvider implements DocumentColorProvider {

    public function new() {}

    public function provideDocumentColors(model:ITextModel, _token:CancellationToken, resolve:(colors:Null<Array<IColorInformation>>) -> Void):Void {
        resolve(EditorSimpleWorker.computeDefaultDocumentColors(model));
    }

    public function provideColorPresentations(_model:ITextModel, colorInfo:IColorInformation, _token:CancellationToken, resolve:(presentations:Null<Array<IColorPresentation>>) -> Void):Void {
        final range = colorInfo.range;
        final colorFromInfo:IColor = colorInfo.color;
        final alpha = colorFromInfo.alpha;
        final color = new Color(new RGBA(Math.round(255 * colorFromInfo.red), Math.round(255 * colorFromInfo.green), Math.round(255 * colorFromInfo.blue), alpha));

        // `alpha ? ... : ...` (an alpha of 0 is falsy)
        final rgb = alpha != 0 ? ColorFormatCSS.formatRGB(color) : ColorFormatCSS.formatRGBA(color);
        final hsl = alpha != 0 ? ColorFormatCSS.formatHSL(color) : ColorFormatCSS.formatHSLA(color);
        final hex = alpha != 0 ? ColorFormatCSS.formatHex(color) : ColorFormatCSS.formatHexA(color);

        final colorPresentations:Array<IColorPresentation> = [];
        colorPresentations.push({label: rgb, textEdit: {range: range, text: rgb}});
        colorPresentations.push({label: hsl, textEdit: {range: range, text: hsl}});
        colorPresentations.push({label: hex, textEdit: {range: range, text: hex}});
        resolve(colorPresentations);
    }

}
