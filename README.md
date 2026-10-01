# Production Grade Pi setup

The Pi setup from the Production Grade video *My Pi Coding Agent Setup for Real Work*:
nine pinned packages that give Pi a baseline for working on code that matters, running
in a container that can reach one checkout and a model route.

Pi gives the model four tools, `read`, `write`, `edit` and `bash`, and gets out of the
way. That means the decisions a bigger coding tool makes for you, about what the agent
can touch, how it plans, and how its work gets checked, are yours to make. This
repository is one set of answers to those questions. It is a starting point you are
expected to change, not a finished opinion.

## What is included

- Pi `0.84.4`, pinned in a Docker image that runs as an unprivileged user and mounts
  only the project you launch it from. No SSH keys, no Docker socket, no browser
  profile, no other repositories.
- Nine packages, each pinned and documented in [`PACKAGES.md`](PACKAGES.md) with what
  it adds and why it is there:

  | Package | Version | What it gives you |
  |---|---|---|
  | `@narumitw/pi-plan-mode` | `0.56.0` | Reading allowed, writing blocked, until you approve a plan |
  | `pi-lens` | `4.1.3` | Language-server errors on every edit, reported straight to the model |
  | `@gotgenes/pi-permission-system` | `29.0.0` | A command policy: safe commands run, anything else stops and asks |
  | `pi-diff-review` | `0.1.26` | The live Git patch, reviewed inside Pi |
  | `@recynie/pi-goal` | `0.2.1` | Keeps working until the accepted behaviour is met, then a fresh verifier checks it |
  | `@gotgenes/pi-subagents` | `21.0.3` | Separate agents with their own context and permissions, such as a read-only critic |
  | `@gotgenes/pi-subagents-worktrees` | `0.3.1` | Each worker gets its own Git worktree, so your checkout does not move |
  | `pi-continue` | `0.9.3` | Compaction that keeps the rules of the job, and a `/handoff` command |
  | `pi-playwright` | `0.1.2` | A real headless browser the model drives from the terminal |

- Four roles in [`preset/agents/`](preset/agents): `worker`, `critic`, `scout` and
  `evidence`. The critic is read-only and carries a short list of review checks you
  should replace with your own.
- Three prompts in [`preset/prompts/`](preset/prompts): `/review`, `/verify` and
  `/handoff`.
- A default-deny command policy in
  [`preset/permission-system.json`](preset/permission-system.json).
- Model routes for local Qwen 3.8 through Ollama, local DeepSeek V4 Flash, and GLM-5.3
  through Z.AI, in [`preset/models.json`](preset/models.json).
- Profiles that are deliberately not installed, for web research, live-browser control
  and MCP, in [`preset/OPTIONAL-PROFILES.md`](preset/OPTIONAL-PROFILES.md).

## Set up once

```bash
./setup.sh
```

That builds the pinned image, creates the session-state volume and installs a small
`pi` launcher in `~/.local/bin`. After that, work from the repository you want to
change:

```bash
cd /path/to/project
pi
```

The launcher mounts the current directory at `/workspace`, attaches your terminal to
Pi, and keeps session files in a named Docker volume. Your source and Git history
stay in the host checkout.

GLM-5.3 through Z.AI is the default route; export `ZAI_API_KEY` in the shell before
launch. Another packaged route can be selected with `PG_PI_PROVIDER` and
`PG_PI_MODEL` without editing the launcher. Do not put the Z.AI key in
`models.json`, a Dockerfile or a shell script.

For a local route, prepare the internal model relay first:

```bash
ollama create pg-qwen3.8-27b-100k -f preset/Qwen.100k.Modelfile
./preset/prepare-network.sh --qwen
# or
./preset/prepare-network.sh --ds4
```

`prepare-network.sh` creates an internal Docker network and a relay that exposes
only the two local model ports, then checks that the named route answers and that
the network cannot reach the public internet. It refuses to finish if it can.

The launcher is equivalent to these invocations:

```bash
# local Qwen through the relay
docker run --rm -it \
  --network pg-pi-models \
  -v "$PWD:/workspace" \
  productiongrade-pi:0.84.4 \
  --provider ollama-local --model pg-qwen3.8-27b-100k:latest

# GLM-5.3 through Z.AI
docker run --rm -it \
  --network bridge \
  -e ZAI_API_KEY \
  -v "$PWD:/workspace" \
  productiongrade-pi:0.84.4 \
  --provider zai --model glm-5.3
```

The local Qwen route above uses a 102,400-token context window, shown as 100K in
the video. A 32 GB unified-memory machine can run that configuration if the rest of
the system stays lean, but it is a tight envelope; 48 GB leaves practical room for
the model, the context, your development tools and the application under test.

## What the video walks through

The video uses one real bug in a Django dispatch console: the console would send a
crew to a site even when one of the job's safety checks had failed. Every package does
its job on that one fix, on local Qwen 3.8 at an 8-bit quant through Ollama.

1. **The container.** From a shell inside it: not root, only the project folder, no SSH
   keys or Docker socket, and no route to the internet.
2. **Plan Mode.** Asked to change the code straight away, the model is refused and
   comes back with a plan first. The plan settles that an advisory check must not block
   a dispatch.
3. **Lens.** It catches an unterminated string and an indentation mistake on the turn
   each is made, and when its own import errors are false positives, the model checks
   with Django before acting on them.
4. **Permission System.** The project's tests run once allowed; `pip install pytest`
   stops and asks, and the refusal reason goes back to the model.
5. **Diff Review.** The real patch, from the policy function through to the page,
   before anything is committed.
6. **Goal.** The model keeps going until the accepted behaviour is met, then a fresh
   verifier with none of the conversation checks all six behaviours.
7. **Subagents.** A read-only critic with team-specific checks finds the 409 page built
   from database fields with no escaping, which the tests and Goal had passed. Its own
   edit is refused, so it reports instead, and the main agent fixes it.
8. **Worktrees.** A worker writes a test on its own branch, and its two problems both
   come down to what was and was not committed.
9. **Continue.** Compaction keeps a ledger of the task, what counts as done and what is
   forbidden, with where each came from; `/handoff` records what is done, the exact
   test command and result, and what is still open.
10. **pi-playwright.** The model checks the fix in Chromium the way a dispatcher would,
    and notices the board's scheduled count never changes after a dispatch.

The hardware in the video is an M5 Max with 128 GB. The same setup runs on a 32 GB
machine, and pointing it at a cloud model gets better results on far less.

## Make it your own

- **Change the permission policy for your stack.** The allowlist in
  `preset/permission-system.json` knows common read-only commands and the usual test
  runners. Add your build and test commands, and keep `"*": "ask"` for the rest.
- **Give the critic your team's checks.** The three in `preset/agents/critic.md` are
  examples. Replace them with what your reviewers actually push back on.
- **Add a package when you keep doing something by hand.** Pin it in both
  `preset/settings.json` and `preset/Dockerfile.pi`, read it first, and note in
  `PACKAGES.md` what it can reach that the image could not reach before.

Keeping the list short is deliberate. With nine, you can say why each one is loaded.

## Normal working sequence

1. Read the repository's own instructions and the checked-in task.
2. Use Plan Mode when the change needs investigation before editing.
3. Implement in the parent session, or give one bounded slice to `worker`.
4. Run diagnostics and the repository's focused tests.
5. Inspect the actual patch with Diff Review.
6. Give the finished task and diff to the read-only `critic`.
7. Check the change in the browser with the `playwright-browser` skill.
8. Run `/verify` against the final source.
9. Use `/handoff` when the work needs a fresh session or another engineer.

## Build on the baseline

Add the database clients, cloud tools, language servers or optional profiles your
work requires, then rebuild the image. Keep additions pinned, and read them before
they enter the environment you develop in every day.

The permission policy allows common read-only commands and the usual test runners.
An unfamiliar build or test command is presented for a session decision; you do not
have to edit the preset first. The `example-project/` files show how a repository
owner can publish durable guidance — they are a template, not an installation step.

Repository-local Pi extensions, prompts and skills are treated differently from
ordinary source: `defaultProjectTrust` is `never`, so Pi can read those files but
waits before loading them as executable configuration. Review them before you
change that, and check the served model ID and context when you select a different
route.

## Security model

Two different controls, often confused for each other.

The permission extension governs Pi's tool calls. It can stop an ordinary mistake
and it leaves a log of the decision.

Docker contains the Pi process and every extension running inside it. Extensions
run with whatever access the process has, so a permission prompt cannot turn a
process with the run of your machine into a sandbox. That is a layer underneath,
and it has to be done underneath.

Review the packages and the container configuration before pointing this at source
or secrets that matter.
