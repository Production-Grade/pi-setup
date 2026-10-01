# The nine packages

Pi ships with four tools: `read`, `write`, `edit` and `bash`. Everything else in
this image is a decision someone made. This file records the nine packages that
are installed, the exact version each is pinned to, what each one adds, why it
earned a place, and what was left out.

Every version below appears in two places that must agree:
[`preset/settings.json`](preset/settings.json) (the `packages` array Pi reads at
startup) and [`preset/Dockerfile.pi`](preset/Dockerfile.pi) (the `pi install`
lines that bake them into the image). If you change one, change the other.

## The set

| Package | Version | The job it does |
|---|---|---|
| `@gotgenes/pi-permission-system` | `29.0.0` | Decides what the process is allowed to run, and shows you the decision |
| `@narumitw/pi-plan-mode` | `0.56.0` | A state where reading is allowed and writing is not |
| `@recynie/pi-goal` | `0.2.1` | Holds the accepted task where a fresh session can read it |
| `pi-lens` | `4.1.3` | Language-server navigation and diagnostics in the terminal |
| `@gotgenes/pi-subagents` | `21.0.3` | Bounded roles instead of one long conversation |
| `@gotgenes/pi-subagents-worktrees` | `0.3.1` | Keeps an implementation worker out of your checkout |
| `pi-diff-review` | `0.1.26` | The live Git patch, inside Pi |
| `pi-continue` | `0.9.3` | Keeps established facts across a compaction |
| `pi-playwright` | `0.1.2` | Lets the model use the app in a real browser, from the terminal |

## How a package earns a place

Four questions, applied to each one before it went in.

1. Does it do a job the base four tools cannot do at all?
2. Does another installed package already do that job?
3. What does installing it let the process reach that it could not reach before?
4. Can you tell, from the screen, whether it is working?

The last one rules out more packages than the first three. A package whose effect
you cannot see is a package you cannot debug, and it will eventually be blamed for
something it did not do.

## What each one adds

### `@gotgenes/pi-permission-system@29.0.0`

**Adds.** A default-deny policy over tools, paths, shell commands, skills and MCP,
with a prompt when something falls outside it. The policy lives in
[`preset/permission-system.json`](preset/permission-system.json) and is copied to
`/opt/pi-home/extensions/pi-permission-system/config.json` in the image.

**Why it earned a place.** Pi asks about a tool call, but it has no idea which
commands are ordinary for your project. The policy in this preset allows the
read-only shell surface (`ls`, `rg`, `grep`, `sed`, `head`, `tail`, `cat`) and the
inspecting half of Git (`status`, `diff`, `log`, `show`, `rev-parse`), allows the
common test runners, and denies the commands you do not want a background decision
made about:

```json
"git push*": "deny",
"git reset*": "deny",
"git clean*": "deny",
"rm *": "deny",
"sudo *": "deny",
"curl *": "deny",
"wget *": "deny"
```

Reads and writes are allowed inside the checkout, `*.env` and `*.env.*` are denied
to the read path, `*/.git/*` is denied to the write path, `external_directory` is
`deny`, and `mcp` is `deny` outright. `permissionReviewLog` is on, `yoloMode` is
off.

**What you see.** When a command falls outside the policy, the prompt names the
tool, the rule that matched, and the full command, and offers four answers: allow
once, allow that shape of command for this session, refuse, or refuse with a
reason. Refusing leaves the session working, and that behaviour is doing as much
for you as the contents of the policy, because in a setup where saying no means
tearing the whole thing down to get anything done, you stop saying no.

**Limit.** It governs Pi's tool calls. It is not an operating-system boundary, and
it cannot constrain code that an extension runs inside the Pi process. That is what
the container is for.

### `@narumitw/pi-plan-mode@0.56.0`

**Adds.** A planning state with its own tool policy, configured in
[`preset/plan-mode.json`](preset/plan-mode.json):

```json
{
  "thinkingLevel": "inherit",
  "defaultPlanTools": ["read", "bash", "grep", "find", "ls", "subagent"],
  "allowedPlanSubagents": ["scout"],
  "safeSubcommands": {
    "git": ["status", "log", "rev-parse", "blame", "show", "diff"]
  }
}
```

**Why it earned a place.** `write` and `edit` are absent from that list, so a call
to either is refused for as long as the state is active. The model's visible tool
list does not change — the extension says so on screen — which means the boundary
does not depend on the model agreeing to respect it, or on how carefully you
worded the prompt. `allowedPlanSubagents` limits delegation during planning to the
read-only `scout` role, so planning cannot subcontract an edit either.

**What you see.** The footer reads `plan active` while it is running and
`plan ready` when a proposal is finished, and a menu offers `Implement here`,
`Start fresh and implement`, `Export plan…`, `Save for later`, `Stay in Plan mode`
or `Discard plan and exit`.

**Limit.** A plan is not evidence about the finished change. It tells you what the
model intends, before you have spent anything on it.

### `@recynie/pi-goal@0.2.1`

**Adds.** An accepted task and its completion evidence, held outside the
conversation, plus a fresh-context verifier that returns a verdict.

**Why it earned a place.** The task contract is the thing every later step is
measured against — the implementation, the review, the check that runs at the end.
Keeping it in the conversation means it decays with the conversation. Keeping it
somewhere a new session can read means a new session can pick up the same
acceptance question without inheriting the argument that produced it.

**Limit.** The verifier is a model reading the workspace. It is a second opinion
with a different starting point, not a deterministic gate. This preset also keeps
a repository check named in the task file, so there is one result that does not
depend on a model's judgement.

### `pi-lens@4.1.3`

**Adds.** Language-server navigation, diagnostics, structural search and a
read-before-edit guard.

**Why it earned a place.** It tells you what the language server thinks, which is
information about the code and occasionally wrong about the code. Both are useful
as long as nothing acts on them automatically. Everything that would act on them
is switched off in [`preset/pi-lens.json`](preset/pi-lens.json):

```json
{
  "format": { "enabled": false },
  "autofix": { "enabled": false },
  "actionableWarnings": {
    "enabled": false,
    "includeLspCodeActions": false,
    "deltaOnly": true,
    "autoFix": { "enabled": false, "maxFixes": 0 }
  },
  "readGuard": { "enabled": true },
  "tests": { "enabled": false },
  "opengrep": { "enabled": false },
  "guard": { "enabled": false },
  "contextInjection": { "enabled": true },
  "tools": { "lazy": true }
}
```

The image also sets `PI_LENS_DISABLE_LSP_INSTALL=1` and
`PI_LENS_DISABLE_TOOL_INSTALL=1`, and bakes in `ripgrep`, `fd` and Pyright, so a
session with no route to the public internet never stalls trying to fetch a tool
mid-task.

**Limit.** A diagnostic is a claim about the code from one tool's point of view.
In a container that deliberately cannot see a project's vendored dependency path,
Pyright will report unresolved imports for code that runs and tests cleanly. Read
it, compare it against the runtime, and move on.

### `@gotgenes/pi-subagents@21.0.3`

**Adds.** Named roles with their own tool lists, permission overrides and turn
budgets. Four are defined in [`preset/agents/`](preset/agents): `worker`,
`critic`, `scout` and `evidence`. Settings are in
[`preset/subagents.json`](preset/subagents.json): one child at a time, twenty
turns by default, two grace turns, and all children aborted on interrupt.

**Why it earned a place.** One conversation that does investigation, implementation
and review becomes a junk drawer, and the review at the end is being performed by
the participant with the strongest reason to like the result. Roles let you say
which part of the work gets a clean context and which tools it is allowed.

The four roles, and the properties that make them different from a prompt asking
politely for the same behaviour:

| Role | `inherit_context` | Write/edit | Runs in background | Turn budget |
|---|---|---|---|---|
| `worker` | `false` | allowed, in a worktree | no | 24 |
| `critic` | `false` | `write: deny`, `edit: deny` | no | 16 |
| `scout` | `false` | `write: deny`, `edit: deny` | yes | 12 |
| `evidence` | `false` | `write: deny`, `edit: deny` | no | 6 |

`critic`, `scout` and `evidence` are also `locked: true`, so the parent session
cannot relax them on the way past.

**Limit.** Children share the container. The isolation here is context and tool
reach, not a second security boundary.

### `@gotgenes/pi-subagents-worktrees@0.3.1`

**Adds.** A disposable Git worktree for named roles.
[`preset/subagents-worktrees.json`](preset/subagents-worktrees.json) applies it to
one:

```json
{ "worktreeAgents": ["worker"] }
```

**Why it earned a place.** An implementation child writing beside your checkout
gives you two sets of uncommitted changes and no clean way to tell them apart. The
worker edits its own worktree, leaves ordinary uncommitted changes, and stops; the
extension saves that work to a generated `pi-agent-*` branch, which the parent
inspects and merges. The permission policy allows exactly that shape of merge —
`git merge pi-agent-*` and `git branch --list pi-agent-*` are allowed, and general
Git write commands are not.

The image sets a non-personal Git identity for this, because the extension cannot
create its rescue commit without one:

```dockerfile
RUN git config --system user.name "Pi Worktree Bot" \
  && git config --system user.email "pi-worktree@local.invalid"
```

**Limit.** It solves where the work lands, not whether the work is right.

### `pi-diff-review@0.1.26`

**Adds.** The live Git patch, hunk by hunk, inside Pi.

**Why it earned a place.** The alternative is reading a summary of the work,
written by the thing that did the work. A file list with line counts and the actual
hunks is a different kind of object: you can see that the policy landed in one
place, that both callers use it, and that the test file is additive.

**Limit.** A review surface is not an acceptance gate. Nothing about it stops you
from approving a patch you skimmed.

### `pi-continue@0.9.3`

**Adds.** A continuation ledger — active task, definition of done, established
facts, open questions, next action — around Pi's native compaction.

**Why it earned a place.** A long session that compacts can carry a test result
forward past the change that invalidated it. Writing down what is established, and
what is still open, gives the post-compaction context something better than a
summary of a summary.

It is configured in [`preset/pi-continue.json`](preset/pi-continue.json) not to
write anything into the project:

```json
{
  "continuationArtifactMode": "off",
  "agentGuideSyncMode": "off",
  "showAfterCompact": false
}
```

**Limit.** This is same-session continuity, not memory. Nothing here persists a
fact from one week into the next, deliberately.

### `pi-playwright@0.1.2`

Pi has no browser. This package is a skill rather than an extension: it wraps
Microsoft's `@playwright/cli`, and the model drives a real headless Chromium with
ordinary commands from the terminal (`open`, `snapshot`, `fill`, `click`,
`screenshot`, `video-start`). Nothing new appears in the model's tool list, and
there is no MCP server to configure.

It earns its place because the tests in a project like this assert on responses,
and nothing else ever looks at the page.
In the video, Qwen signs in to the dispatch console, checks the blocked job shows
its failing checks with the dispatch button disabled, dispatches the healthy job
and reloads it, and records the session as a video. It also notices that the
"scheduled" count at the top of the board never changes after a dispatch, which
none of the tests look at.

What it can reach: the browser runs inside the container, so it can open the app
you start inside the container and nothing on the public internet. Chromium is
installed at build time, under `/opt/ms-playwright`.

Two settings in the image make it work under the default-deny policy:

- the skill's folder is the one allowed exception to `external_directory: deny`,
  because the model has to read the skill's instructions and run its wrapper
  script, and the folder is owned by root so the model still cannot change it;
- `PI_PLAYWRIGHT_ARTIFACTS=.playwright-artifacts` keeps snapshots, screenshots and
  videos inside the project rather than `/tmp`, so the working-directory boundary
  does not need opening for them.

The skill writes into `.playwright-artifacts/` and `.playwright-cli/` in your project;
add both to the project's `.gitignore`.

The browser window size comes from `.playwright/cli.config.json` in the project
(`browser.contextOptions.viewport`), and a recording's size from
`video-start --size=1440x900`.

## The roles, in more detail

Two files carry most of the opinion in this repository.

### `preset/agents/critic.md`

```yaml
---
description: Read-only acceptance and risk critic
tools: read, bash, grep, find, ls
max_turns: 16
locked: true
inherit_context: false
run_in_background: false
permission:
  external_directory: deny
  path_read: allow
  path_write: deny
  write: deny
  edit: deny
  bash:
    "*": ask
    ...
---
```

Three properties are doing the work, and they are worth separating.

`inherit_context: false` means the critic never saw the conversation where the
design was argued for. It reads the task contract and the diff, and forms its own
view of whether they match.

`write: deny` and `edit: deny` mean it cannot change what it is reviewing. A
review process that can edit tends to find something small, fix it in passing, and
hand back a clean report — which reads like a pass and is not one. When editing is
unavailable, the only output available is a description of what is wrong.

`locked: true` means the parent session cannot quietly widen any of that when the
role turns out to be inconvenient.

`path_write: deny` closes the gap that denying two tools leaves open. With only
`write` and `edit` denied, a reviewer can still change a file through bash
(`sed -i`, a redirect, a Python one-liner). The path gate applies to every tool, so
writes to the project are refused whichever tool attempts them, and every bash
command that is not on the allowlist has to ask first. If you set up read-only
roles of your own, use that combination rather than denying the two tools alone.

The instruction the role carries is deliberately narrow:

> Review the approved task contract and the current diff. Do not edit. Inspect the
> implementation and run only non-mutating checks. Name only defects that can
> change acceptance, security, operability, compatibility or maintenance. For every
> finding, cite the file and concrete behavior or missing evidence. Say explicitly
> when no material defect is supported.

The last sentence is there because a model asked to review something will usually
find you a finding. Requiring an explicit "nothing material is supported" gives it
a way to say the true thing.

Below that sits a short list of checks this team cares about:

> - Output escaping: a value from the database, the request or the user reaches
>   HTML only through the framework's escaping (a template, or format_html in
>   Django), SQL only through the ORM or parameters, and a shell only as an argument
>   list. Flag any HTML, SQL or command built by string formatting or concatenation,
>   even when today's data looks harmless.
> - Formatting: new code matches the file's existing indentation and style. Flag
>   ragged or inconsistent indentation.
> - Tests: new tests follow the existing test style, with imports at the top of the
>   module.

Before that list existed, the critic reviewed the dispatch fix and reported no
security risk, in code that built its 409 page from database fields with f-strings.
With the list, it flagged exactly that. Replace these three with the checks your
own team argues about in code review.

### `preset/prompts/review.md`

`/review` is the same posture without spawning a child, for when you want the
current session to look at its own diff with a reviewing stance:

```markdown
---
description: Review the current diff for material defects and missing evidence
---
Review the current Git diff against the task and repository rules. Inspect the
implementation rather than trusting the final explanation. Run the smallest
relevant checks. Report only findings that affect behavior, security,
operability, compatibility or the stated acceptance result. Cite exact files and
evidence. If no material defect is supported, say so plainly. Do not edit.
```

It is weaker than `critic` in exactly one way, and it is the way that matters: the
session running `/review` is the session that wrote the code. Use it as a first
look. Use `critic` when the answer changes what you ship.

The other two prompts are [`verify.md`](preset/prompts/verify.md), which re-runs
the declared acceptance checks plus one targeted check on the riskiest behaviour
that changed and separates what passed from what remains unproved, and
[`handoff.md`](preset/prompts/handoff.md), which writes a session record for the
next engineer from repository evidence rather than from the conversation.

## What is not installed, and why

None of the following are in the default image. Each was inspected on 2026-08-31
against Pi 0.84.4, and each is left out for a stated reason rather than an
oversight. The ones that remain useful are described in
[`preset/OPTIONAL-PROFILES.md`](preset/OPTIONAL-PROFILES.md) as separate profiles
you build deliberately.

| Candidate | Version or pin | Why it is not in the default image |
|---|---|---|
| `pi-web-access` | `0.27.0` | Direct URL fetching plus several search-provider integrations and their secrets. Useful for documentation research, wrong as a standing capability of every repository session. Build a separate research profile with public egress and no source mount the task does not need. |
| `pi-web-search` | `1.3.1` | Small, but its useful routes depend on cloud search accounts. It is not the local-only answer, and it does not belong in a profile that has no reason to reach the network. |
| `pi-mcp-adapter` | `2.31.0` | Peer-compatible with Pi 0.84.4, and an earlier cut of this setup used it with Microsoft's Playwright MCP for browser checks. `pi-playwright` replaced it: the same browser through a CLI the model already knows how to use, with no extra tool schemas in context. No MCP server belongs in *every* session, because each one changes what data and which accounts the process can reach. The default policy sets `"mcp": "deny"`. |
| `pi-browser` | commit `32b5baaf7ca0d6258b1d0841cff9c6c88aafff2b` | A broad Playwright and CDP control surface. The pinned source launches browsers headful and can attach to your everyday browser, including its cookies and storage. `pi-playwright` covers checking your own app inside the container; keep this one as a live-browser profile you choose on purpose. |
| `pi-client` | commit `eb9fc5f47f26b1eb2159f3cacf3644f0d46ca78b` | Genuinely useful for unattended application testing, and the source passed its own 38 tests plus a TypeScript check. Kept out of the default image because acceptance testing should run from a checked-in scenario with a disposable browser profile and a declared origin, not from whatever the session decides to open. |
| `pi-plan-mode` | `0.4.8` | The obsolete package line, targeting pre-Earendil Pi. Excluded so it cannot be installed by name confusion. `@narumitw/pi-plan-mode@0.56.0` is the one in use. |
| memory extensions | — | Persistence is attractive and unproven here. A memory profile has to demonstrate freshness, deletion and conflict handling before it can be trusted to answer a question about code that has since changed. `/handoff`, Pi's own session resume and `pi-continue` cover deliberate continuity. |
| cache prompt rewriters | — | They mutate the system prompt and publish their own performance claims. No independent task-quality result supports adding one. |
| automatic formatting and autofix | — | Available and switched off. The entrypoint runs `pi --no-autoformat --no-autofix`, and Pi Lens's fix paths are disabled in config. A change you did not ask for, arriving inside a diff you are about to review, is a bad trade for a saved keystroke. |

## Notes on the pinning

`preset/Dockerfile.pi` installs the Pi runtime with `--ignore-scripts`, so no npm
lifecycle script from the runtime or from Pyright runs during the image build. Of
the nine packages, eight publish no install lifecycle at all; `pi-lens` has a
`prepare` lifecycle in its source repository, and the artefact that lands in the
image was inspected there. `pi-playwright`'s Chromium is installed by an explicit
`playwright install --with-deps chromium` step in the Dockerfile, not by a
lifecycle script.

The version numbers in this file are the ones that were exercised. They are not a
claim that later versions are worse — only that these are the ones whose behaviour
is described here.
