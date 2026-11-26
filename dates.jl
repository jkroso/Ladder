# Reads a day from text, in the ways Ladder's files and fields write one:
# ISO dates like 2026-11-25, slashes or dots like 25/11/2026 and 3/4/26,
# words like 25 Nov 2026, Wed, 25 Nov 2026 and November 25, 2026, a time of
# day after one, and words typed in a field like today, tomorrow, fri, +3 or
# 25. It also reads the local day of a time in seconds since 1970.
#
# blog.jl, calendar.jl, csv.jl, forms.jl, schedule.jl and main.jl use it.
#
#     day("25 Nov 2026")                              # Date(2026, 11, 25)
#     day("25 Nov"; today=Date(2026, 3, 1), year=:same)   # Date(2026, 11, 25)
#     day("25 Dec"; today=Date(2026, 11, 23), year=:past) # Date(2025, 12, 25)
#     day("fri"; today=Date(2026, 11, 24), relative=:all) # Date(2026, 11, 27)
#     when("2026-11-25 10:30 pm")                     # DateTime(2026, 11, 25, 22, 30)

@use Dates: Dates, Date, DateTime, Day

"An ISO day like 2026-11-25 inside other text, not touching another digit"
const ISO = r"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"
const ISO_ONLY = r"^(\d{4})-(\d{1,2})-(\d{1,2})$"
const ISO_DAY = r"^(\d{4})([-/])(\d{1,2})\2(\d{1,2})$"
const SLASH_DAY = r"^(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?$"
# A year of two digits is only after a slash, so a version number like 1.2.10 is no day
const DOT_DASH_DAY = r"^(\d{1,2})([.-])(\d{1,2})\2(\d{4})$"
const WORD_DAY = r"^(?:([a-z]{3,9})\.?,?\s+)?(\d{1,2})(?:st|nd|rd|th)?\s*([a-z]{3,9})\.?,?(?:\s+(\d{4}))?$"
const MONTH_DAY = r"^(?:([a-z]{3,9})\.?,?\s+)?([a-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?(?:\s+(\d{4}))?$"
# The time of day after a day, like 22:29, 22:29:05, 10:30 pm or 22:29:05.123Z. A time zone after it is left out.
const CLOCK = r"(?:\s*,\s*|\s+|t)(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*(?:(am|pm)(?![a-z]))?\s*(?:z|utc|gmt|[+-]\d{2}:?\d{2}|[a-z]{3,4})?\s*$"i

const MONTHS = ("january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december")
const WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")

"The month that `word` names, like 11 for nov or November, or nothing"
month_of(word::AbstractString) = (w = lowercase(word); length(w) < 3 ? nothing : findfirst(m -> startswith(m, w), MONTHS))

"The day of the week that `word` names, from 1 for Monday to 7 for Sunday, or nothing"
weekday_of(word::AbstractString) = (w = lowercase(word); length(w) < 3 ? nothing : findfirst(d -> startswith(d, w), WEEKDAYS))

"The date `y`-`m`-`d`, or nothing when there's no such day"
day(y::Integer, m::Integer, d::Integer) = Dates.validargs(Date, y, m, d) === nothing ? Date(y, m, d) : nothing

"The date from the first three captures of `m`, as year, month and day, or nothing"
day(m::RegexMatch) = day(parse(Int, m[1]), parse(Int, m[2]), parse(Int, m[3]))

"The day of the time `t`, in seconds since 1970, on this Mac's clock"
day(t::Real) = Date(Libc.strftime("%Y-%m-%d", t))

"The date for month `mo`, day `dd` and optional year text `y`, using `mode` when `y` is nothing"
year_of(y, mo::Int, dd::Int, today::Date, mode::Symbol) = begin
  if y !== nothing
    n = parse(Int, y)
    return day(length(y) == 2 ? 2000 + n : n, mo, dd)
  end
  mode == :same && return day(Dates.year(today), mo, dd)
  if mode == :past
    for k in 0:8
      d = day(Dates.year(today) - k, mo, dd)
      d !== nothing && d <= today && return d
    end
  end
  nothing
end

"""
The day that `text` names, or nothing when it names none.

- `year` says what to do when `text` has no year: `:need` refuses it, `:same`
  takes the year of `today`, and `:past` takes the last such day up to `today`.
- `dayfirst` says whether numeric dates like 3/4/2026 put the day first (the
  3rd of April, as in Australia) or the month first (March the 4th).
- `relative` enables words relative to `today`: `:none` reads none, `:today`
  reads `today`, and `:all` also reads `tomorrow`, `yesterday`, `+3`, a day of
  the month like `25`, and a weekday like `fri`.
- `iso` reads only `YYYY-M-D` dates.
- `anywhere` finds the first valid `YYYY-M-D` date inside `text`.
"""
day(text::AbstractString; today::Date=Dates.today(), year::Symbol=:need, dayfirst::Bool=true,
    relative::Symbol=:none, iso::Bool=false, anywhere::Bool=false) = begin
  if anywhere
    for m in eachmatch(ISO, text)
      d = day(m)
      d === nothing || return d
    end
    return nothing
  end
  s = lowercase(strip(text))
  isempty(s) && return nothing
  if iso
    m = match(ISO_ONLY, s)
    return m === nothing ? nothing : day(m)
  end
  m = match(ISO_DAY, s)
  m === nothing || return day(parse(Int, m[1]), parse(Int, m[3]), parse(Int, m[4]))
  m = match(SLASH_DAY, s)
  if m !== nothing
    a, b = parse(Int, m[1]), parse(Int, m[2])
    return dayfirst ? year_of(m[3], b, a, today, year) : year_of(m[3], a, b, today, year)
  end
  m = match(DOT_DASH_DAY, s)
  if m !== nothing
    a, b = parse(Int, m[1]), parse(Int, m[3])
    return dayfirst ? year_of(m[4], b, a, today, year) : year_of(m[4], a, b, today, year)
  end
  m = match(WORD_DAY, s)
  if m !== nothing && (m[1] === nothing || weekday_of(m[1]) !== nothing)
    mo = month_of(m[3])
    mo === nothing || return year_of(m[4], mo, parse(Int, m[2]), today, year)
  end
  m = match(MONTH_DAY, s)
  if m !== nothing && (m[1] === nothing || weekday_of(m[1]) !== nothing)
    mo = month_of(m[2])
    mo === nothing || return year_of(m[4], mo, parse(Int, m[3]), today, year)
  end
  relative == :none && return nothing
  s == "today" && return today
  relative == :all || return nothing
  s == "tomorrow" && return today + Day(1)
  s == "yesterday" && return today - Day(1)
  m = match(r"^\+(\d{1,3})$", s)
  m === nothing || return today + Day(parse(Int, m[1]))
  if occursin(r"^\d{1,2}$", s)
    n = parse(Int, s)
    for k in 0:62
      Dates.day(today + Day(k)) == n && return today + Day(k)
    end
    return nothing
  end
  k = weekday_of(s)
  k === nothing ? nothing : today + Day(mod1(k - Dates.dayofweek(today), 7))
end

"How `text` writes a day: :iso for 2026-11-25, :words for 25 Nov 2026, :slashes for 25/11/2026, or nothing when it's no such day"
style(text::AbstractString) = begin
  day(text) === nothing && return nothing
  occursin(r"^\d{4}-\d{1,2}-\d{1,2}$", text) ? :iso :
  occursin(r"^\d{1,2} [A-Za-z]{3,9} \d{4}$", text) ? :words :
  occursin(r"^\d{1,2}/\d{1,2}/\d{4}$", text) ? :slashes : nothing
end

"Split a trailing time of day off `text`, returning `(head, h, mi, s)`. When the trailing time isn't a real time of day, `head` is nothing."
split_clock(text::AbstractString) = begin
  m = match(CLOCK, text)
  m === nothing && return (text, 0, 0, 0)
  h, mi = parse(Int, m[1]), parse(Int, m[2])
  s = m[3] === nothing ? 0 : parse(Int, m[3])
  if m[4] !== nothing
    1 <= h <= 12 || return (nothing, 0, 0, 0)
    h = lowercase(m[4]) == "pm" ? h % 12 + 12 : h % 12
  end
  (h < 24 && mi < 60 && s < 60) || return (nothing, 0, 0, 0)
  (SubString(text, 1, prevind(text, m.offset)), h, mi, s)
end

"""
The day and time of day that `text` names, or nothing when it names none: a
day with its year, like 2026-11-25, 25/11/2026, 25 Nov 2026, Wed, 25 Nov 2026
or November 25, 2026, with or without a time of day after it. `dayfirst` says
whether 3/4/2026 is the 3rd of April, as in Australia, or March the 4th.
"""
when(text::AbstractString; dayfirst::Bool=true) = begin
  head, h, mi, s = split_clock(text)
  head === nothing && return nothing
  d = day(head; dayfirst)
  d === nothing ? nothing : DateTime(Dates.year(d), Dates.month(d), Dates.day(d), h, mi, s)
end

"""
Whether the days in `cells` that are written with numbers, like 3/4/2026, have
the day first. They do unless one of them has a number over 12 in its middle,
like 4/23/2026, and none has one first.
"""
dayfirst(cells) = begin
  middle = false
  for x in cells
    head, _, _, _ = split_clock(x)
    head === nothing && continue
    s = strip(head)
    m = match(SLASH_DAY, s)
    a, b, y = if m !== nothing && m[3] !== nothing
      parse(Int, m[1]), parse(Int, m[2]), m[3]
    else
      m = match(DOT_DASH_DAY, s)
      m === nothing && continue
      parse(Int, m[1]), parse(Int, m[3]), m[4]
    end
    a > 12 && year_of(y, b, a, Dates.today(), :need) !== nothing && return true
    b > 12 && year_of(y, a, b, Dates.today(), :need) !== nothing && (middle = true)
  end
  !middle
end
