package be.appmire.secureqr.qr

object Iban {
    /** Removes spaces and upper-cases. */
    fun normalize(iban: String): String = iban.filterNot { it.isWhitespace() }.uppercase()

    /** Groups in blocks of four for display. */
    fun grouped(iban: String): String = normalize(iban).chunked(4).joinToString(" ")

    /**
     * ISO 13616 mod-97 check: move the first four characters to the end, map
     * A-Z to 10-35, and the resulting number mod 97 must equal 1.
     */
    fun isValid(iban: String): Boolean {
        val s = normalize(iban)
        if (s.length !in 15..34) return false
        if (!s.all { it in '0'..'9' || it in 'A'..'Z' }) return false
        val rearranged = s.substring(4) + s.substring(0, 4)
        var remainder = 0
        for (c in rearranged) {
            val n = if (c in '0'..'9') c - '0' else c - 'A' + 10
            remainder = if (n < 10) (remainder * 10 + n) % 97 else (remainder * 100 + n) % 97
        }
        return remainder == 1
    }
}
