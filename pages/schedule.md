# A new driveway

This page plans a job. Each to-do item is a task. The schedule under the tasks shows the days of each one.

## Tasks

- [x] Mark out the driveway
- [x] Dig out the soil and cart it away
- [x] Set the forms along the edges
  - [x] Set the drain across the garage door
- [ ] Fix the steel mesh
- [ ] Book the concrete and the pump
- [ ] Pour and finish the concrete
- [ ] Cut the joints
- [ ] Take the forms off and clean up

Move the mouse over a task. Its days show at the end of its line: its first and last day, how many working days it takes, and the task that it waits for. The − and + buttons there make it a day shorter or a day longer.

## The day

Drag the slider to see the job as the schedule plans it on another day. The line of that day moves in the schedule, the tasks that are finished by then show as done, and the cards of the board move to where the plan has them. **Today** shows the job as it is.

```day
```

```board
```

## Schedule

```schedule
Mark out the driveway | 2 days
Dig out the soil and cart it away | 3 days | after Mark out the driveway
Set the forms along the edges | 2 days | after Dig out the soil and cart it away
Set the drain across the garage door | after Set the forms along the edges
Fix the steel mesh | 2 days | after Set the drain across the garage door
Pour and finish the concrete | after Fix the steel mesh | after Book the concrete and the pump
Cut the joints | after Pour and finish the concrete
Take the forms off and clean up | after Cut the joints
```

A code block in the language `schedule` shows every to-do item of its page as a bar on a line of days. A task takes one day and starts when the work starts, until you say more:

- Drag the right end of a bar to say how many working days the task takes.
- Drag from the circle after a bar to another task. That task then waits for this one, and starts when this one is finished. An arrow shows the link.
- Click an arrow and press Delete to take the link away.
- Drag a bar to say the first day that its task can start. A task never starts before the tasks that it waits for are finished.
- Click a task twice to go to its line of the page.
- Drag the days, or scroll sideways, to see other days. Pinch, or scroll with ⌘ held, to show more days or fewer.
- Click the button at the top right of the schedule to make it fill the window. Esc puts it back in the page.

**Starts** sets the day that the work starts. This schedule has none yet, so its work starts today, and the first change that you make writes the day down. **Weekdays** leaves Saturday and Sunday out of each task's days. Click it to count them.

Add a to-do item to the list, and the schedule has a bar for it. Change the words of an item, and its bar and its links stay with it.

A to-do item that repeats, like `- [ ] Water the slab every 2 days`, has a bar for each time that it's due. A bar that's due on a day with no work moves to the next working day. Drag any of its bars to move them all. On another day of the slider, the bars before that day show as done, but the item stays open, because it's due again. An item with a limit, like `- [ ] Water the slab every day for 3 days`, has that many bars in all. After its last bar, the slider shows it as done.

Each bar of an item that repeats is like a task of its own. Put the mouse on a bar, and drag from its circle to another task. That task then waits for that time of the item. Drag from another task's circle to one bar, and that time waits for the task. The times after it move after it. The circle after the last bar is for the item as a whole, so a task linked from it waits for the last time. The block's lines call one time `time 2 of` and the item's words.

Every change goes into the block's lines, so the file holds the whole schedule. To see the lines, hold ⌥ and click the block.
