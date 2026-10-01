# Reproducible Pi preset

Every installed package, its pin, why it is here and what was left out is in
[`../PACKAGES.md`](../PACKAGES.md).

`../setup.sh` builds this image and installs the launcher. To build it directly
from this directory, use the same tag the launcher and `prepare-network.sh`
expect:

```bash
docker build -f Dockerfile.pi -t productiongrade-pi:0.84.4 .
```

Interactive launch from the repository being changed:

```bash
./prepare-network.sh --ds4
docker run --rm -it \
  --network pg-pi-models \
  -v "$PWD:/workspace" \
  productiongrade-pi:0.84.4
```

The image does not mount the host Pi home, SSH agent, cloud sign-in folders or Docker socket. It contains the whole Pi process and all extension code, and it runs as the unprivileged `node` user. The project is the only host bind mount.

The repository-work profile is intentionally opinionated where stock Pi is not:

- `/plan <task>` enters a tool-enforced read-only planning mode before an edit;
- `/review` checks the current diff from a reviewing posture without editing;
- `/verify` reruns acceptance plus one risk-directed check;
- `/handoff` prepares a fresh-session record from retained evidence;
- `worker` implements in a disposable Git worktree with a bounded tool list and turn budget;
- `critic` is denied write/edit access and returns findings that the parent must verify;
- `pi-continue` is configured not to write continuation artefacts into the project;
- Pi Lens supplies code diagnostics, affected-test feedback and read-before-edit signals while all automatic formatting and autofix paths are disabled at the command line.
- `ripgrep`, `fd`, Pyright and the other diagnostic binaries used by the preset are baked into the image; an offline session does not attempt an on-demand tool download.

Web access and MCP are not absent from the overall setup; they are separate opt-in profiles because they change network, secrets and data reach. They are not loaded into every local repository session.

`prepare-network.sh` creates an internal Docker network and a fixed relay with listeners only for DwarfStar on port 8000 and Ollama on port 11434. The Pi container has no default route to the internet and cannot use the relay as a general HTTP proxy. The script also checks that the internal network cannot reach a public address, and exits non-zero if it can.

Pass `--ds4` or `--qwen` to check only the model route deliberately loaded for that run. `--both` is available for setup diagnosis; do not expect the large DS4 endpoint and a loaded Ollama model to sit in memory together.

Stop and remove the named relay when the local session is finished:

```bash
docker stop pg-pi-model-proxy
docker rm pg-pi-model-proxy
```

For an untrusted repository, do not pass `--approve`. Review project-local Pi resources before trusting them. This preset defaults project trust to `never`.
