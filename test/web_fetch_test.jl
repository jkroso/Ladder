# Tests for web/fetch.jl and the curl wrappers in web/files.jl, remote.jl and
# linkcard.jl. Run them with `julia -O0 --project=. test/web_fetch_test.jl`.
# They use no network: a script on PATH stands in for `curl`.

@use Test: @test, @testset

const dir = mktempdir()
const bin = mkpath(joinpath(dir, "bin"))
const log = joinpath(dir, "calls")

# A stand-in for `curl`: writes each argument on its own line to a file, writes
# a sample body to `--output` (or stdout when there is no `--output`), writes
# `--write-out` to stdout, and exits with FAKE_EXIT if set.
write(joinpath(bin, "curl"), raw"""
#!/bin/sh
out=""
wo=""
: > "$FAKE_ARGS"
for a in "$@"; do
  printf '%s\n' "$a" >> "$FAKE_ARGS"
done
while [ $# -gt 0 ]; do
  case "$1" in
    --output) out="$2"; shift 2 ;;
    --write-out) wo="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$FAKE_EXIT" ] && exit "$FAKE_EXIT"
if [ -n "$out" ]; then
  printf '0123456789abcdef' > "$out"
  if [ -n "$wo" ]; then printf '%s' "$wo"; fi
else
  printf '0123456789abcdef'
fi
exit 0
""")
chmod(joinpath(bin, "curl"), 0o755)
const old_path = ENV["PATH"]
ENV["PATH"] = bin * ":" * old_path
ENV["FAKE_ARGS"] = log

@use "../web/fetch" => Webfetch
@use "../web/files" => Webfiles
@use "../remote" => Remote
@use "../linkcard" => Cards

"Wait until `done()` is true, for 10 seconds at most"
until(done) = (t = time(); while !done() && time() - t < 10; sleep(0.01); end; done())
"The arguments passed to the last fake `curl` call"
last_args() = readlines(log)

@testset "web/fetch.jl options and exit codes" begin
  out = joinpath(dir, "pic.part")
  job = Webfetch.start("https://example.com/a.png", out; seconds=30)
  @test job isa Base.Process
  wait(job)
  @test success(job) && read(out, String) == "0123456789abcdef"
  args = last_args()
  @test args == ["--silent", "--fail", "--location", "--max-redirs", "8",
                 "--proto", "=http,https", "--proto-redir", "=http,https", "--compressed",
                 "--connect-timeout", "10", "--max-time", "30", "--user-agent", Webfetch.AGENT,
                 "--output", out, "--", "https://example.com/a.png"]

  # Media download options: resume, speed limit, no --max-time, and exit code preserved
  media = joinpath(dir, "clip.mp4.part")
  ENV["FAKE_EXIT"] = "33"
  try
    job = Webfetch.start("https://example.com/clip.mp4", media; connect=30, seconds=nothing, speed_limit=1, speed_time=60, resume=true, compressed=false)
    wait(job)
    @test !success(job) && job.exitcode == 33
    args = last_args()
    @test !("--max-time" in args)
    @test args == ["--silent", "--fail", "--location", "--max-redirs", "8",
                   "--proto", "=http,https", "--proto-redir", "=http,https",
                   "--connect-timeout", "30", "--speed-limit", "1", "--speed-time", "60",
                   "--user-agent", Webfetch.AGENT, "--continue-at", "-",
                   "--output", media, "--", "https://example.com/clip.mp4"]
  finally
    delete!(ENV, "FAKE_EXIT")
  end
end

@testset "Webfiles.curl, Remote.curl and Cards.curl" begin
  # Webfiles.curl sends --fail and --max-filesize, and writes --write-out to about
  out, about = joinpath(dir, "wf"), joinpath(dir, "wf.about")
  done = Webfiles.curl("https://example.com/app.js", out, about)
  @test until(done) && read(out, String) == "0123456789abcdef"
  args = last_args()
  @test "--fail" in args && "--max-filesize" in args && string(Webfiles.BIGGEST) in args
  @test startswith(read(about, String), "%{url_effective}\n%{content_type}\n%header{access-control-allow-origin}\n")

  # Remote.curl omits --fail, sends Accept, and writes three --write-out lines to about
  out, about = joinpath(dir, "rm"), joinpath(dir, "rm.about")
  done = Remote.curl("https://example.com/notes.md", out, about)
  @test until(done) && read(out, String) == "0123456789abcdef"
  args = last_args()
  @test !("--fail" in args) && "--max-filesize" in args && string(Remote.BIGGEST) in args
  @test "Accept: " * Remote.ACCEPT in args
  @test read(about, String) == "%{url_effective}\n%{content_type}\n%{http_code}\n"

  # Cards.curl limits moves to 5, times out after 20s, and cuts output to `most` bytes
  out = joinpath(dir, "card")
  done = Cards.curl("https://example.com/page", out, 6)
  @test until(done) && read(out, String) == "012345"
  args = last_args()
  @test "--fail" in args && !("--output" in args) && !("--max-filesize" in args)
  @test args[findfirst(==("--max-redirs"), args)+1] == "5"
  @test args[findfirst(==("--max-time"), args)+1] == string(Cards.SECONDS)
end

ENV["PATH"] = old_path
delete!(ENV, "FAKE_ARGS")
