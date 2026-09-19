# MoonMQTT 项目状态

## 当前里程碑

`0.1.0-rc`：MVP 已在公开仓库持续开发；协议核心、Native 客户端和可靠连接基础能力
均有可运行实现与自动测试。

## 已完成

- MQTT 5.0 协议模型、严格编解码与流式解析；
- QoS 0/1/2 客户端状态机；
- 主题过滤器匹配、流式报文大小限制；
- Receive Maximum、Maximum Packet Size 和持久会话恢复；
- Keep Alive 调度器、重连退避策略与有界离线发布队列；
- Native TCP/TLS 客户端；
- `inspect`、`publish`、`subscribe` 命令行；
- 跨目标测试、模拟 Broker 测试、Mosquitto 集成程序与 CI；
- 示例、参赛提案、演示脚本、架构、支持矩阵、安全与发布文档。

## 本地验证

- `moon fmt --check` 和连续两次 `moon info`：通过；
- Wasm、Wasm-GC、JavaScript：严格检查通过，各 37/37 测试通过；
- Native：严格检查通过，38/38 测试通过；
- Native release 构建、纯协议示例和 CLI 报文解析：通过；
- 协议核心覆盖率：1315/1623，81.0%；
- 真实 Mosquitto 往返：本机未安装 Broker，已配置 Ubuntu CI 任务。

## 仍需项目所有者完成

以下步骤涉及项目所有者账号，不能由源码本身决定：

1. 配置 Mooncakes 命名空间与发布凭据；
2. 补充赛事报名成员信息、联系方式和演示视频链接；
3. 在报名表中重新提交当前公开仓库和最新版申报书。

详见 `docs/COMPETITION_CHECKLIST.zh-CN.md`。
