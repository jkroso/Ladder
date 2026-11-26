# Starts `curl` in the background to get a file from the web.
# Used by web/files.jl, remote.jl, linkcard.jl and main.jl.
#
#     job = start("https://example.com/photo.png", "/tmp/photo.png")
#     process_exited(job)

# Many sites give a page only to a program that says it's a browser
const AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

"""
Start `curl` in the background to get what's at the web address `address` into
`file`, and give its running process. It follows the address to where it has
moved, asks only over HTTP or HTTPS, asks for a compressed answer, and sends
the browser `AGENT`.

What differs between callers is set with keywords:
- `fail`: exit with an error and write nothing when the server answers 404 and the like.
- `redirs`: how many moves to follow, or nothing for no limit.
- `connect`: seconds to wait for the server to answer, or nothing for no limit.
- `seconds`: seconds the whole download can take, or nothing for no limit.
- `biggest`: refuse a file that says it's bigger than this many bytes.
- `speed_limit`, `speed_time`: give up when fewer than `speed_limit` bytes a second come for `speed_time` seconds.
- `headers`: extra lines to send with the request, like `Accept: text/markdown`.
- `resume`: carry on from the end of `file` if part of it is there already.
- `most`: keep no more than the first `most` bytes, by piping through `head -c`.
- `about`, `write_out`: write these `curl` `--write-out` lines into the file `about`.
"""
start(address::AbstractString, file::AbstractString; fail::Bool=true, redirs::Union{Int,Nothing}=8,
      connect::Union{Int,Nothing}=10, seconds::Union{Int,Nothing}=30, biggest::Union{Int,Nothing}=nothing,
      speed_limit::Union{Int,Nothing}=nothing, speed_time::Union{Int,Nothing}=nothing,
      headers::AbstractVector{<:AbstractString}=String[], resume::Bool=false,
      most::Union{Int,Nothing}=nothing, about::Union{AbstractString,Nothing}=nothing,
      write_out::AbstractVector{<:AbstractString}=String[]) = begin
  args = String["curl", "--silent"]
  fail && push!(args, "--fail")
  push!(args, "--location")
  redirs === nothing || push!(args, "--max-redirs", string(redirs))
  push!(args, "--proto", "=http,https", "--proto-redir", "=http,https", "--compressed")
  connect === nothing || push!(args, "--connect-timeout", string(connect))
  seconds === nothing || push!(args, "--max-time", string(seconds))
  biggest === nothing || push!(args, "--max-filesize", string(biggest))
  speed_limit === nothing || push!(args, "--speed-limit", string(speed_limit))
  speed_time === nothing || push!(args, "--speed-time", string(speed_time))
  push!(args, "--user-agent", AGENT)
  for h in headers
    push!(args, "--header", String(h))
  end
  resume && push!(args, "--continue-at", "-")
  most === nothing && push!(args, "--output", String(file))
  if about !== nothing && !isempty(write_out)
    push!(args, "--write-out", join(write_out, '\n') * '\n')
  end
  push!(args, "--", String(address))
  ask = Cmd(args)
  if most !== nothing
    run(pipeline(pipeline(ask, stderr=devnull), pipeline(`head -c $most`, stdout=file, stderr=devnull)), wait=false)
  else
    run(pipeline(ask, stdout=about === nothing ? devnull : about, stderr=devnull), wait=false)
  end
end
