# How the pages of the Mac's own folders name their days, as the Finder does,
# and the folder that the Mac saves screenshots to. main.jl draws each
# folder's page. macfile.jl reads what macOS knows of a file, trash.jl reads
# the Trash, and picture_words.jl reads the words in a picture.
#
#     day_name(t)                 # "Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "October 2026"
#     date_name(t)                # "Today", "Yesterday", "Friday 20 November 2026"
#     when(t)                     # "14:05" for today, "20 Nov 2026" for another day
#     screenshots()               # the folder that the Mac saves screenshots to

@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool
@use Dates: Dates, Date
@use "../dates" day   # the day of a time, in the Mac's own time zone

# --- days ------------------------------------------------------------------------------

"""
The name of the group of days that the time `t` is in, as the Finder names
the groups of a folder that's sorted by date: Today, Yesterday, Previous 7
Days, Previous 30 Days, and then the month, like October 2026.
"""
day_name(t::Real, now::Real=time()) = begin
  ago = Dates.value(day(now) - day(t))
  ago <= 0 ? "Today" : ago == 1 ? "Yesterday" : ago <= 7 ? "Previous 7 Days" : ago <= 30 ? "Previous 30 Days" : month_name(t)
end

"The month of the time `t`, like October 2026"
month_name(t::Real) = Libc.strftime("%B %Y", t)

"The day of the time `t` in words, like Today, Yesterday or Friday 20 November 2026"
date_name(t::Real, now::Real=time()) = begin
  ago = Dates.value(day(now) - day(t))
  ago <= 0 ? "Today" : ago == 1 ? "Yesterday" : Libc.strftime("%A %-d %B %Y", t)
end

"The time `t` in a few characters: the time of day for today, and the date for any other day"
when(t::Real, now::Real=time()) = day(t) == day(now) ? Libc.strftime("%H:%M", t) : Libc.strftime("%-d %b %Y", t)

# --- the folder of the screenshots --------------------------------------------------------

"The folder that the Mac saves screenshots to: the one that its settings name, or the Desktop"
screenshots() = begin
  usual = joinpath(homedir(), "Desktop")
  Sys.isapple() || return usual
  try
    with_pool() do
      defaults = msg(msg(msg(cls("NSUserDefaults"), "alloc"), "initWithSuiteName:", nsstring("com.apple.screencapture")), "autorelease")
      at = msg(defaults, "stringForKey:", nsstring("location"))
      at == C_NULL && return usual
      path = String(rstrip(abspath(expanduser(jstring(at))), '/'))
      isdir(path) ? path : usual
    end
  catch
    usual
  end
end
