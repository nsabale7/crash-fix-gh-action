# Plan Review — SP-1 Crash Auto-Fix GitHub Action

**Reviewer:** gh-rev
**Date:** 2026-05-19
**Documents reviewed:** PLAN.md, requirements.md, design.md

---

## Checkpoint Results

### 1. Clear done criteria for each task
**PASS**

Every task (T-1 through T-7) has explicit, binary done criteria. T-1 requires `actionlint` to pass and inputs/outputs to match FR-1/FR-4. T-2 lists concrete BATS test scenarios (each required field missing individually → exit 1, stack-trace >50 KB → truncated, happy path). T-3 requires headless operation confirmed inside `act`. T-4, T-5, T-6, and T-7 all have measurable, tool-verifiable criteria. No task ends with "it works" or "developer is satisfied."

---

### 2. Riskiest assumption identified in Task 1
**PASS**

T-1 explicitly names the riskiest assumption: "The Claude Code CLI supports a fully non-interactive mode (`--print` or equivalent) that works on a headless runner." It mandates validation before T-3 begins. The standalone "Riskiest Assumption" section at the bottom of PLAN.md reinforces this with an explicit fallback path (use `expect` or API call if CLI requires TTY). The assumption is correctly front-loaded rather than discovered mid-sprint.

---

### 3. Cohesion of tasks (do they fit together?)
**PASS**

The task sequence maps cleanly onto the data flow in design.md: scaffold (T-1) → validator + prompt builder (T-2) → Claude agent (T-3) → stubs (T-4, parallel) → branch + commit (T-5) → PR (T-6) → E2E (T-7). Each task produces an artifact consumed by the next. There are no orphaned tasks and no gaps in the chain from "source files" to "PR opened."

---

### 4. Coupling issues (are dependencies clear?)
**PASS with minor note**

All task dependencies are stated in-line and in the dependency graph. The graph correctly shows T-4 (stubs) must complete before T-5 alongside T-3. Minor note: in practice T-5 only consumes the Claude path at runtime — T-4 stubs do not affect T-5's data flow. Making T-4 a hard gate on T-5 is conservative but not harmful. The rationale ("agent seam fully defined") is stated, which is sufficient for planning purposes.

---

### 5. Session-completable tasks
**PASS with note on T-7**

T-1 through T-6 are each scoped to self-contained shell script work and test authoring, well within the stated ≤4-hour bound. T-7 requires a dedicated external test repository (`crash-fix-e2e-target`) that must be set up before the test can run. If that repo does not already exist, T-7's session begins with repository creation, secret provisioning, and workflow installation — work not surfaced in the task description. T-7 should note "test repo pre-exists with workflow installed" as a precondition, or split setup from execution.

---

### 6. Vague task descriptions
**PASS with note on T-7 setup**

T-1 through T-6 are specific: named files, concrete shell script behavior, referenced schema files. T-7's description says "a dedicated test repository with a simple app containing a known crash signature" but does not specify what that app is, who creates it, or how `ANTHROPIC_API_KEY` is provisioned in that repo's secrets. This is minor for an internal team but should be tightened before assigning T-7 to a developer unfamiliar with the setup.

---

### 7. Alignment with requirements.md
**PASS with gaps on NFR-1 and NFR-4**

FR-1 through FR-8 all have clear task owners:

- FR-1 → T-1 (inputs in action.yml) + T-2 (validate.sh)
- FR-2 → T-5 (branch.sh)
- FR-3 → T-3 (run.sh)
- FR-4 → T-6 (open-pr.sh, outputs)
- FR-5 → T-4 (stubs)
- FR-6 → T-5 (commit.sh empty-diff check)
- FR-7 → T-6 (pr-template.md)
- FR-8 → T-5 + T-6 (structural PR-only flow)

**Gaps:**

- **NFR-1 (retry on transient failure):** requirements.md requires at least one retry on transient network failures during agent install. No task has a done criterion covering retry logic in install.sh. This is unimplemented and must be addressed.
- **NFR-4 (per-step observability):** requirements.md requires each major step to emit a distinct log line or step summary. Only T-6's done criteria mention step summary (`pr-url`). The other five steps have no observability criterion in their done criteria.

---

### 8. Alignment with design.md
**FAIL**

The architecture diagram in design.md includes `.github/workflows/ci.yml` (lint + unit tests on PRs). T-4's done criteria state "CI (actionlint + BATS) is green" — implying CI is already running. Yet no task is assigned to create `ci.yml`. This is a missing deliverable: the ci.yml file appears in the design and is referenced in done criteria, but has no task that creates it. A task (or an addition to T-1) must own the creation of ci.yml with a done criterion of "ci.yml runs actionlint and BATS on all PRs."

Additionally, design.md's R-3 mitigation describes a "log-scan CI job that greps for known key prefixes (`sk-ant-`, `sk-`, etc.) in captured output." This job does not appear in the testing strategy section or in any task's done criteria.

---

### 9. Risk register completeness
**PASS**

Five risks cover the most critical failure modes: CLI API instability (R-1), agent-produced breaking changes (R-2), secret leakage via debug output (R-3), oversized stack traces (R-4), and missing `gh` CLI (R-5). Each entry has likelihood, impact, and a concrete mitigation. Two omissions are acceptable for v1 but worth noting: (a) concurrent crash dispatches producing race conditions on branch naming, and (b) agent run time exceeding GitHub Actions job timeout limits. Neither is a blocker for this plan.

---

### 10. Testing strategy coverage
**PASS with gap on log-scan**

Three-tier strategy (BATS unit, `act` integration, real E2E) is appropriate for a composite action. BATS covers validate.sh, build-prompt.sh, and commit.sh. Integration covers branch naming, PR body, and output correctness. E2E covers the full live flow.

**Gap:** The log-scan CI job mentioned in R-3's mitigation is absent from the testing strategy section and from all task done criteria. If secret leakage is rated Critical (as noted in R-3), the log-scan job must appear in the testing strategy and have an owning task.

**Minor gap:** open-pr.sh is not explicitly covered by unit or integration tests in a way that exercises the actual `gh pr create` invocation. The integration test uses a mock agent but does not clarify whether it exercises the real `gh` CLI against GitHub or a mock. This should be clarified.

---

### 11. Success metrics clarity
**PASS**

Four metrics are stated: all tasks done, E2E test passes (with three sub-criteria), no secrets leaked (log-scan in T-7), actionlint + BATS green. All four are measurable at task completion. The metrics are sufficient to declare "SP-1 is done" without ambiguity.

---

### 12. Feasibility given constraints
**PASS**

Composite action avoids Docker build overhead. ubuntu-latest ships `gh`, `git`, and `npm` — no custom runner setup required. BATS is a widely-used shell testing framework with npm-installable setup. The agent seam (file-system dispatch) is straightforward to implement and test. The only open feasibility question is the Claude Code CLI's non-interactive flag — correctly identified as the riskiest assumption and gated in T-1.

---

## Summary

### What passed (10/12)

Checkpoints 1, 2, 3, 4, 5, 6, 9, 11, 12 are solid. Done criteria are specific and binary across all tasks. The riskiest assumption is correctly front-loaded. Task cohesion and dependency documentation are clear. The risk register and success metrics are actionable.

Checkpoint 7 passes with minor gaps (NFR-1 retry, NFR-4 observability per step) that are addressable within existing tasks by adding done criteria.

Checkpoint 10 passes with a noted gap (log-scan test coverage) that should be addressed.

### What must change (required before implementation begins)

1. **Add a task (or extend T-1) to create `ci.yml`** — Checkpoint 8 FAIL. The CI workflow is referenced in done criteria (T-4) but has no owning task. Done criterion: "ci.yml runs actionlint and BATS on all PRs; pipeline is green before T-2 begins."

2. **Add NFR-1 retry logic to T-3's done criteria** — Checkpoint 7 gap. install.sh must retry on transient network failure; this must be a testable, binary criterion in T-3.

3. **Add log-scan coverage to testing strategy and assign it to a task** — Checkpoints 7 and 10 gap. R-3 names a log-scan CI job as Critical mitigation — it needs an owning task and must appear explicitly in the testing strategy section.

4. **Clarify T-7 preconditions** — Checkpoint 5 note. State whether the test repo exists or must be created as part of T-7. If created, add setup to done criteria or split into a T-6.5 setup task.

### What is deferred (acceptable for v1)

- Concurrency/race condition risk on branch naming — document as known limitation.
- Agent job timeout risk — document recommended timeout setting in README.
- Performance metrics (time-to-PR) — not required for v1.
- open-pr.sh mock coverage in integration tests — acceptable if integration tests use the real `gh` CLI against GitHub.

---

## Final Verdict

**CHANGES NEEDED**

The plan is well-structured and largely complete. One hard blocker: `ci.yml` has no owning task despite being referenced in done criteria — this must be resolved before implementation starts. Three additional changes (NFR-1 retry criterion, log-scan task, T-7 preconditions) are required but can be resolved quickly. No architectural concerns; the design is sound and the agent seam approach is the right call.
