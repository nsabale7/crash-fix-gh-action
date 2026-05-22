# Roadmap — Crash Auto-Fix GitHub Action

This document outlines future enhancements and phases for the Crash Auto-Fix GitHub Action beyond v1.

---

## Vision

**v1 Goal:** Ship a reusable, pluggable Action that invokes Claude to fix crashes, demonstrate the platform, and leave hooks for future agents.

**v2+ Vision:** Expand to multi-agent support, integrate with crash analytics platforms, add intelligence to crash deduplication and agent selection, and build a community of custom agents.

---

## Phase Breakdown

### Phase 1: Foundation (v1, COMPLETE)
- ✅ Composite action with 9 workflow steps
- ✅ Claude agent fully wired (install.sh, run.sh)
- ✅ Aider, Codex, Gemini scaffolded (stubs)
- ✅ Prompt builder (action/build-prompt.sh)
- ✅ Workflow templates (workflow_dispatch, repository_dispatch)
- ✅ Security audit
- ✅ Architecture & design docs

### Phase 2: Multi-Agent Support (v1.1 - v2)

#### Task: Wire Aider Agent
- **What:** Implement action/agents/aider/{install.sh,run.sh}
- **How:** 
  - install.sh: `pip install aider-chat`
  - run.sh: Read prompt, invoke `aider --no-auto-commits --no-git < prompt > output`
- **Why:** Aider is lightweight, open-source, good alternative for cost-conscious users
- **Effort:** Low (4-8 hours)
- **Blocker:** Aider's CLI interface may differ from Claude; test prompt compatibility

#### Task: Wire Codex Agent
- **What:** Implement action/agents/codex/{install.sh,run.sh}
- **How:**
  - install.sh: `pip install openai`
  - run.sh: Python wrapper calling OpenAI Codex API (gpt-3.5-turbo or gpt-4)
- **Why:** Codex (GPT models) may be cheaper or faster for some crash types
- **Effort:** Low (4-8 hours)
- **Blocker:** Codex API deprecation (monitor OpenAI announcements); gpt-3.5-turbo is current path

#### Task: Wire Gemini Agent
- **What:** Implement action/agents/gemini/{install.sh,run.sh}
- **How:**
  - install.sh: `pip install google-generativeai`
  - run.sh: Python wrapper calling Google Generative AI (Gemini 1.5 Pro)
- **Why:** Gemini offers competitive pricing, strong code understanding
- **Effort:** Low (4-8 hours)
- **Blocker:** API rate limits; test batch processing scenarios

#### Task: Agent Selection Heuristics
- **What:** Auto-select agent based on crash type and cost
- **How:**
  - Parse crash signature for language hints (NullPointerException → Java, etc.)
  - Use default (Claude) for complex crashes; fall back to faster/cheaper agent for simple ones
  - Allow explicit override in workflow input
- **Why:** Optimize cost and latency across crash types
- **Effort:** Medium (16-24 hours)
- **Blocker:** Requires metrics on fix quality per agent per language

---

### Phase 3: Crash Deduplication & Deferred PR Update (v2)

#### Task: Detect Duplicate Crashes
- **What:** Before opening PR, check if crash_id has existing open/recent PR
- **How:**
  - Query GitHub API for PRs matching crash_id pattern (title contains "[crash-fix] <signature>")
  - If PR exists and recent (< 24h): comment on existing PR instead of creating new one
  - Include agent_output as comment for comparison
- **Why:** Avoid spam; combine fixes for same crash from multiple runs
- **Effort:** Medium (12-16 hours)
- **Blocker:** Need clean way to extract crash_id from PR title/body for matching

#### Task: Iterative PR Update
- **What:** If duplicate detected, update existing PR with new agent output (comment + optional force-push)
- **How:**
  - Option 1 (safer): Comment on PR with new agent output; let human decide to merge old fix or force-push new fix
  - Option 2 (aggressive): Force-push new commit if new fix is higher quality (requires metrics/heuristic)
- **Why:** Incorporate latest agent insights without creating multiple PRs
- **Effort:** Medium (12-16 hours)
- **Blocker:** Need user feedback on acceptable force-push heuristic

---

### Phase 4: Language-Specific Prompts (v2)

#### Task: Multi-Language Prompt Builder
- **What:** Detect source language (Java, Python, JavaScript, Go, Rust, etc.) and use language-specific prompt
- **How:**
  - Scan stack trace for file extensions (.java, .py, .js, etc.)
  - Load language-specific prompt template from action/prompts/<lang>.md
  - Include language-specific debugging tips and common patterns
- **Why:** Better prompts lead to better fixes; language-specific context is valuable
- **Effort:** Medium (16-24 hours)
- **Blocker:** Need prompt templates for each supported language; requires testing per language

#### Task: Supported Languages
- Java (v2.0)
- Python (v2.0)
- JavaScript / TypeScript (v2.0)
- Go (v2.1)
- Rust (v2.1)
- C++ (v2.2)
- Swift (v2.2)

---

### Phase 5: Crash Analytics Platform Integration (v2)

#### Task: Crashlytics Integration
- **What:** Pre-built workflow to trigger crash-fix from Firebase Crashlytics webhook
- **How:**
  - Crashlytics sends crash notification to Cloud Function or GitHub webhook
  - Cloud Function formats crash payload per schema and calls `gh workflow dispatch`
  - action.yml receives typed inputs, runs fix
- **Why:** Crashes are detected automatically; no manual action needed
- **Effort:** High (32+ hours)
- **Blocker:** Firebase/Google Cloud setup complexity; customer auth scope

#### Task: Sentry Integration
- **What:** Pre-built workflow for Sentry crash events
- **How:**
  - Sentry webhook → GitHub repository_dispatch
  - Workflow unpacks Sentry event payload into action inputs
- **Why:** Similar to Crashlytics; Sentry is popular in web/backend
- **Effort:** High (32+ hours)
- **Blocker:** Sentry event schema compatibility; OAuth scopes

#### Task: Generic Webhook Receiver
- **What:** Lightweight Cloud Function or GitHub App that translates any crash schema to action input
- **How:**
  - Accept POST with crash fields (flexible schema)
  - Map to crash-payload-schema.json
  - Call repository_dispatch
- **Why:** Future-proof for any crash source; reduces per-platform work
- **Effort:** High (40+ hours)
- **Blocker:** Schema inference complexity; security (no open webhook)

---

### Phase 6: Observability & Feedback (v2.1)

#### Task: Fix Quality Metrics
- **What:** Measure agent performance (fix acceptance rate, time-to-merge, etc.)
- **How:**
  - Track PR creation → merge timestamp
  - Count PRs merged vs. abandoned
  - Tag PRs by agent, language, crash type
  - Aggregate in metrics dashboard
- **Why:** Data-driven agent selection; identify which agents perform well on which crash types
- **Effort:** High (32+ hours)
- **Blocker:** Requires analytics infrastructure (BigQuery, Datadog, etc.)

#### Task: Feedback Collection in PR
- **What:** PR comment template asking engineer to rate fix quality (1-5 stars, comments)
- **How:**
  - Include comment template in PR body
  - Scrape feedback via GitHub API or scheduled job
  - Send to analytics backend
- **Why:** Build dataset for future ML model training
- **Effort:** Medium (16-24 hours)
- **Blocker:** Privacy: ensure feedback doesn't contain sensitive info; anonymize if needed

#### Task: Agent Performance Dashboard
- **What:** Internal dashboard showing fix rates, average cost, latency per agent/language
- **How:**
  - Query BigQuery or Datadog for metrics
  - Display trends over time
  - Alert if agent success rate drops
- **Why:** Monitor health; catch regressions early
- **Effort:** High (32+ hours)
- **Blocker:** Requires dashboarding tool (Looker, Grafana, etc.)

---

### Phase 7: Advanced Features (v2.1+)

#### Task: Cost Guardrails
- **What:** Limit total spend per repo / per month
- **How:**
  - Track API calls per agent (Claude tokens, GPT tokens, etc.)
  - Abort workflow if monthly budget exceeded
  - Alert when approaching limit
- **Why:** Prevent runaway costs from high-volume crash events
- **Effort:** Medium (16-24 hours)
- **Blocker:** Need to track costs per agent; update agent run.sh to log token usage

#### Task: Retry Logic with Exponential Backoff
- **What:** If agent API call fails, retry up to N times with exponential backoff
- **How:**
  - Wrap agent invocation in retry loop (set MAX_RETRIES=3)
  - Sleep with backoff: 2s, 4s, 8s between attempts
  - On final failure, create PR with "investigation failed" note
- **Why:** Transient API errors (rate limits, timeouts) should not kill the workflow
- **Effort:** Low (8-12 hours)
- **Blocker:** None identified

#### Task: Custom Prompts per Repo
- **What:** Allow repos to override default prompt template
- **How:**
  - Check for action/custom-prompts/<language>.md in target repo
  - If found, use instead of default
  - Fallback to default if not found
- **Why:** Teams may want repo-specific context (known anti-patterns, style guide, etc.)
- **Effort:** Low (8-12 hours)
- **Blocker:** None identified

#### Task: Crash Deduplication at Analytics Platform Level
- **What:** Detect if two crash_id values are duplicates (same root cause, different stack traces)
- **How:**
  - Use clustering algorithm (similarity hashing, stack trace NLP, etc.)
  - Only trigger crash-fix for first occurrence of each unique root cause
  - Mark future occurrences as "duplicate of PR #XYZ"
- **Why:** Avoid redundant fixes for same crash with minor variations
- **Effort:** Very High (48+ hours)
- **Blocker:** ML model required; need ground truth data

---

### Phase 8: Community & Extensibility (v3+)

#### Task: Community Agent Registry
- **What:** Publish catalog of community-contributed agents (public repos with agent scripts)
- **How:**
  - GitHub org/topic tagging (topic: crash-fix-agent)
  - Registry website listing published agents
  - One-command install: `action-agent install org/custom-agent-repo`
- **Why:** Enable ecosystem around action; reduce custom development
- **Effort:** Very High (56+ hours)
- **Blocker:** Need governance model (code review, license compatibility)

#### Task: Prompt Template Library
- **What:** Curated library of prompt templates for different crash types / languages
- **How:**
  - GitHub organization with templates repo
  - PR process for community contributions
  - Docs on testing/validating prompts
- **Why:** Share best practices across teams; improve fix quality
- **Effort:** High (32+ hours)
- **Blocker:** Need example prompts; community adoption

#### Task: Agent Development Toolkit
- **What:** CLI tool + docs for building and testing agents locally
- **How:**
  - `crash-fix-dev-kit init <agent-name>` → scaffold install.sh + run.sh templates
  - `crash-fix-dev-kit test <prompt-file>` → test agent against sample prompts
  - `crash-fix-dev-kit lint` → validate agent script syntax
- **Why:** Lower friction for agent contributions
- **Effort:** High (40+ hours)
- **Blocker:** None identified

---

## Non-Functional Improvements

### Performance Optimization
- [ ] Cache dependencies (npm, pip) to reduce install time
- [ ] Parallel agent testing (run multiple agents in parallel, return fastest result)
- [ ] Incremental prompt building (reuse previous stack trace analysis)

### Reliability Improvements
- [ ] Graceful degradation if stack trace parsing fails (still generate prompt without file context)
- [ ] Better error messages (e.g., "API key invalid" vs. generic "agent failed")
- [ ] Automated rollback if PR merge breaks CI

### Maintainability Improvements
- [ ] Type system for crash payload (JSON Schema → OpenAPI spec)
- [ ] Automated docs generation (action.yml → README)
- [ ] Test suite expansion (unit, integration, E2E tests for each phase)

---

## Research & Experimentation

### Multi-Agent Consensus
- **Idea:** Invoke multiple agents in parallel, merge their outputs (consensus or voting)
- **Research:** Does consensus improve fix quality? What's the cost vs. single-agent?
- **Timeline:** v3+

### Fine-Tuned Models
- **Idea:** Train organization-specific model on historical crash fixes
- **Research:** Can fine-tuning improve fix quality for common crash patterns?
- **Timeline:** v3+ (requires ML ops infrastructure)

### Crash Clustering
- **Idea:** Group similar crashes and prioritize fixing representative examples
- **Research:** Can we reduce fix count via clustering? How do we measure cluster quality?
- **Timeline:** v2.1+

### Agent Cost Optimization
- **Idea:** Use cheaper models (GPT-3.5) for simple crashes, expensive models (GPT-4, Claude) only for complex ones
- **Research:** Can we predict crash complexity? How do we measure fix quality across model tiers?
- **Timeline:** v2+

---

## Release Cadence

- **v1.0:** Foundation (current)
  - Claude agent wired
  - Aider/Codex/Gemini scaffolded
  - Workflow templates
  - Security audit
  - Architecture docs

- **v1.1:** Multi-agent support
  - Aider agent implemented
  - Initial cost metrics

- **v2.0:** Full multi-agent platform
  - Codex + Gemini agents
  - Crash deduplication
  - Language-specific prompts
  - Sentry integration

- **v2.1:** Observability
  - Feedback collection
  - Agent performance dashboard
  - Cost guardrails

- **v3.0:** Community platform
  - Agent registry
  - Prompt template library
  - Developer toolkit

---

## Success Metrics

### Technical Metrics
- **Agent success rate:** % of triggered fixes that result in merged PRs (target: > 60%)
- **Fix quality:** % of PRs marked "high quality" in feedback (target: > 80%)
- **Cost per fix:** Avg token cost per successful fix (target: < $0.10)
- **Latency:** Time from crash detection to PR creation (target: < 2 min)

### Adoption Metrics
- **Active repos:** Number of GitHub repos using the action (target: 50+ by v2)
- **Agents contributed:** Community agents published (target: 10+ by v3)
- **Prompts shared:** Community prompt templates (target: 20+ by v3)

### Business Metrics
- **Engineering time saved:** Hours of manual crash triage per month (target: 100+ by v2)
- **Time-to-fix:** Median time crash detection → PR merged (target: < 1 hour)
- **Regression rate:** % of merged PRs that introduce new bugs (target: < 5%)

---

## Known Limitations & Future Work

### v1 Limitations
- Single agent per run (future: multi-agent consensus)
- No deduplication (future: crash ID matching)
- Generic prompts (future: language-specific)
- No platform integrations (future: Crashlytics, Sentry, Firebase)
- No feedback collection (future: fix quality metrics)

### Deferred Risks
- Token-counting for cost tracking (deferred to v2)
- Cross-repo PR creation (deferred to v2)
- Crash severity scoring (deferred to v2)

---

## Contributing to the Roadmap

**Want to contribute?** Pick a task from the roadmap above and open an issue or PR. Follow the pattern:

1. Pick a phase and task
2. Fork the repo
3. Create a branch: `feature/<task-name>`
4. Implement the feature
5. Add tests
6. Update docs (README, ARCHITECTURE.md, etc.)
7. Open PR with link to this roadmap

See [CONTRIBUTING.md](./CONTRIBUTING.md) for details (future: will be created in Phase 2).

---

## Questions & Feedback

- **Q:** Can I use this action for non-crash issues (bugs, feature requests)?
- **A:** Not yet. v1 is specifically designed for fatal crashes. v2+ may expand to general code issues.

- **Q:** Can I run the action on self-hosted runners?
- **A:** Possibly, but not officially supported in v1. Action assumes `ubuntu-latest` with Node 20+ and Python 3.x.

- **Q:** How do I add a new agent?
- **A:** See [README.md](./README.md) "Adding a new agent" section. v1 agents are scaffolded; just implement `install.sh` and `run.sh`.

- **Q:** Does the action support private repos?
- **A:** Yes, if the workflow has access to the repo (same-org workflows automatically do). Cross-org workflows need a custom PAT.

---

**Last Updated:** May 2026
**Maintained By:** [Insert team]
**Feedback:** Open an issue on this repo or email [contact]
