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
       page_online, changed_here, fetched, email_head!, email_shows, ismouse, ignored_shown, file_menu!,
       holds_words, page_html, new_page!, build_editor, news_look, web_page_kind, rename!, renaming,
       copy_text!, renamer, move!, toggle_right!, right_w, open_palette!, lens_shapes, theirs, change_diff,
       kind_command, right_opened, in_focus, right_view, agent_kind, commit_talk, ask_talk!, page_module, detail_view, type_brief,
       line_rect, declared, detail_wide, sandbox, made_workspace, coloured, code_place, show_method!,
       settled_line, code_blocks, text_lines, show_code!, select_all!, add_block!, sources_tick!,
       from_pick_tick!, page_media, marking, page_span, table_html, isword, places, run!, as_app, bar_tint,
       right_panel, side_part, each_selection!, nofile, scrub_tick!, end_companions!, eased, omni_arc, tabs,
       preferred_agent!, inline_tick!, unused, is_companion, outline, companion_pane, screen_room,
       palette_click!, show_window!, shown_parts, window!, paper_window, todo_box, go_chip!, palette_chips,
       palette, under_palette, startup_page, command_focus, copied!, mark_chips, mark_preview

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

"The first and last line of the code of the `julia` code block that line `i` is in, or nothing when the line isn't in one"
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

"The name and the icon of what a block of `ui` code shows"
function component end

"The theme `t` at the usual size, in which a length in pixels is that many pixels, as it is on a page"
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

"The names that the text before the caret could be the start of, in a code block"
function code_offered end

"The first line of code from line `i` of `lines` on, after blank lines, comments and documentation, or `i` when there's none"
function code_start end

"Type `name` in place of the text from column `start` of line `i` to the caret, as the list of names does"
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

"The pages of `folder`, with when the file of each last changed"
function folder_pages end

"Follow a wiki link to `target`"
function follow_wiki! end

"Hide the top bar until the mouse is at the top of the window"
function hide_bar! end

"The settings page's name for `how` the top bar hides"
function hiding_name end

"True when the page shows an HTML file as the page that its HTML makes"
function html_shown end

"True when the name of the file at `path` ends as one of `kinds` does, like .png"
function ispicture end

"True when the file at `path` is one that holds a table"
function istable end

"Copy the file at `path` to the media folder of the document's folder, under its own name, and return the copy's path"
function keep_copy end

"Write `bytes` that were pasted to a new file in the media folder of the document's folder, and return its path"
function keep_pasted end

"The place one line up or down the screen from the caret, in the order of the page's lines"
function line_step end

"The names of the agents that Ladder lists for you to choose from"
function listed_agents end

"The colour `back` with the accent colour over it, as strong as a mark is"
function mark_colour end

"The app that opens a Markdown file when you double-click one, or an empty string when macOS can't say"
function markdown_app end

"The name that's written at the place `at` of the page's Julia code"
function name_at end

"What each of `names` is, for the list of names that shows at line `i`"
function name_notes end

"True when the check that went as `r` stopped only because the code of the file that the window of `e` shows hasn't run"
function needs_run end

"Note where the window of `e` is, before it jumps to another line of the file, so ⌘⌥← comes back to it"
function note_place! end

"True when the folder or the file that shows covers the page's whole space with a view of its own"
function page_covered end

"The names that the parts of the page over line `upto` give, each with an expression for its value"
function page_given end

"The view of the page's first time log, read again from the lines of its block, or nothing when the page has none or can't be changed"
function page_log end

"The lines of the page at `path`, what each line is, and a mark that changes when the page's text does"
function page_text end

"The page as git has it for the page's day, when that day is before today"
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

"Run the code `code` of the page at `path` in the page's module `m`, as `include_string` does, and give the value that it comes to"
function run_in end

"Run the code of a sum in a line of text in the module `m`, as `run_in` does"
function run_sum end

"Run `f` with the module of the page's code, for code that the window `e` runs in it now"
function running_code end

"Ask where to save a file, with `name` to start with, in the document's folder"
function save_panel end

"The part of line `i` that's selected, as columns, and whether the selection goes on past it"
function selected end

"What the sheet whose block opens on line `upto` has from the parts of the page over it"
function sheet_given end

"The sheet between lines `s` and `t`, as an HTML table, or nothing while the sheet shows as code"
function sheet_html end

"Work out a sheet of the page of `e` with `f`"
function sheet_work end

"The pages whose lines the parts on `e`'s page edit, with the pages that parts of those edit, and so on"
function shown_buffers end

"How the task `t` of a schedule stands on the page's day"
function standing end

"The rows of the table that line `i` shows when it holds only a CSV file, for a chart to draw"
function table_rows end

"The choice of `options` that `x` names, for a live block of the settings"
function term_choice end

"Give the terminal `v` the font of code and the colours of the theme, as the window of `e` has them now, and the terminal's settings"
function term_look! end

"True when the page shows a terminal's file as the terminal"
function term_shown end

"How far the left edge of the page's text is from the left edge of the window"
function text_left end

"What tells a thing of a calendar from the others for the rest of the page"
function thing_name end

"Tick the box of the to-do item on line `i`, or take its tick away"
function tick! end

"Tick the to-do item `m` in its own page when `done` is true, or take its tick away"
function tick_page! end

"Lines of code in a tooltip, each a row `high` tall, with the colours that code has in the page"
function tip_code end

"The to-do item of the page that a schedule calls `key`, or nothing"
function todo_called end

"The to-do items of the page as they stand on the page's day"
function todos_then end

"A sentence or two on how far the app's update has got, for the settings page"
function update_news end

"The parts of the row that `value_row` makes for `text`, in the font `face`"
function value_parts end

"Show the page at `path`, with the caret at the end of the line that `m` is on now"
function visit! end

"The pages that the name being typed in a wiki link could be"
function wiki_offered end

"The file that the wiki link to `name` names"
function wiki_path end

"The minutes that the page's time logs have for the task called `name`"
function worked end

"Write the lines of every block of the page that a file defines"
function write_blocks! end

"How far the left edge of `it` is from the left edge of the page's text, and how wide it is"
function item_room end

"The place in the page's layout of the item under a point that's `dx` across and `dy` down from the top left corner of the page's text"
function item_under end

"What the bar under a file of a gallery starts with"
function gallery_buttons end

"The arrows at the left and the right edge of a file of a gallery that fills the window, in the middle of the window's height"
function gallery_edges end

"Show the file of the `view` block `v` in the window, as a click on a link to it does"
function go_view! end

"What a tooltip calls the file or the page at `target`"
function view_name end

"How wide the sidebar is now, or the side menu that a kind of folder has in its place"
function side_w end

"What the window's colours are called now, for what's kept with them"
function look_key end

"The player of the sound or the video file at `path`"
function player end

"Show the file or the folder at `path` in the window, as the path in the top bar does"
function show_crumb! end

"How wide the picture of a video is at most"
function video_wide end

"The text of a file"
function textview end

"A file's size in words, like 6.5 KB"
function bytes end

"The viewer of the model in the STL, 3MF or glTF file at `path`, or nothing if the file can't be read as a model"
function model end

"What shows the terminal's file at `path` under a path and in a `view` block"
function terminal end

"True when the page shows an HTML file at one of its levels"
function html_page end

"`n` rows that are each `high` tall, `PREVIEW_LINES` of them at a time"
function scrolled end

"What shows the SolidCraft design at `path` under a path and in a `view` block"
function design end

"What the breadcrumb `l` keeps of the file at `path`"
function kept! end

"The text of the file at `path` for the breadcrumb `l`, or nothing if the file isn't text"
function text! end

"Ask macOS to make Ladder the app that opens Markdown files"
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

"A small square button with a line round it and the icon `icon`, like the one that makes a picture fill the window"
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

"The rows of the file at `path`, for a filter"
function filter_file end

"Write `f` as the lines of the filter `v`"
function filter_write! end

"What a filter shows of `d`, its rows"
function filter_table end

"What the filter in `lines`, on line `line`, shows"
function filter_subset end

"Ask for the key called `name`, in a panel that hides what you type"
function key_panel end

"What went wrong, in words, for an error that Julia gives"
function error_words end

"The first `most` bytes of the file at `path`, as text, or \"\" when it isn't there"
function file_start end

"What a server said with an answer that says no"
function server_said end

"Keep `key` in the login Keychain as the password called `name`, in place of one that's there"
function keep_key end

"The CSV file that the line `text` holds, if it holds only that, and the words of its link"
function table_file end

"True when the row `r` has every one of the words in `typed`"
function choice_matches end

"Add the table of row `k` of the list to the tables that the chart of `c` draws, or take it away when the chart draws it already"
function toggle_source! end

"Tick the to-do item on line `i` of `b` when `done`, or take its tick away, in one edit, so one ⌘Z takes it back"
function tick_item! end

"The last line of the block that line `i` is in"
function block_end end

"Put `new` where the selection is, or at the caret"
function type! end

"The Browser of the `view` block `v`, for an HTML file or a page of the web"
function web_browser end

"The name that the code of a sum gives, like `:farm` for `farm = 2GW`, or nothing"
function sum_name end

"`page_given`, and where each name that a sum gives is"
function given_and_sums end

"Give the page of the HTML file of `v` the sums that a `view` block gave it, when the window went to the file from that block"
function carry_sums! end

"Follow the link `url` of the page from a web server that `e` shows"
function follow_remote! end

"The path that the page's code runs as, and the folder that it runs in"
function run_place end

"`value` as the text that Julia shows for it, with the middle of a long list or a big table left out"
function value_text end

"A new module called `name`, with what a Julia file that Kip loads has, like `@use`, and the names that the window `e` gives a page's code"
function usual_module end

"The expression `ex` of a page's code, with `function bar end` before it for each unit, like `bar`, that it defines a function of"
function own_units end

"The whole web address that `src` means in the page from a web server that `e` shows, or nothing when it names no place on the web, as a path of the Mac written `file:` doesn't"
function remote_src end

"True while the find bar of the editor `e` is open"
function finding end

"Open a link"
function follow! end

"True when something fills the window in place of the page and the sidebar"
function filled end

"The line of the to-do item whose box is under a point in the window, or nothing"
function todo_at end

"The link that's drawn under a point in the window, or nothing"
function link_on end

"Close the find bar of the editor `e`, and give the keyboard back to the page"
function close_find! end

"True when the node that has the keyboard is something other than the text, and the click that is happening now is on that node, or on a part of it, or on a node that holds it"
function took end

"The room under the last line of the page"
function page_bottom end

"Put `bytes`, what the server sent for `address`, in the file at `path` of the browser folder, marked with the address and the fingerprint of the bytes"
function keep_got! end

"Ask the server for the page at `address`, and show it in the window of `e`"
function get_page! end

"The file of the browser folder that keeps what's at `address`, or nothing when no file can, as for a name that starts with a dot"
function browser_path end

"True when the window of `e` may ask a web server for a page"
function page_online end

"True when the file at `path` of the browser folder isn't what the server last sent"
function changed_here end

"The file that holds the picture at the web address `url`"
function fetched end

"The top of the email that the page shows"
function email_head! end

"True when the page that shows is an email that came or went, so that its front matter shows as the top of an email"
function email_shows end

"True when the key `k` is a button of the mouse"
function ismouse end

"True when a list shows the file or the folder at `path` only because it shows the hidden files too"
function ignored_shown end

"Show the menu of the file or the folder at `path`"
function file_menu! end

"How many folders and files the table `t`, a `FolderTable`, lists, in words, and what the folder holds, once that's known"
function holds_words end

"The document as a page of HTML"
function page_html end

"Make a new empty page in the folder `dir` and show it"
function new_page! end

"Open the editor on a file, or on the first Markdown file in a folder"
function build_editor end

"True when the window shows a front page of a folder of news, or an article of one, which have a newspaper's look"
function news_look end

"The kind that the .ladder page of the web folder at `f` gives the folder, or nothing"
function web_page_kind end

"Start to rename the file or the folder at `path`"
function rename! end

"The path of the file that's being renamed in `at`, the `:sidebar` or the `:title`"
function renaming end

"Put `text` on the clipboard"
function copy_text! end

"The text field that a file's new name is typed in"
function renamer end

"Move the caret to `p`, which was reached by going in the direction `by`"
function move! end

"Show or hide the panel at the right of the page, like git's panel beside a repository's files"
function toggle_right! end

"How wide the panel at the right is when it's open"
function right_w end

"Open the command palette on the command called `name`, to ask for what it takes"
function open_palette! end

"The outline of a list and what it hangs over, as the places along it, and the outline of what's filled with the list's colour"
function lens_shapes end

"The runs of lines of the page that were changed from outside, by an agent, since you last sent the page, or since it was opened"
function theirs end

"The diff of the text `was` of the file `file` to the text `now`, as `git diff` writes it, with the file's whole path"
function change_diff end

"The command of the agent `k` with the options `options`, which the words go after, with its own folder and Homebrew's on its PATH"
function kind_command end

"How far the panel at the right is open, from 0 to 1"
function right_opened end

"The things in focus in the window of `e`, from the nearest"
function in_focus end

"What the panel at the right shows for the page, or nothing when the page has no panel"
function right_view end

"The agent called `name` that Ladder can start, or Claude Code when there's none of that name"
function agent_kind end

"The pane of the conversation beside the page of the editor `e`, whose agent writes the message of a commit, or nothing"
function commit_talk end

"Give the agent of the pane `p` words that the pane shows, with words that it doesn't before them, and give back its reply, once it has said it all"
function ask_talk! end

"The module of the page at `path`, which the window `e` asks for"
function page_module end

"What the open box of a function or a module shows"
function detail_view end

"What the box of the type `T` says"
function type_brief end

"Where line `i` of the page is in the window of `e`, across the whole page"
function line_rect end

"True when the box of the value `v` opens to show the type that `v` is"
function declared end

"How wide the open box of a function or a module is"
function detail_wide end

"The names that the window gives the code of its pages, with no line that loads them, in a module of the window"
function sandbox end

"The module of the page's `julia` code, or nothing when it has none yet"
function made_workspace end

"One part of a line of code in a chip, in the colour of its kind, as the parts of a row"
function coloured end

"The file on this Mac that has the method `m`, and its line there"
function code_place end

"Show the code of the method `m`"
function show_method! end

"The line of `lines`, the lines of a file as it is now, that the method `m` starts on"
function settled_line end

"The blocks of Julia code in the window of `e`, in the order of its lines"
function code_blocks end

"The lines of the file text `s`, as `text` reads them from a file"
function text_lines end

"Show the method `m` in a window beside the window of `e`"
function show_code! end

"What `select_all!` gives"
function select_all! end

"Add a block of `lines` to the document, and put the caret at `at`"
function add_block! end

"The list of the block `v`, in each frame"
function sources_tick! end

"When a file has been clicked in the file picker of `v`, it's where the rows of `v` come from, as a path from the page's folder"
function from_pick_tick! end

"The folder for the files that the pages of the folder `dir` make"
function page_media end

"True while the bars beside the agent's changes stay on the page that's showing"
function marking end

"Where the page's space is across the window"
function page_span end

"The line `text` as HTML when it holds only a CSV file"
function table_html end

"What `isword` gives"
function isword end

"The columns of each place in `line` that has `text`"
function places end

"Run the command called `name` in the window `w` of `e`"
function run! end

"True when the window of `e` shows its page as an app"
function as_app end

"The colour of the web page that the window shows, which the top bar takes, or nothing"
function bar_tint end

"The panel at the right of the window, while the page has one"
function right_panel end

"What's at the left of the window of `e`"
function side_part end

"Do `f` at each selection"
function each_selection! end

"True when the window shows no file, because ⌘W closed the page that it showed"
function nofile end

"What happens in each frame to a number that the mouse holds"
function scrub_tick! end

"The reading companions of the window of `e` end with it"
function end_companions! end

"How far a slide from `from` to `to` that started at the time `at` has gone"
function eased end

"The places along a quarter of a circle round `(cx, cy)`, from the angle `from` to the angle `to`"
function omni_arc end

"The files that are open in the window of `e`, as tabs at the top of the sidebar, in the order that they opened"
function tabs end

"Make the agent called `name` the one that Ladder starts for a change or a question"
function preferred_agent! end

"Run again the sums in a line of text that come after a sum that changed, so that a sum which uses a name follows the sum that gives the name its value"
function inline_tick! end

"A path in `dir` that no file has yet"
function unused end

"True when the pane `p` is the session's file of a reading companion that runs"
function is_companion end

"The headings and the components among `lines`, from the top"
function outline end

"The pane of the reading companion of the file at `path`"
function companion_pane end

"How tall the part of the main screen is that a window can use, under the menu bar and over the Dock"
function screen_room end

"A click on the window while the palette shows a chip that a click chooses for"
function palette_click! end

"Put the window `w` on the screen, if the window `by` that asked for it is on the screen"
function show_window! end

"Each part of the page that shows"
function shown_parts end

"Make a window for the editor `e`"
function window! end

"The size that a new window opens at"
function paper_window end

"The box of a to-do item"
function todo_box end

"Put the keyboard in chip `k`"
function go_chip! end

"The chips of a command whose function has the methods `sigs`, when `values` are what's said so far"
function palette_chips end

"The command palette of the window of `e`"
function palette end

"The deepest part of the window `w` under its mouse, leaving out what the palette `p` draws"
function under_palette end

"The page that Ladder opens when no file is named and it has no place to open from the last time (see `take_place!`), and whose Julia code it runs when it starts"
function startup_page end

"What's in focus in the window of `e` for a command"
function command_focus end

"Note what was just copied"
function copied! end

"Draw a line round the thing of each chip that's for a thing in the window, in the chip's colour, with the chip's letter, for as long as the command shows"
function mark_chips end

"While the window shows a row of the list, a line round the thing of that row, as for a place that Find Uses found"
function mark_preview end
