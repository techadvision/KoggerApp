# Pulse UI — working documents

Design and planning documents for the Pulse Echo Sounder UI modernisation.

These live in the repo on purpose: they are on disk, they travel with the branch,
and every change to them shows up in a diff alongside the code change it describes.

| Document | What it holds |
|---|---|
| `upstream-merge-survey.md` | What is in upstream's 537 commits since 0.14.3, what of it Pulse wants, and the merge shape that follows. Written 12 Sept 2026. |
| `pulse-ui-strategy.md` | The staged plan: the `PulseApp.qml` extraction, the settings model, the device-profile rework, and the design decisions behind each. Updated at the end of every stage. |
| `pulse-bug-backlog.md` | The grouped bug backlog of the v2 UI (groups A-E and what followed), each item with its diagnosis, its commit and what to check on the device. |
| `pulse-high-performance-mode.md` | The PULSE blue performance mode over the IP link: ping period, range and the boat-speed setting. |
| `pulse-depth-source-analysis.md` | The depth source on the shore and in the shallows: the bottom track's gates, the outlier filter, the rangefinder rules and the chosen depth (branch `feature/pulse-depth-source`), with every field test of Oct 2026 and the bench (`tools/pulse-bt-bench/`). Its status block at the top says what is current. |

The visual prototype these documents describe is a design canvas, linked from the
Claude project for this work. The canvas is the picture; this folder is the
reasoning and the plan.

## Resuming this work in a new session

The work runs one stage per chat session, so each session starts cold. To pick up:

1. Read `pulse-ui-strategy.md` top to bottom. It is written to be read by someone
   with no memory of the conversation that produced it.
2. Go to **Stage status** near the end — it says what is done, what is next, and
   what decision (if any) is open.
3. Check the branch: `git log --oneline -5` and `git status`. The strategy document
   records what the last stage committed, so the two should agree. If they do not,
   trust the repo and fix the document.
4. Re-derive anything about the code rather than trusting the document for it.
   Line numbers, property names and file sizes quoted here were true when written.
   The *decisions* and *reasons* are what this document is for; the *facts about
   the code* are cheap to look up again and go stale quickly.

At the end of a stage, update **Stage status** and append a dated section covering
what changed and why, before the session closes.

## Conventions

- One document per subject. Append revisions with a dated heading rather than
  rewriting history, so the reasoning behind a reversal stays readable.
- Nothing here is generated from the code, so nothing here is authoritative about
  the code.
- Where a stage leaves a known defect or an unresolved question, write it down.
  A stage that looks finished but left something behind is worse than one that
  says so.
