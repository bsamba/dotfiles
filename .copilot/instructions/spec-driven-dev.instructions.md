# Spec-Driven Development — run before coding

Before implementing any feature, fixing a bug, refactoring, or making any
code change — i.e. before writing code or taking action to reach a coding
goal — run this pre-flight workflow so the work is aligned first.

Not needed for read-only questions, pure exploration, chat, or answering a
quick fact.

## The workflow (in order)

1. **grill-me** — Sharpen the plan. Interview relentlessly, map the design
   tree, work the decision frontier, and reach a shared understanding before
   touching anything.
2. **to-spec** — Synthesize the aligned conversation into a spec (problem,
   solution, user stories, implementation/testing decisions, out-of-scope)
   and publish it to the project issue tracker.
3. **to-tickets** — Break the spec into tracer-bullet tickets, each
   declaring its blocking edges.
4. **tdd** — Implement each ticket test-first (red -> green -> refactor),
   verifying behaviour at pre-agreed seams.

Do not skip ahead to code. Only start implementing once the spec and tickets
are agreed with the user.

## How to run these

These are Copilot skills. Invoke each one with the Skill tool, for example
"call the Skill tool with grill-me". They are not slash commands.

## Prerequisite

The repo must be configured for these skills (issue tracker, triage labels,
domain docs). If `docs/agents/` is missing or you are unsure, run
`setup-matt-pocock-skills` once to configure it first.
