# Tests for contact.jl. Run them with `julia -O0 --project=. test/contact_test.jl`.

@use Test: @test, @testset
@use "../contact" => C

const BLOCK = ["Ada Lovelace", "role: Engineer", "company: Analytical Engines", "email: ada@example.com", "mobile: 0400 123 456",
               "address: 12 Example St, Sydney NSW 2000", "web: example.com", "photo: ada.jpg", "note: Met at the 2026 conference.",
               "ABN: 12 345 678 901"]
kinds(c) = [d.kind for d in c.lines]
values(c, kind) = [d.value for d in c.lines if d.kind == kind]

@testset "reading and writing" begin
  c = C.contact(BLOCK)
  @test C.title(c) == "Ada Lovelace" && !C.iscompany(c) && C.tagline(c) == "Engineer, Analytical Engines"
  @test kinds(c) == [:name, :role, :company, :email, :phone, :address, :web, :photo, :note, :other]
  @test C.photo(c) == "ada.jpg" && C.initials(C.title(c)) == "AL"
  # The rows are the lines that aren't the name, the role, the company and the photo, in the order of the block
  @test [c.lines[i].kind for i in C.rows(c)] == [:email, :phone, :address, :web, :note, :other]
  @test [C.caption(c.lines[i]) for i in C.rows(c)] == ["", "mobile", "", "", "", "ABN"]
  @test C.written(c) == BLOCK && C.written(C.contacts(BLOCK)) == BLOCK
  # Labels ignore case, and spaces round a label and a value don't matter. Each line is kept as it's written.
  odd = ["  Ada Lovelace  ", "EMAIL : ada@example.com", "Role:Engineer", "Website:   example.com", "URL: https://example.org/a?b=c", "Fax: 02 9000 0000"]
  c = C.contact(odd)
  @test C.title(c) == "Ada Lovelace" && kinds(c) == [:name, :email, :role, :web, :web, :phone] && C.written(c) == odd
  @test values(c, :web) == ["example.com", "https://example.org/a?b=c"] && C.caption(c.lines[6]) == "Fax"
  # A label can be there more than once
  c = C.contact(["Ada", "email: a@example.com", "email: b@example.com", "phone: 1234 5678", "work: 8765 4321"])
  @test values(c, :email) == ["a@example.com", "b@example.com"] && length(C.rows(c)) == 4
  @test [C.caption(c.lines[i]) for i in C.rows(c)] == ["", "", "", "work"]
  # A second role and a second company are rows with their labels
  c = C.contact(["Ada", "role: Engineer", "role: Author", "company: One", "company: Two"])
  @test C.tagline(c) == "Engineer, One" && [C.caption(c.lines[i]) * " " * c.lines[i].value for i in C.rows(c)] == ["role Author", "company Two"]
  # A block with nothing in it is a contact with nothing in it, and writes no lines
  @test C.isblank(C.contact(String[])) && isempty(C.contacts(["", "  "])) && C.written(C.Contact[]) isa Vector{String}
  @test isempty(C.written(C.contacts(["", "  "])))
end

@testset "a line with no label is read by its shape" begin
  c = C.contact(["Ada Lovelace", "ada@example.com", "https://example.com/about", "www.example.com", "+61 (0)400 123-456", "Met at the conference.",
                 "ada lovelace at example.com", "12345", "http://x.example", "12 Example St, Sydney"])
  @test kinds(c) == [:name, :email, :web, :web, :phone, :note, :note, :note, :web, :note]
  # A web address isn't a line with the label https, and a time isn't one with a label
  @test C.labelled("https://x.com") === nothing && C.labelled("Call at 10:30") === nothing && C.labelled("10:30 call") === nothing
  @test C.labelled("ABN: 12 345 678 901") == ("ABN", "12 345 678 901") && C.labelled("Note to self: call back") == ("Note to self", "call back")
  @test C.labelled("email:ada@example.com") == ("email", "ada@example.com") && C.labelled("email:") == ("email", "")
  # A sentence with a colon in it has too many words for a label
  @test C.labelled("She said to me once: never") === nothing
  @test C.shape("ada@example.com") == :email && C.shape("a b@example.com") == :note && C.shape("WWW.Example.com") == :web
  @test C.shape("0400 123 456") == :phone && C.shape("040 12") == :note && C.shape("0400 123 456 ext 2") == :note
  # The first line with no label is the name, wherever it is
  c = C.contact(["email: ada@example.com", "Ada Lovelace", "A note."])
  @test C.title(c) == "Ada Lovelace" && kinds(c) == [:email, :name, :note]
  # A name can have a label, for a name that would be read as something else
  c = C.contact(["name: Ada: the first", "A note.", "name: again"])
  @test C.title(c) == "Ada: the first" && kinds(c) == [:name, :note, :other]
end

@testset "a company" begin
  c = C.contact(["Analytical Engines", "kind: company", "role: Maker", "company: Babbage Holdings", "email: hello@example.com"])
  @test C.iscompany(c) && C.title(c) == "Analytical Engines" && C.tagline(c) == ""
  # The kind shows as no row. A company has no line under its name, so its role and its company are rows.
  @test [c.lines[i].kind for i in C.rows(c)] == [:role, :company, :email]
  @test C.iscompany(C.contact(["Acme", "Kind: Company"]))
  # A person can have a company, and any other kind is a person
  for kind in ("kind: person", "kind: robot", "kind:", "company: Acme")
    p = C.contact(["Ada", kind])
    @test !C.iscompany(p) && isempty([i for i in C.rows(p) if p.lines[i].kind == :kind])
  end
  @test C.tagline(C.contact(["Ada", "company: Acme"])) == "Acme"
end

@testset "several contacts in a block" begin
  lines = ["Ada Lovelace", "email: ada@example.com", "", "Analytical Engines", "kind: company", "", "", "Charles Babbage", "mobile: 0400 000 000"]
  list = C.contacts(lines)
  @test C.title.(list) == ["Ada Lovelace", "Analytical Engines", "Charles Babbage"] && [c.before for c in list] == [0, 1, 2]
  @test C.iscompany.(list) == [false, true, false] && C.written(list) == lines
  # Empty lines at the top are kept, and those at the end go
  @test C.written(C.contacts(["", "Ada", "", ""])) == ["", "Ada"]
  # A change to one contact leaves the lines of the others as they are
  C.set!(list[2], 1, "Difference Engines")
  @test C.written(list) == [lines[1:3]; "Difference Engines"; lines[5:end]]
  # A contact that's taken out takes the empty lines before it with it
  C.remove!(list, 2)
  @test C.written(list) == ["Ada Lovelace", "email: ada@example.com", "", "", "Charles Babbage", "mobile: 0400 000 000"]
  C.remove!(list, 1)
  @test C.written(list) == ["Charles Babbage", "mobile: 0400 000 000"]
  # A new contact goes after an empty line
  new = C.Contact()
  C.rename!(new, "Grace Hopper")
  C.add!(list, new)
  @test C.written(list) == ["Charles Babbage", "mobile: 0400 000 000", "", "Grace Hopper"]
  C.remove!(list, 9)
  @test length(list) == 2
end

@testset "changing a contact" begin
  c = C.contact(BLOCK)
  @test C.set!(c, 4, " ada@example.org ") && C.written(c)[4] == "email: ada@example.org"
  @test !C.set!(c, 4, "ada@example.org") && !C.set!(c, 99, "x")
  # A value is one line
  @test C.set!(c, 9, "Met at\nthe  conference.") && C.written(c)[9] == "note: Met at the conference."
  # An emptied value takes its line out
  @test C.set!(c, 10, "  ") && length(c.lines) == 9 && !any(d -> d.kind == :other, c.lines)
  @test C.rename!(c, "Ada King") && C.written(c)[1] == "Ada King" && C.title(c) == "Ada King"
  # A name that would be read as a line with a label is written with the label `name`
  @test C.rename!(c, "Ada: the first") && C.written(c)[1] == "name: Ada: the first" && C.title(C.contact(C.written(c))) == "Ada: the first"
  # A new detail goes at the end, with its label
  @test C.add!(c, :phone, "02 9000 0000") && C.written(c)[end] == "phone: 02 9000 0000"
  @test C.add!(c, :web, "example.org") && C.written(c)[end] == "web: example.org" && !C.add!(c, :note, "  ")
  # A line with no label keeps none while its new value reads as the same kind of line, and gets one when it doesn't
  c = C.contact(["Ada", "ada@example.com", "A note.", "0400 123 456"])
  C.set!(c, 2, "ada@example.org"); C.set!(c, 3, "see https://example.com"); C.set!(c, 4, "after 5")
  @test C.written(c) == ["Ada", "ada@example.org", "see https://example.com", "phone: after 5"]
  C.set!(c, 3, "www.example.com")
  @test C.written(c)[3] == "note: www.example.com" && kinds(C.contact(C.written(c))) == [:name, :email, :note, :phone]
  # With the name gone, no other line is read as the name
  c = C.contact(["Ada", "ada@example.com", "A note.", "role: Engineer"])
  @test C.set!(c, 1, "") && C.written(c) == ["email: ada@example.com", "note: A note.", "role: Engineer"]
  @test C.title(C.contact(C.written(c))) == "" && C.tagline(c) == "Engineer"
  # A contact with no name gets its name as its first line
  @test C.rename!(c, "Ada") && C.written(c)[1] == "Ada" && !C.rename!(C.Contact(), " ")
  # Every line can go, which leaves a contact with nothing in it
  c = C.contact(["Ada"])
  @test C.set!(c, 1, "") && isempty(c.lines) && C.isblank(c)
end

@testset "what a click opens" begin
  c = C.contact(["Ada", "email: ada+work@example.com", "mobile: +61 (0)400 123-456", "address: 12 Example St,  Sydney NSW 2000", "web: example.com",
                 "web: http://example.org/a b", "note: a note", "ABN: 12", "phone: none"])
  opens = [C.link(d) for d in c.lines]
  @test opens[2] == "mailto:ada+work@example.com" && opens[3] == "tel:+610400123456"
  @test opens[4] == "maps://?q=12%20Example%20St%2C%20Sydney%20NSW%202000"
  @test opens[5] == "https://example.com" && opens[6] == "http://example.org/a b"
  @test opens[1] === nothing && opens[7] === nothing && opens[8] === nothing && opens[9] === nothing
  @test C.link(c.lines[4], maps="https://maps.apple.com/?q=") == "https://maps.apple.com/?q=12%20Example%20St%2C%20Sydney%20NSW%202000"
  @test C.initials("ada") == "A" && C.initials("Ada Augusta King") == "AK" && C.initials("") == "" && C.initials("(Dr) émile zola") == "ÉZ"
end

@testset "the vCard of a contact" begin
  card = C.vcard(C.contact(BLOCK))
  lines = split(card, "\r\n")
  @test lines[1:2] == ["BEGIN:VCARD", "VERSION:3.0"] && lines[end-1:end] == ["END:VCARD", ""]
  @test "N:Lovelace;Ada;;;" in lines && "FN:Ada Lovelace" in lines && "ORG:Analytical Engines" in lines && "TITLE:Engineer" in lines
  @test "EMAIL;TYPE=INTERNET:ada@example.com" in lines && "TEL;TYPE=CELL:0400 123 456" in lines && "URL:https://example.com" in lines
  # A comma has a \ before it, and the address is the street of the vCard's address
  @test "ADR;TYPE=WORK:;;12 Example St\\, Sydney NSW 2000;;;;" in lines
  # A line that a vCard has no place for goes in the note, and the photo is left out
  @test "NOTE:Met at the 2026 conference.\\nABN: 12 345 678 901" in lines
  @test !occursin("ada.jpg", card) && !occursin("PHOTO", card) && !occursin("X-ABShowAs", card)
  # The escapes for a comma, a semicolon and a \
  odd = C.vcard(C.contact(["Lee, Sam; Jr", "company: A;B, C\\D", "note: one, two; three"]))
  @test occursin("FN:Lee\\, Sam\\; Jr\r\n", odd) && occursin("ORG:A\\;B\\, C\\\\D\r\n", odd) && occursin("NOTE:one\\, two\\; three\r\n", odd)
  @test C.vtext("a\nb\r\nc") == "a\\nb\\nc"
  # One word is a given name
  @test occursin("N:;Ada;;;\r\n", C.vcard(C.contact(["Ada"])))
  # The kinds of phone
  phones = C.vcard(C.contact(["Ada", "phone: 1", "work: 2", "home: 3", "Fax: 4", "5550 1234"]))
  @test all(t -> occursin(t, phones), ["TEL;TYPE=VOICE:1", "TEL;TYPE=WORK:2", "TEL;TYPE=HOME:3", "TEL;TYPE=FAX:4", "TEL;TYPE=VOICE:5550 1234"])
  # A company is marked as one, and its name is its ORG line
  firm = C.vcard(C.contact(["Analytical Engines", "kind: company", "email: hello@example.com", "role: Maker"]))
  @test occursin("N:;;;;\r\nFN:Analytical Engines\r\nORG:Analytical Engines\r\nX-ABShowAs:COMPANY\r\n", firm)
  @test occursin("NOTE:role: Maker\r\n", firm) && !occursin("TITLE", firm) && !occursin("kind", firm)
  # A long line is folded into pieces of 75 bytes at the most, and no character is cut in two
  long = C.vcard(C.contact(["Ada", "note: " * "é"^120]))
  @test all(l -> ncodeunits(l) <= 75, split(long, "\r\n")) && isvalid(long)
  @test occursin("é"^120, replace(long, "\r\n " => ""))
  # Every contact of a block in one file
  file = C.vcards(C.contacts(["Ada", "", "Acme", "kind: company", "", "email:"]))
  @test count("BEGIN:VCARD", file) == 2 && count("END:VCARD\r\n", file) == 2 && occursin("FN:Acme", file)
  @test C.filename(C.contact(["Ada/Lovelace: 1"])) == "Ada Lovelace  1.vcf" && C.filename(C.Contact()) == "Contact.vcf"
end

# A card as the Contacts app of macOS writes it
const APPLE = """
BEGIN:VCARD\r
VERSION:3.0\r
PRODID:-//Apple Inc.//macOS 15.0//EN\r
N:Lovelace;Ada;Augusta;Dr;\r
FN:Dr Ada Augusta Lovelace\r
ORG:Analytical Engines;Research\r
TITLE:Engineer\r
EMAIL;type=INTERNET;type=WORK;type=pref:ada@example.com\r
item1.EMAIL;type=INTERNET:ada.home@example.com\r
item1.X-ABLabel:Other\r
TEL;type=CELL;type=VOICE;type=pref:0400 123 456\r
TEL;type=WORK;type=FAX:02 9000 0000\r
TEL;type=MAIN:1300 000 000\r
item2.ADR;type=WORK;type=pref:;;12 Example St\\nLevel 2;Sydney;NSW;2000;Australia\r
item2.X-ABADR:au\r
item3.URL;type=pref:https\\://example.com/a\\,b\r
NOTE:Met at the 2026 conference.\\nLikes tea\\; no milk\\, please.\r
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoH\r
 BwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkU\r
BDAY:1815-12-10\r
END:VCARD\r
BEGIN:VCARD\r
VERSION:3.0\r
N:;;;;\r
FN:Analytical Engines\r
ORG:Analytical Engines;\r
EMAIL;type=INTERNET;type=WORK;type=pref:hello@example.c\r
 om\r
X-ABShowAs:COMPANY\r
END:VCARD\r
"""

@testset "reading a vCard" begin
  list = C.from_vcard(APPLE)
  @test length(list) == 2 && C.isvcard(APPLE) && !C.isvcard("Ada Lovelace")
  @test C.written(list[1]) == ["Dr Ada Augusta Lovelace", "role: Engineer", "company: Analytical Engines",
                               "email: ada@example.com", "email: ada.home@example.com", "mobile: 0400 123 456", "fax: 02 9000 0000", "phone: 1300 000 000",
                               "address: 12 Example St, Level 2, Sydney, NSW, 2000, Australia", "web: https://example.com/a,b",
                               "note: Met at the 2026 conference.", "note: Likes tea; no milk, please."]
  # A line that's folded is one line. A company has the line that says so, and its ORG line isn't its company.
  @test C.written(list[2]) == ["Analytical Engines", "kind: company", "email: hello@example.com"] && C.iscompany(list[2])
  @test C.written(list) == [C.written(list[1]); ""; C.written(list[2])]
  # What's written is read back as the same contacts
  again = C.contacts(C.written(list))
  @test C.written(again) == C.written(list) && C.title.(again) == ["Dr Ada Augusta Lovelace", "Analytical Engines"]
  # A card with no FN uses N, and a company with no name uses ORG
  @test C.title(only(C.from_vcard("BEGIN:VCARD\nVERSION:3.0\nN:Lovelace;Ada;;;\nEND:VCARD\n"))) == "Ada Lovelace"
  firm = only(C.from_vcard("begin:vcard\nversion:3.0\norg:Acme Pty Ltd;\nx-abshowas:company\nend:vcard"))
  @test C.title(firm) == "Acme Pty Ltd" && C.iscompany(firm) && C.written(firm) == ["Acme Pty Ltd", "kind: company"]
  # Version 2.1: a setting is a word alone, and a value can be quoted-printable, with a line that goes on
  old = """
  BEGIN:VCARD
  VERSION:2.1
  N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Zola;=C3=89mile;;;
  FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=C3=89mile Zola
  TEL;CELL;VOICE:0400 111 222
  TEL;HOME:02 9111 2222
  EMAIL;PREF;INTERNET:emile@example.com
  ADR;WORK;ENCODING=QUOTED-PRINTABLE:;;1 Rue de l'=C3=89cole=0D=0AB=C3=A2timent 2;Paris;;75005;France
  NOTE;ENCODING=QUOTED-PRINTABLE:A long note that the app that wrote it =
  cut into two lines=2E
  END:VCARD
  """
  c = only(C.from_vcard(old))
  @test C.written(c) == ["Émile Zola", "mobile: 0400 111 222", "home: 02 9111 2222", "email: emile@example.com",
                         "address: 1 Rue de l'École, Bâtiment 2, Paris, 75005, France", "note: A long note that the app that wrote it cut into two lines."]
  # Version 4.0: a phone number is an address that starts with tel:, and the kinds are in quotes
  new = "BEGIN:VCARD\r\nVERSION:4.0\r\nFN:Grace Hopper\r\nTEL;VALUE=uri;TYPE=\"voice,cell\":tel:+1-555-0100\r\nURL;VALUE=uri:https://example.com\r\nKIND:individual\r\nEND:VCARD\r\n"
  @test C.written(only(C.from_vcard(new))) == ["Grace Hopper", "mobile: +1-555-0100", "web: https://example.com"]
  # A name that would be read as a line with a label is written with the label `name`
  @test C.written(only(C.from_vcard("BEGIN:VCARD\nFN:Ada: the first\nEND:VCARD"))) == ["name: Ada: the first"]
  # Text that isn't a vCard, a card with nothing in it and a card that never ends give no contacts
  @test isempty(C.from_vcard("Ada Lovelace\nemail: ada@example.com")) && isempty(C.from_vcard("BEGIN:VCARD\nVERSION:3.0\nEND:VCARD"))
  @test isempty(C.from_vcard("BEGIN:VCARD\nFN:Ada")) && isempty(C.from_vcard("")) && isempty(C.from_vcard("FN:Ada\nEND:VCARD\n:::\n;;;:"))
  # A contact that's written as a vCard is read back as it was
  back = only(C.from_vcard(C.vcard(C.contact(BLOCK))))
  @test C.written(back) == ["Ada Lovelace", "role: Engineer", "company: Analytical Engines", "email: ada@example.com", "mobile: 0400 123 456",
                            "address: 12 Example St, Sydney NSW 2000", "web: https://example.com", "note: Met at the 2026 conference.", "note: ABN: 12 345 678 901"]
  @test C.iscompany(only(C.from_vcard(C.vcard(C.contact(["Acme", "kind: company"])))))
end

@testset "the card of a page of HTML" begin
  html = C.markup(C.contact(BLOCK))
  @test startswith(html, "<div class=\"h-card\"") && endswith(html, "</div>\n</div>")
  @test occursin("<strong class=\"p-name\">Ada Lovelace</strong>", html)
  @test occursin("<span class=\"p-job-title\">Engineer</span>, <span class=\"p-org\">Analytical Engines</span>", html)
  @test occursin("<a class=\"u-email\" href=\"mailto:ada@example.com\">ada@example.com</a>", html)
  @test occursin("mobile</span> <a class=\"p-tel\" href=\"tel:0400123456\">0400 123 456</a>", html)
  @test occursin("<div class=\"p-adr\"><a href=\"https://maps.apple.com/?q=12%20Example%20St%2C%20Sydney%20NSW%202000\">12 Example St, Sydney NSW 2000</a></div>", html)
  @test occursin("<a class=\"u-url\" href=\"https://example.com\">example.com</a>", html)
  @test occursin("<div class=\"p-note\">Met at the 2026 conference.</div>", html) && occursin("ABN</span> 12 345 678 901</div>", html)
  @test occursin("<img class=\"u-photo\" src=\"ada.jpg\"", html)
  # With no photo, the card shows the initials. A company shows a building, and its name is its organisation.
  @test occursin(">AL</span>", C.markup(C.contact(BLOCK[1:3])))
  firm = C.markup(C.contact(["Analytical Engines", "kind: company"]))
  @test occursin("<strong class=\"p-name p-org\">Analytical Engines</strong>", firm) && occursin("<svg ", firm) && !occursin("kind", firm)
  # Every value is escaped
  odd = C.markup(C.contact(["<b>Ada</b> & \"co\"", "role: <i>", "email: a\"b@example.com", "web: example.com/?a=1&b=<2>", "note: 1 < 2", "x<y: z>w", "photo: a\".jpg"]))
  @test !occursin("<b>", odd) && !occursin("<i>", odd) && occursin("&lt;b&gt;Ada&lt;/b&gt; &amp; &quot;co&quot;", odd)
  @test occursin("href=\"mailto:a%22b@example.com\"", odd) && occursin("href=\"https://example.com/?a=1&amp;b=&lt;2&gt;\"", odd)
  @test occursin("1 &lt; 2", odd) && occursin("src=\"a&quot;.jpg\"", odd)
  # One card for each contact of a block, and nothing for a block with nothing to show
  @test count("class=\"h-card\"", C.markup(C.contacts(["Ada", "", "Acme", "kind: company", "", "kind: company"]))) == 2
  @test C.markup(C.Contact()) == "" && C.markup(C.contacts(["", ""])) == ""
end

@testset "lines that are wrong never throw" begin
  wrong = [":", "::", ": value", "label:", "a: b: c", "```", "\t", "kind: company", "kind: company", "photo:", "🙂: 🙂", "x"^500 * ": y", "é: è", "-: -", "1: 2"]
  list = C.contacts(wrong)
  @test length(list) == 2
  for c in list
    @test C.markup(c) isa String && C.vcard(c) isa String && C.rows(c) isa Vector{Int} && C.tagline(c) isa String
    @test all(d -> C.link(d) isa Union{String,Nothing} && C.caption(d) isa String, c.lines)
  end
  @test C.written(C.contacts(wrong)) == [wrong[1:6]; ""; wrong[8:end]]
end
