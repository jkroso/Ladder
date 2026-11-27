# What the part of a page asks of the window that shows it: the window's
# editor, the object of the file or the folder that the page shows, and the
# things that the window does with a folder or a file. This file only names
# them. main.jl gives each its methods for its Editor, so a view in a file of
# its own, like the page of a kind of folder, can call them without main.jl.
#
#     e = editor(node)               # the window's editor that a node of a page is part of
#     go_folder!(e, "/Users/sam")    # list that folder in the sidebar
#     open_folder!(e, "/Users/sam")  # show it in the page

export editor, page_object, object, list_files!, go_folder!, open!, open_folder!, show_path!, show_beside!,
       free_path, folder_kind, page_top, trash!, file_act!, show_in_finder, above_page, touch!, show_line!,
       page_day, save_settings!, rerun!, page_room, page_tables, named_table, layout!, command_of,
       click_page!, text_object, say_result!, lowered, rewrap!, reload_changed!, loaded_module, fillable,
       diagram_html, outcome_face, julia_code, calendar_today, marked, term_page, chat_page, scroll_page!,
       keep_talk!, follow_host!, celltext, lowest, component, unscaled, command_kind, pinch_open, another_day,
       blocks, chart_file, chat_shown, code_offered, code_start, complete!, def_call, definition_of,
       design_field_of, escaped, file_table, folder_pages, follow_wiki!, hide_bar!, hiding_name, html_shown,
       ispicture, istable, keep_copy, keep_pasted, line_step, listed_agents, mark_colour, markdown_app,
       name_at, name_notes, needs_run, note_place!, page_covered, page_given, page_log, page_text, page_then,
       part_lines, part_texts, passing, plain_name, planned_tasks, redraw_windows!, rows, run_in, run_sum,
       running_code, save_panel, selected, sheet_given, sheet_html, sheet_work, shown_buffers, standing,
       table_rows, term_choice, term_look!, term_shown, text_left, thing_name, tick!, tick_page!, tip_code,
       todo_called, todos_then, update_news, value_parts, visit!, wiki_offered, wiki_path, worked,
       write_blocks!, item_room, item_under, gallery_buttons, gallery_edges, go_view!, view_name, side_w,
       look_key, player, show_crumb!, video_wide, textview, bytes, model, terminal, html_page, scrolled,
       design, kept!, text!, make_default!, fill_what, fill_wide, preview, zoomed_node, zoom_for, held_room,
       square_button, enter, bar_bottom, chart_path, chart_sources, isfilterable, filter_file, filter_write!,
       filter_table, filter_subset, key_panel, error_words, file_start, server_said, keep_key, table_file,
       choice_matches, toggle_source!, tick_item!, block_end, type!, web_browser, sum_name, given_and_sums,
       carry_sums!, follow_remote!, run_place, value_text, usual_module, own_units, remote_src, finding,
       follow!, filled, todo_at, link_on, close_find!, took, page_bottom, keep_got!, get_page!, browser_path,
       page_online, changed_here

"The editor of the window that `node`, a part of a page, is part of"
function editor end

"The object of the file or the folder that the page of the editor `e` shows, or nothing"
function page_object end

"The object of the folder or the file at `path`, as the sidebar of the editor `e` lists it, or nothing when nothing is there"
function object end

"Read the folder of the sidebar of the editor `e` again"
function list_files! end

"Show the folders and the files of `folder` in the sidebar of the editor `e`"
function go_folder! end

"Show the file or the folder at `path` in the page of the editor `e`"
function open! end

"Open the folder at `path` in the page of the editor `e`"
function open_folder! end

"Show the file or the folder at `path` the way that a click on a link to it does, in the window of the editor `e`"
function show_path! end

"Show the folder or the file at `path` in the page of the editor `e`, while the sidebar goes on with the folder that it lists"
function show_beside! end

"A path in the folder `dir` for something new called `base`, with the ending `ending`, that no file and no page of the editor `e` has yet"
function free_path end

"The kind of the folder at `path`: the type under AbstractDirectory that its object has"
function folder_kind end

"How far down the page of the editor `e` its text starts, under the top bar and what the page shows over its text"
function page_top end

"Move the file or the folder at `path` to the Trash, and take it out of the sidebar of the editor `e`"
function trash! end

"Do to the file or the folder at `path` what the item `name` of its menu says, in the editor `e`"
function file_act! end

"Open a Finder window on the folder of the file at `path`, with the file selected"
function show_in_finder end

"How much room the top bar of the editor `e` keeps at the top of the window, over the page"
function above_page end

"The caret of the editor `e` moved or its text changed, so show the caret"
function touch! end

"Put the caret of the editor `e` at the end of line `i` of the page, and bring the line in sight"
function show_line! end

"The day that the page of the editor `e` shows itself on: today, unless a `day` block says another"
function page_day end

"Give the other windows the settings of the editor `e`, and write them to their file if `e` keeps them"
function save_settings! end

"Run again the live blocks of the editor `e` that asked for `setting`"
function rerun! end

"How wide and how tall the page's space in the window of the editor `e` is"
function page_room end

"Every table of the page of the editor `e` that shows, with its lines, its heading and the text of its cells"
function page_tables end

"Which of `tables`, the tables of the page of the editor `e`, the line `from` calls, or nothing"
function named_table end

"Work out what the page of the editor `e` shows and how tall each part is, for text that's `width` wide"
function layout! end

"The command that the key `K` runs by itself in the window `w` of the editor `e`, or nothing"
function command_of end

"Give a click on `node`, a part of a page, to the page, as a click on its text is given"
function click_page! end

"The object of the page of text that the editor `e` shows, or nothing"
function text_object end

"Say `words` under the top bar of the editor `e` for a while"
function say_result! end

"The first and the last line of the block whose lines fill the window of the editor `e` as text, or nothing"
function lowered end

"Wrap the page's text of the editor `e` again, for a live block that changed a setting"
function rewrap! end

"Run in the module `mod` the parts of the Julia file `file` that changed since it had the lines `before`"
function reload_changed! end

"The module that Kip made from the Julia file at `path`, or nothing when Ladder hasn't loaded that file"
function loaded_module end

"`content`, a part of the page that `owner` shows, with a button beside it that makes `what` fill the window"
function fillable end

"The `mermaid` code block from line `s` to line `t` as HTML"
function diagram_html end

"The font of what code came to, which is the font of the code, at `size` and in the colour `ink`"
function outcome_face end

"True while Ladder is built into an app (see app/bundle.jl)"
function julia_code end

"The day that counts as today: the real one, unless a test names another"
function calendar_today end

"True while the mouse is on a thing called `name`, in any part of the page"
function marked end

"True when the page shows a terminal's file at one of its levels"
function term_page end

"True when the page shows a session's file at one of its levels"
function chat_page end

"Scroll the page by `by`, as far as it goes"
function scroll_page! end

"Write the session of the pane `p` to its file, when the file doesn't have all of it yet"
function keep_talk! end

"Give the editor of a part the choices of the editor of the page that shows it"
function follow_host! end

"The text of a cell as the table shows it"
function celltext end

"How far down the page the lowest of `items` ends"
function lowest end

"True while Ladder is built into an app (see app/bundle.jl)"
function component end

"True while Ladder is built into an app (see app/bundle.jl)"
function unscaled end

"What kind of command the command `name` is"
function command_kind end

"A pinch outwards on a picture, a diagram, a page or a sketch in the page makes it fill the window"
function pinch_open end

"True when the page shows a day that isn't today"
function another_day end

"The items as the nodes of the document"
function blocks end

"What the chart `c` draws when its `from` names a CSV file"
function chart_file end

"True when the page shows a session's file as the session"
function chat_shown end

"True while Ladder is built into an app (see app/bundle.jl)"
function code_offered end

"The first line of code from line `i` of `lines` on, after blank lines, comments and documentation, or `i` when there's none"
function code_start end

"True while Ladder is built into an app (see app/bundle.jl)"
function complete! end

"The call that the definition `def` of a function starts with, like `share(s)`, without what's written after it, like `where T`"
function def_call end

"The function that the top part `ex` of a file of Julia code defines"
function definition_of end

"The field of a SolidCraft design that the editor `e` is the text of, or nothing for any other editor"
function design_field_of end

"`path` as a link writes it"
function escaped end

"The table in the CSV file at `path`"
function file_table end

"True while Ladder is built into an app (see app/bundle.jl)"
function folder_pages end

"True while Ladder is built into an app (see app/bundle.jl)"
function follow_wiki! end

"True while Ladder is built into an app (see app/bundle.jl)"
function hide_bar! end

"The settings page's name for `how` the top bar hides"
function hiding_name end

"True when the page shows an HTML file as the page that its HTML makes"
function html_shown end

"True when the name of the file at `path` ends as one of `kinds` does, like .png"
function ispicture end

"True when the file at `path` is one that holds a table"
function istable end

"True while Ladder is built into an app (see app/bundle.jl)"
function keep_copy end

"True while Ladder is built into an app (see app/bundle.jl)"
function keep_pasted end

"The place one line up or down the screen from the caret, in the order of the page's lines"
function line_step end

"True while Ladder is built into an app (see app/bundle.jl)"
function listed_agents end

"The colour `back` with the accent colour over it, as strong as a mark is"
function mark_colour end

"The app that opens a Markdown file when you double-click one, or an empty string when macOS can't say"
function markdown_app end

"True while Ladder is built into an app (see app/bundle.jl)"
function name_at end

"True while Ladder is built into an app (see app/bundle.jl)"
function name_notes end

"True when the check that went as `r` stopped only because the code of the file that the window of `e` shows hasn't run"
function needs_run end

"Note where the window of `e` is, before it jumps to another line of the file, so ⌘⌥← comes back to it"
function note_place! end

"True when the folder or the file that shows covers the page's whole space with a view of its own"
function page_covered end

"True while Ladder is built into an app (see app/bundle.jl)"
function page_given end

"The view of the page's first time log, read again from the lines of its block, or nothing when the page has none or can't be changed"
function page_log end

"True while Ladder is built into an app (see app/bundle.jl)"
function page_text end

"True while Ladder is built into an app (see app/bundle.jl)"
function page_then end

"The first and the last line of the part of the code of `lines` that line `i` is in, without the blank lines after it"
function part_lines end

"The text of each part of the Julia code of `lines`, with the line that the part starts on"
function part_texts end

"True when the file at `path` is a temporary one, which macOS removes later"
function passing end

"A name as two parts of the page compare it"
function plain_name end

"The tasks of the page's schedule, when the page shows another day than today"
function planned_tasks end

"Draw each window again with the methods that Julia has now, after code gave a function a new one"
function redraw_windows! end

"The lines of a Flow, as rows of text"
function rows end

"True while Ladder is built into an app (see app/bundle.jl)"
function run_in end

"True while Ladder is built into an app (see app/bundle.jl)"
function run_sum end

"True while Ladder is built into an app (see app/bundle.jl)"
function running_code end

"Ask where to save a file, with `name` to start with, in the document's folder"
function save_panel end

"The part of line `i` that's selected, as columns, and whether the selection goes on past it"
function selected end

"True while Ladder is built into an app (see app/bundle.jl)"
function sheet_given end

"The sheet between lines `s` and `t`, as an HTML table, or nothing while the sheet shows as code"
function sheet_html end

"True while Ladder is built into an app (see app/bundle.jl)"
function sheet_work end

"The pages whose lines the parts on `e`'s page edit, with the pages that parts of those edit, and so on"
function shown_buffers end

"True while Ladder is built into an app (see app/bundle.jl)"
function standing end

"The rows of the table that line `i` shows when it holds only a CSV file, for a chart to draw"
function table_rows end

"The choice of `options` that `x` names, for a live block of the settings"
function term_choice end

"Give the terminal `v` the font of code and the colours of the theme, as the window of `e` has them now, and the terminal's settings"
function term_look! end

"True when the page shows a terminal's file as the terminal"
function term_shown end

"True while Ladder is built into an app (see app/bundle.jl)"
function text_left end

"What tells a thing of a calendar from the others for the rest of the page"
function thing_name end

"True while Ladder is built into an app (see app/bundle.jl)"
function tick! end

"True while Ladder is built into an app (see app/bundle.jl)"
function tick_page! end

"True while Ladder is built into an app (see app/bundle.jl)"
function tip_code end

"The to-do item of the page that a schedule calls `key`, or nothing"
function todo_called end

"The to-do items of the page as they stand on the page's day"
function todos_then end

"A sentence or two on how far the app's update has got, for the settings page"
function update_news end

"The parts of the row that `value_row` makes for `text`, in the font `face`"
function value_parts end

"True while Ladder is built into an app (see app/bundle.jl)"
function visit! end

"True while Ladder is built into an app (see app/bundle.jl)"
function wiki_offered end

"True while Ladder is built into an app (see app/bundle.jl)"
function wiki_path end

"The minutes that the page's time logs have for the task called `name`"
function worked end

"True while Ladder is built into an app (see app/bundle.jl)"
function write_blocks! end

"How far the left edge of `it` is from the left edge of the page's text, and how wide it is"
function item_room end

"True while Ladder is built into an app (see app/bundle.jl)"
function item_under end

"True while Ladder is built into an app (see app/bundle.jl)"
function gallery_buttons end

"True while Ladder is built into an app (see app/bundle.jl)"
function gallery_edges end

"True while Ladder is built into an app (see app/bundle.jl)"
function go_view! end

"What a tooltip calls the file or the page at `target`"
function view_name end

"True while Ladder is built into an app (see app/bundle.jl)"
function side_w end

"What the window's colours are called now, for what's kept with them"
function look_key end

"The player of the sound or the video file at `path`"
function player end

"True while Ladder is built into an app (see app/bundle.jl)"
function show_crumb! end

"How wide the picture of a video is at most"
function video_wide end

"The text of a file"
function textview end

"A file's size in words, like 6.5 KB"
function bytes end

"The viewer of the model in the STL, 3MF or glTF file at `path`, or nothing if the file can't be read as a model"
function model end

"True while Ladder is built into an app (see app/bundle.jl)"
function terminal end

"True while Ladder is built into an app (see app/bundle.jl)"
function html_page end

"True while Ladder is built into an app (see app/bundle.jl)"
function scrolled end

"True while Ladder is built into an app (see app/bundle.jl)"
function design end

"True while Ladder is built into an app (see app/bundle.jl)"
function kept! end

"The text of the file at `path` for the breadcrumb `l`, or nothing if the file isn't text"
function text! end

"True while Ladder is built into an app (see app/bundle.jl)"
function make_default! end

"What fills the window when you click the button over `x`, a node that a live block made, or nothing if it has no button"
function fill_what end

"How wide `x` is at most in the page, for the button over its top right corner"
function fill_wide end

"What shows under the path of a file"
function preview end

"True when `node`, a model or a video, fills the window now"
function zoomed_node end

"The zoom that makes the page's text `size` pixels tall"
function zoom_for end

"The empty room that the page keeps for the model or the video that fills the window"
function held_room end

"True while Ladder is built into an app (see app/bundle.jl)"
function square_button end

"Where the caret goes when ↑ or ↓ brings it into a sheet from the line above or below it"
function enter end

"How far down the window the top bar reaches now"
function bar_bottom end

"The CSV file that the `from` of a chart names, or nothing when it names a heading or several tables"
function chart_path end

"The tables that the `from` of the chart `c` names, with commas between them"
function chart_sources end

"True when the file at `path` is one that a filter reads"
function isfilterable end

"True while Ladder is built into an app (see app/bundle.jl)"
function filter_file end

"Write `f` as the lines of the filter `v`"
function filter_write! end

"What a filter shows of `d`, its rows"
function filter_table end

"True while Ladder is built into an app (see app/bundle.jl)"
function filter_subset end

"Ask for the key called `name`, in a panel that hides what you type"
function key_panel end

"What went wrong, in words, for an error that Julia gives"
function error_words end

"The first `most` bytes of the file at `path`, as text, or \"\" when it isn't there"
function file_start end

"What a server said with an answer that says no"
function server_said end

"True while Ladder is built into an app (see app/bundle.jl)"
function keep_key end

"The CSV file that the line `text` holds, if it holds only that, and the words of its link"
function table_file end

"True when the row `r` has every one of the words in `typed`"
function choice_matches end

"True while Ladder is built into an app (see app/bundle.jl)"
function toggle_source! end

"True while Ladder is built into an app (see app/bundle.jl)"
function tick_item! end

"The last line of the block that line `i` is in"
function block_end end

"Put `new` where the selection is, or at the caret"
function type! end

"The Browser of the `view` block `v`, for an HTML file or a page of the web"
function web_browser end

"The name that the code of a sum gives, like `:farm` for `farm = 2GW`, or nothing"
function sum_name end

"True while Ladder is built into an app (see app/bundle.jl)"
function given_and_sums end

"True while Ladder is built into an app (see app/bundle.jl)"
function carry_sums! end

"True while Ladder is built into an app (see app/bundle.jl)"
function follow_remote! end

"True while Ladder is built into an app (see app/bundle.jl)"
function run_place end

"True while Ladder is built into an app (see app/bundle.jl)"
function value_text end

"True while Ladder is built into an app (see app/bundle.jl)"
function usual_module end

"The expression `ex` of a page's code, with `function bar end` before it for each unit, like `bar`, that it defines a function of"
function own_units end

"True while Ladder is built into an app (see app/bundle.jl)"
function remote_src end

"True while the find bar of the editor `e` is open"
function finding end

"True while Ladder is built into an app (see app/bundle.jl)"
function follow! end

"True while Ladder is built into an app (see app/bundle.jl)"
function filled end

"The line of the to-do item whose box is under a point in the window, or nothing"
function todo_at end

"True while Ladder is built into an app (see app/bundle.jl)"
function link_on end

"Close the find bar of the editor `e`, and give the keyboard back to the page"
function close_find! end

"True while Ladder is built into an app (see app/bundle.jl)"
function took end

"True while Ladder is built into an app (see app/bundle.jl)"
function page_bottom end

"True while Ladder is built into an app (see app/bundle.jl)"
function keep_got! end

"True while Ladder is built into an app (see app/bundle.jl)"
function get_page! end

"True while Ladder is built into an app (see app/bundle.jl)"
function browser_path end

"True when the window of `e` may ask a web server for a page"
function page_online end

"True when the file at `path` of the browser folder isn't what the server last sent"
function changed_here end
