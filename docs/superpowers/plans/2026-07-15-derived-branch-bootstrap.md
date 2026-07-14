# Derived Branch Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the vendor-neutral core the verified common ancestor of Isaac/MoveIt, Doosan, OpenArm, and tutorial branches.

**Architecture:** Keep draft PR #1 as the temporary bootstrap base. Add a machine-checkable topology contract there, create one long-lived branch for each concern, and commit a focused `BRANCH.md` to every derived branch. Runtime support remains unclaimed until its own branch-local implementation and acceptance PR exists.

**Tech Stack:** Git branches/worktrees, Bash, existing core test harness, Docker Compose, ROS 2 Jazzy.

## Global Constraints

- Preserve the dirty root `user/damin` worktree; do not reset, clean, stash, or switch it.
- Do not merge or force-push draft PR #1; its head is the temporary branch base.
- Keep `main` vendor-neutral and do not automatically control hardware or transmit CAN messages.
- Branch contracts state one parent, allowed scope, prohibited scope, synchronization rule, and no-hardware verification.

---

### Task 1: Add a topology contract to the core branch

**Files:**
- Create: `docs/branching.md`
- Create: `scripts/verify_branch_topology.bash`
- Modify: `tests/test_static_contract.bash`

**Interfaces:**
- Produces: `bash scripts/verify_branch_topology.bash [base-ref]`.
- Validates: `base -> isaac-moveit`, `base -> doosan-robotics -> doosan-tutorial`, and `base -> open-arm -> openarm-tutorial`.

- [ ] **Step 1: Write the failing static test**

```bash
assert_file docs/branching.md
assert_file scripts/verify_branch_topology.bash
for branch in isaac-moveit doosan-robotics open-arm doosan-tutorial openarm-tutorial; do
  assert_contains docs/branching.md "$branch"
done
```

- [ ] **Step 2: Verify RED**

Run: `bash tests/test_static_contract.bash`
Expected: `missing file: docs/branching.md`.

- [ ] **Step 3: Implement the minimal contract**

`docs/branching.md` defines the sibling branches of `main`, tutorial children, one-way synchronization, and safe worktree commands. The verifier uses `git show-ref --verify --quiet refs/heads/<branch>` and `git merge-base --is-ancestor`; its default base is `main`, and the optional `refactor/core-branch-layout` base supports pre-merge bootstrap validation.

- [ ] **Step 4: Verify GREEN and commit**

Run: `bash tests/test_static_contract.bash`
Expected: `static core contract passed`.

```bash
git add docs/branching.md scripts/verify_branch_topology.bash tests/test_static_contract.bash
git commit -m "docs: add derived branch topology contract"
```

### Task 2: Create and document the five derived branches

**Files:**
- Create on each of `isaac-moveit`, `doosan-robotics`, `open-arm`, `doosan-tutorial`, `openarm-tutorial`: `BRANCH.md`

**Interfaces:**
- Consumes: the Task 1 bootstrap commit.
- Produces: one committed ownership contract per branch.

- [ ] **Step 1: Create refs from the verified bootstrap base**

```bash
base="$(git rev-parse HEAD)"
git branch isaac-moveit "$base"
git branch doosan-robotics "$base"
git branch open-arm "$base"
git branch doosan-tutorial doosan-robotics
git branch openarm-tutorial open-arm
```

- [ ] **Step 2: Add a focused branch contract**

Every `BRANCH.md` has these headings: `Parent and synchronization`, `Owns`, `Does not own`, `Safe start`, `Verification`, and `Hardware safety`. The robot branches own only their vendor runtime; the tutorial branches own only course assets and examples. All use `./run.sh init`, `./run.sh doctor`, and `bash tests/run_all.bash --checks` as a no-hardware baseline.

- [ ] **Step 3: Verify and commit**

Run: `bash scripts/verify_branch_topology.bash refactor/core-branch-layout`
Expected: five `PASS` lines.

Commit each `BRANCH.md` independently with a `docs: initialize ... branch` message.

### Task 3: Verify checkout safety and publish the topology

**Files:** No content changes beyond Tasks 1-2.

- [ ] **Step 1: Verify clean checkouts and core checks**

Create isolated worktrees for `isaac-moveit`, `doosan-robotics`, and `open-arm`; run `bash tests/run_all.bash --checks` in each. Check tutorials are clean.

- [ ] **Step 2: Publish refs without merging**

```bash
git push -u origin isaac-moveit doosan-robotics open-arm doosan-tutorial openarm-tutorial
git fetch origin
```

Verify every matching `refs/remotes/origin/<branch>` exists. Do not change `main`.

### Task 4: Record runtime PR boundaries

**Files:**
- Create on `isaac-moveit`, `doosan-robotics`, `open-arm`: `docs/next-runtime-pr.md`

- [ ] **Step 1: Isaac/MoveIt scope**

Require vendor-neutral robot description input, opt-in profile, generic model acceptance, and no Isaac installation in Docker.

- [ ] **Step 2: Doosan scope**

Require a full upstream SHA, license review, source-patch tests, non-root profile, and manual-only robot/emulator acceptance. Do not use the legacy coupled Dockerfile as a direct base.

- [ ] **Step 3: OpenArm scope**

Require a pinned upstream ROS2 source, SocketCAN/vcan separation, non-transmitting no-hardware tests, and manual enable/control confirmation. Do not infer CAN IDs, limits, or safety state.

- [ ] **Step 4: Commit and re-run branch checks**

Commit one focused document per runtime branch and re-run `bash tests/run_all.bash --checks`.

## Completion Audit

- [ ] Core topology contract passes static checks.
- [ ] All five named branches exist locally and on `origin`.
- [ ] Topology verification passes against the bootstrap base.
- [ ] Every derived branch has a committed ownership contract.
- [ ] Unsupported runtime and hardware capability is explicitly documented as future branch-local work.
- [ ] Draft PR #1 remains unmerged unless separately approved.
