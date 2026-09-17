# MoonMQTT 项目状态

## 当前里程碑

`0.1.0-rc`：作品本体和本地质量门禁已完成，等待账号相关的公开发布与赛事提交。

## 已完成

- MQTT 5.0 协议模型、严格编解码与流式解析；
- QoS 0/1/2 客户端状态机；
- Native TCP/TLS 客户端；
- `inspect`、`publish`、`subscribe` 命令行；
- 跨目标测试、模拟 Broker 测试、Mosquitto 集成程序与 CI；
- 示例、参赛提案、演示脚本、架构、支持矩阵、安全与发布文档。

## 本地验证

- `moon fmt --check` 和连续两次 `moon info`：通过；
- Wasm：严格检查通过，24/24 测试通过；
- JavaScript：严格检查通过，24/24 测试通过；
- Native：严格检查通过，25/25 测试通过；
- Native release 构建、纯协议示例和 CLI 报文解析：通过；
- 协议核心覆盖率：1160/1447，80.2%；
- 真实 Mosquitto 往返：本机未安装 Broker，已配置 Ubuntu CI 任务。

## 发布阻塞项

以下步骤涉及项目所有者账号，不能由源码本身决定：

1. 明确授权使用 `bzhangui` 创建并公开 `MoonMQTT` 仓库、推送完整源码；
2. Mooncakes 命名空间与发布凭据；
3. 赛事报名成员信息、联系方式、视频链接与最终提交确认。

详见 `docs/COMPETITION_CHECKLIST.zh-CN.md`。
