package elements;

import ceramic.Slug;
import ceramic.Utils;

/**
 * Utility class providing various text manipulation and transformation functions.
 * 
 * This class contains static methods for common text operations used throughout
 * the elements framework, including string transformations, comparisons, and
 * identifier sanitization. It's particularly useful for UI elements that need
 * to process and format text data.
 * 
 * ## Features
 * 
 * - Field label generation from camelCase
 * - String comparison utilities
 * - Case conversion (UPPER_CASE ↔ camelCase)
 * - Text sanitization for identifiers
 * - Prefix extraction from strings
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Convert camelCase to readable label
 * var label = TextUtils.toFieldLabel("firstName"); // "First Name"
 * 
 * // Compare strings case-insensitively
 * var result = TextUtils.compareStrings("Hello", "hello"); // 0
 * 
 * // Convert UPPER_CASE to camelCase
 * var camel = TextUtils.upperCaseToCamelCase("SOME_CONSTANT"); // "SomeConstant"
 * 
 * // Sanitize text for use as identifier
 * var id = TextUtils.sanitizeToIdentifier("My Variable!"); // "My_Variable"
 * ```
 * 
 * @see SanitizeTextField
 * @see Slug
 */
@:allow(elements.SanitizeTextField)
class TextUtils {

    /**
     * Regular expression to match strings ending with numeric suffixes.
     * Captures the non-numeric prefix and the numeric suffix separately.
     * @private
     */
    static final RE_PREFIXED = ~/^(.*?)([0-9]+)$/;

    /**
     * Regular expression to match numeric prefixes at the start of strings.
     * @private
     */
    static final RE_NUMERIC_PREFIX = ~/^[0-9]+/;

    /**
     * Regular expression to match one or more whitespace characters.
     * @private
     */
    static final RE_SPACES = ~/\s+/;

    /**
     * Converts a camelCase string to a human-readable field label.
     * 
     * This function transforms camelCase strings into space-separated words
     * with proper capitalization, making them suitable for use as UI labels.
     * 
     * ## Transformation Rules
     * - First character is capitalized
     * - Uppercase letters (except the first) are preceded by a space
     * - Lowercase letters remain unchanged
     * 
     * @param str The camelCase string to convert
     * @return A human-readable label with spaces and proper capitalization
     * 
     * ## Examples
     * ```haxe
     * TextUtils.toFieldLabel("firstName");    // "First Name"
     * TextUtils.toFieldLabel("lastName");     // "Last Name"
     * TextUtils.toFieldLabel("emailAddress"); // "Email Address"
     * TextUtils.toFieldLabel("userID");       // "User I D"
     * ```
     */
    public static function toFieldLabel(str:String):String {

        var result = new StringBuf();

        for (i in 0...str.length) {
            var char = str.charAt(i);

            if (i == 0) {
                result.add(char.toUpperCase());
            }
            else if (char.toUpperCase() == char) {
                result.add(' ');
                result.add(char);
            }
            else {
                result.add(char);
            }
        }

        return result.toString();

    }

    /**
     * Performs a case-insensitive string comparison.
     * 
     * Compares two strings alphabetically, ignoring case differences.
     * This is useful for sorting strings in a case-insensitive manner.
     * 
     * @param a The first string to compare
     * @param b The second string to compare
     * @return -1 if a < b, 1 if a > b, 0 if they are equal (ignoring case)
     * 
     * ## Examples
     * ```haxe
     * TextUtils.compareStrings("apple", "BANANA");  // -1 (apple comes before banana)
     * TextUtils.compareStrings("Hello", "hello");   // 0 (equal ignoring case)
     * TextUtils.compareStrings("zebra", "apple");   // 1 (zebra comes after apple)
     * ```
     */
    public static function compareStrings(a:String, b:String) {
        a = a.toUpperCase();
        b = b.toUpperCase();

        if (a < b) {
          return -1;
        }
        else if (a > b) {
          return 1;
        }
        else {
          return 0;
        }
    }

    /**
     * Compares the first string entries of two arrays in a case-insensitive manner.
     * 
     * This function is useful for sorting arrays where the first element is a string
     * that should be used as the sort key. Both arrays must have at least one element.
     * 
     * @param aArray Array containing the first string to compare at index 0
     * @param bArray Array containing the second string to compare at index 0
     * @return -1 if aArray[0] < bArray[0], 1 if aArray[0] > bArray[0], 0 if equal (ignoring case)
     * 
     * ## Examples
     * ```haxe
     * var arr1 = ["apple", "red", 5];
     * var arr2 = ["BANANA", "yellow", 3];
     * TextUtils.compareStringFirstEntries(arr1, arr2); // -1 (apple < banana)
     * ```
     */
    public static function compareStringFirstEntries(aArray:Array<Dynamic>, bArray:Array<Dynamic>) {
        var a:String = aArray[0];
        var b:String = bArray[0];

        a = a.toUpperCase();
        b = b.toUpperCase();

        if (a < b) {
          return -1;
        }
        else if (a > b) {
          return 1;
        }
        else {
          return 0;
        }
    }

    /**
     * Transforms UPPER_CASE_WITH_UNDERSCORES to camelCase or PascalCase.
     * 
     * Converts underscore-separated uppercase strings to camelCase format,
     * with optional separators between words and configurable first letter casing.
     * 
     * @param input The UPPER_CASE string to convert
     * @param firstLetterUppercase Whether the first letter should be uppercase (PascalCase vs camelCase)
     * @param between Optional string to insert between converted words
     * @return The converted string in camelCase or PascalCase format
     * 
     * ## Examples
     * ```haxe
     * // Convert to PascalCase (default)
     * TextUtils.upperCaseToCamelCase("SOME_IDENTIFIER");           // "SomeIdentifier"
     * 
     * // Convert to camelCase
     * TextUtils.upperCaseToCamelCase("SOME_IDENTIFIER", false);    // "someIdentifier"
     * 
     * // Convert with separator
     * TextUtils.upperCaseToCamelCase("SOME_ID", true, " ");       // "Some Identifier"
     * ```
     */
    public static function upperCaseToCamelCase(input:String, firstLetterUppercase:Bool = true, ?between:String):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var nextLetterUpperCase = firstLetterUppercase;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '_') {
                nextLetterUpperCase = true;
            }
            else if (nextLetterUpperCase) {
                nextLetterUpperCase = false;
                if (i > 0 && between != null) {
                    res.add(between);
                }
                res.add(c.toUpperCase());
            }
            else {
                res.add(c.toLowerCase());
            }

            i++;
        }

        return res.toString();

    }

    /**
     * Extracts the non-numeric prefix from a string.
     * 
     * Removes any trailing numeric suffix and trailing underscores from a string,
     * leaving only the text prefix. This is useful for processing identifiers
     * that may have numeric suffixes.
     * 
     * @param str The string to extract the prefix from
     * @return The string with numeric suffixes and trailing underscores removed
     * 
     * ## Examples
     * ```haxe
     * TextUtils.getPrefix("item123");     // "item"
     * TextUtils.getPrefix("value_42");   // "value"
     * TextUtils.getPrefix("test_");      // "test"
     * TextUtils.getPrefix("simple");     // "simple"
     * ```
     */
    public static function getPrefix(str:String):String {

        if (RE_PREFIXED.match(str)) {
            str = RE_PREFIXED.matched(1);
        }
        while (str.length > 0 && str.charAt(str.length - 1) == '_') {
            str = str.substring(0, str.length - 1);
        }
        return str;

    }

    /**
     * Extracts an uppercase prefix from a fully qualified class name.
     * 
     * Takes a class name (potentially with package path) and converts the class part
     * to UPPER_CASE format, removing any trailing underscores. This is useful for
     * generating constants or identifiers from class names.
     * 
     * @param className The fully qualified class name (e.g., "com.example.MyClass")
     * @return The uppercase prefix derived from the class name
     * 
     * ## Examples
     * ```haxe
     * TextUtils.uppercasePrefixFromClass("com.example.MyClass");     // "MY_CLASS"
     * TextUtils.uppercasePrefixFromClass("SimpleClass");             // "SIMPLE_CLASS"
     * TextUtils.uppercasePrefixFromClass("utils.TextHelper");        // "TEXT_HELPER"
     * ```
     */
    public static function uppercasePrefixFromClass(className:String):String {

        var parts = className.split('.');
        var str = parts[parts.length-1];
        str = Utils.camelCaseToUpperCase(str);
        while (str.length > 0 && str.charAt(str.length - 1) == '_') {
            str = str.substring(0, str.length - 1);
        }
        return str;

    }

    /**
     * Slug options for uppercase conversion.
     * Configured to preserve uppercase and use underscores as separators.
     * @private
     */
    static final _slugUpperCase:SlugOptions = {
        lower: false,
        replacement: '_',
        remove: Slug.RE_SLUG_REMOVE_CHARS
    };

    /**
     * Converts a string to a slugified uppercase format.
     * 
     * Replaces spaces with underscores and applies slug encoding to create
     * a clean, uppercase identifier suitable for constants or keys.
     * 
     * @param str The string to slugify
     * @return A slugified uppercase string with underscores replacing spaces
     * 
     * ## Examples
     * ```haxe
     * TextUtils.slugifyUpperCase("My Variable Name");  // "MY_VARIABLE_NAME"
     * TextUtils.slugifyUpperCase("test-value");        // "TEST_VALUE"
     * TextUtils.slugifyUpperCase("Special Chars!");    // "SPECIAL_CHARS"
     * ```
     * 
     * @see Slug.encode
     */
    public static function slugifyUpperCase(str:String):String {

        str = RE_SPACES.replace(str, '_');
        str = Slug.encode(str, _slugUpperCase);
        return str;

    }

    /**
     * Sanitizes a string to make it suitable for use as an identifier.
     * 
     * Removes numeric prefixes, replaces spaces with underscores, and applies
     * slug encoding to ensure the result is a valid identifier. This is useful
     * for converting user input or arbitrary text into valid variable names.
     * 
     * @param str The string to sanitize
     * @return A sanitized string suitable for use as an identifier
     * 
     * ## Examples
     * ```haxe
     * TextUtils.sanitizeToIdentifier("123variable");    // "variable"
     * TextUtils.sanitizeToIdentifier("my variable");    // "my_variable"
     * TextUtils.sanitizeToIdentifier("special@chars");  // "special_chars"
     * TextUtils.sanitizeToIdentifier("42 test name");   // "test_name"
     * ```
     * 
     * @see Slug.encode
     */
    public static function sanitizeToIdentifier(str:String):String {

        str = RE_NUMERIC_PREFIX.replace(str, '');
        str = RE_SPACES.replace(str, '_');
        str = Slug.encode(str, {
            lower: false,
            replacement: '_'
        });
        return str;

    }

}