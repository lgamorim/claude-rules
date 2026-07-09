# Workflow

- Make minimal, focused changes; do not refactor unrelated code in the same change.
- One logical change per commit, with an imperative-mood message explaining *why*.
- When unsure between two designs, present both with trade-offs and ask before implementing.
- Never commit or push directly to the default branch (`master`/`main`). All
  work happens on a `feature/`-prefixed branch.
- On multi-contributor repos, the branch lands on the default branch only
  through a reviewed pull request. Enforce this with branch protection
  (require a PR, disallow direct pushes, require the squash-merge strategy) so
  it can't be bypassed by accident.
- Solo-project exception: when you are the only contributor and there is no
  one else to review, a PR adds no review value. You may squash-merge the
  `feature/` branch into the default branch yourself without opening one
  (e.g. `git switch master && git merge --squash feature/x`, then a single
  commit). The feature-branch and squash steps still stand — only the
  PR/review step is waived. Reintroduce PRs the moment a second contributor
  joins.
- Either way, merge by squash so each feature arrives as a single logical
  commit on the default branch, consistent with the "one logical change per
  commit" rule above; the squash commit message keeps the imperative,
  *why*-focused form.
- Update this file when a new convention or correction is established.
