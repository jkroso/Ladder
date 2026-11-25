# The episodes of the shows that you follow in Apple Podcasts, from its
# library on this Mac. A folder of news puts them in the paper when its
# `Feeds.md` has the line `Apple Podcasts` (see feeds.jl): each new episode is
# an article by its show, made from its show notes, with a link that opens it
# in Apple Podcasts.
#
# Ladder reads the library with the Mac's `sqlite3`, and changes nothing in it.
# It never needs a show's feed, so the address of a paid feed, which holds a
# key of yours, isn't written anywhere.
#
#     episodes(since)    # the episodes of the shows that you follow, since a time, the newest first
#     library()          # the file of the library

@use "github.com/jkroso/Prospects.jl" @def
@use Dates: Dates, DateTime

"The file of the library of Apple Podcasts. A test names a file of its own."
const LIBRARY = Ref("")

"The file of the library of Apple Podcasts on this Mac, or \"\" when Apple Podcasts has none"
library() = begin
  isempty(LIBRARY[]) || return LIBRARY[]
  groups = joinpath(homedir(), "Library", "Group Containers")
  names = try readdir(groups) catch; String[] end
  i = findfirst(n -> endswith(n, "groups.com.apple.podcasts"), names)
  i === nothing && return ""
  file = joinpath(groups, names[i], "Documents", "MTLibrary.sqlite")
  isfile(file) ? file : ""
end

"An episode of a show that you follow"
@def struct Episode
  id::String = ""        # Apple Podcasts' name for it
  title::String = ""
  show::String = ""
  when::DateTime = DateTime(2000)   # when it came out, by the Mac's clock
  notes::String = ""     # its show notes, as HTML
  link::String = ""      # where it opens in Apple Podcasts, or its page on the web
end

"The seconds from 1970 to 2001, when Apple Podcasts counts its times from"
const APPLE_TIME = 978307200

"""
The episodes of the shows that you follow in Apple Podcasts, that came out
since `since`, the newest first. It throws an error with words for you when
it can't read the library.
"""
episodes(since::DateTime) = begin
  file = library()
  (isempty(file) || !isfile(file)) && error("This Mac has no library of Apple Podcasts")
  # Seconds since 2001 by the Mac's clock, as the library keeps times
  from = round(Int, Dates.datetime2unix(since - (Dates.now() - Dates.now(Dates.UTC)))) - APPLE_TIME
  sql = """
  select e.ZUUID, e.ZTITLE, p.ZTITLE, datetime(e.ZPUBDATE + $APPLE_TIME, 'unixepoch', 'localtime'), coalesce(d.ZTEXT, d.ZPLAINTEXT, ''),
         coalesce(p.ZSTORECOLLECTIONID, 0), coalesce(e.ZSTORETRACKID, 0), coalesce(e.ZWEBPAGEURL, '')
  from ZMTEPISODE e join ZMTPODCAST p on e.ZPODCAST = p.Z_PK left join ZMTEPISODEDESCRIPTION d on d.ZEPISODE = e.Z_PK
  where p.ZSUBSCRIBED = 1 and e.ZPUBDATE > $from and coalesce(e.ZUSERDELETED, 0) = 0
  order by e.ZPUBDATE desc
  """
  # Apple Podcasts writes the library while it runs. Read only, it has the changes that wait in its log too. When
  # that fails, `immutable` reads the file as it is, and takes no lock.
  out, err = IOBuffer(), IOBuffer()
  run_on(how) = (truncate(out, 0); truncate(err, 0); success(pipeline(`/usr/bin/sqlite3 -ascii $("file:$file?$how") $sql`, stdout=out, stderr=err)))
  ok = run_on("mode=ro") || run_on("immutable=1")
  if !ok
    said = strip(String(take!(err)))
    # macOS keeps another app's files from an app that it hasn't let read them
    occursin(r"unable to open|authori[sz]ation denied|not permitted"i, said) &&
      error("Ladder isn't allowed to read the library of Apple Podcasts. In System Settings, open Privacy & Security, then Full Disk Access, and turn Ladder on")
    error("Ladder can't read the library of Apple Podcasts: " * said)
  end
  out = String(take!(out))
  found = Episode[]
  for row in split(out, '\x1e', keepempty=false)
    cells = split(row, '\x1f')
    length(cells) == 8 || continue
    id, title, show, when, notes, collection, track, page = cells
    at = tryparse(DateTime, replace(when, ' ' => 'T'))
    (isempty(title) || at === nothing) && continue
    link = collection != "0" && track != "0" ? "https://podcasts.apple.com/podcast/id$collection?i=$track" : String(page)
    push!(found, Episode(id=String(id), title=String(title), show=String(show), when=at, notes=String(notes), link=link))
  end
  found
end
