# The names and numbers that a page of HTML writes characters with, like
# &amp; and &#8217;, and the bytes of Windows-1252 and ISO-8859-1 as text.
# Used by web/, mime.jl, linkcard.jl and feeds.jl.
#
#     entities("Tom &amp; Sam&rsquo;s")            # "Tom & Sam’s"
#     latin(UInt8[0x63, 0x61, 0x66, 0xe9, 0x80])   # "café€"

# What the bytes 0x80 to 0x9f mean in Windows-1252. ISO-8859-1 has no characters there, and
# pages and emails that say ISO-8859-1 often mean Windows-1252, so both read the same way.
const CP1252 = Char[0x20ac, 0x81, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8d, 0x017d, 0x8f,
                    0x90, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, 0x9d, 0x017e, 0x0178]

"Names that pages and emails give to ISO-8859-1 and Windows-1252"
const LATIN_NAMES = ("iso-8859-1", "iso8859-1", "iso_8859-1", "latin1", "l1", "windows-1252", "cp1252", "cp-1252", "x-cp1252")

"Bytes of Windows-1252 or ISO-8859-1 as text"
latin(bytes) = String(Char[0x80 <= b <= 0x9f ? CP1252[b-0x7f] : Char(b) for b in bytes])

const NAMED = Dict{String,String}(
  "amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"", "apos" => "'", "nbsp" => "\u00a0", "copy" => "©", "reg" => "®", "trade" => "™",
  "hellip" => "…", "mdash" => "—", "ndash" => "–", "lsquo" => "‘", "rsquo" => "’", "sbquo" => "‚", "ldquo" => "“", "rdquo" => "”",
  "bdquo" => "„", "bull" => "•", "middot" => "·", "laquo" => "«", "raquo" => "»", "lsaquo" => "‹", "rsaquo" => "›", "euro" => "€",
  "pound" => "£", "yen" => "¥", "cent" => "¢", "curren" => "¤", "deg" => "°", "times" => "×", "divide" => "÷", "frac12" => "½",
  "frac14" => "¼", "frac34" => "¾", "plusmn" => "±", "sect" => "§", "para" => "¶", "micro" => "µ", "sup1" => "¹", "sup2" => "²",
  "sup3" => "³", "ordf" => "ª", "ordm" => "º", "iexcl" => "¡", "iquest" => "¿", "not" => "¬", "brvbar" => "¦", "uml" => "¨",
  "acute" => "´", "cedil" => "¸", "macr" => "¯", "tilde" => "˜", "circ" => "ˆ", "dagger" => "†", "Dagger" => "‡", "permil" => "‰",
  "prime" => "′", "Prime" => "″", "minus" => "−", "le" => "≤", "ge" => "≥", "ne" => "≠", "asymp" => "≈", "infin" => "∞",
  "larr" => "←", "rarr" => "→", "uarr" => "↑", "darr" => "↓", "harr" => "↔", "rArr" => "⇒", "hearts" => "♥", "check" => "✓",
  "star" => "☆", "starf" => "★", "zwnj" => "\u200c", "zwj" => "\u200d", "lrm" => "\u200e", "rlm" => "\u200f", "shy" => "\u00ad",
  "ensp" => "\u2002", "emsp" => "\u2003", "thinsp" => "\u2009", "hairsp" => "\u200a", "numsp" => "\u2007",
  "agrave" => "à", "aacute" => "á", "acirc" => "â", "atilde" => "ã", "auml" => "ä", "aring" => "å", "aelig" => "æ", "ccedil" => "ç",
  "egrave" => "è", "eacute" => "é", "ecirc" => "ê", "euml" => "ë", "igrave" => "ì", "iacute" => "í", "icirc" => "î", "iuml" => "ï",
  "eth" => "ð", "ntilde" => "ñ", "ograve" => "ò", "oacute" => "ó", "ocirc" => "ô", "otilde" => "õ", "ouml" => "ö", "oslash" => "ø",
  "ugrave" => "ù", "uacute" => "ú", "ucirc" => "û", "uuml" => "ü", "yacute" => "ý", "thorn" => "þ", "yuml" => "ÿ", "szlig" => "ß",
  "Agrave" => "À", "Aacute" => "Á", "Acirc" => "Â", "Atilde" => "Ã", "Auml" => "Ä", "Aring" => "Å", "AElig" => "Æ", "Ccedil" => "Ç",
  "Egrave" => "È", "Eacute" => "É", "Ecirc" => "Ê", "Euml" => "Ë", "Igrave" => "Ì", "Iacute" => "Í", "Icirc" => "Î", "Iuml" => "Ï",
  "ETH" => "Ð", "Ntilde" => "Ñ", "Ograve" => "Ò", "Oacute" => "Ó", "Ocirc" => "Ô", "Otilde" => "Õ", "Ouml" => "Ö", "Oslash" => "Ø",
  "Ugrave" => "Ù", "Uacute" => "Ú", "Ucirc" => "Û", "Uuml" => "Ü", "Yacute" => "Ý", "THORN" => "Þ", "oelig" => "œ", "OElig" => "Œ",
  "scaron" => "š", "Scaron" => "Š", "Yuml" => "Ÿ")
const ENTITY = r"&(#[0-9]{1,8}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{1,10});"

"The character with the number `n`, as a page of HTML means it"
numbered(n) = 0x80 <= n <= 0x9f ? string(CP1252[n-0x7f]) : n > 0 && isvalid(Char, n) ? string(Char(n)) : "\ufffd"

"`s` with each name like &amp; and each number like &#8217; as its character. A name that isn't known stays."
entities(s::AbstractString) = begin
  occursin('&', s) || return String(s)
  replace(s, ENTITY => m -> begin
    body = SubString(m, 2, lastindex(m) - 1)
    startswith(body, "#x") || startswith(body, "#X") ? numbered(parse(Int, SubString(body, 3), base=16)) :
    startswith(body, '#') ? numbered(parse(Int, SubString(body, 2))) : get(NAMED, body, String(m))
  end)
end
