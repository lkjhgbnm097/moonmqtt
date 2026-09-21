# MoonMQTT Guard

**面向 MQTT 5.0 的消息契约与发布治理门禁，使用 MoonBit 实现。**

MoonMQTT Guard 不是另一套通用 MQTT 客户端，也不实现 Broker。它在业务数据进入 MQTT
基础设施之前，对每一条 `PUBLISH` 做确定性的“是否允许发布”判定：主题是否属于已登记契约、
载荷是否超限、QoS/Retain 是否符合用途、Content Type 与 User Property 是否完整、消息是否
设置合理的过期时间，以及请求消息是否携带 Response Topic 与 Correlation Data。

项目保留自研 MQTT 5.0 编解码、流式解析和会话代码作为**可移植协议适配层**，核心交付则是
可嵌入边缘网关、工业采集程序和测试流水线的发布治理能力。

> 当前版本为 0.1.0 开发版。门禁判定器、MQTT 5 协议核心和 Native 验证链路可用；尚未宣称
> 获得 MQTT 一致性认证，也不替代 Broker ACL、身份认证或端到端数据治理平台。

## 一分钟体验：阻止“合法但不该发”的消息

```bash
moon update
moon run examples/release_gate
```

示例为 `factory/+/telemetry` 定义发布契约：JSON 载荷不超过 16 字节、QoS 不高于 1、
禁止 Retain、必须声明 `purpose=maintenance` 与 `schema=telemetry-v1`，并在 60 秒内过期。
协议上完全合法但不符合业务契约的消息会得到包含**全部违规项**的拒绝结果。

```moonbit
let contract = @mqtt.PublishContract::new(
  "factory-telemetry-v1",
  "factory/+/telemetry",
  max_payload_bytes=1024,
  maximum_qos=@mqtt.QoS::AtLeastOnce,
  allow_retain=false,
  required_content_type=Some("application/json"),
  required_user_properties=[
    @mqtt.UserPropertyRequirement::new("purpose", "maintenance"),
    @mqtt.UserPropertyRequirement::new("schema", "telemetry-v1"),
  ],
  require_message_expiry=true,
  maximum_message_expiry_secs=Some(60),
)

let decision = @mqtt.evaluate_publish_contract(contract, publish).unwrap()
```

返回值不是模糊的布尔量：

- `Permit(contract_name)`：消息满足选中的具名契约；
- `Deny(contract_name?, violations)`：一次给出所有稳定、机器可读的违规原因；
- 非法 Topic Filter 作为配置错误返回 `MqttError`，不会被误当成普通拒绝。

## 实际应用价值

### 工业边缘网关的数据最小化

同一个设备可能产生运维、计费和诊断数据。门禁通过 Topic Filter 与 MQTT 5 User Property
把“用途”变成可执行契约，阻止诊断载荷误入长期保留主题，并限制载荷大小和有效期。

### 命令/响应链路的可追踪性

设备命令可以强制要求 `Response Topic` 和 `Correlation Data`。缺少回执路径或关联标识的命令
在进入 Broker 前被拒绝，避免出现无法对账的远程操作。

### CI 中的 MQTT 报文契约测试

门禁核心没有网络依赖。团队可以把抓包、固件生成的测试向量或模拟 PUBLISH 直接交给同一套
MoonBit 规则，稳定复现拒绝原因，不需要启动 Broker。

### 边缘侧的低开销预检

协议核心可编译到 Native、JavaScript 和 WebAssembly。Native 网关可在发送前执行规则；
浏览器/Wasm 工具可对抓包离线审计，二者共享完全相同的判定语义。

## 与现有 MoonBit MQTT 项目的边界

2026-09-21 对 GitHub 公开仓库进行了同类检索，详见
[`docs/DIFFERENTIATION.md`](docs/DIFFERENTIATION.md)。结论如下：

| 项目 | 主要职责 | 与 MoonMQTT Guard 的关系 |
|---|---|---|
| [`zbhzs1/moonbit-mqtt`](https://github.com/zbhzs1/moonbit-mqtt) | MQTT 3.1.1 报文编解码 | 可作为另一种协议适配来源；不做发布契约 |
| [`Strangelight-Merser/moon-mqtt-client`](https://github.com/Strangelight-Merser/moon-mqtt-client) | TCP/TLS/WS/WSS 客户端、重连、QoS 1、持久 outbox | 推荐的上游传输客户端；本项目只做发送前治理，不与其竞争连接生命周期 |
| [`ChaonanShen/moonbit-mqtt-broker`](https://github.com/ChaonanShen/moonbit-mqtt-broker) | MQTT 3.1.1 Broker、会话、路由、持久化、ACL | 部署端基础设施；门禁可在消息到达 Broker 前补充内容契约 |
| **MoonMQTT Guard** | MQTT 5 消息契约、用途绑定、元数据完整性、可审计拒绝 | 应用/Broker 之间的治理层 |

“能否连接、重连和送达”不是本项目的差异点；“这条消息是否符合被允许的用途和数据契约”才是。

## 当前核心能力

### 发布治理 MVP

- 按标准 MQTT Topic Filter 选择契约，未登记主题默认拒绝；
- 载荷字节上限、最大 QoS、Retain 策略；
- Content Type 精确约束；
- MQTT 5 User Property 名值约束，可表达用途和 Schema 版本；
- Message Expiry 必填及最大有效期；
- Response Topic / Correlation Data 完整性约束；
- 确定性“首个匹配契约”优先级；
- 单次返回全部违规项，适合形成审计事件和 CI 报告；
- 纯函数 API，无网络、文件和系统时间依赖。

### 协议适配与验证底座

- MQTT 5.0 全部 15 类控制报文的数据模型；
- 属性、Reason Code、主题与 UTF-8 约束校验；
- 流式拆包/粘包与报文大小限制；
- QoS 0/1/2 确定性会话状态机；
- Native TCP/TLS 互操作适配器与 Mosquitto 测试；
- Native、JavaScript、Wasm 和 Wasm-GC 自动测试。

上述客户端代码是用于验证门禁前后报文仍能与现有 Broker 互操作的参考适配器，不再作为项目
的产品定位。生产环境可将门禁 API 接到现有 MoonBit MQTT 客户端或其他传输实现之前。

## 架构

```text
Application / device data
          │
          ▼
PublishContract registry
  topic / purpose / schema / TTL / size / QoS
          │
          ▼
Deterministic release gate ──► Permit(contract)
          │
          └──────────────────► Deny(contract?, all violations) ──► audit / CI
          │
          ▼
Existing MQTT client or reference Native adapter
          │
          ▼
Existing broker (Mosquitto / EMQX / HiveMQ / MoonBit broker)
```

门禁与网络生命周期分离，因此判断结果不会受重连时序、系统时间或具体 Broker 影响；策略错误
与消息拒绝也有不同的返回通道。

## 安装与验证

```bash
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
moon run examples/release_gate
```

需要验证参考 Native 适配器时：

```bash
moon test --target native
moon run --target native integration/mosquitto
```

公开仓库：<https://github.com/lkjhgbnm097/moonmqtt>

## 明确非目标

- 不重新实现完整通用 MQTT 客户端；
- 不实现 MQTT Broker、设备管理云平台或 Web 管理后台；
- 不替代 Broker ACL、TLS 身份认证或组织级权限系统；
- 首版不解析 JSON Schema，不保存含业务载荷的审计日志；
- 首版策略由 MoonBit API 构造，配置文件加载器列入后续版本；
- 未完成一致性认证前不宣称完全兼容所有 Broker。

## 项目文档

- [参赛项目申报书](docs/PROPOSAL.zh-CN.md)
- [差异化与同类项目审计](docs/DIFFERENTIATION.md)
- [架构设计](docs/ARCHITECTURE.md)
- [协议支持矩阵](docs/PROTOCOL_SUPPORT.md)
- [演示与答辩脚本](docs/DEMO_SCRIPT.zh-CN.md)
- [路线图](docs/ROADMAP.md)
- [质量报告](docs/QUALITY_REPORT.md)
- [开发日志](docs/DEVELOPMENT_LOG.zh-CN.md)

## 标准、来源与许可证

协议字段和行为依据 [OASIS MQTT Version 5.0](https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html)。
网络验证适配器使用 Apache-2.0 许可的
[`moonbitlang/async`](https://github.com/moonbitlang/async)。第三方边界与来源见 [`NOTICE`](NOTICE)。

本项目采用 Apache License 2.0，详见 [`LICENSE`](LICENSE)。
