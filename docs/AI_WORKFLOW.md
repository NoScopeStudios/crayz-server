# CrayZ - AI Workflow

## Modes

Use planning/review before implementation.

## Codex Rules

Codex may implement only the approved milestone scope.

Before editing files, Codex should state:

- files it expects to touch
- behavior it will implement
- validation commands it will run
- what remains out of scope

## Validation Rules

Each milestone should provide:

- `docker compose config` result
- shell syntax check for scripts
- build result
- run/startup evidence where applicable
- Git diff summary

## Secrets Rule

If a task touches Steam credentials, Codex must avoid printing real credentials and must not commit them.
