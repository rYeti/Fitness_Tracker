# Chat timestamps: the date that was not a date, and the time nobody could see

A chat message carries exactly one number the reader cares about besides its
text: when it was sent. Chat rendered that number in three places, parsed it in
two, and got it wrong in both — once visibly, as a day divider reading
`01/01/0001`, and once invisibly, as every message in the thread being stamped
an hour or two away from when it actually arrived.

Neither was a bug the compiler or the test suite could have caught. Both were
type-correct, and the tests supplied their fixtures in a shape the server does
not always send. This is what was wrong, why nothing noticed, and the rule the
fix leaves behind.

Line references are to the commit that introduced this document.

---

## 1. `DateTime` is two different things, and Dart will not tell you which

The whole family of defects comes from one fact about `DateTime`, in Dart and in
C# alike: the same type is used for two incompatible concepts.

| Concept | What it means | Example |
| --- | --- | --- |
| An **instant** | A point on the world's timeline, the same for everyone | "the moment this message was sent" |
| A **wall-clock time** | Digits on a clock, meaningless without a zone | "09:30", somewhere |

`DateTime.parse` returns one or the other depending on a single character at the
end of the string. Given `2026-08-01T09:30:00Z` it returns an instant. Given
`2026-08-01T09:30:00` — the same string minus the `Z` — it returns a wall-clock
time, marked local, holding UTC digits. Both are a `DateTime`. Both are
non-null. Neither logs anything.

The API stamps `ChatMessage.SentAt` with `DateTime.UtcNow`, and whether that
reaches JSON with its `Z` depends on the `Kind` flag surviving a round trip
through the database provider. On Npgsql against `timestamp with time zone` it
does. That is not a property the client can rely on, and it is not one anything
in the client asserted: `ChatMessage.fromJson` called `DateTime.parse` on
whatever arrived and shipped the result into the thread. If a `Z` ever went
missing — a provider change, a column typed `timestamp without time zone`, a
future endpoint composing the value by hand — every message in the app would
have silently shifted by the reader's UTC offset. In most of Europe that is one
or two hours: wrong, but *plausible*, which is the worst kind of wrong. Nobody
reports a chat message that says 10:30 instead of 09:30. They just quietly stop
trusting the timestamps.

### The same confusion, one layer up

`ChatDateDivider` had a smaller version of the same mistake, and this one was
live rather than latent:

```dart
String get label {
  final local = DateTime(date.year, date.month, date.day);   // UTC fields
  ...
}

static bool needed(DateTime? previous, DateTime next) {
  final a = previous.toLocal();                              // local fields
  final b = next.toLocal();
  ...
}
```

The variable is called `local`. It is not local. It reads the calendar fields
straight off a UTC instant, while the method that decides *whether a divider is
needed at all* converts to local first. So the two halves of one widget
disagreed about what day a message fell on, and either side of local midnight
the pill could announce a different date than the messages sitting under it. In
UTC+2, a message sent at 00:30 local on the 5th is 22:30 UTC on the 4th:
`needed` correctly saw a new day and inserted a divider, and `label` printed the
4th above it.

The lesson is smaller than the bug: **`toLocal()` is not a formatting detail, it
is the conversion from instant to wall-clock time, and every place that reads
`.year`, `.month`, `.day` or `.hour` is doing wall-clock arithmetic whether it
says so or not.**

---

## 2. `01/01/0001` is not a date, it is a missing value wearing one

The visible symptom was a day divider reading `01/01/0001`. That value has one
origin: it is what year 1 looks like — `DateTime(1)` in Dart, `default(DateTime)`
in C#. It is not a date anyone ever sent a message on. It is the shape a
*missing* timestamp takes when a non-nullable field has to hold something.

The old parse could not express that:

```dart
sentAt: DateTime.parse(json['sentAt'] as String),
```

Two failure modes, neither survivable. If the payload omits `sentAt` or sends
null, the cast throws — and it throws inside `loadThread`, whose `catch` turns
the whole thread into "Could not load this conversation", so a single malformed
message hides an entire conversation with an error that names nothing. If the
payload sends a sentinel, it parses perfectly and gets drawn.

Both are the same design error: **the parser had no way to say "the server did
not really send me one of these"**, so it either exploded or passed nonsense
downstream. The type system was satisfied throughout. `DateTime` is
non-nullable, `DateTime.parse` returns one, and year 1 is a perfectly valid
`DateTime`.

### Why the tests were green

`test/chat/fakes.dart` builds its fixtures like this:

```dart
'sentAt': (sentAt ?? DateTime.now().toUtc()).toIso8601String(),
```

`toIso8601String()` on a UTC `DateTime` always emits the `Z`, and no fixture
ever omitted the field or used a sentinel. Every test therefore fed the parser
the one input shape it handled correctly. That is the general trap: **a fixture
built by calling the serializer's inverse tests the round trip, not the
contract.** The inputs worth writing down are the ones a real payload can
contain and your fixture builder cannot produce — a missing field, a null, a
sentinel, a string with no zone.

---

## 3. What the fix is

One file — `lib/feature/chat/domain/chat_timestamps.dart` — owns every instant
chat touches, both directions.

**Parsing** (`ChatTimestamps.parseInstant`) returns `DateTime?` and makes both
ambiguities explicit:

- A string with a `Z` or an offset is an instant, taken as given.
- A string with neither is *reinterpreted* as UTC rather than converted. The
  digits are what the server meant; only the missing label was wrong.
- Anything before the Unix epoch — which covers year 1 from either language — is
  a sentinel, and comes back `null`. Chat did not exist in 1969; a timestamp
  claiming otherwise is missing data, not history.
- Null, empty, unparseable and wrong-typed input all come back `null` instead of
  throwing, so one bad message can no longer take a conversation's whole thread
  down with it.

What each caller does with that `null` differs, and the difference is the
interesting part:

| Caller | On an unusable timestamp | Why |
| --- | --- | --- |
| `ConversationSummary.lastMessageAt` | stays `null` | Null is already a real state — a relationship nobody has written in yet. The row shows no time, which is true. |
| `ChatMessage.sentAt` | falls back to now | The field is load-bearing: the thread sorts on it and the dividers are cut from it. There is no "unknown" position in an ordered list. |

That fallback is a deliberate, documented lie, and it is the smallest one
available. A message we are reading right now did arrive right now, so dating it
to this moment is wrong by seconds instead of by two millennia, and it puts the
bubble at the bottom of the thread where the reader just watched it appear. The
alternative — making `sentAt` nullable all the way through `ThreadMessage`,
sorting and dividers — buys a more honest model at the cost of a "where do
undated messages go?" decision in four places, and every answer to that question
is also a guess.

**Formatting** is the same file, so the three surfaces cannot drift:

| Surface | Format | Rationale |
| --- | --- | --- |
| Day divider | `Today` / `Yesterday` / `04/08/2026` | Padded and always year-bearing; a thread scrolled far back should not need arithmetic. |
| Message bubble | `09:07` | The resolution a message needs; the divider above it supplies the day. |
| Conversation row | time / weekday / `04/08` / `04/08/2025` | Precision decreasing with distance. The year appears once it differs from today's — without it, last August and this August are the same two digits, in a list *sorted by exactly that value*. |

Every one of them converts with `toLocal()` at the point of formatting and
nowhere else. Instants in, wall-clock out, one boundary.

---

## 4. The time under the bubble

The second half of the request: a thread showed no time at all. A day divider
told you which day, and nothing told you which minute — so a conversation that
happened over one afternoon was an undated wall of text, and "did they answer
before or after the session?" was unanswerable.

`ChatBubble` now carries a timestamp line, with one rule worth stating: **only a
settled message shows a time.** A pending message and a failed one both carry
`createdAt` from the local outbox — the moment the user pressed send, which is
not the moment the message exists. The server may never have received it. Those
two states keep the markers they already had (a clock icon, a tap-to-retry
strip), which say something true about the message; a printed time would say
something false.

The same distinction reaches the accessibility tree. The bubble's semantic value
now appends the full `dayLabel at timeOfDay` for settled messages only — a screen
reader gets no day dividers and no small grey text, so without it a thread reads
as one undated run of messages. This is CLAUDE.md's "color is never the only
signal" rule generalised: *position* is not the only signal either. A sighted
reader infers a message's day from the pill it is under. A screen reader user has
no pill.

---

## 5. The rule this leaves behind

**A timestamp crossing the API boundary is an instant, and the only place that
converts it to a wall-clock time is the widget drawing it.**

Concretely, for anything that touches a chat time:

1. Parse through `ChatTimestamps.parseInstant`. Never `DateTime.parse` on a
   payload field — it cannot express "the server did not send one", and it makes
   a silent guess about the zone.
2. Format through `ChatTimestamps`. If a new surface needs a shape that is not
   there, add it to that file rather than to the widget, or the three surfaces
   start disagreeing again.
3. Treat a pre-epoch date as missing data, wherever it comes from. It is never a
   real value; it is always a default that escaped.
4. When a fixture needs a timestamp, write at least one that your serializer
   would never produce. The bugs live in exactly the inputs a round-trip fixture
   cannot generate.
