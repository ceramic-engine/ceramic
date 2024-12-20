package tools;

import haxe.ds.Map;

using StringTools;

class Condition {

    static final operators = [
        "&&" => 2,
        "||" => 1,
        "==" => 3,
        "!=" => 3,
        ">" => 3,
        "<" => 3,
        ">=" => 3,
        "<=" => 3,
        "!" => 4
    ];

    public static function evaluate(expression:String, context:Map<String, Any> = null):Bool {
        if (context == null) context = new Map<String, Any>();

        // Handle simple true/false literals
        final trimmedLowercase = expression.trim().toLowerCase();
        if (trimmedLowercase == "true") return true;
        if (trimmedLowercase == "false") return false;

        // Handle single variable reference
        if (!containsOperators(expression)) {
            return evaluateToken(expression.trim(), context);
        }

        return evaluateExpression(tokenize(expression), context);
    }

    private static function containsOperators(expr:String):Bool {
        for (op in operators.keys()) {
            if (expr.indexOf(op) != -1) return true;
        }
        return expr.indexOf("(") != -1 || expr.indexOf(")") != -1;
    }

    private static function tokenize(expression:String):Array<String> {
        var tokens = new Array<String>();
        var current = new StringBuf();
        var i = 0;

        while (i < expression.length) {
            var charCode = expression.charCodeAt(i);

            // Check for whitespace
            if (charCode == " ".code || charCode == "\t".code ||
                charCode == "\n".code || charCode == "\r".code) {
                if (current.length > 0) {
                    tokens.push(current.toString());
                    current = new StringBuf();
                }
                i++;
                continue;
            }

            // Check for parentheses
            if (charCode == "(".code || charCode == ")".code) {
                if (current.length > 0) {
                    tokens.push(current.toString());
                    current = new StringBuf();
                }
                tokens.push(String.fromCharCode(charCode));
                i++;
                continue;
            }

            // Check for operators
            var foundOperator = false;
            for (op in operators.keys()) {
                if (expression.substr(i, op.length) == op) {
                    if (current.length > 0) {
                        tokens.push(current.toString());
                        current = new StringBuf();
                    }
                    tokens.push(op);
                    i += op.length;
                    foundOperator = true;
                    break;
                }
            }

            if (!foundOperator) {
                current.addChar(charCode);
                i++;
            }
        }

        if (current.length > 0) {
            tokens.push(current.toString());
        }

        return tokens;
    }

    private static function evaluateExpression(tokens:Array<String>, context:Map<String, Any>):Bool {
        // Handle parentheses first
        var i = 0;
        while (i < tokens.length) {
            if (tokens[i] == "(") {
                var depth = 1;
                var j = i + 1;
                var subExpr = new Array<String>();

                while (j < tokens.length && depth > 0) {
                    if (tokens[j] == "(") depth++;
                    if (tokens[j] == ")") depth--;
                    if (depth > 0) subExpr.push(tokens[j]);
                    j++;
                }

                var result = evaluateExpression(subExpr, context);
                tokens.splice(i, j - i);
                tokens.insert(i, Std.string(result));
            }
            i++;
        }

        // Handle NOT operator
        i = 0;
        while (i < tokens.length) {
            if (tokens[i] == "!") {
                var operand = evaluateToken(tokens[i + 1], context);
                tokens.splice(i, 2);
                tokens.insert(i, Std.string(!operand));
            } else {
                i++;
            }
        }

        // Handle comparison operators
        i = 0;
        while (i < tokens.length) {
            var op = tokens[i];
            if (operators.exists(op) && operators[op] == 3) {
                var left = getVariableValue(tokens[i - 1], context);
                var right = getVariableValue(tokens[i + 1], context);
                var result = evaluateComparison(left, right, op);
                tokens.splice(i - 1, 3);
                tokens.insert(i - 1, Std.string(result));
                i--;
            } else {
                i++;
            }
        }

        // Handle AND
        i = 0;
        while (i < tokens.length) {
            if (tokens[i] == "&&") {
                var left = evaluateToken(tokens[i - 1], context);
                var right = evaluateToken(tokens[i + 1], context);
                tokens.splice(i - 1, 3);
                tokens.insert(i - 1, Std.string(left && right));
                i--;
            } else {
                i++;
            }
        }

        // Handle OR
        i = 0;
        while (i < tokens.length) {
            if (tokens[i] == "||") {
                var left = evaluateToken(tokens[i - 1], context);
                var right = evaluateToken(tokens[i + 1], context);
                tokens.splice(i - 1, 3);
                tokens.insert(i - 1, Std.string(left || right));
                i--;
            } else {
                i++;
            }
        }

        return tokens.length == 1 ? evaluateToken(tokens[0], context) : false;
    }

    private static function evaluateToken(token:String, context:Map<String, Any>):Bool {
        if (token == "true") {
            return true;
        }
        if (token == "false") {
            return false;
        }
        if (Std.parseInt(token) != null) {
            return Std.parseInt(token) != 0;
        }

        var value = getVariableValue(token, context);
        return convertToBool(value);
    }

    private static function evaluateComparison(left:Dynamic, right:Dynamic, op:String):Bool {
        return switch (op) {
            case "==": left == right;
            case "!=": left != right;
            case ">": Std.parseFloat(Std.string(left)) > Std.parseFloat(Std.string(right));
            case "<": Std.parseFloat(Std.string(left)) < Std.parseFloat(Std.string(right));
            case ">=": Std.parseFloat(Std.string(left)) >= Std.parseFloat(Std.string(right));
            case "<=": Std.parseFloat(Std.string(left)) <= Std.parseFloat(Std.string(right));
            default: false;
        }
    }

    private static function getVariableValue(name:String, context:Map<String, Any>):Dynamic {
        return context.exists(name) ? context.get(name) : null;
    }

    private static function convertToBool(value:Dynamic):Bool {
        if (value is Bool) {
            return value;
        }
        else if (value == null) {
            return false;
        }
        else {
            return true;
        }
    }
}