# Issues

Tickets for this repo are markdown files in this directory, not GitHub or
GitLab issues.

## Naming

`TICKET-ID.md` with a short id such as `CITYHUB-2`. Title the file's first
heading with the same id and a short task name.

## Required sections

Use these headings so tickets stay scannable:

- **Description** — what and why
- **Acceptance Criteria** — verifiable checklist
- **Resources** — links, benches, related tickets (`None` if empty)
- **Notes** — constraints, out of scope (`None` if empty)
- **Status** — `open` or `done`, plus the branch/commits that landed it

## Workflow

1. Add or update `issues/TICKET-ID.md` before or with the first commit.
2. Branch if the work needs isolation; otherwise commit on `main`.
3. Commit directly. Do not open a pull or merge request.
4. Mark the ticket `done` when acceptance criteria are met and benches or
   tests that belong to the ticket are recorded.
