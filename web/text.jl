# Finds the fonts that a page asks for, and measures text in them.
#
#     f = font(["Helvetica Neue", "Arial", "sans-serif"], 14, 700, false)
#     f = font(["Archivo"], 50, 800, false, 78)   # 78% of its normal width, as `font-stretch: 78%` asks
#     f.ascent, f.descent      # how far its letters go over and under the line they stand on, in px
#     normal(f)                # how tall a line of it is when the page says no line height
#     d = drawn(f, 'é')        # the font that has the letter, which glyph of it, and how wide it is
#     widths(f, "Hi there")    # how wide each letter is
#
# The font is the first of the page's families that this computer has. A
# letter that the font doesn't have is drawn in a font that has it, which the
# system picks: an emoji, or a letter of another script. `serif`, `sans-serif`
# and `monospace` are the fonts that Safari uses for them.
#
#     advances(f, collect("AV"))   # how wide each letter is in a run of text, where the font moves some pairs together
#
# On a Mac, `advances` asks Core Text, the Mac's own text system, so a run of
# text is as wide as Safari draws it: with the font's kerning, and with the
# system font's own spacing at each size. Anywhere else, each letter is as
# wide as it is alone.
#
# A variable font, which has all of its weights and widths in one file, is
# drawn at the weight and the width that the page asks for, as far as its
# @font-face says that it goes. Core Text sets the font's axes, and Skia's
# face is made from Core Text's font, so what's measured is what's drawn.

@use Skia
@use Libdl: dlopen, dlsym

struct Font
  raw::Ptr{Skia.sk_font_t}
  face::Ptr{Skia.sk_typeface_t}
  family::String
  size::Float64
  ascent::Float64
  descent::Float64
  gap::Float64          # the room that the font asks for between two lines
  xheight::Float64
  under::Float64        # how far under the line an underline is, and how thick
  thick::Float64
  core::Ptr{Cvoid}      # Core Text's font for it, or C_NULL
end

"How tall a line of the font is when nothing says a line height"
normal(f::Font) = f.ascent + f.descent + f.gap

const manager = Ref{Ptr{Skia.sk_font_mgr_t}}(C_NULL)
const fonts = Dict{Tuple{String,Float64,Int,Bool,Float64},Font}()
const faces = Dict{Tuple{String,Int,Bool,Float64},Ptr{Skia.sk_typeface_t}}()
const variants = Dict{Tuple{Ptr{Skia.sk_typeface_t},Any,Float64},Ptr{Skia.sk_typeface_t}}()
const made_for = Dict{Ptr{Skia.sk_typeface_t},Tuple{Any,Float64}}()   # the weight and the width that each face of `variants` was made for
const sized = Dict{Tuple{Ptr{Skia.sk_typeface_t},Float64},Font}()
const glyphs = Dict{Tuple{Ptr{Skia.sk_font_t},Char},Tuple{Font,UInt16,Float64}}()
const stand_ins = Dict{Tuple{Char,Int,Bool},Ptr{Skia.sk_typeface_t}}()
const installed = Dict{String,Bool}()
const spaces = Dict{Ptr{Skia.sk_font_t},Float64}()

"A face of a font that a page gives with @font-face"
mutable struct WebFace
  weights::Tuple{Int,Int}                # the first and the last weight that it's for
  italic::Bool
  ranges::Vector{UnitRange{UInt32}}      # the letters that it's for, or none for all
  sources::Vector{Any}                   # each the name of a font of this computer, or a function that gives the bytes of a file
  face::Ptr{Skia.sk_typeface_t}          # C_NULL until its file is read
  widths::Tuple{Float64,Float64}         # the narrowest and the widest that it's for, in percent of a normal width
end
const web = Dict{String,Vector{WebFace}}()
# Core Text's description of each face that came from a file, so that its text is measured with the file's own widths
const described = Dict{Ptr{Skia.sk_typeface_t},Ptr{Cvoid}}()

# What Skia made is gone when the process ends, so a compiled app starts with none of it
__init__() = (manager[] = C_NULL; foreach(empty!, (fonts, faces, variants, made_for, sized, glyphs, stand_ins, installed, spaces, web, described)))

"Skia's font manager. The faces of the system font are found when it's first asked for, while Skia is sure to find them."
mgr() = begin
  manager[] == C_NULL || return manager[]
  manager[] = Skia.sk_fontmgr_ref_default()
  for weight in 100:100:900, italic in (false, true)
    face(SYSTEM, weight, italic)
  end
  manager[]
end

const SYSTEM = ".AppleSystemUIFont"
# The fonts that Safari draws these names with
const GENERIC = Dict("serif" => "Times", "sans-serif" => "Helvetica", "monospace" => "Courier", "cursive" => "Apple Chancery", "fantasy" => "Papyrus",
                     "system-ui" => SYSTEM, "-apple-system" => SYSTEM, "blinkmacsystemfont" => SYSTEM,
                     "ui-sans-serif" => SYSTEM, "ui-rounded" => SYSTEM, "ui-serif" => "Times", "ui-monospace" => "Menlo",
                     "math" => "STIX Two Math", "emoji" => "Apple Color Emoji")
const STANDARD = "Times"

covers(f::WebFace, c::Char) = isempty(f.ranges) || any(r -> UInt32(c) in r, f.ranges)

"Read the file of the face `f`, from the first of its sources that gives one"
load!(f::WebFace) = begin
  f.face == C_NULL || return f.face
  for src in f.sources
    if src isa AbstractString
      has(src) || continue
      st = style(100clamp(round(Int, sum(f.weights) / 200), 1, 9), f.italic)
      f.face = Skia.sk_fontmgr_match_family_style(mgr(), String(src), st)
      Skia.sk_fontstyle_delete(st)
    else
      bytes = try src() catch; nothing end
      (bytes === nothing || isempty(bytes)) && continue
      bytes = Vector{UInt8}(bytes)
      data = Skia.sk_data_new_with_copy(bytes, Csize_t(length(bytes)))
      f.face = Skia.sk_fontmgr_create_from_data(mgr(), data, Cint(0))
      Skia.sk_data_unref(data)
      f.face == C_NULL || describe!(f.face, bytes)
    end
    f.face == C_NULL || break
  end
  f.face
end

"Keep Core Text's description of the font in `bytes`, for the face that Skia made of them"
describe!(face, bytes) = begin
  Sys.isapple() || return
  try
    data = ccall((:CFDataCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Clong), C_NULL, bytes, length(bytes))
    desc = ccall((:CTFontManagerCreateFontDescriptorFromData, CT), Ptr{Cvoid}, (Ptr{Cvoid},), data)
    release(data)
    desc == C_NULL || (described[face] = desc)
  catch
  end
  nothing
end

"How far `x` is from the range `(lo, hi)`: 0 inside it"
off(x, (lo, hi)) = lo <= x <= hi ? 0.0 : Float64(min(abs(x - lo), abs(x - hi)))

"""
The face of the page's font `key` that's nearest the width, the slant and the
weight, in that order as in a browser, of those that have the letter `c` and
whose file can be read. Nothing when there's none.
"""
picked(key, weight, italic, c::Char='A'; width=100.0) = begin
  far(f) = (off(width, f.widths), f.italic != italic, off(weight, f.weights))
  for f in sort(filter(f -> covers(f, c), web[key]); by=far)
    load!(f) == C_NULL || return f
  end
  nothing
end

"The typeface of `picked`, or C_NULL"
pick(key, weight, italic, c::Char='A'; width=100.0) = (f = picked(key, weight, italic, c; width); f === nothing ? Ptr{Skia.sk_typeface_t}(C_NULL) : f.face)

"""
Note the faces that a page's @font-face rules give a font, under the name
`key`. Each is its weights, whether it's italic, the letters that it's for
and its sources. It's true when a face for plain text can be read, so that
`key` can be used as a family.
"""
web!(key::String, faces) = begin
  found = get!(web, key) do
    [WebFace(f[1], f[2], f[3], f[4], C_NULL, length(f) > 4 ? f[5] : (100.0, 100.0)) for f in faces]
  end
  # The sources of a font that couldn't be read are asked again: a file may have come from the web since
  for (f, given) in zip(found, faces)
    f.face == C_NULL && (f.sources = given[4])
  end
  pick(key, 400, false) != C_NULL
end

"True when this computer has a font of the family `name`"
has(name::AbstractString) = haskey(web, name) || get!(installed, name) do
  set = Skia.sk_fontmgr_match_family(mgr(), name)
  set == C_NULL && return false
  n = Skia.sk_fontstyleset_get_count(set)
  Skia.sk_fontstyleset_unref(set)
  n > 0
end

"The first of `families` that this computer has, or the font that a page with no font gets"
family(families) = begin
  for name in families
    name = get(GENERIC, lowercase(name), name)
    has(name) && return name
  end
  STANDARD
end

# Skia's nine widths, from ultra-condensed to ultra-expanded, as percents of a normal width
const WIDTHS = (50.0, 62.5, 75.0, 87.5, 100.0, 112.5, 125.0, 150.0, 200.0)

style(weight, italic, width=100.0) = Skia.sk_fontstyle_new(Int32(weight), Int32(argmin(abs.(WIDTHS .- width))),
                                                           italic ? Skia.SK_FONT_STYLE_SLANT_ITALIC : Skia.SK_FONT_STYLE_SLANT_UPRIGHT)

"""
The typeface of `name` that's nearest the weight, the slant and the width, in
percent of a normal width. The weight is one of the nine from 100 to 900:
Skia finds no system font for a weight between two of them, like 550, and
after it's asked for one it finds no system font at all.
"""
face(name::String, weight::Int, italic::Bool, width::Real=100.0) = begin
  weight = 100clamp(round(Int, weight / 100), 1, 9)
  width = Float64(width)
  get!(faces, (name, weight, italic, width)) do
    if haskey(web, name)
      f = picked(name, weight, italic; width)
      # A variable font is drawn at the weight and the width that its @font-face allows, nearest those asked for
      f === nothing || return varied(f.face, clamp(weight, f.weights...), clamp(width, f.widths...))
    end
    st = style(weight, italic, width)
    found = haskey(web, name) ? Ptr{Skia.sk_typeface_t}(C_NULL) : Skia.sk_fontmgr_match_family_style(mgr(), name, st)
    # A family that has no such face, which shouldn't happen, is drawn in the font that every Mac has
    found == C_NULL && name != STANDARD && (found = Skia.sk_fontmgr_match_family_style(mgr(), STANDARD, st))
    Skia.sk_fontstyle_delete(st)
    width == 100 || found == C_NULL || (found = narrowed(found, name, weight, italic, width))
    found
  end
end

"""
The face `found` of a font of this computer for text `width` percent of its
normal width: one with a width axis, set to it, or the face of that width that
Skia found. Core Text measures that face. A family with no face of another
width keeps its normal face, as in a browser.
"""
narrowed(found, name, weight, italic, width) = begin
  v = varied(found, nothing, width)
  v == found || return v
  normal = face(name, weight, italic, 100.0)
  found == normal && return normal
  own!(found)
  found
end

# The tags of a variable font's axes of weight and of width
const WGHT, WDTH = 0x77676874, 0x77647468

"Core Text's font of the Skia face `face`, or C_NULL. Skia keeps it."
ct_font(face) = Sys.isapple() && face != C_NULL ? ccall((:_Z23SkTypeface_GetCTFontRefPK10SkTypeface, Skia.libskia), Ptr{Cvoid}, (Ptr{Cvoid},), face) : C_NULL

"Keep Core Text's description of the face that Skia found, so that its text is measured in that face"
own!(face) = begin
  haskey(described, face) && return
  ct = ct_font(face)
  ct == C_NULL || (described[face] = ccall((:CTFontCopyFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid},), ct))
  nothing
end

"The axes of the variable font `ct`: the tag of each, with its least, its usual and its most"
variation_axes(ct) = begin
  out = Dict{UInt32,NTuple{3,Float64}}()
  list = ccall((:CTFontCopyVariationAxes, CT), Ptr{Cvoid}, (Ptr{Cvoid},), ct)
  list == C_NULL && return out
  field(d, key) = ccall((:CFDictionaryGetValue, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}), d, named(CT, key))
  for i in 0:ccall((:CFArrayGetCount, CF), Clong, (Ptr{Cvoid},), list)-1
    d = ccall((:CFArrayGetValueAtIndex, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Clong), list, i)
    tag = UInt32(cf_int(field(d, :kCTFontVariationAxisIdentifierKey)) & 0xffffffff)
    out[tag] = (cf_float(field(d, :kCTFontVariationAxisMinimumValueKey)), cf_float(field(d, :kCTFontVariationAxisDefaultValueKey)),
                cf_float(field(d, :kCTFontVariationAxisMaximumValueKey)))
  end
  release(list)
  out
end

"""
The face `face` of a variable font with its weight axis set to `weight` (left
as it is when that's nothing) and its width axis to `width` percent, where it
has them. `face` itself when it has neither. The new face is made from Core
Text's font, so Core Text measures what Skia draws.
"""
varied(face, weight, width) = get!(variants, (face, weight, Float64(width))) do
  ct = ct_font(face)
  ct == C_NULL && return face
  has = variation_axes(ct)
  want = Tuple{UInt32,Float64}[]
  weight === nothing || !haskey(has, WGHT) || push!(want, (WGHT, clamp(Float64(weight), has[WGHT][1], has[WGHT][3])))
  haskey(has, WDTH) && push!(want, (WDTH, clamp(Float64(width), has[WDTH][1], has[WDTH][3])))
  isempty(want) && return face
  desc = ccall((:CTFontCopyFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid},), ct)
  for (tag, x) in want
    id = cf_number(Int32(reinterpret(Int32, tag)))
    next = ccall((:CTFontDescriptorCreateCopyWithVariation, CT), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Float64), desc, id, x)
    foreach(release, (id, desc))
    desc = next
  end
  font = ccall((:CTFontCreateWithFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid}, Float64, Ptr{Cvoid}), desc, 12.0, C_NULL)
  # Skia gives a counted pointer, a C++ object that's handed back in memory that the caller gives: a return
  # value of more than 16 bytes is handed back that way too, so Julia gives the memory. The pointer is the first 8 bytes.
  made = Ptr{Skia.sk_typeface_t}(ccall((:_Z24SkMakeTypefaceFromCTFontPK8__CTFont, Skia.libskia), NTuple{3,UInt}, (Ptr{Cvoid},), font)[1])
  release(font)
  made == C_NULL && (release(desc); return face)
  described[made] = desc
  made_for[made] = (weight, Float64(width))
  made
end

"The name of the family of a typeface"
family_name(face) = begin
  str = Skia.sk_typeface_get_family_name(face)
  name = unsafe_string(Skia.sk_string_get_c_str(str))
  Skia.sk_string_delete(str)
  name
end

"The typeface `face` at `size` px"
at(face::Ptr{Skia.sk_typeface_t}, size::Float64, name=family_name(face)) = get!(sized, (face, size)) do
  raw = Skia.sk_font_new_with_values(face, Float32(size), 1f0, 0f0)
  Skia.sk_font_set_subpixel(raw, true)
  Skia.sk_font_set_hinting(raw, Skia.SK_FONT_HINTING_NONE)
  m = Ref{Skia.sk_font_metrics_t}()
  Skia.sk_font_get_metrics(raw, m)
  near(x) = round(x, RoundNearestTiesAway)
  ascent, descent, gap = near(-m[].ascent), near(m[].descent), near(m[].leading)
  # Safari makes these three taller, to match the fonts that Windows has of the same names
  name in ("Times", "Helvetica", "Courier") && (ascent += floor((ascent + descent) * 0.15 + 0.5))
  thick = m[].underlineThickness > 0 ? Float64(m[].underlineThickness) : size / 16
  under = m[].underlinePosition > 0 ? Float64(m[].underlinePosition) : size / 10
  st = Skia.sk_typeface_get_fontstyle(face)
  weight, italic = Int(Skia.sk_fontstyle_get_weight(st)), Skia.sk_fontstyle_get_slant(st) != Skia.SK_FONT_STYLE_SLANT_UPRIGHT
  Skia.sk_fontstyle_delete(st)
  core = haskey(described, face) ? (size > 0 ? ccall((:CTFontCreateWithFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid}, Float64, Ptr{Cvoid}), described[face], size, C_NULL) : C_NULL) :
         haskey(web, name) ? C_NULL : core_font(name, weight, italic, size)
  Font(raw, face, name, size, ascent, descent, gap, m[].xHeight > 0 ? Float64(m[].xHeight) : size / 2, under, thick, core)
end

"The font for text that asks for `families` in turn, `size` px tall, of a weight from 100 to 900, and `width` percent of its normal width"
font(families, size::Real, weight::Integer=400, italic::Bool=false, width::Real=100.0) = begin
  size = round(Float64(size), digits=2)
  get!(fonts, (join(families, ','), size, weight, italic, Float64(width))) do
    name = family(families)
    at(face(name, Int(weight), italic, width), size, name)
  end
end

# These take no room and draw nothing: spaces of no width, marks that say how letters join, and the soft hyphen
invisible(c::Char) = c == '­' || c == '͏' || '​' <= c <= '‏' || c == '⁠' || c == '﻿' || '︀' <= c <= '️' ||
                     '‪' <= c <= '‮' || '⁦' <= c <= '⁩' || c == '؜'

"""
How the letter `c` is drawn in text of the font `f`: the font that has it,
which is `f` when `f` has it, the glyph, and how wide it is in px. The glyph
is 0 for a letter that draws nothing.
"""
drawn(f::Font, c::Char) = get!(glyphs, (f.raw, c)) do
  invisible(c) && return (f, 0x0000, 0.0)
  c in ('\n', '\r', '\t', '\f') && (c = ' ')
  g = Skia.sk_font_unichar_to_glyph(f.raw, Int32(c))
  use = f
  if g == 0
    other = stand_in(f, c)
    if other !== nothing
      use = other
      g = Skia.sk_font_unichar_to_glyph(use.raw, Int32(c))
    end
  end
  wide = Ref{Cfloat}(0)
  id = Ref{UInt16}(g)
  Skia.sk_font_glyph_widths(use.raw, id, Cint(1), wide)
  (use, g, Float64(wide[]))
end

"A font of the size of `f` that has the letter `c`, which the system picks, or nothing"
stand_in(f::Font, c::Char) = begin
  if haskey(web, f.family)
    # Another file of the page's font may have the letter: a font from the web comes in parts, each for some letters
    st = Skia.sk_typeface_get_fontstyle(f.face)
    weight, italic = Int(Skia.sk_fontstyle_get_weight(st)), Skia.sk_fontstyle_get_slant(st) != Skia.SK_FONT_STYLE_SLANT_UPRIGHT
    Skia.sk_fontstyle_delete(st)
    # A face of a variable font has the weight and the width that it was made for, and so has the one for the letter
    asked, width = get(made_for, f.face, (weight, 100.0))
    weight = something(asked, weight)
    p = picked(f.family, weight, italic, c; width)
    other = p === nothing ? Ptr{Skia.sk_typeface_t}(C_NULL) : varied(p.face, clamp(weight, p.weights...), clamp(width, p.widths...))
    other != C_NULL && other != f.face && Skia.sk_font_unichar_to_glyph(at(other, f.size, f.family).raw, Int32(c)) != 0 && return at(other, f.size, f.family)
  end
  found = get!(stand_ins, (c, 400, false)) do
    st = style(400, false)
    face = Skia.sk_fontmgr_match_family_style_character(mgr(), f.family, st, C_NULL, Int32(0), Int32(c))
    Skia.sk_fontstyle_delete(st)
    face
  end
  found == C_NULL ? nothing : at(found, f.size)
end

"How wide each letter of `text` is in the font `f`, in px"
widths(f::Font, text) = Float64[drawn(f, c)[3] for c in text]
width(f::Font, text) = sum(c -> drawn(f, c)[3], text; init=0.0)

# --- Core Text ----------------------------------------------------------------------------

const CT = "/System/Library/Frameworks/CoreText.framework/CoreText"
const CF = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

release(p) = p == C_NULL || ccall((:CFRelease, CF), Cvoid, (Ptr{Cvoid},), p)
"One of Core Text's named values"
named(lib, name::Symbol) = unsafe_load(Ptr{Ptr{Cvoid}}(dlsym(dlopen(lib), name)))
cf_string(s::AbstractString) = (b = codeunits(String(s)); ccall((:CFStringCreateWithBytes, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Clong, UInt32, Bool), C_NULL, b, length(b), 0x08000100, false))
cf_number(x::Float64) = ccall((:CFNumberCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Clong, Ref{Float64}), C_NULL, 13, x)
cf_number(x::Int32) = ccall((:CFNumberCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Clong, Ref{Int32}), C_NULL, 3, x)
"The number that the CFNumber `n` holds, or 0 for none"
cf_float(n) = (x = Ref(0.0); n == C_NULL || ccall((:CFNumberGetValue, CF), Bool, (Ptr{Cvoid}, Clong, Ref{Float64}), n, 13, x); x[])
cf_int(n) = (x = Ref(Int64(0)); n == C_NULL || ccall((:CFNumberGetValue, CF), Bool, (Ptr{Cvoid}, Clong, Ref{Int64}), n, 4, x); x[])
cf_dict(pairs...) = begin
  keys, values = Ptr{Cvoid}[first(p) for p in pairs], Ptr{Cvoid}[last(p) for p in pairs]
  ccall((:CFDictionaryCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Ptr{Cvoid}}, Ptr{Ptr{Cvoid}}, Clong, Ptr{Cvoid}, Ptr{Cvoid}), C_NULL, keys, values, length(keys),
        cglobal((:kCFTypeDictionaryKeyCallBacks, CF)), cglobal((:kCFTypeDictionaryValueCallBacks, CF)))
end

# How heavy Core Text says each of the nine weights is
const HEAVY = Dict(100 => -0.8, 200 => -0.6, 300 => -0.4, 400 => 0.0, 500 => 0.23, 600 => 0.3, 700 => 0.4, 800 => 0.56, 900 => 0.62)

"Core Text's font of a family, a weight and a size, or C_NULL where there's no Core Text"
core_font(name::AbstractString, weight::Integer, italic::Bool, size::Real) = begin
  # Core Text takes a size of nothing to mean its usual size, so text of no size is left to Skia
  (Sys.isapple() && size > 0) || return C_NULL
  try
    heavy = cf_number(get(HEAVY, 100clamp(round(Int, weight / 100), 1, 9), 0.0))
    slant = cf_number(Int32(italic ? 1 : 0))
    traits = cf_dict(named(CT, :kCTFontWeightTrait) => heavy, named(CT, :kCTFontSymbolicTrait) => slant)
    desc = if name == SYSTEM
      # The system font has no name that Core Text takes. It's asked for as the font of the Mac's own text.
      base = ccall((:CTFontCreateUIFontForLanguage, CT), Ptr{Cvoid}, (UInt32, Float64, Ptr{Cvoid}), 2, size, C_NULL)
      own = ccall((:CTFontCopyFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid},), base)
      attrs = cf_dict(named(CT, :kCTFontTraitsAttribute) => traits)
      d = ccall((:CTFontDescriptorCreateCopyWithAttributes, CT), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}), own, attrs)
      foreach(release, (base, own, attrs))
      d
    else
      family = cf_string(name)
      attrs = cf_dict(named(CT, :kCTFontFamilyNameAttribute) => family, named(CT, :kCTFontTraitsAttribute) => traits)
      d = ccall((:CTFontDescriptorCreateWithAttributes, CT), Ptr{Cvoid}, (Ptr{Cvoid},), attrs)
      foreach(release, (family, attrs))
      d
    end
    font = ccall((:CTFontCreateWithFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid}, Float64, Ptr{Cvoid}), desc, size, C_NULL)
    foreach(release, (heavy, slant, traits, desc))
    font
  catch
    C_NULL
  end
end

"How wide a space is in text of the font `f`"
space(f::Font) = get!(() -> advances(f, [' '])[1], spaces, f.raw)

"""
How wide each letter of `chars` is in a run of text of the font `f`, in px. Two
letters that the font moves together, like AV, are that much narrower. A new
line or a tab is as wide as a space.
"""
advances(f::Font, chars::Vector{Char}) = begin
  (f.core == C_NULL || isempty(chars)) && return Float64[drawn(f, c)[3] for c in chars]
  text = cf_string(String([c in ('\n', '\r', '\t', '\f') ? ' ' : c for c in chars]))
  none = cf_number(Int32(0))
  attrs = cf_dict(named(CT, :kCTFontAttributeName) => f.core, named(CT, :kCTLigatureAttributeName) => none)
  styled = ccall((:CFAttributedStringCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), C_NULL, text, attrs)
  line = ccall((:CTLineCreateWithAttributedString, CT), Ptr{Cvoid}, (Ptr{Cvoid},), styled)
  out = Vector{Float64}(undef, length(chars))
  at, before = 0, 0.0
  for (i, c) in enumerate(chars)
    # Core Text counts in the units of UTF-16, where a letter outside the first 65536 is two
    at += c > '￿' ? 2 : 1
    x = ccall((:CTLineGetOffsetForStringIndex, CT), Float64, (Ptr{Cvoid}, Clong, Ptr{Cvoid}), line, at, C_NULL)
    out[i] = invisible(c) ? 0.0 : max(0.0, x - before)
    before = max(before, x)
  end
  foreach(release, (line, styled, attrs, none, text))
  out
end
