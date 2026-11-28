# Tests for eml.jl: what Ladder shows of an email file. Run them with
# `julia -O0 --project=. test/eml_test.jl`. They use no network and no email
# account. mime_test.jl has the tests of how an email is taken apart.

@use Test: @test, @testset
@use "../files/eml" => E

# A page shows a date in the Mac's time zone, so the tests choose one
ENV["TZ"] = "Australia/Sydney"
ccall(:tzset, Cvoid, ())

E.CACHE[] = mktempdir()
const dir = mktempdir()
const path = joinpath(dir, "2026-11-14 0932 Sam Lee - Roof quote.eml")
write(path, replace("""
  From: Sam Lee <sam@example.com>
  To: you@example.com
  Reply-To: Office <office@example.com>
  Subject: Roof quote
  Date: Sat, 14 Nov 2026 09:32:00 +1100
  MIME-Version: 1.0
  Content-Type: multipart/mixed; boundary=m

  --m
  Content-Type: text/html; charset=utf-8

  <p>Hi Jake, the <b>quote</b> is attached.</p>
  --m
  Content-Type: application/pdf; name="Roof quote (v2).pdf"
  Content-Disposition: attachment; filename="Roof quote (v2).pdf"
  Content-Transfer-Encoding: base64

  JVBERi0xLjcK
  --m--
  """, "\n" => "\r\n"))

@testset "an email file, and what isn't one" begin
  @test E.isemail(path) && E.isemail("A.EML") && !E.isemail("notes.md") && !E.isemail("eml")
end

@testset "the page of an email file" begin
  lines = E.render(path)
  kept = joinpath(E.attachments(path), "Roof quote (v2).pdf")
  @test lines == ["---", "from: Sam Lee <sam@example.com>", "reply-to: Office <office@example.com>", "to: you@example.com",
                  "date: 14 Nov 2026, 9:32 am", "subject: Roof quote", "---", "", "Hi Jake, the **quote** is attached.", "",
                  "[Roof quote (v2).pdf]($(E.escaped(kept)))"]
  # The file that came with the email is kept in Ladder's cache, and the email's own file isn't changed
  @test startswith(kept, E.CACHE[]) && read(kept, String) == "%PDF-1.7\n" && E.unescaped(E.escaped(kept)) == kept
  # The lines at the end that link to the email's files, and the email's HTML
  @test E.attached(path, lines) == 11 && E.attached(path, lines[1:9]) == 10
  @test E.webpage(path) == "<p>Hi Jake, the <b>quote</b> is attached.</p>"
  # A file that isn't there has no HTML
  @test E.webpage(joinpath(dir, "none.eml")) == ""
end

@testset "what the front matter of a page says" begin
  said, text = E.fields(E.render(path))
  @test said["from"] == "Sam Lee <sam@example.com>" && said["subject"] == "Roof quote" && said["date"] == "14 Nov 2026, 9:32 am" && text == 8
  # A long list of people can go on in the next line, and a key is read in lower case
  said, text = E.fields(["---", "To: a@example.com,", "  b@example.com", "Subject:", "---", "", "Hi"])
  @test said == Dict("to" => "a@example.com, b@example.com", "subject" => "") && text == 6
  @test E.fields(["No front matter"]) == (Dict{String,String}(), 1)
  # A page that's an email to send names who it's to, and has no date
  @test E.isdraft(["---", "to: sam@example.com", "subject: Hi", "---", "", "Hi Sam"])
  @test !E.isdraft(E.render(path)) && !E.isdraft(["---", "title: Notes", "---"]) && !E.isdraft(["Hi"])
end

@testset "names and people, as a page writes them" begin
  @test E.written(["Sam Lee" => "sam@example.com", "" => "b@example.com", "Lee, Kim" => "kim@example.com"]) ==
        "Sam Lee <sam@example.com>, b@example.com, \"Lee, Kim\" <kim@example.com>"
  @test E.flat("one\ttwo\r\nthree") == "one two three"
  @test E.clean("  .a/b:c\\d\n e  ", 80, 150) == "a b c d e" && E.clean("abcdef", 3, 150) == "abc" && sizeof(E.clean("ééééé", 80, 6)) <= 6
end
