---
name: 错误报告
about: 请使用这个模板来提交 bug
title: ''
labels: ''
assignees: ''

---
**任务列表**

- [ ] 我已阅读[自述文件](https://github.com/hwdsl2/headscale-install/blob/main/README-zh.md)或相关章节
- [ ] 我搜索了已有的 [Issues](https://github.com/hwdsl2/headscale-install/issues?q=is%3Aissue)
- [ ] 这个问题是关于 Headscale 安装脚本/配置，而不只是 Headscale 本身

<!---
如果你确认问题属于上游项目本身，请考虑在相应上游项目提交 issue：[Headscale](https://github.com/juanfont/headscale)。
--->

**问题描述**
使用清楚简明的语言描述这个问题。

**重现步骤**
重现该问题的步骤：

1. ...
2. ...

**期待的正确结果**
简要描述你期望发生的结果。

**服务器环境**
- 操作系统和版本: [例如 Ubuntu 24.04, Debian 12]
- 服务提供商（如果适用）: [例如 AWS, GCP, 家用服务器]
- CPU 架构: [例如 amd64, arm64]
- 使用的安装或管理命令: [例如 `sudo bash headscale.sh --auto ...`]

**配置**
发布前请删除 secrets、密钥、tokens 和私有 URL。

- Server URL / `--serverurl` 值格式: [只写域名格式；需要时移除私有值]
- 监听地址 / 端口：
- TLS / 反向代理配置: [Caddy / nginx / 其它 / 无]
- 去除敏感信息后的 `/etc/headscale/config.yaml` 相关片段：

**客户端信息**
- 设备: [例如 iPhone 15, Windows laptop]
- 操作系统: [例如 iOS 17, Windows 11]
- Tailscale 客户端应用/版本：
- 节点注册或预授权密钥行为：

**日志**
请添加相关日志，并删除敏感信息。

```bash
sudo systemctl status headscale
sudo journalctl -u headscale -n 50
```

**其它信息**
添加关于该问题的其它信息。
