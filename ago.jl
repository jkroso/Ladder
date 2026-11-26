# Words for how long ago a time was, like `just now`, `5 min ago`, `3 h ago`,
# `yesterday`, `4 days ago`, or the date when it was two weeks ago or more.
# git.jl loads it for commits, and main.jl uses it through git.jl for commits,
# notes and folders.
#
#     ago(time() - 300)    # "5 min ago"
#     ago(t, now)          # relative to `now`

"How long ago `t` was, in a few words: `just now`, `5 min ago`, `3 h ago`, `4 days ago`, or the date"
ago(t::Real, now::Real=time()) = begin
  s = now - t
  s < 90 ? "just now" :
  s < 3600 ? "$(round(Int, s / 60)) min ago" :
  s < 86400 ? "$(round(Int, s / 3600)) h ago" :
  s < 14 * 86400 ? (d = round(Int, s / 86400); d == 1 ? "yesterday" : "$d days ago") :
  Libc.strftime("%-d %b %Y", t)
end
