package serve;

class Utils {

    public static function normalizeHeaderName(name:String):String {

        var needsNormalization = false;
        var afterHyphen = true;

        // First pass: check if normalization is needed
        for (i in 0...name.length) {
            var charCode = name.charCodeAt(i);

            if (charCode == "-".code) {
                afterHyphen = true;
            } else if (afterHyphen) {
                // Should be uppercase
                if (charCode >= "a".code && charCode <= "z".code) { // lowercase letter
                    needsNormalization = true;
                    break;
                }
                afterHyphen = false;
            } else {
                // Should be lowercase
                if (charCode >= "A".code && charCode <= "Z".code) { // uppercase letter
                    needsNormalization = true;
                    break;
                }
            }
        }

        // If already normalized, return as-is (no allocation)
        if (!needsNormalization) {
            return name;
        }

        // Second pass: build normalized string
        var result = new StringBuf();
        afterHyphen = true;

        for (i in 0...name.length) {
            var charCode = name.charCodeAt(i);

            if (charCode == "-".code) {
                result.addChar(charCode);
                afterHyphen = true;
            } else if (afterHyphen) {
                // Convert to uppercase if needed
                if (charCode >= "a".code && charCode <= "z".code) { // lowercase a-z
                    result.addChar(charCode - ("a".code - "A".code)); // Convert to uppercase
                } else {
                    result.addChar(charCode);
                }
                afterHyphen = false;
            } else {
                // Convert to lowercase if needed
                if (charCode >= "A".code && charCode <= "Z".code) { // uppercase A-Z
                    result.addChar(charCode + ("a".code - "A".code)); // Convert to lowercase
                } else {
                    result.addChar(charCode);
                }
            }
        }

        return result.toString();

    }

    public static function matchRoute(pattern:String, input:String, code:Int):Null<Dynamic<String>> {

        var patternLen = pattern.length;
        var inputLen = input.length;
        var patternPos = 0;
        var inputPos = 0;
        var result:Dynamic = null;

        while (patternPos < patternLen && inputPos < inputLen) {
            if (pattern.charCodeAt(patternPos) == code) {
                // Found a parameter
                patternPos++; // Skip $

                // Find parameter name end (next / or end of string)
                var paramStart = patternPos;
                while (patternPos < patternLen && pattern.charCodeAt(patternPos) != "/".code) {
                    patternPos++;
                }

                // Extract parameter name
                var paramName = pattern.substr(paramStart, patternPos - paramStart);

                // Find the value in input (until next / or end)
                var valueStart = inputPos;
                while (inputPos < inputLen && input.charCodeAt(inputPos) != "/".code) {
                    inputPos++;
                }

                if (valueStart == inputPos) {
                    // Empty value not allowed
                    return null;
                }

                // Extract and store the value
                if (result == null) {
                    result = {};
                }
                Reflect.setField(result, paramName, input.substr(valueStart, inputPos - valueStart));
            } else {
                // Match literal characters
                if (pattern.charCodeAt(patternPos) != input.charCodeAt(inputPos)) {
                    return null;
                }
                patternPos++;
                inputPos++;
            }
        }

        // Check if we consumed both strings entirely
        if (patternPos != patternLen || inputPos != inputLen) {
            return null;
        }

        return result ?? {};

    }

}