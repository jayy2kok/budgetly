# Token-Template SMS-Parsing Upgrade – Plan for Sherlock

> **Goal** – Replace the "LLM-writes-regex" step with a *template-generation* step that is far less error-prone, and then turn that template into a deterministic, cross-language regular expression on the backend.
> **Result** – Every new sender that the LLM sees for the first time will be stored as a `SmsPattern` whose `regex` field is **generated automatically** from a safe template, guaranteeing that the Dart-side `RegExp` and the Java-side `java.util.regex` behave identically.

---

## 1. High-Level Flow

| Phase | Current Implementation | New Implementation (Token-Template) |
|-------|------------------------|--------------------------------------|
| **Inbox read** (Flutter) | ✅ Load cached `SmsPattern`s → `RegExp` match → fallback to LLM if no match. | ✅ Same, but patterns now contain a *template*-derived regex. |
| **Backend processing** (Spring) | ✅ LLM returns JSON `{amount, merchant, timestamp, …, regex}` → store `SmsPattern`. | ✅ LLM returns **template** string (e.g. `"Spent Rs {amount} at {merchant} via UPI"`). Backend **converts** that template into a strict regex and stores it. |
| **Pattern cache sync** (Flutter) | ✅ Pull raw regex from `/patterns`. | ✅ Pull raw regex (unchanged for the client). |
| **Future SMS** | ✅ Match against stored regex. | ✅ Same – the regex is now guaranteed to be syntactically correct. |

---

## 2. Backend – Template → Regex Converter

Create a new service class `TemplateRegexService` under `com.budgetly.api.service`:

```java
package com.budgetly.api.service;

import org.springframework.stereotype.Service;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class TemplateRegexService {

    private static final Pattern TOKEN_PATTERN = Pattern.compile("\\{([^}]+)\\}");

    /**
     * Turns a tokenised template (e.g. "Spent Rs {amount} at {merchant} on {timestamp}")
     * into a Java-compatible regex with named capture groups.
     */
    public String generateRegex(String template, Map<String, String> extractionMap) {
        // Escape all regex meta-characters outside of tokens
        String escaped = Pattern.quote(template);

        // Undo the quoting for token placeholders, then replace each with a named group
        Matcher m = TOKEN_PATTERN.matcher(escaped);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String token = m.group(1);
            String groupPattern = defaultPatternFor(token);
            String namedGroup = "(?<" + token + ">" + groupPattern + ")";
            m.appendReplacement(sb, namedGroup);
        }
        m.appendTail(sb);
        
        // Un-quote the surrounding literal text
        return sb.toString()
                 .replaceAll("^\\\\Q", "")
                 .replaceAll("\\\\E$", "")
                 .replaceAll("\\\\E\\\\Q", ""); 
    }

    private String defaultPatternFor(String token) {
        return switch (token) {
            case "amount"    -> "\\d+(?:\\.\\d+)?";
            case "timestamp" -> "\\d{2}/\\d{2}/\\d{4}|\\d{4}-\\d{2}-\\d{2}";
            case "merchant"  -> ".+?";
            case "accountLast4" -> "\\d{4}";
            default           -> ".+?"; 
        };
    }
}
```

Integration point for `MessageService.java`:
```java
String template = llmResult.getTemplate(); 
Map<String, String> extractionMap = llmResult.getExtractionMap();
String regex = templateRegexService.generateRegex(template, extractionMap);

// Store standard Regex going forward
```

---

## 3. LLM Prompt – Return a Template, Not a Regex

Modify the prompt in `GeminiLlmProvider` to ask for **two fields**:

1. **`template`** – the raw SMS with *tokens* in curly braces.
2. **`extractionMap`** – a map from token name → target field (`amount`, `merchant`, `timestamp`, …).

Prompt rules to add:
- Only use the tokens listed in `extractionMap`.
- Do not include any regex syntax (e.g. `.*`, `\\d`) – output plain text with `{}` placeholders.

---

## 4. Data-Model Adjustments

*   **`LlmAnalysisResult`**: Add `String template;` and `Map<String,String> extractionMap;`.
*   **`GeminiLlmProvider`**: Update JSON parsing to parse the new structure.
*   **`MessageService`**: Call `TemplateRegexService` before saving `SmsPatternDocument`.

---

## 5. End-to-End Test Plan

1. **Unit test**: `TemplateRegexServiceTest` to ensure templates correctly become `(?<amount>\d+(?:\.\d+)?)` style regex strings.
2. **Integration test**: `MessageService` flow with a mocked LLM response returning a template.
3. **Run CI**: `mvn verify` in `budgetly_api`.
