# ADR-0003: Public repos by default

- Status: Accepted
- Date: 2026-11-21

## Context
The workflow depends on branch rulesets: main changes only through a PR whose `check` CI job is
green, with no force-push or deletion. The owner is on GitHub Free, which enforces rulesets on public
repos only. On a private Free repo the rules are silently not applied and "don't merge red" is a habit.

## Options
1. Private by default, rules advisory — good: code stays private / bad: no enforcement at all.
2. Pay for GitHub Pro — good: private and enforced / bad: a recurring cost the owner declined.
3. Public by default, `--private` opt-out with a loud warning — good: enforced for free / bad: code
   and history are readable by anyone, so a committed secret is a leak.

## Decision
Option 3. `pinew` creates public repos; `pi-gh-setup` applies the rulesets and turns on GitHub's free
secret scanning with push protection (pushes containing recognised secrets are rejected). On a private
repo it warns that main is unprotected and prints the command to make it public — it never changes the
visibility of an existing repo itself.

## Consequences
- Good: branch protection is a hard rule on every new project, at no cost.
- Bad: everything pushed is public. Secrets stay out of git (`.env` is ignored; keys live in
  `~/.config/pi-kit/secrets.env`); push protection is a backstop, not a guarantee.
