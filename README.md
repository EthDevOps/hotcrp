# HotCRP Docker builds

Versioned Docker images of [HotCRP](https://github.com/kohler/hotcrp), built automatically from upstream releases.

This repo holds no HotCRP code. It only holds the image build: our `docker/Dockerfile` (Apache + mod_php), the env-driven `docker/options.php`, the first-boot `docker/entrypoint.sh` and `docker/trusted-proxy.php`. Every upstream release becomes an image in our registry and a matching GitHub release here.

## Images

```
ghcr.io/ethdevops/hotcrp:<version>
```

| Tag      | Points to                        |
|----------|----------------------------------|
| `3.4`    | exactly that upstream release    |
| `3`      | latest release of major 3        |
| `latest` | newest upstream release          |

Upstream tags are `vX.Y` or `vX.Y.Z`. For a `vX.Y.Z` release, `X.Y` points to the latest patch of that minor. Only those tags are built; upstream `master` and pre-releases are ignored.

## How it works

[`.github/workflows/docker.yaml`](.github/workflows/docker.yaml) runs every 6 hours:

1. Finds the newest `vX.Y[.Z]` tag in `kohler/hotcrp`.
2. Stops if this repo already has a release with that tag.
3. Otherwise checks out upstream at that tag, copies `docker/` into it, builds `docker/Dockerfile` with the upstream tree as context, and pushes the image to GHCR. `docker/Dockerfile.dockerignore` keeps VCS metadata and local state out of the image.
4. Creates a GitHub release with the same tag here. Update tooling that watches this repo's releases picks up the new version from it.

The release is created only after the image has been pushed, so a release always has a pullable image behind it.

## Manual runs

Actions → Docker → *Run workflow*. Leave the tag empty to build the latest upstream release, or enter a specific tag (e.g. `v3.3.1`). Manual builds of older tags do not move `latest`.

To rebuild a version that has already been released, delete its GitHub release first.

To rebuild with a security fix (e.g. a patched `php:8.4-apache` base) without touching existing tags, set `suffix` (e.g. `-php8.4.27`): only `<version><suffix>` is pushed and no release is created.

**Temporary:** the image ships php2shell (CVE-2026-109618/109619) hardening in `docker/php2shell.conf` (Apache `conf-enabled/zz-php2shell.conf`: one request per worker, no PHP memory limit, upload progress off). Remove it once the base ships PHP >= 8.4.27.

## Local build

```
git clone --branch v3.4 https://github.com/kohler/hotcrp.git src
cp -r docker src/docker
docker build -f src/docker/Dockerfile -t hotcrp:local src
```

## Caveats

- Only the newest tag is checked each run. If upstream publishes two releases within 6 hours, build the older one manually.
- GitHub disables scheduled workflows in public repos after 60 days without commits. Re-enable it in the Actions tab, or commit something occasionally.
