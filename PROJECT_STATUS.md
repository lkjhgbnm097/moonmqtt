# MoonMQTT Guard 项目状态

## 当前里程碑

`0.1.0-rc`：消息契约与发布治理 MVP 已完成。项目不再以通用 MQTT 客户端为参赛定位；
已有协议与 Native 代码保留为可移植适配和互操作验证底座。

## 差异化 MVP 已完成

- 具名 `PublishContract` 与首个匹配契约的确定性优先级；
- 未登记 Topic 默认拒绝；
- Payload 大小、最大 QoS 与 Retain 策略；
- Content Type、用途/Schema User Property 约束；
- Message Expiry 必填及最大期限；
- Response Topic 与 Correlation Data 完整性约束；
- 一次返回全部机器可读违规原因；
- 无 Broker 的 `examples/release_gate` 演示；
- GitHub 同类项目差异审计与重写后的申报书。

## 协议适配底座

- MQTT 5.0 报文模型、严格编解码与流式解析；
- QoS 0/1/2 状态机和标准 Topic Filter 匹配；
- Native TCP/TLS 参考客户端、CLI、模拟 Broker 与 Mosquitto CI；
- Native、JavaScript、Wasm 和 Wasm-GC 测试。

## 本地验证（2026-09-21）

- 工具链：`moon 0.1.20260920 (914d7da 2026-09-20)`；
- `moon check --target all --deny-warn`：通过；
- `moon test --target all --deny-warn`：Wasm/Wasm-GC/JavaScript 各 43/43，Native 44/44；
- `moon fmt --check`、`moon info`：通过；
- `moon run examples/release_gate`：允许与复合拒绝结果均符合预期。

## 项目所有者仍需完成

1. 推送当前提交并确认公开 GitHub Actions 全部通过；
2. 将报名表项目名称和简介更新为 MoonMQTT Guard 的治理定位；
3. 补充联系方式、演示视频与 Mooncakes 发布信息；
4. 在报名表中重新提交最新版申报书。

详见 `docs/COMPETITION_CHECKLIST.zh-CN.md`。
