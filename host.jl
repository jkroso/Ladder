# What the part of a page asks of the window that shows it: the window's
# editor, the object of the file or the folder that the page shows, and the
# things that the window does with a folder or a file. This file only names
# them. main.jl gives each its methods for its Editor, so a view in a file of
# its own, like the page of a kind of folder, can call them without main.jl.
#
#     e = editor(node)               # the window's editor that a node of a page is part of
#     go_folder!(e, "/Users/sam")    # list that folder in the sidebar
#     open_folder!(e, "/Users/sam")  # show it in the page

export editor, page_object, object, list_files!, go_folder!, open_folder!, show_path!, free_path,
       folder_kind, page_top, file_act!, show_in_finder, above_page, under_bar, page_crumb,
       bar_corner, touch!, show_line!, page_day, save_settings!, rerun!, page_room, page_tables,
       layout!, command_of, click_page!, text_object, say_result!, lowered, rewrap!, loaded_module,
       fillable, diagram_html, outcome_face, calendar_today, marked, chat_page, scroll_page!,
       keep_talk!, follow_host!, lowest, component, unscaled, command_kind, another_day, blocks,
       chat_shown, code_offered, code_start, complete!, design_field_of, escaped, folder_pages,
       follow_wiki!, hiding_named, same_settings!, ispicture, mark_colour, markdown_app, name_at,
       name_notes, page_covered, page_given, page_text, page_then, part_lines, part_texts,
       plain_name, planned_tasks, redraw_windows!, run_in, run_sum, running_code, selected,
       sheet_given, sheet_html, sheet_work, shown_buffers, standing, text_left, tick!, tick_page!,
       tip_code, todos_then, value_parts, visit!, wiki_offered, wiki_path, worked, write_blocks!,
       item_room, gallery_buttons, gallery_edges, view_name, side_w, look_key, player, show_crumb!,
       textview, model, terminal, design, make_default!, zoom_for, bar_bottom, chart_sources,
       isfilterable, filter_file, filter_write!, key_panel, server_said, keep_key, toggle_source!,
       tick_item!, block_end, type!, web_browser, sum_name, given_and_sums, follow_remote!,
       run_place, value_text, usual_module, own_units, remote_src, finding, todo_at, link_on,
       close_find!, took, keep_got!, get_page!, site_shows!, browser_path, page_online,
       changed_here, fetched, email_head!, email_shows, ismouse, file_menu!, page_html, new_page!,
       build_editor, news_look, web_page_kind, rename!, renaming, copy_text!, renamer, right_w,
       lens_shapes, theirs, right_opened, in_focus, right_view, commit_talk, ask_talk!, page_module,
       detail_view, type_brief, line_rect, declared, detail_wide, sandbox, coloured, show_method!,
       code_blocks, select_all!, add_block!, sources_tick!, from_pick_tick!, page_span, isword,
       places, run!, as_app, bar_tint, right_panel, side_part, each_selection!, nofile, scrub_tick!,
       end_companions!, eased, omni_arc, tabs, preferred_agent!, inline_tick!, unused, is_companion, outline,
       companion_pane, screen_room, palette_click!, show_window!, shown_parts, window!,
       paper_window, todo_box, go_chip!, palette_chips, palette, under_palette, startup_page,
       command_focus, copied!, mark_chips, mark_preview, text_width, code_module!, page_value,
       page_code, show_opened!, toast!, untoast!, site_code_changed!, go_heading!, known_lang,
       reset_module!, bar_parts, bar_sliding, bar_top, blank_editor, block, callable_methods,
       close_file!, close_file_or_window!, code_module, delete_lines!, directory, ended_rename!,
       enter_part!, file_tree, fill_selection, fill_tree!, find!, finder_key!, folder_trail,
       inside_path, issettings, job_tip, ladder_runs, load_settings!, make_job!, mark, mark_pointed,
       move_old_folders!, new_window!, node_name!, off, omni_label, open_finder!, open_on_folder!,
       open_projects!, page_window, palette_key!, palette_plan, panel_theme, paste!, peek!,
       rename_key!, ring_part, run_startup!, scrub!, settings_page, show_no_file!, startup_page!,
       toggle_palette!, toggle_settings!, transclusion_item, watch_front!, whole_node, window_object

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

"Open the folder at `path` in the page of the editor `e`"
function open_folder! end

"Show the file or the folder at `path` the way that a click on a link to it does, in the window of the editor `e`"
function show_path! end


"A path in the folder `dir` for something new called `base`, with the ending `ending`, that no file and no page of the editor `e` has yet"
function free_path end

"The kind of the folder at `path`: the type under AbstractDirectory that its object has"
function folder_kind end

"How far down the page of the editor `e` its text starts, under the top bar and what the page shows over its text"
function page_top end

"Do to the file or the folder at `path` what the item `name` of its menu says, in the editor `e`"
function file_act! end

"Open a Finder window on the folder of the file at `path`, with the file selected"
function show_in_finder end

"How much room the top bar of the editor `e` keeps at the top of the window, over the page"
function above_page end

"How much room the page of the editor `e` leaves at its top for the top bar: none when the page shows the file's path itself"
function under_bar end

"The path of the file, for a page of the editor `e` that shows the path itself, in `room` at most, on the colour `ground`"
function page_crumb end

"How far past the sidebar's edge the left end of the top bar of the editor `e` reaches over the page, with its buttons"
function bar_corner end

"The caret of the editor `e` moved or its text changed, so show the caret"
function touch! end

"Put the caret of the editor `e` at the end of line `i` of the page, and bring the line in sight"
function show_line! end

"The day that the page of the editor `e` shows itself on: today, unless a `day` block says another"
function page_day end

"Give the other windows the settings of the editor `e`, and write them to their file if `e` keeps them"
function save_settings! end

"Give `new`, the editor of a window that's about to open, each setting of `e` that every window has the same"
function same_settings! end

"Run again the live blocks of the editor `e` that asked for `setting`"
function rerun! end

"How wide and how tall the page's space in the window of the editor `e` is"
function page_room end

"Every table of the page of the editor `e` that shows, with its lines, its heading and the text of its cells"
function page_tables end

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


"The module that Kip made from the Julia file at `path`, or nothing when Ladder hasn't loaded that file"
function loaded_module end

"`content`, a part of the page that `owner` shows, with a button beside it that makes `what` fill the window"
function fillable end

"The `mermaid` code block from line `s` to line `t` as HTML"
function diagram_html end

"The font of what code came to, which is the font of the code, at `size` and in the colour `ink`"
function outcome_face end

"The day that counts as today: the real one, unless a test names another"
function calendar_today end

"True while the mouse is on a thing called `name`, in any part of the page"
function marked end

"True when the page shows a session's file at one of its levels"
function chat_page end

"Scroll the page by `by`, as far as it goes"
function scroll_page! end

"Write the session of the pane `p` to its file, when the file doesn't have all of it yet"
function keep_talk! end

"Give the editor of a part the choices of the editor of the page that shows it"
function follow_host! end


"How far down the page the lowest of `items` ends"
function lowest end

"The name and the icon of what a block of `ui` code shows"
function component end

"The theme `t` at the usual size, in which a length in pixels is that many pixels, as it is on a page"
function unscaled end

"What kind of command the command `name` is"
function command_kind end

"True when the page shows a day that isn't today"
function another_day end

"The items as the nodes of the document"
function blocks end

"True when the page shows a session's file as the session"
function chat_shown end

"The names that the text before the caret could be the start of, in a code block"
function code_offered end

"The first line of code from line `i` of `lines` on, after blank lines, comments and documentation, or `i` when there's none"
function code_start end

"Type `name` in place of the text from column `start` of line `i` to the caret, as the list of names does"
function complete! end



"The field of a SolidCraft design that the editor `e` is the text of, or nothing for any other editor"
function design_field_of end

"`path` as a link writes it"
function escaped end

"The pages of `folder`, with when the file of each last changed"
function folder_pages end

"Follow a wiki link to `target`"
function follow_wiki! end

"How the top bar hides, from its name on the settings page"
function hiding_named end

"True when the name of the file at `path` ends as one of `kinds` does, like .png"
function ispicture end




"The colour `back` with the accent colour over it, as strong as a mark is"
function mark_colour end

"The app that opens a Markdown file when you double-click one, or an empty string when macOS can't say"
function markdown_app end

"The name that's written at the place `at` of the page's Julia code"
function name_at end

"What each of `names` is, for the list of names that shows at line `i`"
function name_notes end


"True when the folder or the file that shows covers the page's whole space with a view of its own"
function page_covered end

"The names that the parts of the page over line `upto` give, each with an expression for its value"
function page_given end


"The lines of the page at `path`, what each line is, and a mark that changes when the page's text does"
function page_text end

"The page as git has it for the page's day, when that day is before today"
function page_then end

"The first and the last line of the part of the code of `lines` that line `i` is in, without the blank lines after it"
function part_lines end

"The text of each part of the Julia code of `lines`, with the line that the part starts on"
function part_texts end


"A name as two parts of the page compare it"
function plain_name end

"The tasks of the page's schedule, when the page shows another day than today"
function planned_tasks end

"Draw each window again with the methods that Julia has now, after code gave a function a new one"
function redraw_windows! end


"Run the code `code` of the page at `path` in the page's module `m`, as `include_string` does, and give the value that it comes to"
function run_in end

"Run the code of a sum in a line of text in the module `m`, as `run_in` does"
function run_sum end

"Run `f` with the module of the page's code, for code that the window `e` runs in it now"
function running_code end

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

"How far the left edge of the page's text is from the left edge of the window"
function text_left end


"Tick the box of the to-do item on line `i`, or take its tick away"
function tick! end

"Tick the to-do item `m` in its own page when `done` is true, or take its tick away"
function tick_page! end

"Lines of code in a tooltip, each a row `high` tall, with the colours that code has in the page"
function tip_code end


"The to-do items of the page as they stand on the page's day"
function todos_then end

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

"What the bar under a file of a gallery starts with"
function gallery_buttons end

"The arrows at the left and the right edge of a file of a gallery that fills the window, in the middle of the window's height"
function gallery_edges end

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

"The text of a file"
function textview end


"The viewer of the model in the STL, 3MF or glTF file at `path`, or nothing if the file can't be read as a model"
function model end

"What shows the terminal's file at `path` under a path and in a `view` block"
function terminal end


"What shows the SolidCraft design at `path` under a path and in a `view` block"
function design end



"Ask macOS to make Ladder the app that opens Markdown files"
function make_default! end

"The zoom that makes the page's text `size` pixels tall"
function zoom_for end

"How far down the window the top bar reaches now"
function bar_bottom end

"The tables that the `from` of the chart `c` names, with commas between them"
function chart_sources end

"True when the file at `path` is one that a filter reads"
function isfilterable end

"The rows of the file at `path`, for a filter"
function filter_file end

"Write `f` as the lines of the filter `v`"
function filter_write! end

"Ask for the key called `name`, in a panel that hides what you type"
function key_panel end



"What a server said with an answer that says no"
function server_said end

"Keep `key` in the login Keychain as the password called `name`, in place of one that's there"
function keep_key end

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


"The line of the to-do item whose box is under a point in the window, or nothing"
function todo_at end

"The link that's drawn under a point in the window, or nothing"
function link_on end

"Close the find bar of the editor `e`, and give the keyboard back to the page"
function close_find! end

"True when the node that has the keyboard is something other than the text, and the click that is happening now is on that node, or on a part of it, or on a node that holds it"
function took end

"Put `bytes`, what the server sent for `address`, in the file at `path` of the browser folder, marked with the address and the fingerprint of the bytes"
function keep_got! end

"Ask the server for the page at `address`, and show it in the window of `e`"
function get_page! end

"Show the page at `address` in the window of `e` as the viewer of its site shows it: true when the site has a viewer, and it showed the page"
function site_shows! end

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

"Show the menu of the file or the folder at `path`"
function file_menu! end

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

"How wide the panel at the right is when it's open"
function right_w end

"The outline of a list and what it hangs over, as the places along it, and the outline of what's filled with the list's colour"
function lens_shapes end

"The runs of lines of the page that were changed from outside, by an agent, since you last sent the page, or since it was opened"
function theirs end


"How far the panel at the right is open, from 0 to 1"
function right_opened end

"The things in focus in the window of `e`, from the nearest"
function in_focus end

"What the panel at the right shows for the page, or nothing when the page has no panel"
function right_view end

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

"One part of a line of code in a chip, in the colour of its kind, as the parts of a row"
function coloured end

"Show the code of the method `m`"
function show_method! end

"The blocks of Julia code in the window of `e`, in the order of its lines"
function code_blocks end


"What `select_all!` gives"
function select_all! end

"Add a block of `lines` to the document, and put the caret at `at`"
function add_block! end

"The list of the block `v`, in each frame"
function sources_tick! end

"When a file has been clicked in the file picker of `v`, it's where the rows of `v` come from, as a path from the page's folder"
function from_pick_tick! end


"Where the page's space is across the window"
function page_span end

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

"How wide the page's text is in the window"
function text_width end

"A new module for the code of the startup page, or of a folder's page, at `path`, for Ladder to run the page in now."
function code_module! end

"Run the code of the Markdown page at `path` in the module `m`, as `run_page!` does."
function page_value end

"The code of each `julia` block of the Markdown page at `path`, with the line of the page that it starts on."
function page_code end

"Show the folder that the window was opened on in the page, when it's of a kind that shows there, as a desktop is."
function show_opened! end

"Show a toast in each window that says `title`, and why in `words`."
function toast! end

"Close the toast about `key` in every window, if there's one"
function untoast! end

"Run the code of each page of `site` that a window shows again, from the start, in a new module: after you trust the site, put it back in the sandbox, or let its code do something more."
function site_code_changed! end

"Show the page at `path` with its heading `name` near the top of the window."
function go_heading! end

"True when Ladder itself says what a code block in the language `lang` shows"
function known_lang end

"Give the file that the window `e` shows a new, empty module for its code, in place of the one it had."
function reset_module! end

"The buttons that code from the startup page adds to the top bar for the page that shows"
function bar_parts end

"True while the top bar slides into the window or out of it"
function bar_sliding end

"Where the top bar's top is: 0 while the bar shows, and as far above the window as the bar is tall while it hides"
function bar_top end

"An editor that shows no file yet"
function blank_editor end

"The kind of block that line `i` is in."
function block end

"The methods of `f` that the palette can call when the things in `focus` are in focus, each as its arguments, in the order that they're written in."
function callable_methods end

"Close the file that the window shows, and its tab, and show the tab under it."
function close_file! end

"What ⌘W does: close the file that the window shows, or the window when it shows a page of the settings, or no file and no tab is open."
function close_file_or_window! end

"A new module for the code of the startup page, or of a folder's page, at `path`."
function code_module end

"Take away each line that the selection touches"
function delete_lines! end

"The object of the sidebar's folder, or nothing when no folder is there"
function directory end

"A click somewhere else while a file is renamed gives the file the name that's typed"
function ended_rename! end

"What Return does while the caret is on a part of the page as a whole: it gives the part the keyboard, in the way that suits the part."
function enter_part! end

"The sidebar's tree"
function file_tree end

"Fill the selection."
function fill_selection end

"Make the sidebar's tree show the folder's files and the headings of each file that's open in it"
function fill_tree! end

"⌘F, and Find… in the page's menu."
function find! end

"What the key `K` does while the file finder or the project picker is open, or nothing when it does nothing there"
function finder_key! end

"The folder at the top of the sidebar, as a trail of names"
function folder_trail end

"True when `p` is the path `at`, or the path of something in the folder at `at`"
function inside_path end

"True when `e` is the editor of the settings window: the one that ⌘, opened, while it shows a page of the settings' folder."
function issettings end

"What the tooltip of the button that makes the job says: what the button does, or what happened when it did it"
function job_tip end

"True when Ladder runs the code of the page at `path` itself: the startup page, and a folder's page"
function ladder_runs end

"Give `e` the settings that were kept the last time one changed"
function load_settings! end

"Ask Centient to make the page's job."
function make_job! end

"The icon that a file, a heading or a component starts with in the sidebar, in the place a tree has its arrow"
function mark end

"Mark the thing that the mouse is on where the page's text has it too: a soft box behind each to-do item and each row of a table that has its name."
function mark_pointed end

"Give the app's folders in `home`'s Library the name Ladder, if they still have the old name Kaydown"
function move_old_folders! end

"⌘N: open a new window on the folder that the window of `e` is in."
function new_window! end

"The name of the block of `b` from line `s` to line `t`, which a link from another page uses, like `prices` in ![[costs#^prices]]."
function node_name! end


"True for a button of the top bar that does nothing now: the one that makes the job, when the Mac has no Centient or Centient makes a job, the ones that go back and forward, when they have no file to go to, and one that code from the startup page added, when that code says so"
function off end

"A line of words in the command palette's font, at the size and in the colour that it's given"
function omni_label end

"Open the file finder"
function open_finder! end

"Show the folder at `path` in a window that's opened on it: its first Markdown file, or the folder's own page when it has no Markdown file."
function open_on_folder! end

"Open the project picker."
function open_projects! end


"A window that shows the Markdown file or the folder at `path`, with the settings of the editor `like`."
function page_window end

"What a key does while the palette shows."
function palette_key! end

"Where each part of the palette is in the window in this frame, in pixels: the strip along the bottom, the bar in it, each thing in the bar, and the list with what it hangs over."
function palette_plan end

"The colours of the sidebar's tree"
function panel_theme end

"Put what the clipboard holds into the text at the caret."
function paste! end


"Show the card of the words `found` when the mouse has rested on them for a moment while ⌘ is held, and take it away when the mouse is on other words."
function peek! end

"Return gives the file the name that's typed, and esc leaves it with the name it has"
function rename_key! end

"Draw a line round the part of the page that the caret is on as a whole."
function ring_part end

"Run the code of the startup page: each of its `julia` blocks, from the top, in one module, which this gives."
function run_startup! end

"Take hold of the number at `found`, which `scrub_at` gave, with the mouse at `pos`"
function scrub! end

"Where the page of the settings is whose file is called `name`."
function settings_page end

"Show no file in the window: an empty page that nothing can be typed in"
function show_no_file! end

"Write the startup page, if there's none."
function startup_page! end

"Show the command palette, or close it when it shows"
function toggle_palette! end

"Show the settings page in a window of its own."
function toggle_settings! end

"What line `i` shows when it holds a link to a part of another page."
function transclusion_item end


"Have macOS tell `e` when its window `w` comes to the front, and when it stops being the front window."
function watch_front! end

"The block of `b` that lines `s` to `t` are the whole of, or nothing: a block of the page, a heading with the lines under it, or an item of a list with the lines indented under it."
function whole_node end

"The object that the window is about: the file or the folder that it shows."
function window_object end

