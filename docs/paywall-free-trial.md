# The free trial that stopped being offered

## What was reported

"The buy premium screen from RevenueCat does not have the 'try premium for
2 weeks' option." The trial itself is configured in the stores and RevenueCat
serves it. What went missing is the screen's willingness to say so.

## How it went missing

Release 1.0.2+6 shipped RevenueCat's *hosted* paywall (`purchases_ui_flutter`).
A hosted paywall is a template configured in the RevenueCat dashboard, and its
templates know about trials: when the selected product carries a free phase,
the call to action reads "Start 2-week free trial" without anyone writing that
code. That is where "added a free trial option" in the 1.0.2+6 changelog came
from.

1.0.2+8 replaced it with `PaywallScreen`, a custom screen styled with
ForgeForm's own tokens. Everything the template had done implicitly now had to
be done explicitly, and the trial was the piece that got only half carried
over. 1.0.2+9 added `_introOfferLabel`, a small orange line under a plan card
reading "14 days free trial", and stopped there. The purchase button kept
saying "Upgrade · €49.99". The pre-selected plan was always the annual one,
whether or not the annual plan was the one carrying the trial. Nothing said
what would be charged when the trial ended.

So from the user's side the option had simply gone: the trial was one line of
12-pixel text, possibly under a card that wasn't selected, and the only button
on the screen advertised a price.

None of this was visible to the compiler or the tests. `purchases_ui_flutter`
is still in `pubspec.yaml` (nothing references it), so removing the hosted
paywall didn't break a build. The custom screen type-checks because a trial is
just a nullable field, `StoreProduct.introductoryPrice`. A null there and a
trial the UI never mentions look exactly the same. There was no test for the
paywall at all. Losing behaviour that a framework or template supplied for
free is the kind of regression nothing flags, because the old code never
spelled it out. Whoever replaces a template has to list what the template did
before deleting it.

## What the screen does now

`fittnes_tracker/lib/feature/premium/paywall_screen.dart`:

| Where | What |
|---|---|
| `_defaultPackage` (line 111) | Pre-selects annual-with-trial, then any plan with a trial, then annual, then the first. |
| `_introOffer` / `_freeTrial` (lines 96, 102) | The one place that decides whether a package's intro offer is real for *this* user. The card and the button both read from it. |
| Button (line 332) | "Try Premium free for 2 weeks" when the selected plan has a free trial; the old "Upgrade · price" otherwise. |
| Line under the button (line 342) | "After the trial: €49.99 (Annual). Cancel before it ends and you won't be charged." |
| `_ineligibleIntroProducts` (line 77) | Apple only: asks RevenueCat whether the user can still get each intro offer. |
| `paywallIntroDuration` (line 510) | Folds whole weeks back out of Android's day count. |

The purchase call itself did not change. On Android,
`PurchaseParams.package(...)` buys the product's `defaultOption`, and that is
the same subscription option `introductoryPrice` is read from. What the button
advertises is therefore exactly what gets bought.

## Three things the diff doesn't make obvious

### "14 days", not "2 weeks"

The Android side of the Flutter plugin is RevenueCat's
`purchases-hybrid-common`. Its `StoreProductMapper.mapIntroPrice` takes the
free phase of the product's `defaultOption`, and its
`Period.mapPeriodForStoreProduct` turns `Period.Unit.WEEK` into `DAY × 7`, which
its own source comments describe as being "for backwards compatibility". A Play
offer configured as `P2W` therefore reaches Dart as `periodUnit: day,
periodNumberOfUnits: 14`. The Play Console says two weeks, the paywall said 14
days, and the SDK did exactly what it was written to do. `paywallIntroDuration`
folds any whole number of weeks back into weeks. That rule is pinned by
`test/premium/paywall_intro_duration_test.dart`, the only test the paywall has.

### The two stores disagree about eligibility

On **Google Play**, an offer the user isn't eligible for (for example a
"new customer acquisition" trial for someone who has subscribed before) is left
out of the product details entirely. `introductoryPrice` comes back null and
the answer is already built in. RevenueCat's
`checkTrialOrIntroductoryPriceEligibility` always returns `unknown` on
Android, so calling it there tells us nothing.

The **App Store** is the opposite. It reports the introductory offer to every
user, including someone who used their trial last year. Before this change the
screen would show that person a trial and then charge them full price on day
one. That was hidden only because the trial was barely visible. Once the button
says "Try Premium free for 2 weeks" it becomes a promise, so on iOS/macOS the
screen asks RevenueCat and advertises the trial only on a definite `eligible`.
It treats `unknown` and a thrown error as ineligible, which is RevenueCat's own
documented guidance. It is better to show the regular price than to advertise
a trial the user won't get. `kIsWeb` is excluded explicitly, because
`defaultTargetPlatform` reports iOS in Safari on an iPhone, and the web build
can't purchase anyway (see "Known web constraints" in `CLAUDE.md`).

### Why the default selection prefers the trial over annual

The old rule, "annual, else the first plan", is still the tiebreaker. It now
loses to a plan that has a trial. If the stores put the trial on the monthly
plan only, an annual default would leave the trial on an unselected card and
the button would never mention it, which is the bug again. The rejected
alternative was to keep the annual default and add a separate trial banner.
That banner would advertise a trial the selected plan wouldn't start, so
tapping the button under it would charge the user immediately.

## If the trial still doesn't show

After this change the screen shows whatever trial the store returns. If it
shows none, the store returned none, and the cause is outside the app:

- **Play:** the free-trial offer must be *active* on the base plan behind the
  package's product in Play Console, with no `rc-ignore-offer` tag (RevenueCat
  skips offers with that tag when it picks `defaultOption`). The test account
  must also be eligible. An account that has already subscribed to that
  product won't be offered a "new customer acquisition" trial again, so test
  with a fresh licence-tester account.
- **App Store:** an introductory offer of type *free* has to be configured on
  the subscription, and the Sandbox tester must not have used one in that
  subscription group.
- **RevenueCat:** the package has to be in the *current* offering. This screen
  never reads any other offering.

## The lesson

When a hosted or templated component is replaced with your own code, list
everything it did for you, including the things nobody configured, before
deleting it. The template's "Start free trial" button was never a line of code
in this repository, so its disappearance never showed up in a diff anyone
reviewed.
