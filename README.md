# Tor exit relay in a container

A headless [Tor](https://www.torproject.org/) **exit relay**, packaged as a
container image (Docker or Podman). Config is generated from environment
variables; Tor runs in the foreground and drops privileges to `debian-tor`.

## ⚠️ Read this before running an exit

Running an exit relay is legal and valuable in many places, but it is **not**
zero-risk. Traffic to the wider internet leaves *your* IP address, so:

- You **will** get abuse complaints; you may get DMCA notices or law-enforcement
  contact. A monitored `ContactInfo` address is **mandatory** (this image
  refuses to start without one).
- Run it **only** on a **dedicated public IP** with a provider that **explicitly
  allows Tor exits**. Do **not** run it on a home connection, and **never on an
  employer's / corporate network** — you would route third parties' abuse
  through infrastructure you don't own.
- Set reverse DNS and, ideally, publish a DNS/HTTP notice that the IP is a Tor
  exit (see the Tor Project's *"Tips for running an exit relay"*).
- Consider a **dedicated ASN/IP** and register abuse contacts with your RIR.

This image runs a **plain relay**: it never logs, inspects, or modifies the
traffic passing through it (`SafeLogging 1`). Operating a malicious exit that
sniffs or tampers with user traffic is illegal and violates Tor's rules — don't.

## Run

Everything lives in `docker-compose.yml` — a stock Debian image installs `tor`
on first start and runs the inlined torrc. No image build, no extra files.

```sh
export TOR_CONTACT="tor-admin <abuse@example.org>"   # or put it in a .env file
docker compose up -d
docker compose logs -f      # watch for "Bootstrapped 100% (done)"
```

Podman works identically: `podman compose up -d`.

`TOR_CONTACT` is **mandatory** — compose refuses to start without it.

> The standalone `Dockerfile` + `entrypoint.sh` in this directory are an
> alternative pre-built-image approach and are **not** used by the compose
> file; you can delete them if you only want the compose workflow.

## Configuration (environment / `.env`)

Interpolated into the torrc by compose at `up` time:

| Variable        | Default   | Purpose |
|-----------------|-----------|---------|
| `TOR_CONTACT`   | *(none)*  | **Required.** Abuse/ops contact published in the consensus. |
| `TOR_NICKNAME`  | `torexit` | Relay nickname (1–19 alphanumerics). |
| `TOR_ORPORT`    | `9001`    | Public relay port; published *and* port-mapped. |
| `TOR_IPV6_EXIT` | `0`       | Allow IPv6 exit traffic. |

Bandwidth caps, accounting, and exit-policy changes are edited directly in the
torrc block of `docker-compose.yml`:

- **Non-exit (middle) relay** — all the network benefit, essentially none of the
  abuse/legal exposure (a good first step if unsure): set `ExitRelay 0` and
  replace the `ExitPolicy accept …` lines with a single `ExitPolicy reject *:*`.
- **Throttle** — add `RelayBandwidthRate 10 MBytes` / `RelayBandwidthBurst
  20 MBytes`, or `AccountingMax 3 TBytes`.

## Reachability & becoming published

After `Bootstrapped 100%`, Tor performs a **reachability self-test** on your
ORPort. Your ORPort must be reachable **from the public internet** (correct
port-publish, host firewall, and provider security groups all open). Only then
does the relay get published in the consensus; exit flags and meaningful traffic
follow over the next hours-to-days as the relay earns trust.

Verify from outside once running:

```sh
# from another host
nc -vz <your-public-ip> 9001
```

## Data persistence

The relay identity keys and state live in `/var/lib/tor`. Keep the volume: a new
identity key restarts the relay's reputation from zero. For **bind mounts**,
`chown` the host dir to uid `debian-tor` (`chown -R 101:101 ./tor-data`, verify
the uid with `docker run --rm tor-exit id debian-tor`).
