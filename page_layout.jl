# The page's lines, laid out: where the page starts, how wide its text is, and an item for each line and block

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "./markdown" Kind Line isdivider front_matter MATTER TOML_MATTER MATH
@use "./markdown" COMMENT
@use "./sheet" parts
@use "./eml" => Eml
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./math_view" exports...
@use "./julia_levels" exports...
@use "./csv_view" exports...
@use "./json_view" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./columns_view" exports...
@use "./long_file" exports...
@use "./slides_view" exports...
@use "./cover_view" exports...
@use "./email_view" exports...
@use "./email_head" exports...
@use "./media_view" exports...
@use "./page_extras" exports...
@use "./agent/window" exports...
@use "./news_page" exports...
@use "./sum_functions" exports...
@use "./top_bar" exports...
@use "./editing" exports...

export PLAIN_KINDS, keep_plain!, page_margin, page_x, reveal!, sheet_page, text_inset, right_room

# --- the page's lines, laid out ----------------------------------------------------
#
# How far under the top bar the page starts, how wide its text is, and where
# its left edge is. `layout!` makes an item for each line and block of the
# page, and `reveal!` scrolls the page so that the caret shows.

"True when the page shows a CSV file as a table"
sheet_page(b::Buffer) = b.view == :file && lowercase(splitext(b.path)[2]) in TABLES

"How far under the top bar the page starts. A CSV file's table and a JSON file's tree start nearer than the text of a page does, and a kind of folder can say how near its own page starts."
page_top(e) = begin
  own = page_top(e, page_object(e))
  own !== nothing ? own : sheet_page(e.buf) || (e.buf.view == :file && json_page(e.buf)) ? SHEET_ABOVE : PAGE_TOP
end

"""
How far under the top bar the page of `o` starts, for a file or a folder that's
shown its own way, or nothing for the room that a page of text has. What the
page shows is `LIVE_GAP` further down. A kind of folder has a method of this,
and of `page_margin`, for a page like a table, which wants less room round it.
"""
page_top(e, o) = nothing

"How much room the page of `o` has at each side, for a file or a folder that's shown its own way, or nothing for the room that a page of text has"
page_margin(e, o) = nothing

"How much room the page has at each side: the least beside a page's text, or what the kind of the file or folder that shows says"
page_x(e) = something(page_margin(e, page_object(e)), PAGE_X)

"""
How much of the window's width the panel at the right takes from the page's
text, as git's panel takes it beside the page of a folder in a repository. A
page that covers the page's space lays itself out beside the panel, and in
agent mode the page's card has its own room, so they lose none.
"""
right_room(e) = agent_shows(e) || page_covered(e) || right_view(e) === nothing ? 0px : right_w(e) * right_opened(e)

"How wide the page's text is in the window"
text_width(e) = begin
  w, _ = window_size(e)
  # While the sidebar slides, the text keeps the width it has beside the
  # sidebar, so it doesn't wrap again on each frame
  # The numbers of a file's lines have room on the left of the text
  # The lines of a block that fill the window have no sidebar beside them
  alone = lowered(e) !== nothing
  # A side menu's compact form keeps its width beside the text while the sidebar is closed
  beside = alone ? 0px : e.panel || sliding(e) ? panel_w(e) : side_least(e)
  # In agent mode, the text is on the page's card, which keeps its width while a pane slides
  # A panel at the right takes its room too
  room = (agent_shows(e) ? page_card_wide(e) : w - beside - right_room(e)) - 2page_x(e) - gutter(e)
  # A file of code or of text takes all the room that the window has, and so do a CSV file's table and
  # the lines of a block that fill the window. A page is no wider than the settings say. A page of a blog is
  # as wide as its site's text, for as many words to a line. A page with comments leaves room for them at its right.
  numbered(e.buf) || alone || json_page(e.buf) || bytes_page(e.buf) || sheet_page(e.buf) || own_page(e) ? max(room, 240px) :
    clamp(room - comment_room(e), 240px, e.look == :site ? SITE_MEASURE * TEXT_SIZE * e.zoom :
                                         e.look == :news ? NEWS_MEASURE * TEXT_SIZE * e.zoom : e.widest * e.zoom)
end

"""
How far the left edge of the page's text is from the left edge of the window.
A page's text is in the middle of the space beside the file panel. A file with
numbered lines starts at the left of that space, after its numbers, unless it's
scrolled to the right.
"""
text_left(e) = begin
  side, space = page_span(e)
  # The lines of a file's bytes start at the left too, and scroll to the right as numbered lines do
  # ... and a page of text is in the middle of the room that a panel at the right leaves it
  numbered(e.buf) || bytes_page(e.buf) ? side + PAGE_X + gutter(e) - sideways(e) : side + text_inset(e, space - right_room(e))
end

"""
How far the left edge of a page's text is from the left edge of `space`, the
room beside the file panel. The text is in the middle of it. When the page's
comments at its right don't fit in the margin there, the text and the comments
are in the middle together, so the text is to the left of the middle.
"""
text_inset(e, space) = begin
  extra = comment_room(e)
  extra == 0px && return max(page_x(e), (space - e.width) / 2)
  before = comment_balance(e, space)
  max(page_x(e), (space - e.width - extra - before) / 2) + before
end

# A page of Markdown is laid out again in each frame, since what a block shows
# can change with no change to the text. A line of plain text is different: it
# only changes when its text does. So each such line is kept by its number,
# with what it was laid out from, and the next frame takes it as it is when
# the line still has that text and is still the same kind of line. A long
# page then costs little more in a frame than a short one. The lines are kept
# with the other layouts, in `e.flows`, so what empties those empties them too.

"The kinds of line that are laid out from their own text alone. A to-do item is left out: on a day before today its box shows that day's tick."
const PLAIN_KINDS = (Kind.blank, Kind.paragraph, Kind.heading, Kind.bullet, Kind.ordered, Kind.blockquote, Kind.code, Kind.rule)

"Keep line `i` as it was laid out in this frame, for the next frame, when its layout came from its text alone"
keep_plain!(kept::Vector{Union{Nothing,PlainLine}}, b::Buffer, i::Int, line::Line, flow::Flow, tall::px) = begin
  text = b.lines[i]
  # A picture, what inline code made, and a footnote's number each come from more than the line's text
  # ... and a line with a comment can take no room, which isn't a layout of its own
  # ... and a line that shows the markup of one of its runs goes with where the caret is in it
  plain = line.kind in PLAIN_KINDS && !occursin("![", text) && !occursin(INLINE, text) && !occursin("[^", text) && !occursin("%%", text) &&
          raw_part(b, i) === nothing
  kept[i] = plain ? PlainLine(text, line, flow.raw, flow, tall) : nothing
end

"Work out what the page shows and how tall each part is, for text that's `width` wide"
layout!(e, width=text_width(e)) = begin
  b = e.buf
  unlist!(node!(Document, e, :document))   # the document's children are the parts that this layout gives it
  # The page is written as rich text or as plain text, as the switch in the top bar says. After a
  # change, the caret's place is looked at afresh.
  shows = e.plain && b.view == :markdown
  b.plain == shows || (b.plain = shows; b.stood = nothing)
  stand!(b)
  ks = kinds(b)
  width == e.width || (e.width = width; empty!(e.flows))
  columns = page_columns!(e)   # the blocks that show side by side after a `columns` block, or nothing when the page has none
  # A file that's only shown is one viewer, or lines of text that are laid out once and kept
  b.view == :file && return e.layout = [file_item(e, b)]
  # The text of a CSV file is lines of text too, which a key can change
  (readonly(b) || b.view == :text) && return e.layout = file_lines(e, b)
  # A file of code is lines of text too, which a key can change
  b.view == :code && columns === nothing && lowered(e) === nothing && return e.layout = slide_items(e, file_lines(e, b))
  items = Item[]
  # These three have their types written out. What a block or a table gives has no type that Julia knows before it
  # runs, and without these the loop below would look up the type of each of them for every line of the page.
  top::px = 0px
  i::Int = 1
  n::Int = length(b.lines)
  # The lines of a block that went down a level from the window it filled show by themselves, and so do
  # the lines of a part of this page that another page shows
  span = hosted(e) === nothing ? lowered(e) : shown_span(e)
  span === nothing || ((i, n) = span)
  # The email as it was sent, with the lines that it stands for, or nothing when the page shows its lines
  sent = span === nothing ? sent_email(e) : nothing
  sent === nothing || (lines = sent_lines(e); sent = lines === nothing ? nothing : (sent, lines))
  parts = 0   # how many lines that show a part of another page
  seen = Dict{String,Int}()   # and how many blocks in each of the languages of `BLOCKS`
  # The lines of plain text as the frame before laid them out: see `PlainLine`. A page in columns, an email as it
  # was sent, and a page of emails have lines that are laid out another way.
  kept = columns === nothing && sent === nothing && !Eml.isemail(b.path) ?
    get!(() -> Union{Nothing,PlainLine}[], e.flows, (:plain, b.path))::Vector{Union{Nothing,PlainLine}} : nothing
  # A page that has more lines than it had has nothing kept for the new ones
  kept === nothing || length(kept) == length(b.lines) || (had = length(kept); resize!(kept, length(b.lines)); fill!(view(kept, had+1:length(kept)), nothing))
  # The last line, while it leaves room at its end for a button, is laid out afresh and not kept: see `end_room`
  room_at_end = end_room(e) > 0px
  while i <= n
    # In a column, the page's text is as wide as the column, and each column starts level with the first
    columns === nothing || (top = column_turn!(columns, e, items, i, top))
    if kept !== nothing && !(room_at_end && i == length(b.lines))
      was = kept[i]
      if was !== nothing && pointer(was.text) == pointer(b.lines[i]) && was.line === ks[i] && was.raw == israw(b, i) && raw_part(b, i) === nothing &&
         html_runs(b)[i][1] == 0
        push!(items, Item(i, i, top, was.tall, was.flow))
        top += was.tall
        i += 1
        continue
      end
    end
    j = i
    if ks[i].kind == Kind.table
      while j < n && ks[j+1].kind == Kind.table
        j += 1
      end
    end
    # Front matter shows as a card, unless the caret is in it
    if i == 1 && ks[1].kind == Kind.fence && ks[1].lang in (MATTER, TOML_MATTER) && !incode(b, 1)
      t = front_matter(b.lines)
      if t > 1
        content = matter_card(e, t)
        if content === nothing
          push!(items, flat(e, Item(1, t, top, 0px, nothing)))
        else
          push!(items, Item(1, t, top, content.tall, content))
          top += content.tall
        end
        i = t + 1
        continue
      end
    end
    # A comment on lines of its own takes no room, unless the caret is in it. Nor do the empty lines after it that
    # `comment_fold` counts, unless the caret is on one of them, which then shows.
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == COMMENT && !incode(b, i)
      t = codeblock(b, i)[2]
      fold = comment_fold(b, i)[2]
      (caretless(b) || !(t < b.caret[1] <= fold || t < b.anchor[1] <= fold)) && (t = fold)
      push!(items, flat(e, Item(i, t, top, 0px, nothing)))
      i = t + 1
      continue
    end
    # An email shows as it was sent, in place of the lines that were made of it, once its pictures are there
    if sent !== nothing && i == sent[2][1]
      content = sent_item(e, sent[1])
      push!(items, Item(i, sent[2][2], top, content.tall, content))
      top += content.tall
      i = sent[2][2] + 1
      continue
    end
    # A block in one of the languages of `BLOCKS` shows as its component, grid or view
    if ks[i].kind == Kind.fence && ks[i].level == 0 && haskey(BLOCKS, ks[i].lang)
      lang = ks[i].lang
      seen[lang] = get(seen, lang, 0) + 1   # each one keeps its view by its place among the page's blocks in its language
      laid = block_layout(BLOCKS[lang], e, lang, i, seen[lang])
      if laid !== nothing
        t, content = laid
        push!(items, Item(i, t, top, tall(content), content))
        top += tall(content)
        i = t + 1
        continue
      end
    end
    # A block in a language that a file defines shows what the file's function makes of it, unless the caret is in it
    if ks[i].kind == Kind.fence && ks[i].level == 0 && !isempty(ks[i].lang) && !known_lang(ks[i].lang)
      lang = ks[i].lang
      seen[lang] = get(seen, lang, 0) + 1   # every block in the language counts, as `block_lines` counts them
      source = block_source(b, i)
      t = codeblock(b, i)[2]
      if source !== nothing && !incode(b, i) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1
        content = file_block_item(e, lang, source, i, t, seen[lang])
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A formula between two lines of $$, or in a `math` code block, shows as it's set, unless the caret is in it
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == MATH && !incode(b, i)
      t = codeblock(b, i)[2]
      content = t > i && ks[t].kind == Kind.fence && ks[t].level == 1 ? equation_item(e, join(b.lines[i+1:t-1], "\n")) : nothing
      if content !== nothing
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A line that holds only a formula between $$ and $$ shows the formula, unless the caret is in the line
    if ks[i].kind == Kind.paragraph && !israw(b, i) && maths_line(b, i)
      content = equation_item(e, maths_text(b.lines[i]))
      if content !== nothing
        push!(items, Item(i, i, top, content.tall, content))
        top += content.tall
        i += 1
        continue
      end
    end
    # The links at the end of an email to the files that came with it show as file icons, at both of its levels
    if ks[i].kind == Kind.paragraph && !israw(b, i) && Eml.isemail(b.path)
      content = attached_item(e, i)
      if content !== nothing
        push!(items, Item(i, content.node.to, top, content.tall, content))
        top += content.tall
        i = content.node.to + 1
        continue
      end
    end
    # A line that holds only a link like ![[Ideas#Plans]] shows that part of the other page, unless the caret is in the line
    if ks[i].kind == Kind.paragraph && !israw(b, i) && transcludes(b, i)
      parts += 1   # each one keeps its view by its place among the page's lines like it
      content = transclusion_item(e, i, parts)
      push!(items, Item(i, i, top, content.tall, content))
      top += content.tall
      i += 1
      continue
    end
    # A line that holds only a comment takes no room either, unless the caret is on it
    if ks[i].kind == Kind.paragraph && !alone(b, i) && comment_only(b.lines[i])
      t = something(comment_fold(b, i), (i, i))[2]
      (caretless(b) || !(i < b.caret[1] <= t || i < b.anchor[1] <= t)) || (t = i)
      push!(items, flat(e, Item(i, t, top, 0px, nothing)))
      i = t + 1
      continue
    end
    # Lines of HTML show as a browser draws them, unless the caret is in them: see "HTML in a page"
    if ks[i].kind == Kind.paragraph && (tags = html_block(b, i)) !== nothing && tags[1] == i && !html_typed(b, tags...)
      content = html_item(e, tags...)
      if content !== nothing
        push!(items, Item(i, tags[2], top, content.tall, content))
        top += content.tall
        i = tags[2] + 1
        continue
      end
    end
    # A line that holds only a picture shows the picture, unless the caret is on the line
    if ks[i].kind == Kind.paragraph && !israw(b, i) && occursin("![", b.lines[i])
      content = picture_item(e, i)
      if content !== nothing
        push!(items, Item(i, i, top, content.tall, content))
        top += content.tall
        i += 1
        continue
      end
    end
    # A kind of folder can show a table its own way, unless the caret is in the table: see `table_view`. A page
    # that you can't change has a caret on its first line, which doesn't count.
    if j > i && isdivider(b.lines[i+1]) && (caretless(b) || !(i <= b.caret[1] <= j))
      content = table_item(e, i, j)
      if content !== nothing
        push!(items, Item(i, j, top, content.tall, content))
        top += content.tall
        i = j + 1
        continue
      end
    end
    # A table needs its line of dashes. It shows as plain lines while the caret is on that line.
    if j > i && isdivider(b.lines[i+1]) && !israw(b, i + 1)
      content = grid(e, i, j)
      push!(items, Item(i, j, top, tall(content), content))
      top += tall(content)
      i = j + 1
    else
      content = flow(e, i)::Flow
      high = tall(content)
      push!(items, Item(i, i, top, high, content))
      kept === nothing || (room_at_end && i == length(b.lines)) || keep_plain!(kept, b, i, ks[i], content, high)
      top += high
      i += 1
    end
  end
  columns === nothing || column_turn!(columns, e, items, n + 1, top)   # the page ends in a column
  e.layout = slide_items(e, items)   # while the page shows as slides, only the items of one slide
end

"Scroll so the caret is on screen"
reveal!(e) = begin
  e.buf.view == :file && return   # a viewer has no caret
  it = item(e, e.buf.caret[1])
  top, bottom = it.top, it.top + it.tall
  if it.content isa Flow
    k, x = spot(it.content, e.buf.caret[2])
    top = it.top + line_top(it.content, k)
    bottom = top + it.content.lines[k].high
    # A long line that doesn't wrap scrolls sideways to show the caret, with a little of the line on each side of it
    if !wraps(e)
      b = e.buf
      x < b.across + SIDE_ROOM && (b.across = x - SIDE_ROOM)
      x > b.across + e.width - SIDE_ROOM && (b.across = x - e.width + SIDE_ROOM)
      scroll_sideways!(e, 0px)
    end
  elseif it.content isa Sheet
    r = clamp(e.buf.caret[1] - it.first, 1, length(it.content.rows))
    top = it.top + row_top(it.content, r)
    bottom = top + it.content.heights[r]
  end
  scroll_into_view!(e.scroll, PAGE_TOP + top - 30px, PAGE_TOP + bottom + 40px)
end
