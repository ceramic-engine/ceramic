package tools;

using StringTools;

class UnityShader {

    public static function isMultiTextureTemplate(content:String):Bool {

        for (line in content.split('\n')) {
            if (line.trim().replace(' ', '').toLowerCase() == '//ceramic:multitexture') {
                return true;
            }
        }

        return false;

    }

    public static function processMultiTextureTemplate(content:String, maxConditions:Int = 8):String {

        var lines = content.split('\n');
        var newLines:Array<String> = [];

        var nextLineIsTextureUniform = false;
        var inConditionBody = false;
        var conditionLines:Array<String> = [];

        var didProcessShaderName = false;

        for (i in 0...lines.length) {
            var line = lines[i];
            var cleanedLine = line.trim().replace(' ', '').toLowerCase();
            if (nextLineIsTextureUniform) {
                nextLineIsTextureUniform = false;
                for (n in 0...maxConditions) {
                    if (n == 0) {
                        newLines.push(line);
                    }
                    else {
                        newLines.push(line.replace('_MainTex', '_Tex' + n).replace('"Main', '"Tex' + n));
                    }
                }
            }
            else if (inConditionBody) {
                if (cleanedLine == '//ceramic:multitexture/endif') {
                    inConditionBody = false;
                    if (conditionLines.length > 0) {
                        for (n in 0...maxConditions) {

                            if (n == 0) {
                                newLines.push('if (IN.textureId == 0.0) {');
                            }
                            else {
                                newLines.push('else if (IN.textureId == ' + n + '.0) {');
                            }

                            for (l in 0...conditionLines.length) {
                                if (n == 0) {
                                    newLines.push(conditionLines[l]);
                                }
                                else {
                                    newLines.push(conditionLines[l].replace('_MainTex', '_Tex' + n));
                                }
                            }

                            newLines.push('}');
                        }
                    }
                }
                else {
                    conditionLines.push(line);
                }
            }
            else if (cleanedLine.startsWith('//ceramic:multitexture')) {
                if (cleanedLine == '//ceramic:multitexture/texture') {
                    nextLineIsTextureUniform = true;
                }
                else if (cleanedLine == '//ceramic:multitexture/textureidstruct') {
                    newLines.push('fixed textureId : COLOR1;');
                }
                else if (cleanedLine == '//ceramic:multitexture/textureidassign') {
                    newLines.push('OUT.textureId = IN.vertex.w;');
                }
                else if (cleanedLine == '//ceramic:multitexture/if') {
                    inConditionBody = true;
                }
            }
            else if (!didProcessShaderName && cleanedLine.startsWith('shader"') && cleanedLine.endsWith('"')) {
                newLines.push('Shader "' + line.split('"')[1] + '_mt' + maxConditions + '"');
                didProcessShaderName = true;
            }
            else {
                newLines.push(line);
            }
        }

        return newLines.join('\n');

    }

}
