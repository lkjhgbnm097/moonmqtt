# 2026 年 9 月 MoonBit 黑客松项目申报书

## 一、申报信息

- 项目名称：**MoonMQTT Guard——基于 MoonBit 的 MQTT 5 消息契约与发布治理门禁**
- 申报人：苏天纬
- GitHub 仓库：<https://github.com/lkjhgbnm097/moonmqtt>
- 所属方向：物联网数据治理、网络安全、开发者工具
- 许可证：Apache-2.0

## 二、项目摘要

MoonMQTT Guard 解决的不是“如何再写一个 MQTT 客户端”，而是“应用准备发送的这条 MQTT
消息是否符合被允许的业务用途与数据契约”。项目提供纯 MoonBit、可跨 Native/JavaScript/
WebAssembly 运行的确定性发布门禁，在 PUBLISH 进入现有客户端或 Broker 之前检查：

1. Topic 是否命中已登记的业务契约；
2. Payload 大小、QoS 与 Retain 是否满足最小化要求；
3. MQTT 5 Content Type、User Property 与 Message Expiry 是否完整、正确；
4. 命令类消息是否带有 Response Topic 与 Correlation Data；
5. 拒绝时是否能一次输出全部稳定、机器可读的违规原因。

项目保留已有 MQTT 5 编解码与参考 Native 客户端作为协议适配和互操作验证底座，但产品核心、
演示重点和验收指标均为“发布治理”，不再以通用客户端能力作为差异点。

## 三、问题与实际价值

MQTT Broker 的 ACL 通常回答“某个身份能否向某主题发布”，却不能完整回答：这条消息是否属于
声明用途、是否携带规定的 Schema 版本、是否超出允许大小、是否会被 Retain 长期保存、是否设置
合理有效期，以及远程命令能否被关联和回执。

这些约束若散落在设备、网关和云端业务代码中，会产生三类风险：

- **数据越界**：诊断或个人数据误发到长期保留、宽订阅的 Topic；
- **契约漂移**：生产者升级字段却未声明 Schema 版本，消费者静默误读；
- **操作失联**：设备命令缺少响应主题或关联 ID，失败后无法安全判断是否重试。

MoonMQTT Guard 把这些规则变成可测试的代码契约，并把“默认允许”改为“未匹配契约默认拒绝”。
它可用于工业采集网关、实验室设备、智能家居控制、固件 CI 和浏览器抓包审计。

## 四、与现有项目的差异和扩展关系

2026-09-21 使用 GitHub 仓库搜索对公开 MoonBit/MQTT 项目进行了复核：

| 公开项目 | 已有能力 | 本项目不重复的边界 | 可组合方式 |
|---|---|---|---|
| [`zbhzs1/moonbit-mqtt`](https://github.com/zbhzs1/moonbit-mqtt) | MQTT 3.1.1 字节级 codec | 不以基础 codec 作为最终产品 | 未来可增加 3.1.1 适配层，但治理语义保持独立 |
| [`Strangelight-Merser/moon-mqtt-client`](https://github.com/Strangelight-Merser/moon-mqtt-client) | TCP/TLS/WS/WSS、连接生命周期、重连、QoS 1、SQLite outbox、MQTT 5 子集 | 不竞争连接、重连和持久投递 | 在其 `publish` 之前调用门禁，拒绝不合规消息 |
| [`ChaonanShen/moonbit-mqtt-broker`](https://github.com/ChaonanShen/moonbit-mqtt-broker) | MQTT 3.1.1 Broker、路由、持久会话、ACL | 不实现服务端路由或 Broker | 在边缘发送端预检，补充 ACL 无法表达的内容契约 |

因此本项目与近期维护的 Mooncakes MQTT 客户端属于**上下层扩展关系**：对方负责可靠传输，
MoonMQTT Guard 负责传输前的用途绑定和消息契约。详细检索记录与逐能力矩阵位于
[`docs/DIFFERENTIATION.md`](DIFFERENTIATION.md)。

## 五、核心创新点

### 1. MQTT 5 原生的用途绑定契约

利用 User Property 表达 `purpose=maintenance`、`schema=telemetry-v1` 等业务声明，并与 Topic
Filter、Content Type、有效期共同判断，而不是只做字符串 Topic 白名单。

### 2. “协议合法”与“允许发布”分层

编解码层验证 MQTT 规范；门禁层验证组织业务契约。一个报文即使协议上合法，也可能因为用途、
大小、有效期或回执信息不完整而被拒绝。两类错误使用不同返回通道，便于排错和审计。

### 3. 完整而稳定的拒绝证据

一次判定收集所有违规项，返回具名契约和机器可读枚举；调用方可以直接生成 CI 报告、指标或
不含业务载荷的审计事件，避免依赖易变的自然语言日志。

### 4. 确定性、无网络依赖的治理核心

核心不读取文件、网络或系统时间。同一契约与同一报文在 Native、JS、Wasm 上得到相同结果，
便于边缘运行和可复现测试。

## 六、MVP 已实现功能

- `PublishContract`：具名 Topic Filter 契约与显式优先级；
- 未登记 Topic 默认拒绝；
- Payload 字节上限、最大 QoS、Retain 开关；
- Content Type 必填和精确匹配；
- 多个 MQTT 5 User Property 名值要求；
- Message Expiry 必填及最大期限；
- Response Topic 与 Correlation Data 强制要求；
- `Permit` / `Deny` 决策和完整违规列表；
- 无 Broker 的 `examples/release_gate` 可运行演示；
- 针对允许、复合违规、未登记 Topic、命令缺少关联信息的测试。

协议适配底座另提供 MQTT 5 报文编解码、流式解析、主题匹配、QoS 状态机和 Native
Mosquitto 互操作，确保门禁不是孤立的概念文档。

## 七、目标用户与完整场景

### 场景 A：工业遥测最小化

工厂网关只允许 `factory/+/telemetry` 发布 `application/json`，载荷不超过 1 KiB、QoS 不超过
1、禁止 Retain、最长存活 60 秒，并要求声明用途和 Schema。调试转储或永久 Retain 数据在
离开网关前即被拒绝。

### 场景 B：可追踪的设备命令

向 `factory/+/command` 发布时必须携带 Response Topic 与 Correlation Data。缺少任一字段都
拒绝，防止控制服务发出无法对账的指令。

### 场景 C：固件升级的 CI 契约测试

设备团队把固件生成的 PUBLISH 测试向量交给 Wasm/Native 门禁；一旦 Content Type、Schema
版本或有效期与契约不一致，CI 用稳定的违规枚举阻止发布。

## 八、技术架构

```text
业务消息
  │
  ▼
PublishContract registry
  │ Topic Filter 选择（首个匹配，顺序即优先级）
  ▼
Release Gate
  ├─ 协议/配置错误 ─► MqttError
  ├─ 允许 ─────────► Permit(contract_name)
  └─ 拒绝 ─────────► Deny(contract_name?, all violations)
                         │
                         ├─ CI / audit / metrics
                         └─ 不进入现有 MQTT client
```

门禁 API 位于协议核心包中，没有传输依赖。参考 Native 客户端仅用于端到端互操作验证；生产集成
可选择现有 MoonBit MQTT 客户端、其他语言网关或 Broker 插件边界。

## 九、交付物

- Apache-2.0 公开 GitHub 仓库；
- MoonBit 发布契约与判定 API；
- 机器可读违规类型及单元测试；
- `examples/release_gate` 可运行差异化演示；
- Native/JS/Wasm/Wasm-GC 构建测试；
- 同类项目审计、架构、协议支持、路线图与答辩文档；
- 参考 Native 适配器和 Mosquitto 互操作测试。

## 十、验收方式

```bash
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
moon run examples/release_gate
```

验收重点：

1. 合规遥测得到 `Permit("factory-telemetry-v1")`；
2. 同一报文中的大小、QoS、Retain、Content Type、用途、Schema 和有效期问题一次全部返回；
3. 未登记 Topic 默认拒绝；
4. 命令缺少 Response Topic/Correlation Data 时得到明确违规项；
5. 同一测试在 Native、JavaScript 和 WebAssembly 目标保持一致。

## 十一、原创性、引用与边界

发布门禁、契约模型与拒绝语义为本项目原创实现。协议字段和行为参考 OASIS MQTT 5.0；
Native 互操作适配使用 `moonbitlang/async`。未复制上述同类项目源码；项目差异文档明确记录其
公开能力和组合关系，后续引入第三方测试向量或代码时将在 NOTICE 中记录来源与许可证。

本项目不声称替代身份认证、Broker ACL、完整数据防泄漏系统或 MQTT 一致性认证。
