# Contributing

Thanks for helping improve this project. This repository maintains the bare-metal Headscale install script; Docker image changes belong in [docker-headscale](https://github.com/hwdsl2/docker-headscale).

## Before You Start

- Search existing issues and pull requests.
- Keep changes focused and easy to review.
- For upstream Headscale or Tailscale client behavior, check the upstream project first.
- Do not include private keys, pre-auth keys, node keys, config files with secrets, database dumps, or logs with secrets.

## Pull Requests

- Update `README.md` or docs when install behavior, options, service names, paths, or defaults change.
- Include the tested Linux distribution, version, architecture, hosting environment, and `server_url` setup.
- Note whether install, user/key/device management, reverse proxy, or uninstall paths were tested.

## Testing

Test the smallest relevant path before opening a PR, for example:

- Run ShellCheck when editing shell scripts.
- Test install or management paths touched by the change.
- Check `systemctl status headscale` and relevant `journalctl` output for service changes.
- Verify client connection docs when changing `server_url`, TLS, or reverse proxy behavior.
