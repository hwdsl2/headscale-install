---
name: Bug report
about: Tell us about a problem you are experiencing
title: ''
labels: ''
assignees: ''

---
**Checklist**

- [ ] I read the [README](https://github.com/hwdsl2/headscale-install/blob/main/README.md) or the relevant section
- [ ] I searched existing [Issues](https://github.com/hwdsl2/headscale-install/issues?q=is%3Aissue)
- [ ] This issue is about the Headscale install script/config, not only Headscale itself

<!---
If you found a reproducible bug in the upstream project itself, consider opening an issue upstream: [Headscale](https://github.com/juanfont/headscale).
--->

**Describe the issue**
A clear and concise description of the problem.

**To Reproduce**
Steps to reproduce the behavior:

1. ...
2. ...

**Expected behavior**
A clear and concise description of what you expected to happen.

**Server environment**
- OS and version: [e.g. Ubuntu 24.04, Debian 12]
- Hosting provider (if applicable): [e.g. AWS, GCP, home server]
- CPU architecture: [e.g. amd64, arm64]
- Install or management command used: [e.g. `sudo bash headscale.sh --auto ...`]

**Configuration**
Remove secrets, keys, tokens and private URLs before posting.

- Server URL / `--serverurl` value format: [domain only; remove private values if needed]
- Listen address / port:
- TLS / reverse proxy setup: [Caddy / nginx / other / none]
- Relevant `/etc/headscale/config.yaml` snippets with secrets removed:

**Client information**
- Device: [e.g. iPhone 15, Windows laptop]
- OS: [e.g. iOS 17, Windows 11]
- Tailscale client app/version:
- Node registration or pre-auth key behavior:

**Logs**
Add relevant logs with secrets removed.

```bash
sudo systemctl status headscale
sudo journalctl -u headscale -n 50
```

**Additional context**
Add any other context about the problem here.
