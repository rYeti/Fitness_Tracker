# Attendance by week: labels that wrapped one bar at a time

This is about the **Attendance by week** card on the Trainer Console's Client
Detail screen (`_AttendanceCard` in
`fittnes_tracker/lib/feature/trainer_console/presentation/view/client_detail_screen.dart`).
It covers a layout bug that only showed up on a phone, why nothing caught it,
and what to check before drawing any chart with one label per column.

## What a trainer saw

On a phone the chart looked broken. Most weeks sat on a flat baseline, but two
of them (`20/7` and `24/8` in the report) had their bar raised and their label
split across two lines, `20/` above `7`. The chart looked like it had random
steps in it that meant nothing.

## Why it happened

The card draws twelve weeks. Each one got an `Expanded` column in a `Row`, and
each column was a `Column` holding the bar in an `Expanded` with the date label
below it. On a 390px-wide phone, after page and card padding, that leaves about
20px per column. The label was a plain `Text` with default wrapping.

A `Text` that doesn't fit its width wraps at the next break it can use, and in
`d/M` that break is the slash. So whether a label wrapped depended on how long
that one date was: `6/7` and `3/8` fit, `20/7` and `24/8` didn't. A wrapped
label is two lines tall. It sits inside a column of fixed height with the bar
in an `Expanded`, so the extra line came out of that bar's space and its bottom
edge moved up. **One long date took height from its own bar only**, so the bars
no longer shared a baseline.

Nothing had anything to say about it:

- **The compiler** can't know text is too wide for a column. That's a runtime
  layout fact, and it depends on the font, the text scale and the screen width.
- **Flutter's overflow warning** didn't fire, because nothing overflowed.
  Wrapping *is* the layout handling a narrow width. The yellow-and-black stripe
  only appears when a child can't fit at all.
- **Desktop and web**, where the console is mostly used, give each column over
  80px, so every label fits and the bug never appears there.
- **Tests** in `flutter test` use a font where every character is a 1em square.
  That changes which widths make a label wrap. At a 390px test width *every*
  label wrapped the same way, so the chart looked even. The new test's first
  draft passed against the broken code for exactly this reason. The bug only
  shows at widths where short labels fit and long ones don't, so
  `client_detail_attendance_test.dart` now checks five widths from 360 to 1400.
  Before the fix it fails at 460.

## The fix

**Give every week the same label height, and make one choice for the whole
row about which weeks get a label.**

1. Measure every label once with a `TextPainter`, using the same style and
   text scale the chart will draw with, and keep the widest.
2. Divide the chart's width by the number of weeks to get each column's width
   (`slot`). The stride is `ceil((widest + 8) / slot)`: how many columns one
   label needs, plus a gap of 8. On desktop that's 1, so every week gets a
   label. On a phone it's usually 2 or 3.
3. Count back from the newest week, so the current week always gets a label
   and the others get one every `stride` weeks.
4. Every column reserves a label area of the same fixed height, whether or not
   it shows a label. This is what fixes the baseline: the bars' space no longer
   depends on the label below them.
5. A label shown under a narrow column sits in an `OverflowBox`, centred under
   its bar, and spills into the blank label areas next to it. The stride makes
   sure those areas are empty.

The label also grew from 8px to 10px and got a little more contrast. 8px was
below what any trainer could comfortably read, and the stride now gives it
room. The gap between bar and label and the bars' side padding moved onto the
4px grid (8, and 2 or 1) from 6 and 3. Hovering or reading with a screen reader
still gives the full date and the sessions done out of planned for **every**
week, labelled or not, because `Semantics` stays on each column.

## Alternatives that were rejected

- **`maxLines: 1` with `TextOverflow.ellipsis`**: the baseline would be even,
  but a trainer would read `2…` for a week and learn nothing from it.
- **`FittedBox(fit: BoxFit.scaleDown)` on each label**: each label shrinks by
  its own amount, so `20/7` would be drawn smaller than `6/7` next to it. That
  swaps uneven bars for uneven text: the same mistake of each column deciding
  for itself.
- **Showing fewer weeks on a phone**: that changes what the chart says, and
  that's a product decision, not a layout fix. The 12-week window is the API's
  and stays the same on every screen.
- **Rotating the labels**: it works, but slanted dates are hard to read, and it
  still needs the same measurement to know when to rotate.

## The general lesson

When a row of items has to line up, **a layout choice any one item makes for
itself will eventually break the line.** A `Text` wrapping, a `FittedBox`
scaling and a `Flexible` shrinking all look harmless in one column and
misalign the row as soon as the columns make different choices. Measure once
for the whole row, decide once, and give every column the same space whether
or not it uses it.

And when a layout bug depends on width, test a spread of widths. One phone
size in the test font can put every item on the same side of the threshold,
and then the test passes without testing anything.
