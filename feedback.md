# SP-1 Crash Auto-Fix GitHub Action — Plan Review

**Reviewer:** gh-rev
**Date:** 2026-05-19
**Verdict:** CHANGES NEEDED

## Checklist

### 1. Clear done criteria for each task
**Status:** PASS with caveats

**Narrative:** All seven tasks have explicit "Done criteria" sections that are testable and observable. However, there is a critical gap: the riskiest assumption (Claude Code CLI non-interactive support) is identified in the narrative but NOT explicitly included in T-1's done criteria. T-1 says validate this "by reading the CLI docs" and "run a smoke test in a local Docker container before writing T-3 code," but the actual done criteria only mentions `action.yml` validation and directory skeleton. **ACTION REQUIRED:** Add to T-1 done criteria: "Smoke test confirms Claude Code CLI accepts `--print` flag or equivalent on headless runner; test run produces non-empty output without interactive prompt."

Similarly, T-3 assumes `claude --print <  > ` works, but the done criteria doesn't mandate testing this exact invocation. **ACTION REQUIRED:** Add to T-3 done criteria: "Successful non-TTY run verified using `act` with --print flag."

---

### 2. Riskiest assumption in Task 1
**Status:** PASS

**Narrative:** The plan explicitly identifies the riskiest assumption: "Claude Code CLI non-interactive mode — the entire T-3 implementation depends on the CLI supporting a headless, non-TTY invocation." This is correct; if the CLI requires TTY or interactive confirmation, T-3 code becomes invalid. The mitigation is stated: validate before T-3 begins. However, see issue #1 above — this validation is not reflected in the done criteria for T-1.

---

### 3. Cohesion of tasks
**Status:** PASS

**Narrative:** Tasks flow logically: scaffold (T-1) ? validate/prompt (T-2) ? agent installs/runs (T-3/T-4) ? branch/commit/PR (T-5/T-6) ? E2E test (T-7). Each task adds a layer of functionality. No orphaned or misaligned tasks.

---

### 4. Coupling and dependencies
**Status:** PASS

**Narrative:** Dependencies are clearly documented in a DAG. T-1 is the entry point; T-2 depends on T-1; T-3 and T-4 depend on T-1 and (for T-3) T-2; T-5 waits for T-3 and T-4; T-6 waits for T-5; T-7 waits for T-6. The plan correctly notes that T-4 stubs are independent and do not block the Claude path. No circular dependencies or missing links detected.

---

### 5. Session-completable tasks
**Status:** PASS with note

**Narrative:** Each task explicitly scopes to =4 hours, which is reasonable. However, T-1 includes reading docs + running a smoke test + creating directory structure — this could be tight depending on CLI documentation depth. T-7 (E2E test with live ANTHROPIC_API_KEY) is described as out-of-scope for the CI loop, which is wise; it's a manual release gate. No task appears unreasonably long or dependent on unpredictable events.

---

### 6. Vague or underspecified task descriptions
**Status:** PASS with minor caveats

**Narrative:** Most tasks are well-specified. Two minor gaps:

- **T-2 prompt builder:** The plan says "structured markdown prompt" but does not show a template or example. What is the exact format? How are optional fields (stack-trace, device-info, etc.) formatted if absent? Recommend: add a template snippet or reference to `action/pr-template.md` structure in the done criteria.

- **T-5 branch naming:** Branch name format `crash-fix/<signature>-<run-id>` is clear, but how is `<run-id>` generated? From ``? From a hash of the crash signature? Recommend: specify the run-id source explicitly.

- **T-6 PR body:** The plan references `action/pr-template.md` and says it includes all required fields, but the template itself is not shown in the design. Recommend: add or reference the template in the design.

Overall, tasks are clear enough to begin work; these are refinements, not blockers.

---

### 7. Alignment with requirements.md
**Status:** PASS

**Narrative:** Spot-check of major functional requirements:
- FR-1 (crash payload ingestion): ? T-1 (action.yml inputs) + T-2 (validate.sh)
- FR-2 (branch creation): ? T-5 (branch.sh)
- FR-3 (Claude agent invocation): ? T-3 (claude/install.sh + run.sh)
- FR-4 (PR creation): ? T-6 (open-pr.sh)
- FR-5 (multi-agent stubs): ? T-4 (aider/codex/gemini stubs)
- FR-6 (empty-diff failure): ? T-6 (commit.sh checks git diff --exit-code)
- FR-7 (PR content): ? T-6 (pr-template.md)
- FR-8 (no direct default-branch pushes): ? Structural guarantee via composite action and `gh pr create`

NFR-1 (reliability, retries): ? Mentioned in design but not explicit in T-1 done criteria. Recommend: add "install.sh retries transient network failures at least once."

NFR-2 (secret handling): ? T-2/T-3 must not log `AGENT_API_KEY`; Risk R-3 acknowledges this. Recommend: add specific log-scan CI check to the testing strategy.

NFR-3 (extensibility): ? T-4 demonstrates this; adding a new agent requires only T-4-style stubs.

NFR-4 (observability): ? Each task uses GitHub Actions step summary or logging; T-7 verifies no secrets leak.

**No alignment gaps detected.**

---

### 8. Alignment with design.md
**Status:** PASS

**Narrative:** The design provides a detailed architecture, data flow, agent seam contract, and risk register. The plan tasks map to design components:
- T-1 scaffold: `action.yml`, `action/crash-payload-schema.json`, directory structure ?
- T-2 validate/prompt: `validate.sh`, `build-prompt.sh` ?
- T-3/T-4 agents: `action/agents/claude/*`, stubs ?
- T-5/T-6 branch/PR: `branch.sh`, `commit.sh`, `open-pr.sh`, `pr-template.md` ?
- T-7 E2E: Covered by integration/E2E test strategy ?

The agent seam contract (environment vars, exit codes, install.sh semantics) is documented in the design and referenced in T-3/T-4. One gap: the design says agent exit code `1` means "ran but produced no changes" (pre-empts commit.sh), but the plan does not explicitly state whether T-3 run.sh must return exit code 1 on no changes or if commit.sh is solely responsible. Recommend: clarify in T-3 done criteria or T-5 seam contract.

**One alignment gap:** Design mentions T-7 includes a "log-scan CI job" to grep for key prefixes, but the plan does not list this as a deliverable or task. Is this part of the `ci.yml` setup? Recommend: clarify ownership.

---

### 9. Risk register completeness
**Status:** PASS

**Narrative:** Design includes a 5-item risk register:
- R-1: CLI version drift (mitigation: pin version)
- R-2: Agent produces breaking diff (mitigation: human review before merge)
- R-3: API key leaks into logs (mitigation: GitHub Actions masking + log-scan CI)
- R-4: Stack trace input size (mitigation: truncate to 50 KB)
- R-5: gh CLI missing/outdated (mitigation: version assertion)

All risks are reasonable for a v1 GitHub Action. R-2 is acknowledged as out-of-scope (consumer repo CI is the safety net), which is pragmatic.

**One gap:** The plan does not mention what happens if the target repo's branch protection rules prevent pushing a new branch, or if PR creation fails due to permission or rule violations. These should be documented as expected failure modes (FR-8 guarantees this is not a bug) and reflected in task done criteria (e.g., "branch.sh fails gracefully if branch already exists; open-pr.sh fails gracefully if gh pr create fails").

**Additional consideration:** The plan does not address what happens if the base-branch is deleted or renamed between branch creation (T-5) and PR creation (T-6). Unlikely but possible; out of scope for v1, but worth noting.

---

### 10. Testing strategy coverage
**Status:** PASS

**Narrative:** The design specifies three tiers:
1. **Unit tests (BATS):** Scripts tested in isolation with mocks. Covers missing fields, empty diff, happy path.
2. **Integration tests (act):** Full composite action locally against a throwaway test repo. Verifies branch name, PR body, outputs, no base-branch push.
3. **E2E tests (real workflow_dispatch):** Against a dedicated test repo with real ANTHROPIC_API_KEY. Manual release gate.

This is comprehensive and appropriate for a GitHub Action. The plan correctly defers E2E to a manual gate due to cost/latency.

**Gap:** The plan does not specify BATS coverage percentage or which scripts are tested. Recommend: add to CI config (ci.yml) or T-1 done criteria that unit test coverage is =80% for each script.

**Additional:** T-7 mentions "log-scan CI job" but does not detail what patterns are grepped. Recommend: define list of secret prefixes to detect (e.g., `sk-ant-`, `ghp_`, etc.) and add to ci.yml or T-7 done criteria.

---

### 11. Success metrics clarity
**Status:** PASS

**Narrative:** Plan defines clear success metrics:
- All tasks T-1 through T-7 marked done ?
- E2E test passes: PR opened, branch named correctly, no push to main ?
- No secrets leaked (verified by log-scan in T-7) ?
- actionlint and BATS tests green on final commit ?

These are measurable and objective. No ambiguity.

---

### 12. Feasibility given constraints
**Status:** PASS with considerations

**Narrative:** Constraints are:
- Each task =4 hours: ? Reasonable scopes
- No Docker images required for v1: ? Composite action + runtime install
- Agent stubs do not block T-5/T-6/T-7: ? Independence documented
- All work targets ubuntu-latest: ? Specified

**Feasibility assessment:** The plan is feasible IF the riskiest assumption (Claude Code CLI non-interactive mode) is validated in T-1. If that validation fails, T-3 needs a major redesign (e.g., using the Claude API instead of CLI). This is a binary gate; mitigated by the plan's explicit call-out of the risk.

**Time estimate check:** T-1 through T-4 (scaffold + validators + agent stubs) appear to be 1–2 days. T-5 through T-6 (branch/commit/PR logic) are 1 day. T-7 (E2E test) is 1 day. Rough total: 4–5 working days, which fits a single sprint.

---

## Summary

### What Passed

- **Task structure and dependencies:** Clear, logical flow with no circular deps.
- **Requirements alignment:** All 8 functional and 4 non-functional requirements have corresponding tasks.
- **Design alignment:** Architecture, data flow, and agent seam contract are well-specified.
- **Risk identification:** Riskiest assumption called out; risk register addresses plausible failure modes.
- **Testing strategy:** Three-tier approach (unit/integration/E2E) is appropriate.
- **Feasibility:** Realistic scope and session times given constraints.

### What Must Change

1. **T-1 done criteria MUST explicitly validate Claude Code CLI non-interactive mode.** Current done criteria does not include smoke test; this is the gate for T-3. Add: "Smoke test run in headless sandbox confirms CLI accepts non-interactive input/output (e.g., --print flag or stdin/stdout) without TTY requirement."

2. **T-3 done criteria MUST verify the exact invocation pattern works.** Add: "BATS test confirms `claude --print < \ > \` succeeds in non-TTY environment (simulated via act)."

3. **Clarify T-5/T-6 failure modes.** Add to done criteria: "Branch.sh fails gracefully if branch already exists (exit 1 with clear message); open-pr.sh fails gracefully if gh pr create fails (exit 1 with error message); in both cases, no orphaned branches or partial PRs are left behind."

4. **Define prompt template format and handling of optional fields.** T-2 done criteria should specify: "Prompt file includes all provided fields in Markdown format; optional fields (stack-trace, device-info, etc.) are omitted if not provided; prompt is human-readable and instructs the agent to limit edits to crash-related files."

5. **Specify run-id generation.** T-5 should clarify: "Branch name run-id component is derived from \ or a deterministic hash of signature + timestamp (specify choice)."

6. **Add secret masking and log-scan to CI.** Update ci.yml specification or T-1 done criteria to include: "GitHub Actions secret-masking step before agent run; post-run log-scan greps for API key patterns (sk-ant-, ghp_, etc.) and fails job if found."

### What Is Deferred

- E2E test (T-7) with real ANTHROPIC_API_KEY is a manual gate, not automated CI. ? Correct for v1.
- R-2 (agent produces breaking diff) is mitigated by human review on consumer repo. ? Appropriate out-of-scope deferral.
- T-1 smoke test may use local Docker; `act` setup is separate. ? Reasonable separation of concerns.

---

## Final Verdict

**CHANGES NEEDED**

The plan is well-structured and feasible, but has a critical gap: the riskiest assumption (CLI non-interactive mode) is identified but not validated in the done criteria. Additionally, several task specifications need clarification on failure handling, optional field treatment, and secret masking. These are not blockers but must be resolved before execution begins. Recommend:

1. Update T-1, T-3, and T-5 done criteria per above.
2. Add secret masking and log-scan CI check to T-1 or ci.yml spec.
3. Add prompt template example or reference.
4. Clarify branch run-id generation.

Once these clarifications are made, the plan is ready to execute.
