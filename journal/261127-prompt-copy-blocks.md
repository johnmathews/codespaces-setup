# /prompt's start command and paste line come out through /copy

> Purpose
>
> Why `/prompt`'s Step 5 report now puts the start command and the paste line in their own code
> blocks, and why the clipboard now holds the start command.

## 1. Why

Starting the new session took two manual copies out of the terminal: the `cd … && claude …` command
and the paste line. Both are long, the terminal wraps them on screen, and a selection had to be
dragged across the wrapped lines.

Claude Code's `/copy` copies from the last reply, and when that reply holds code blocks it offers a
picker of them. It copies the text as written, so the on-screen wrap never reaches the clipboard.

## 2. What changed

1. `commands/prompt.md` Step 5: the start command is the reply's first code block (`bash`) and the
   paste line its second (`text`), each holding only the text to paste. Nothing else is a code block
   before them, so they are always items 1 and 2 in the picker. The full prompt block, when shown,
   comes third.
2. The report is written as one reply after the turn's last tool call, so it is the reply `/copy`
   reads.
3. Step 4 now copies the **start command** to the clipboard, not the paste line. It is the first
   thing needed, in a new terminal, and the paste line is one `/copy` away. With the old order, the
   user's first `/copy` overwrote the clipboard copy anyway.
4. The report ends with one line saying how to copy each block.
5. Lane hand-offs: each lane's command and prompt are separate blocks, in lane order.
6. `sitrep/SKILL.md` and `status-updates.md` §4.4 say the same, so the sitrep route and the fallback
   keep the two blocks first.
