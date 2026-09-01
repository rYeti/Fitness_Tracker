# Why the app vanished from Play search, and why I diagnosed it wrong

A walkthrough of an outage that was never an outage, written to be read on its
own. It covers the symptoms, the four theories that fit them, the two Console
screenshots that killed all four, and the rule the whole episode leaves behind.

It is also a record of a reasoning failure. The wrong diagnosis got far enough to
ship a commit and a documentation section before anyone looked at the Play
Console. That part is the most useful thing here, so it is not buried.

---

## 1. The symptoms, and why they are so misleading

The report was three facts:

1. The app is no longer findable in the Play Store by searching for it.
2. The store URL still resolves in a desktop browser.
3. Devices that already have it can still update it from the Play Store.

That combination feels diagnostic. It rules out the two things anyone reaches for
first — an app that has been **unpublished** or **suspended** does the opposite,
returning 404 on the URL and cutting updates off. So the app is published, it is
serving existing users, and something is preventing new discovery specifically.

There is a well-known mechanism with exactly that signature. Play enforces an
annual `targetSdk` bar, and an app below it **keeps its listing, keeps serving
existing installs, and stops being offered to new users**. Three symptoms out of
three. The deadline lands on 31 August. The report came in on 1 September.

That is a very good fit, and it was wrong.

## 2. What I did with a good fit

I confirmed from the repository that `targetSdk` was not pinned —
`fittnes_tracker/android/app/build.gradle.kts` delegated it to
`flutter.targetSdkVersion`, meaning the API level Play judges a release by was
whatever the CI toolchain resolved on the day, invisible in the diff. I confirmed
from `.github/workflows/android-release.yml` that `DEFAULT_TRACK: internal`, so
no release from this repo had ever gone to production on its own. I confirmed
there were no `v*` tags, so every publish had been a manual dispatch.

Every one of those findings is true. None of them is the cause. They are the
facts a repository can produce about a problem that does not live in the
repository, and producing them felt like progress.

I shipped a commit pinning `targetSdk = 36` with a message asserting the app had
disappeared through "the signature of a target-API compliance lapse", and a
section in `docs/android-release.md` built on that story.

**The Play Console had the answer the whole time, one click away, and settled it
in two screenshots.**

## 3. The two screenshots

### Policy status: "No issues found"

That single line kills the entire policy branch — no strike, no enforcement
action, no distribution restriction, and no lapsed declaration for the
policy-sensitive `SCHEDULE_EXACT_ALARM` permission the manifest carries. Play
does not restrict an app's distribution silently; it says so on this page and it
emails. The page was clean.

### Publishing overview: two changes never submitted

```
Changes not yet submitted for review          [ Submit 2 changes for review ]

  Closed testing - Alpha
    Countries/regions   Add 175 countries/regions: Albania, Algeria and 173 more
    Countries/regions   Add rest of world
```

The country list that would make the app broadly available had been **staged and
never submitted**. Managed publishing was off, so nothing was deliberately being
held back — the changes had simply never been sent.

## 4. The trap: the Console shows you draft state in a published-state widget

The track summary, on a different tab, reads:

```
Track summary (Phones, Tablets, Chrome OS, Android XR)
Active · Latest release: 1.0.2 · 177 countries/regions
```

Read that after configuring countries and you will conclude the app is
distributed to 177 countries. It is not. That number includes the staged,
unsubmitted additions. Do the arithmetic against the pending changes — 175
additions, plus "rest of world", plus a small pre-existing set — and the
*published* distribution is on the order of **two countries**.

This is the mechanical heart of the incident:

| Question | Page that answers it |
| --- | --- |
| What have I configured? | The track's own tabs (Countries/regions, Testers, …) |
| **What is the store actually serving right now?** | **Publishing overview** |

Those are different questions, and the track tabs answer only the first while
looking like they answer both. Nothing flags that a change is sitting
unsubmitted; you have to go to Publishing overview and notice a button.

Play search results are scoped to the viewer's Play Store account country. An app
not distributed to your country cannot surface in your search results. A direct
link backed by an active tester grant resolves through a more permissive path,
which is why the opt-in link worked and search did not — the exact split that had
been reported.

## 5. Three more things that surprised us, in the order they bit

**Tester opt-in is per track, not per app.** Moving the build from the internal
track to closed testing required every tester to re-accept through the *new*
Join-on-Android link, even though their address was already on the
`ForgeForm_Test` email list. Being on the list is **authorization**; clicking the
link is **enrolment**. Play needs both, and only the first is visible in the
Console.

**"On the list" is therefore not "opted in."** The list showed 9 users. The
number of those 9 actually enrolled is a different, smaller-or-equal number, and
the Console's tester count does not distinguish them at a glance. Any plan that
depends on a tester headcount has to verify enrolment, not membership.

**Closed testing is never publicly searchable.** For an enrolled tester it
behaves exactly like a normal listing — which is precisely why its disappearance
reads as an outage rather than as configuration. For everyone else it does not
exist, in any country, no matter how the countries are configured. Public search
requires a production release, and per the submission history this app has never
had one.

## 6. The connective lesson

Play gates production access behind a sustained closed test — the requirement in
force here is **12 opted-in testers held continuously for 14 days**. That is the
project's actual next milestone.

The pieces interlock in a way that is easy to miss and expensive to get wrong:

```
unsubmitted country list
        ↓
testers in excluded countries cannot install
        ↓
they never count as opted-in testers
        ↓
the 14-day clock stalls, or resets
        ↓
production access never unlocks
```

So the country changes are not a side quest to be done whenever. **They have to
be genuinely published before the 14-day clock is worth starting**, or the clock
runs against a tester population that is smaller than it appears.

Verify the current requirement against Google's own documentation before planning
around it. The numbers above are what applied to this account at the time of
writing, and Play's testing requirements have changed more than once.

## 7. The rule this leaves behind

The general shape of the mistake was not a missing fact. It was reasoning from
symptoms to a mechanism that fit them, and then treating the quality of the fit
as evidence that the mechanism was real. Three symptoms out of three matched, the
dates lined up to the day, and the repository obligingly produced a genuine
weakness — an unpinned `targetSdk` — that made the story feel confirmed.

None of that is evidence. A mechanism that explains the symptoms is a hypothesis;
it becomes a diagnosis only when the system that owns the behaviour is asked
directly. Here the system that owned the behaviour was the Play Console, the
repository could not see into it at all, and everything the repository *could*
produce was beside the point no matter how true it was.

**When the failure is in a system this repo does not own, findings from this repo
cannot diagnose it — they can only describe what we ship into it.** Go and look
at the owning system first. Publishing overview and Policy status, in this case,
between them cost two clicks and would have replaced four theories with an
answer.

A corollary worth keeping: **a doc that confidently explains a real incident with
the wrong cause is worse than no doc**, because it will be trusted next time the
same symptoms appear. `docs/android-release.md` originally carried that wrong
explanation; the commit that introduces this document removes it and keeps only
the general hazard, which is still real and still worth guarding against — just
not what happened here.

## 8. What was kept from the wrong diagnosis, and why

The `targetSdk` pin stays, on its own merits. Delegating it to
`flutter.targetSdkVersion` means the API level Play judges a release by is a
property of whichever toolchain CI resolved that day: it does not appear in any
diff, nobody reviews it, and it can move under you between two builds of the same
commit. Pinning it makes a target-API bump a deliberate, dated, reviewable
change. The release workflow also logs the resolved value in its preflight step,
so every release leaves a record of the number Play will judge it by.

That argument never depended on the diagnosis. It is worth separating cleanly
from it — good hardening arrived here attached to bad reasoning, and the honest
thing is to keep the first and retract the second rather than quietly let the
commit stand as though it had been right all along.
