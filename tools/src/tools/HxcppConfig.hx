package tools;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class HxcppConfig {

    public static function readHxcppConfig(localDefines:Map<String,String>) {

        final homeDirectory = homedir();
        var configPath = Path.join([homeDirectory, '.hxcpp_config.xml']);

        if (localDefines.exists('HXCPP_CONFIG') && localDefines.get('HXCPP_CONFIG').trim().length > 0) {
            configPath = localDefines.get('HXCPP_CONFIG').trim();
            if (!Path.isAbsolute(configPath)) {
                configPath = Path.join([context.cwd, configPath]);
            }
        }

        if (!FileSystem.exists(configPath)) return;

        try {
            final xml = Xml.parse(File.getContent(configPath));

            // Process the XML document
            for (section in xml.elementsNamed("section")) {
                if (section.get("name") == "vars") {
                    processSection(section, localDefines);
                }
            }
        }
        catch (e:Any) {
            warning('Failed to read HXCPP config: ' + configPath);
        }
    }

    private static function processSection(section:Xml, localDefines:Map<String,String>):Void {
        // Check if the section has conditions and if they are met
        if (!evaluateConditions(section, localDefines)) return;

        // Process all set elements in this section
        for (element in section.elements()) {
            if (element.nodeName == "set") {
                processSetElement(element, localDefines);
            } else if (element.nodeName == "section") {
                // Process nested sections
                processSection(element, localDefines);
            }
        }
    }

    private static function processSetElement(element:Xml, localDefines:Map<String,String>):Void {
        // Check if the set element has conditions and if they are met
        if (!evaluateConditions(element, localDefines)) return;

        final name = element.get("name");
        var value = element.get("value");

        if (name != null && value != null) {
            // Replace any ${VAR} in the value with the corresponding value from localDefines
            value = substituteVars(value, localDefines);

            // Update localDefines
            localDefines.set(name, value);
        }
    }

    private static function evaluateConditions(node:Xml, localDefines:Map<String,String>):Bool {
        // Check 'if' condition
        final ifCondition = node.get("if");
        if (ifCondition != null && !evaluateLogicalExpression(ifCondition, localDefines, true)) {
            return false;
        }

        // Check 'unless' condition (negated if)
        final unlessCondition = node.get("unless");
        if (unlessCondition != null && evaluateLogicalExpression(unlessCondition, localDefines, true)) {
            return false;
        }

        return true;
    }

    private static function evaluateLogicalExpression(expression:String, localDefines:Map<String,String>, defaultValue:Bool):Bool {
        // Handle OR expressions
        if (expression.indexOf("||") >= 0) {
            final parts = expression.split("||");
            for (part in parts) {
                if (evaluateLogicalExpression(part.trim(), localDefines, false)) {
                    return true;
                }
            }
            return false;
        }

        // Handle AND expressions
        if (expression.indexOf("&&") >= 0) {
            final parts = expression.split("&&");
            for (part in parts) {
                if (!evaluateLogicalExpression(part.trim(), localDefines, true)) {
                    return false;
                }
            }
            return true;
        }

        // Simple variable existence check
        final name = expression.trim();
        if (name.startsWith("!")) {
            // Negated check
            final varName = name.substr(1).trim();
            return !localDefines.exists(varName) || localDefines.get(varName) == "0" || localDefines.get(varName) == "false";
        } else {
            return localDefines.exists(name) && localDefines.get(name) != "0" && localDefines.get(name) != "false";
        }
    }

    private static function substituteVars(value:String, localDefines:Map<String,String>):String {
        // Replace ${VAR} with the value from localDefines
        var result = value;

        while (RE_VAR_PATTERN.match(result)) {
            final varName = RE_VAR_PATTERN.matched(1);
            final replacement = localDefines.exists(varName) ? localDefines.get(varName) : "";
            result = RE_VAR_PATTERN.replace(result, replacement);
        }

        return result;
    }

    static final RE_VAR_PATTERN = ~/\${([^}]+)}/g;

}
