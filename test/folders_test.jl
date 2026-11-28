# Tests for what Ladder knows of folders and shows of them: the table of a
# folder, with its sizes, its times and the menus of its headings, the home
# folder, which is a folder like any other, and the favourite folders. See "a
# table of what's in a folder" and "the home folder, and favourite folders" in
# main.jl, and folders.jl. Run them with
# `julia -O0 --project=. test/folders_test.jl`. They use a home folder of
# their own, never the Mac's, and they click in a window that isn't on the
# screen. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle

const px = K.px
const H = K.Folders

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
H.FILE[] = joinpath(dir, "home-list")

# A home folder with a repository, a folder on its Desktop, a folder of email, its Library and a hidden folder
const home = mkpath(joinpath(dir, "sam"))
made(rel, text="some text") = (path = joinpath(home, rel); mkpath(dirname(path)); write(path, text); path)
const app = mkpath(joinpath(home, "Code", "app"))
run(pipeline(`git -C $app init -q`, stdout=devnull, stderr=devnull))
made("Code/app/.gitignore", "build/\n")
const main_file = made("Code/app/main.jl", "f(x) = x\n")
const notes = made("Code/app/notes.md", "# Notes\n")
const built = made("Code/app/build/out.bin")
const finder_file = made("Code/.DS_Store", "what the Finder keeps")   # hidden, so the table leaves it out, but it counts in the folder's size
const plan = mkpath(joinpath(home, "Desktop", "Plan"))
run(pipeline(`git -C $plan init -q`, stdout=devnull, stderr=devnull))
const report = made("Desktop/Plan/2026/report.md", "# Report\n")
const mail = made("Mail/Inbox/1.eml", "Subject: hi\n\nhi\n")
const loose = made("list.csv", "a,b\n1,2\n")
const prefs = made("Library/Preferences/x.plist")
const config = made(".config/tool/settings")
const page = made("page.md", "# Sam's page\n")
const favs = [mkpath(joinpath(home, name)) for name in ("Alpha", "Beta", "Gamma")]

const hour = 3600.0

@testset "the list of favourites is kept in its file" begin
  @test H.favourites() == []
  H.favourite!(favs[1]); H.favourite!(favs[2] * "/"); H.favourite!(favs[1])
  @test H.favourites() == favs[1:2]
  H.unfavourite!(favs[1])
  @test H.favourites() == [favs[2]]
  # Another window of Ladder reads the same file
  H.READ[] = (-1.0, H.Kept())
  @test H.favourites() == [favs[2]] && H.isfavourite(favs[2]) && !H.isfavourite(favs[1])
  H.unfavourite!(favs[2])
  @test H.favourites() == []
  # A file from when the home folder's page hid projects keeps its favourites, and loses the rest when it's written
  write(H.file(), "favourite\t$(favs[1])\nhidden\t$(app)\n")
  @test H.favourites() == [favs[1]]
  H.unfavourite!(favs[1])
  @test read(H.file(), String) == ""
end

"Give the folder or the file at `path` the time `t` as the time that it last changed"
stamp(path, t) = run(`touch -m -t $(Libc.strftime("%Y%m%d%H%M.%S", t)) $path`)
"Give the folder at `path` and everything in it, at any depth, the time `t`"
stamp_all(path, t) = run(`find $path -exec touch -m -t $(Libc.strftime("%Y%m%d%H%M.%S", t)) "{}" +`)
"Wait until `f()` is true, for no longer than `s` seconds, and say whether it is"
wait_until(f; s=10) = (t0 = time(); while !f() && time() - t0 < s; sleep(0.05) end; f())
"The bytes of every file in the folder at `path`, at any depth, hidden ones too"
bytes_in(path) = sum((lstat(joinpath(r, f)).size for (r, _, fs) in walkdir(path) for f in fs), init=0)

@testset "a folder's time is when anything in it last changed, at any depth" begin
  root = mkpath(joinpath(dir, "times"))
  put(rel) = (p = joinpath(root, rel); mkpath(dirname(p)); write(p, "x"); p)
  put("Deep/a/b/c/new.txt"); put("Deep/old.txt"); put("Deep/a/.git/HEAD"); put("Flat/one.txt"); put("Library/Caches/x")
  now = time()
  stamp_all(root, now - 100hour)
  stamp(joinpath(root, "Deep/a/b/c/new.txt"), now - 3hour)
  # Neither a hidden file nor what's in the Library counts
  stamp(joinpath(root, "Deep/a/.git/HEAD"), now - 0.1hour)
  stamp(joinpath(root, "Library/Caches/x"), now - 1hour)
  deep, flat, library = folders = [joinpath(root, n) for n in ("Deep", "Flat", "Library")]
  # The Library's time is known at once: it's its own. The others are read on a second thread.
  @test haskey(H.newest(root, folders), library)
  @test wait_until(() -> H.times_read(root))
  got = H.newest(root, folders)
  @test isapprox(got[deep], now - 3hour, atol=1)
  @test isapprox(got[flat], now - 100hour, atol=1)
  @test isapprox(got[library], now - 100hour, atol=1)
  # A folder's size is of its files at any depth, hidden ones too. The Library isn't read, so it has none.
  @test H.sizes(root) == Dict(deep => 3, flat => 1)
  # A change that macOS tells of moves its folder's time on, at any depth, in the Library too
  put("Flat/x/y/z.txt"); put("Library/Caches/y")
  @test wait_until(() -> (g = H.newest(root, folders); g[flat] > now - 60 && g[library] > now - 60))
  # A folder that came is read for its size
  @test wait_until(() -> H.sizes(root)[flat] == 2)
  # A change in a hidden folder doesn't move the time on, but its size counts
  put("Deep/a/.git/index")
  sleep(1.5)
  @test isapprox(H.newest(root, folders)[deep], now - 3hour, atol=1)
  @test H.sizes(root)[deep] == 4
  # A file that grows, and a folder that goes, change the size
  write(joinpath(root, "Deep/old.txt"), "xxxxx")
  rm(joinpath(root, "Flat/x"), recursive=true)
  @test wait_until(() -> H.sizes(root) == Dict(deep => 8, flat => 1))
  # The page of the Library, or of a folder in it, doesn't read the folders in it either: each time is its own
  caches = joinpath(library, "Caches")
  @test H.unread(library) && H.unread(caches) && !H.unread(deep)
  @test haskey(H.newest(library, [caches]), caches)
  H.forget_times!()
end

K.HOME[] = home
const e = K.build_editor(page)
e.panel = true   # the sidebar is open
const w = Window(e, size=(1100px, 760px))
const (; frames, at, click, typed, key, shot) = drive(w, frames=3, pressed=1, latest=true)
frames()

menu() = (ps = [p for p in popups(w) if p.key == :menu]; isempty(ps) ? nothing : only(ps).content)
choose(name) = (m = menu(); foreach(_ -> key(Keys.down), 1:findfirst(==(name), m.items)); key(Keys.enter))
right_click(place) = (at(place); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())
"Sort the folder table `t` by the column `k` from its heading's menu, Z, the largest or the newest first when `desc` is true"
sort_by(t, k, desc) = (click(middle(t.heads[k])); click(middle(t.parts[(:order, desc)])); K.close_folder_menu!(t); frames())
"True when the menu of a column of a folder's table shows"
column_menu() = any(p -> p.key == K.FOLDER_KEY, popups(w))
"What's typed in the field `k` of the menus of the folder table `t`"
field(t, k) = K.field_text(t, k)

"The name in the trail at the top of the sidebar of the folder at `path`"
trail_name(path) = only(n for n in values(e.nodes) if n isa K.TrailName && n.path == path && rect(n) !== nothing)

@testset "the home folder is a folder like any other, and its name in the trail opens it" begin
  @test e.folder == home
  d = K.object(e, home)
  # It has the icon of a folder, and no page of its own
  @test K.entry_icon(d) == "folder" && K.page_view(e, d) === nothing
  @test K.folder_view(e, d).bar === nothing
  frames()
  # The sidebar's own folder is the last name of the trail. A click on it opens the folder's table.
  t = trail_name(home)
  @test t.last && K.goes(t)
  click(middle(t))
  @test e.buf.path == home && e.folder == home
  @test e.nodes[(:folder_page, home)] isa K.FolderPage && rect(e.nodes[(:folder_table, home)]) !== nothing
  shot("folders-home")
  K.open!(e, page)
  frames()
end

@testset "⌘⇧H opens the home folder" begin
  @test e.buf.path == page
  e.panel = false; frames()
  key(Keys.h, Keys.cmd, Keys.shft)
  @test e.buf.path == home && e.folder == home && e.nodes[(:folder_page, home)] isa K.FolderPage
  @test !e.panel   # a hidden sidebar stays hidden
  e.panel = true; frames()
end

@testset "a folder's menu makes it a favourite, and Go To Favourite opens it" begin
  @test "Add to Favourites" in K.file_menu(favs[1])
  foreach(f -> K.file_act!(e, f, "Add to Favourites"), favs)
  @test H.favourites() == favs
  @test "Remove from Favourites" in K.file_menu(favs[1]) && !("Add to Favourites" in K.file_menu(favs[1]))
  # A file's menu has neither
  @test !any(i -> occursin("Favourites", i), K.file_menu(page))
  K.file_act!(e, favs[3], "Remove from Favourites")
  @test H.favourites() == favs[1:2]
  # The palette's Go To Favourite lists them in their order, and opens one in the page
  @test [f.path for f in K.choices_for(K.Favourite, e)] == favs[1:2]
  @test K.worded(K.Favourite(favs[2])) == "Beta"
  K.go_to_favourite!(e, K.Favourite(favs[2]))
  frames()
  @test e.folder == favs[2] && e.buf.path == favs[2] && e.nodes[(:folder_page, favs[2])] isa K.FolderPage
  # The commands of the folder in focus do the same as its menu
  K.add_to_favourites!(K.object(e, favs[3]))
  @test H.favourites() == favs
  K.remove_from_favourites!(K.object(e, favs[3]))
  @test H.favourites() == favs[1:2]
  K.go_home!(e); frames()
end

@testset "the home folder's page is the table of what's in it, the newest first" begin
  v = e.nodes[(:folder_table, home)]
  @test v isa K.FolderTable
  H.forget_times!()
  now = time()
  ages = ["page.md" => 0.02, "Desktop" => 2, "Code" => 26, "list.csv" => 50, "Mail" => 80,
          "Alpha" => 100, "Beta" => 120, "Gamma" => 140, "Library" => 400]
  foreach(((name, h),) -> stamp_all(joinpath(home, name), now - h * hour), ages)
  # A folder's time is when anything in it changed, apart from hidden things
  stamp(main_file, now - 0.5hour)
  stamp(joinpath(app, ".git", "HEAD"), now)
  order = ["page.md", "Code", "Desktop", "list.csv", "Mail", "Alpha", "Beta", "Gamma", "Library"]
  # Until a folder is read, its time says so
  all_read() = (v.read = 0.0; frames(1); all(it -> it.known && (it.sized || basename(it.path) == "Library"), v.items))
  @test wait_until(all_read)
  frames()
  names() = [K.entry_name(it.object) for it in K.folder_sorted(v)]
  row(name) = v.rows[(:item, joinpath(home, name))]
  # The sidebar's folders and files, with no hidden folder, the one that changed last first
  @test v.sort == :when && v.desc
  @test names() == order
  @test isapprox(only(it.when for it in v.items if basename(it.path) == "Code"), now - 0.5hour, atol=1)
  # The rows show in that order, from the top
  tops = [K.num(rect(row(n)).top) for n in order]
  @test issorted(tops) && allunique(tops)
  shot("folders-table")
  # A click on a heading sorts the table by its column, and a second click sorts it the other way
  by_name = ["Alpha", "Beta", "Code", "Desktop", "Gamma", "Library", "list.csv", "Mail", "page.md"]
  sort_by(v, :name, false)
  @test v.sort == :name && !v.desc && names() == by_name
  @test issorted([K.num(rect(row(n)).top) for n in by_name])
  sort_by(v, :name, true)
  @test v.desc && names() == reverse(by_name)
  # The largest first. A folder's size is of everything in it, and the two repositories have the most, in their .git folders.
  # Empty folders keep the sidebar's order, and the Library, which isn't read, comes last.
  sort_by(v, :size, true)
  @test v.sort == :size && v.desc
  @test sort(names()[1:2]) == ["Code", "Desktop"]
  @test names()[3:end] == ["Mail", "page.md", "list.csv", "Alpha", "Beta", "Gamma", "Library"]
  sizes = Dict(basename(it.path) => K.size_cell(it) for it in v.items)
  @test sizes["Mail"] == "16 bytes" && sizes["Alpha"] == "0 bytes" && sizes["Library"] == "" && sizes["page.md"] == "13 bytes"
  # The Library isn't read, so the line under the home folder's name can't say how big the home folder is
  @test v.bytes == -1 && K.holds_words(v) == "7 folders  ·  2 files"
  # A new column starts with the newest first, and a second click puts the oldest first
  sort_by(v, :when, true)
  @test v.sort == :when && v.desc && names() == order
  sort_by(v, :when, false)
  @test !v.desc && names() == reverse(order)
  shot("folders-table-oldest")
  sort_by(v, :when, true)
  @test v.desc
  # A new file deep in a folder puts the folder first, as soon as macOS tells of it
  made("Mail/Inbox/2.eml", "Subject: hello\n\nhello\n")
  @test wait_until(() -> (v.read = 0.0; frames(1); names()[1] == "Mail"))
  shot("folders-table-change")
  # A right-click shows the row's menu, with no Rename
  right_click(middle(row("Code")))
  @test menu() !== nothing && "Show in Finder" in menu().items && !("Rename" in menu().items)
  key(Keys.escape)
  # A click on a folder opens it in the page, as a table of its own, the newest first
  click(middle(row("Code")))
  code = joinpath(home, "Code")
  @test e.buf.path == code && e.nodes[(:folder_page, code)] isa K.FolderPage
  t = e.nodes[(:folder_table, code)]
  @test [basename(it.path) for it in t.items] == ["app"]
  # Under its name is what it holds, and how big that is once its folders are read, with the hidden file that
  # the table leaves out. Its path is in the top bar, not there.
  @test wait_until(() -> (t.read = 0.0; frames(1); t.bytes >= 0))
  @test t.bytes == bytes_in(code) > bytes_in(app)
  @test K.holds_words(t) == "1 folder  ·  " * K.Zips.size_words(bytes_in(code))
  @test t.sort == :when && t.desc
  @test rect(t.rows[(:item, app)]) !== nothing && rect(t.heads[:when]) !== nothing
  shot("folders-folder-table")
  # Its folder's time is when anything in it changed: the newest file in app is main.jl
  @test wait_until(() -> (t.read = 0.0; frames(1); only(t.items).known))
  @test isapprox(only(t.items).when, now - 0.5hour, atol=1)
  # Its own order, apart from the home folder's
  sort_by(t, :name, false)
  @test t.sort == :name && v.sort == :when
  # A click on a file shows it
  K.go_home!(e); frames()
  click(middle(row("page.md")))
  @test e.buf.path == page
  K.go_home!(e); frames()
end

@testset "a click on a heading opens its menu, which sorts the table and shows fewer rows" begin
  K.go_home!(e); frames()
  v = e.nodes[(:folder_table, home)]
  v.read = 0.0; frames()
  names() = Set(K.entry_name(it.object) for it in K.folder_filtered(v, v.items))
  everything = Set(["page.md", "Code", "Desktop", "list.csv", "Mail", "Alpha", "Beta", "Gamma", "Library"])
  @test names() == everything
  # Each thing has the Finder's kind, which its icon shows. The heading over the icons opens the menu of the kinds.
  @test all(it -> (it.kind == "Folder") == it.folder, v.items) && all(it -> !isempty(it.kind), v.items)
  @test rect(v.heads[:kind]) !== nothing
  # The name's menu has a field for words that a name holds, and it has the keyboard
  click(middle(v.heads[:name]))
  @test column_menu() && v.asking == :name && w.focus === v.fields[:name]
  shot("folders-name-menu")
  typed("a")
  @test names() == Set(["page.md", "Mail", "Alpha", "Beta", "Gamma", "Library"])
  @test K.narrowed(v, :name) && K.narrowed(v)
  # esc puts back what the column had, and closes the menu
  key(Keys.escape)
  @test !column_menu() && v.asking == :none && field(v, :name) == "" && names() == everything
  # Return keeps what's typed, and a line over the rows has a button that shows every row again
  click(middle(v.heads[:name])); typed("a"); key(Keys.enter)
  @test !column_menu() && names() == Set(["page.md", "Mail", "Alpha", "Beta", "Gamma", "Library"])
  shot("folders-name-filtered")
  click(middle(v.buttons[:clear]))
  @test !K.narrowed(v) && names() == everything
  # The size has two ends. A folder's size counts, and a folder that isn't read has none.
  click(middle(v.heads[:size]))
  @test w.focus === v.fields[:size_lo]
  typed("10")
  @test names() == Set(["page.md", "Mail", "Code", "Desktop"])
  key(Keys.tab)
  @test w.focus === v.fields[:size_hi]
  typed("1 KB")
  @test names() == Set(["page.md", "Mail"])
  shot("folders-size-menu")
  # Words that aren't a size don't count, and the field says so
  v.fields[:size_lo].text = "ten"
  frames()
  @test K.unread_field(v, :size_lo) && names() == Set(["page.md", "Mail", "list.csv", "Alpha", "Beta", "Gamma"])
  key(Keys.escape)
  @test !K.narrowed(v)
  # The time has two ends, written as the column writes times, or as days
  click(middle(v.heads[:when]))
  typed("1 day ago")
  @test names() == Set(["page.md", "Mail", "Code", "Desktop"])
  key(Keys.tab); typed("1 h ago")
  @test names() == Set(["Desktop"])
  shot("folders-when-menu")
  key(Keys.enter)
  K.clear_filters!(v); frames()
  # The menu of the kinds has a tick for each kind, with its icon and how many there are
  click(middle(v.heads[:kind]))
  @test v.parts[(:kind, "Folder")].count == 7
  click(middle(v.parts[(:kind, "Folder")]))
  @test v.kinds == Set(["Folder"]) && names() == Set(["Code", "Desktop", "Mail", "Alpha", "Beta", "Gamma", "Library"])
  shot("folders-kind-menu")
  # The menu's orders sort by its column
  click(middle(v.parts[(:order, false)]))
  @test v.sort == :kind && !v.desc
  key(Keys.enter)
  K.clear_filters!(v)
  sort_by(v, :when, true)
end

@testset "the ends of a size or a time can be written in many ways" begin
  @test K.read_size("10 MB") == 10_000_000 && K.read_size("1.5gb") == 1_500_000_000 && K.read_size("500k") == 500_000
  @test K.read_size("300") == 300 && K.read_size("300 bytes") == 300 && K.read_size(" 2 GB ") == 2_000_000_000
  @test K.read_size("ten") === nothing && K.read_size("5 parsecs") === nothing && K.read_size("") === nothing
  noon = K.day_edge(K.Date(2026, 11, 23), false) + 12hour
  start(y, m, d) = K.day_edge(K.Date(y, m, d), false)
  @test K.read_when("3 days ago", false; now=noon) == noon - 72hour == K.read_when("3d", false; now=noon)
  @test K.read_when("2 h ago", false; now=noon) == noon - 2hour == K.read_when("2 hours", true; now=noon)
  @test K.read_when("5 min ago", false; now=noon) == noon - 300 && K.read_when("just now", true; now=noon) == noon
  @test K.read_when("today", false; now=noon) == start(2026, 11, 23)
  @test K.read_when("yesterday", false; now=noon) == start(2026, 11, 22)
  @test K.read_when("yesterday", true; now=noon) ≈ start(2026, 11, 23) - 0.001
  @test K.read_when("1 Nov 2026", false; now=noon) == start(2026, 11, 1) == K.read_when("1 nov", false; now=noon)
  @test K.read_when("2026-11-01", false; now=noon) == start(2026, 11, 1) == K.read_when("1/11/2026", false; now=noon)
  @test K.read_when("Nov 1", false; now=noon) == start(2026, 11, 1) == K.read_when("1 November", false; now=noon)
  # A day with no year that's still to come this year is last year's
  @test K.read_when("25 Dec", false; now=noon) == start(2025, 12, 25)
  @test K.read_when("soon", false; now=noon) === nothing && K.read_when("", false) === nothing
end

@testset "a click on a folder in the trail opens it in the page at once" begin
  K.open!(e, notes)
  frames()
  @test e.folder == app && e.buf.path == notes
  code = joinpath(home, "Code")
  click(middle(trail_name(code)))
  @test e.folder == code && e.buf.path == code && e.nodes[(:folder_page, code)] isa K.FolderPage
  click(middle(trail_name(home)))
  @test e.folder == home && e.buf.path == home && e.nodes[(:folder_page, home)] isa K.FolderPage
  # ⌘⌥← goes back to the page that showed before
  K.go_back!(e)
  frames()
  @test e.buf.path == code
end
