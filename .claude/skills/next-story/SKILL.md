---
name: next-story
description: Implement the next unchecked story in docs/BACKLOG.md, run tests, tick it off, and commit. Pass a story id (e.g. 1.3) to pick a specific one.
disable-model-invocation: true
argument-hint: "[story-id]"
allowed-tools: Bash(scripts/test.sh *) Bash(git status *) Bash(git diff *) Bash(git add *) Bash(git commit *) Bash(git log *)
---

## Backlog state

!`grep -n "^- \[ \]" docs/BACKLOG.md | head -5 || true`

## Recent commits

!`git log --oneline -5 2>/dev/null || echo "(no commits yet)"`

## Task

Implement one story from `docs/BACKLOG.md`.

Story to implement: `$ARGUMENTS` (if empty, the first unchecked story listed above).

Steps, in order:

1. Read `CLAUDE.md`. The design rules and assist table apply to every story.
2. Read the story's full block in `docs/BACKLOG.md`: Goal, Context, Acceptance, Out of scope.
3. Read the files the story's Context names. Do not read the whole repo.
4. Write a short plan: which files you will add or change, and which test proves each acceptance item. Show the plan before you code.
5. Implement. Stay inside Out of scope. Keep the diff small.
6. Add or extend a `tests/test_*.gd` so every acceptance item has a method that returns false when it fails.
7. Run `scripts/test.sh`. Fix failures. Do not tick the story until it passes.
8. Change the story's `- [ ]` to `- [x]` in `docs/BACKLOG.md`.
9. Commit with message `Story X.Y: <title>`. Stage only files this story touched.
10. Report in five lines or fewer: what exists now, what the tests cover, anything the next story should know.

If an acceptance item cannot be met as written, stop at step 4 and say why. Do not weaken the criteria.
