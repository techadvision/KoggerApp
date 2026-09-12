# Pulse UI — working documents

Design and planning documents for the Pulse Echo Sounder UI modernisation.

These live in the repo on purpose: they are on disk, they travel with the branch,
and every change to them shows up in a diff alongside the code change it describes.

| Document | What it holds |
|---|---|
| `pulse-ui-strategy.md` | The staged plan: the `PulseApp.qml` extraction, the settings model, the device-profile rework, and the design decisions behind each. Updated as the work moves. |

The visual prototype that these documents describe is a separate design canvas,
linked from the Claude project for this work. The canvas is the picture; this
folder is the reasoning and the plan.

## Conventions

- One document per subject. Append revisions with a dated heading rather than
  rewriting history, so the reasoning behind a reversal stays readable.
- Nothing here is generated from the code, so nothing here is authoritative about
  the code. Where a document quotes a file, a line number or a property name, it
  was true at the time of writing and is worth re-checking before relying on it.
