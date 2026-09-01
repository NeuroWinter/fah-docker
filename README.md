# Folding@home in a container

Headless [Folding@home](https://foldingathome.org/) **v8** client, packaged as a
container image. Works with Docker or Podman.

The upstream project ships no container image, so this installs the official
x86_64 client RPM (version pinned via a build arg) on a `fedora:44` base. The v8
client boots **paused**; the entrypoint enables folding over the client's local
websocket control API (`fahctl fold`) once it is up.

## Build

```sh
docker build -t foldingathome:8.5.6 .
# or
podman build -t foldingathome:8.5.6 .
```

## Run

```sh
docker run -d --name foldingathome \
  -p 127.0.0.1:7396:7396 \
  -v fah-data:/fah \
  -e FAH_USER="YourName" \
  -e FAH_TEAM="0" \
  foldingathome:8.5.6
```

Or with compose: `docker compose up -d --build`.

Watch it fold:

```sh
docker logs -f foldingathome
```

You will see a WU assignment, the GROMACS core download, then
`Project: NNNNN ... Completed N out of M steps`.

## Configuration (environment variables)

| Variable            | Default        | Purpose |
|---------------------|----------------|---------|
| `FAH_USER`          | `Anonymous`    | Contributor name shown on stats. |
| `FAH_TEAM`          | `0`            | Team number. |
| `FAH_PASSKEY`       | *(empty)*      | 32-hex passkey for bonus points. |
| `FAH_ACCOUNT_TOKEN` | *(empty)*      | Link the machine to a F@h account. |
| `FAH_MACHINE_NAME`  | *(empty)*      | Name for this machine in the account. |
| `FAH_CPUS`          | *(all visible)*| CPU threads to fold with. |
| `FAH_CAUSE`         | `any`          | Preferred research cause. |
| `FAH_HTTP`          | `0.0.0.0:7396` | Control/Web API bind address inside the container. |
| `FAH_ALLOW`         | `0/0`          | Client addresses allowed to reach the control API. |
| `FAH_EXTRA_ARGS`    | *(empty)*      | Extra raw `fah-client` flags. |

Limit CPU usage either with `FAH_CPUS` or the container runtime
(`docker run --cpus=4 ...`); the client auto-detects the cores visible to the
container.

## Web Control

The bundled Web Control API listens on port 7396. With the port published to
`127.0.0.1`, open <https://app.foldingathome.org/> and connect it to
`http://localhost:7396` to inspect progress and change settings.

> **Security:** the control API is unauthenticated. Only publish it to
> `127.0.0.1` (as shown), never to a public interface.

## Data persistence

WU progress, downloaded cores, config and logs live in `/fah`. Mount a volume
there (as the examples do) so an in-progress work unit survives restarts.

> **Podman note:** progress is streamed to the container's stdout, so
> `docker logs -f` / `podman logs -f` shows live folding output. If your Podman
> defaults to the `journald` log driver and `podman logs` looks empty, run with
> `--log-driver k8s-file` (or read `/fah/log.txt` in the volume directly).

## GPU folding

This image folds on CPU. GPU folding needs the host GPU passed into the
container (`--device`/NVIDIA runtime) plus the matching drivers, and is out of
scope here.
