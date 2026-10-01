# Optional Pi capability profiles

The repository-work image is the default. These capabilities are deliberately separate because enabling them changes what the Pi process can reach.

## Documentation research

Candidate: `pi-web-access@0.27.0`.

Use it only in a separately built image with public egress and no mounted source-code or credential directory that the research task does not need. Its package contains direct fetching plus several search/provider integrations; configure one intended provider instead of exposing every credential source. Move verified excerpts or URLs into the repository-work session after review. Do not turn public egress on for the default image merely so the agent can search occasionally.

`pi-web-search@1.3.1` is smaller, but its useful routes depend on cloud-provider search credentials. It is not the local-only answer and is not installed in the default image.

## Browser control and application UAT

The default image now includes `pi-playwright@0.1.2` for checking your own app in a
headless Chromium inside the container. See [`PACKAGES.md`](../PACKAGES.md). It covers
the common case: start the app, use it the way a user would, take screenshots and a
recording, and report what happened, with no route out to the public internet.

Two capabilities stay out of the default image:

- `pi-browser`, pinned to Git commit `32b5baaf7ca0d6258b1d0841cff9c6c88aafff2b`, is a
  broad Playwright and CDP control surface. It launches browsers headful and can attach
  to your everyday browser, including its cookies and storage, and it does not bound
  navigation for every path. Keep it as a live-browser profile you choose on purpose,
  with a separate browser profile and human approval for sensitive actions.
- `pi-client`, pinned to Git commit `eb9fc5f47f26b1eb2159f3cacf3644f0d46ca78b`, runs
  checked-in acceptance scenarios with console, network and screenshot gates. Use it
  when browser checks need to run unattended and repeatably, from a scenario in the
  repository with a disposable browser profile and a declared origin, rather than from
  whatever the session decides to open.

For either, gate the profile on a fixture you have actually run: a declared app start
command and local origin, a disposable browser profile with no host cookies, one
authenticated journey with fixture credentials, deliberate console and failed-request
defects that must fail the run, and an attempted off-origin navigation that must be
blocked.

## MCP

Candidate: `pi-mcp-adapter@2.31.0`, which is compatible with pinned Pi 0.84.4.

Create a profile for one named MCP server and one task. Review its exact tool list, OAuth/keyring behavior, config-write location and data reach. Do not load the adapter's example remote servers into the default profile, and do not mount the host Pi auth store into the contained repository session.

## Planning

The default image uses `@narumitw/pi-plan-mode@0.56.0`. It is kept separate from Goal mode: Plan mode enforces a read-only investigation boundary, while Goal mode records the accepted task and completion evidence. The obsolete `pi-plan-mode@0.4.8` package remains excluded because it targets the pre-Earendil Pi package line.

## Memory

No cross-session memory package is enabled. `/handoff`, Pi's native session tree/resume behavior and the pinned continuation extension cover deliberate continuity. A future memory profile must demonstrate freshness, deletion and conflict handling before it can enter this setup.
