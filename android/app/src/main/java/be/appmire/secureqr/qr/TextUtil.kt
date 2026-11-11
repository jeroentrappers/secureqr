package be.appmire.secureqr.qr

import java.io.ByteArrayOutputStream

/** Stand-in for an escaped comma while a value is still being split on commas. */
private const val ESCAPED_COMMA = ''

/** A `K:value` item from a Wi-Fi / MECARD / MATMSG style payload. */
internal class KeyValue(val key: String, private val rawValue: String) {
    val value: String get() = rawValue.replace(ESCAPED_COMMA, ',')

    /** The value split on unescaped commas. */
    val parts: List<String> get() = rawValue.split(',').map { it.replace(ESCAPED_COMMA, ',').trim() }
}

/**
 * Parses `K:value;K:value;;` where `\;`, `\:`, `\,` and `\\` are escapes.
 * Keys are upper-cased; items without a key are dropped.
 */
internal fun parseKeyValues(body: String): List<KeyValue> {
    val out = ArrayList<KeyValue>()
    val key = StringBuilder()
    val value = StringBuilder()
    var inValue = false

    fun flush() {
        val k = key.toString().trim().uppercase()
        if (k.isNotEmpty()) out += KeyValue(k, value.toString())
        key.setLength(0)
        value.setLength(0)
        inValue = false
    }

    var i = 0
    while (i < body.length) {
        val c = body[i]
        val target = if (inValue) value else key
        when {
            c == '\\' && i + 1 < body.length && body[i + 1] in "\\;:," -> {
                val next = body[i + 1]
                target.append(if (next == ',') ESCAPED_COMMA else next)
                i++
            }
            c == ':' && !inValue -> inValue = true
            c == ';' -> flush()
            else -> target.append(c)
        }
        i++
    }
    flush()
    return out
}

/** Splits on [separator] wherever it is not preceded by a backslash escape; segments stay escaped. */
internal fun splitUnescaped(text: String, separator: Char): List<String> {
    val out = ArrayList<String>()
    val current = StringBuilder()
    var i = 0
    while (i < text.length) {
        val c = text[i]
        when {
            c == '\\' && i + 1 < text.length -> {
                current.append(c).append(text[i + 1])
                i++
            }
            c == separator -> {
                out += current.toString()
                current.setLength(0)
            }
            else -> current.append(c)
        }
        i++
    }
    out += current.toString()
    return out
}

/** Percent-decodes as UTF-8. Malformed escapes are kept as they are. */
internal fun percentDecode(text: String, plusAsSpace: Boolean = false): String {
    if ('%' !in text && !(plusAsSpace && '+' in text)) return text
    val bytes = ByteArrayOutputStream(text.length)
    var i = 0
    while (i < text.length) {
        val c = text[i]
        if (c == '%' && i + 2 < text.length) {
            val hi = Character.digit(text[i + 1], 16)
            val lo = Character.digit(text[i + 2], 16)
            if (hi >= 0 && lo >= 0) {
                bytes.write(hi * 16 + lo)
                i += 3
                continue
            }
        }
        if (c == '+' && plusAsSpace) {
            bytes.write(' '.code)
            i++
        } else {
            val codePoint = text.codePointAt(i)
            val chars = Character.charCount(codePoint)
            bytes.write(text.substring(i, i + chars).toByteArray(Charsets.UTF_8))
            i += chars
        }
    }
    return bytes.toString(Charsets.UTF_8.name())
}

/** A URI-style payload split on the first `?`. Query keys are lower-cased. */
internal class UriParts(val path: String, val query: Map<String, String>) {
    operator fun get(key: String): String? = query[key]?.takeIf { it.isNotEmpty() }
}

/** [text] is everything after the scheme prefix. */
internal fun splitUri(text: String, plusAsSpace: Boolean = false): UriParts {
    val q = text.indexOf('?')
    if (q < 0) return UriParts(text, emptyMap())
    val query = LinkedHashMap<String, String>()
    for (pair in text.substring(q + 1).split('&')) {
        if (pair.isEmpty()) continue
        val eq = pair.indexOf('=')
        val key = (if (eq < 0) pair else pair.substring(0, eq)).lowercase()
        val value = if (eq < 0) "" else pair.substring(eq + 1)
        if (key !in query) query[key] = percentDecode(value, plusAsSpace)
    }
    return UriParts(text.substring(0, q), query)
}

/** Lower-cased host of an http(s)-style URL, or null when there is none. */
fun hostOf(url: String): String? {
    val match = HOST_REGEX.find(url.trim()) ?: return null
    return match.groupValues[1].lowercase().takeIf { it.isNotEmpty() }
}

private val HOST_REGEX = Regex("^[a-zA-Z][a-zA-Z0-9+.-]*:/*(?:[^/?#@]*@)?(\\[[^\\]]*]|[^/?#:]*)")
