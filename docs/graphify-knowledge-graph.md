# Graphify — the knowledge graph, and why the install is checked in

ForgeForm is now four codebases sharing one repository: an ASP.NET Core API, a
Flutter client that targets six platforms, a Playwright suite, and a growing
pile of prose in `docs/`. Every agent session that starts here begins the same
way — grepping for a symbol, reading a file, following an import, grepping
again — and pays for that rediscovery in tokens and in wrong turns, because
`grep` finds *strings*, not *relationships*. "What breaks if I change
`SyncService.saveCompleteWorkout`?" is not a question a text search can answer.

[Graphify](https://github.com/Graphify-Labs/graphify) builds a persistent
knowledge graph of the repository — files, symbols, and the edges between them,
clustered into communities, with the most connected nodes ("god nodes")
surfaced — and exposes it as three cheap lookups: `query`, `path`, and
`explain`. This document explains what was installed into the repo, what was
deliberately *not* installed, and the two failure modes this tool has that
nothing in the build will ever tell you about.

## What is in the repository now

| Path | What it is | Who owns it |
| --- | --- | --- |
| `.claude/skills/graphify/SKILL.md` + `references/` | The `/graphify` skill: the build pipeline, query recipes, export formats | Copied verbatim from the `graphifyy` package |
| `.claude/skills/graphify/.graphify_version` | The package version the skill was copied from (`0.9.50`) | Graphify's upgrade check |
| `CLAUDE.md` → `## graphify` | The always-on rule: prefer `graphify query` over raw search when a graph exists | Copied verbatim; Graphify replaces this section in place on upgrade |
| `.gitignore` → `graphify-out/` | The graph itself is a build artifact, not source | This repo |
| `.claude/settings.json` | `PreToolUse` hooks that nudge toward the graph *before* a search runs | This repo (see "The hook" below) |

Everything above is project-scoped. The CLI itself is not vendored — each
developer installs it once:

```bash
pip install graphifyy          # the PyPI name is graphifyy; the command is graphify
graphify . --code-only         # first build: local AST parse, no API key, no cost
graphify update .              # after changing code: re-extract, still AST-only
```

A full `/graphify .` run additionally sends chunks to an LLM backend to infer
edges that the AST cannot see, and needs whichever API key that backend uses.
`--code-only` and `update` need neither, which is why they are what the commands
above recommend for a first pass.

## Why the install is project-scoped and checked in

Graphify's default install (`graphify install`) writes the skill to
`~/.claude/skills/` — one copy per developer, invisible to everyone else, and
silently absent for anyone who clones the repo. That is the right default for a
general-purpose tool and the wrong one for a shared convention. `graphify
install --project` writes the same files under `.claude/` instead, which is
exactly how this repo already treats its ten other skills and its three
Playwright agents: a convention that only exists on one machine is not a
convention, it is a habit.

One thing the project installer would have written was deliberately dropped: a
`.claude/CLAUDE.md` containing a four-line "the graphify skill lives at
`.claude/skills/graphify/SKILL.md`" registration. Claude Code discovers skills
in `.claude/skills/` on its own — the ten skills already in this repo have never
had such a stanza — so the registration buys nothing and costs a second
project-memory file loaded into every session. If a future `graphify install
--project` re-creates it, deleting it is safe.

## The hook, and the absolute path that must not be committed

The always-on block in `CLAUDE.md` is a *rule*, and rules are advisory: an agent
mid-investigation reaches for `Grep` by reflex. The `PreToolUse` hooks are what
make the rule land at the moment it matters. They fire *before* a `Bash`,
`Grep`, `Read` or `Glob` call, and when — and only when — `graphify-out/graph.json`
exists, they inject a line of context suggesting the graph instead. The guard
fails open by design: no graph, no stdin, a crash, an unparseable payload, a
non-matching call — all print nothing and exit zero. It cannot block a tool
call.

Graphify's installer resolves the `graphify` executable to an **absolute path**
at install time and writes that path into the hook. For a per-machine config
that is correct, and the reasoning is sound (a venv's `bin/` may not be on
`PATH` when the hook runs). For a *committed* config it is a bug waiting to
happen: the path recorded is whichever environment ran the installer, so the
file would carry one developer's `/home/…/venv/bin/graphify` into everyone
else's checkout. The hooks in `.claude/settings.json` therefore invoke a bare
`graphify` from `PATH`, behind a guard:

```
command -v graphify >/dev/null 2>&1 || exit 0; graphify hook-guard search
```

The guard is the second deviation. Without it, a collaborator who has not
installed the CLI gets a *command not found* on every file read and every
search — non-blocking, but constant noise, for a tool they never asked for. With
it, the hooks are inert until the day they install it, and they need no repo
change to switch them on.

The general shape, which outlives Graphify: **anything an installer resolves at
install time — an absolute path, a home directory, a machine name — is
machine-local by construction, and machine-local values do not belong in
version control.** Vendor installers optimise for the machine in front of them.
A file that is going to be committed has to be re-read with "will this be true
on a different machine?" in mind, because nothing else will ask that question.

Re-running `graphify claude install` locally will overwrite both hooks with the
absolute-path form (the installer replaces any hook entry whose matcher it
recognises). That is fine on your own machine — just don't commit the result.

## The two things that fail silently

Neither of the following produces a compile error, a failing test, or a red CI
run. Both produce *confident wrong answers*, which is worse than an error,
because an error stops you.

**A stale graph.** `graphify-out/graph.json` is a snapshot of the repository at
the moment it was extracted. `grep` is never stale — its answer is recomputed
from the files on disk every time. A knowledge graph is stale the instant
someone renames a class, and it will keep answering questions about the old name
with total confidence. `graphify update .` is the maintenance the always-on
block asks for after code changes; it is AST-only, so it costs nothing but a few
seconds. The hook's staleness check softens its nudge for a file the graph
hasn't seen recently, but it is a heuristic, not a guarantee. Treat a graph
answer the way you would treat a comment: evidence about intent, to be confirmed
against the code before you act on it.

**A hook that never fires.** The guard is deliberately unable to fail loudly —
that is what stops a bug in a third-party tool from wedging every file read in
the repository. The cost of that choice is that a hook which never runs looks
exactly like a hook that ran and had nothing to say. If you want to know whether
yours is live, the only honest test is to check that `graphify-out/graph.json`
exists and that `command -v graphify` resolves; there is no signal in the
session itself.

There is also a smaller honesty problem in the always-on block: it opens with
"This project has a knowledge graph at graphify-out/", which is not true until
someone builds one. The block is copied verbatim from the package so that
Graphify's own upgrade path can replace it in place, and every *rule* under it is
correctly conditioned on `graphify-out/graph.json` existing — so the opening
line is a claim the rules themselves don't rely on. Left as-is rather than
edited, because an edited section would be silently overwritten on the next
upgrade anyway.

## Removing it

```bash
graphify uninstall --project      # skill + CLAUDE.md section + hooks
```

Then check the diff: the uninstaller strips the `## graphify` section from
`CLAUDE.md` by locating that exact heading and deleting to the next `##`, so
anything accidentally filed *under* that heading goes with it. Keep the section
last in the file and keep nothing else inside it.
