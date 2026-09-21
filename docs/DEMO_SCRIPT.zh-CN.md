# MoonMQTT Guard 演示与答辩脚本

## 目标

在 5 至 7 分钟内证明项目能阻止“协议合法但业务上不应发布”的 MQTT 5 消息，并清楚说明
它与现有 MoonBit codec、客户端和 Broker 的互补关系。

## 演示准备

在仓库根目录执行：

```bash
moon update
moon test --target all --deny-warn
```

主演示不依赖 Broker 或网络，避免现场环境影响治理结果。

## 演示流程

### 1. 展示已存在的生态能力（约 45 秒）

打开 `docs/DIFFERENTIATION.md`，指出 MoonBit 已有 MQTT 3.1.1 codec、功能完整的异步客户端
和 Broker。本项目不再把 TCP/TLS、重连或 QoS 当成创新点。

### 2. 运行发布门禁（约 2 分钟）

```bash
moon run examples/release_gate
```

第一条遥测符合 `factory-telemetry-v1`，返回 `Permit`。第二条仍是合法 MQTT PUBLISH，
但同时违反 Retain、Content Type、用途、Schema 与有效期要求；门禁一次返回全部违规项。

强调三个行为：

- 未登记 Topic 默认拒绝；
- 配置错误与普通消息拒绝分开返回；
- 判定不依赖网络、Broker 或系统时间，可在 Native/JS/Wasm 复现。

### 3. 展示命令可追踪性（约 1 分钟）

打开 `release_gate_test.mbt` 中的 `device-command-v1` 测试。说明远程命令必须同时包含
Response Topic 与 Correlation Data，否则在发送前拒绝，避免产生无法对账的操作。

### 4. 展示跨目标质量门禁（约 1 分钟）

```bash
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
```

说明治理核心与协议核心共用测试：Wasm、Wasm-GC、JavaScript 各 43 项，Native 44 项。

### 5. 架构与组合方式（约 1 分钟）

展示 `docs/ARCHITECTURE.md`：应用先调用 Release Gate，只有 `Permit` 才进入现有 MQTT client；
Broker 继续负责身份、ACL、路由与会话。门禁补充的是内容契约，不取代现有基础设施。

### 6. 可选互操作备用演示（约 1 分钟）

若现场有 Mosquitto，可运行参考适配器验证允许后的报文仍能正常传输。该部分只是兼容性证据，
不是项目差异化主线。

## 常见问答

**与 Mooncakes 上的 MQTT 客户端有什么区别？**

客户端解决连接、重连和可靠发送；MoonMQTT Guard 在调用客户端前判断消息是否满足用途、Schema、
大小、QoS、Retain、TTL 和关联信息契约。两者是上层治理与下层传输的组合关系。

**Broker ACL 不能解决吗？**

ACL 主要约束“谁能发哪个 Topic”。门禁还检查一条具体消息的 MQTT 5 元数据和发布语义，并能在
数据离开设备或网关前拒绝。

**为什么使用 MoonBit？**

同一份无 I/O 判定核心可编译到 Native、JavaScript 和 WebAssembly，适合边缘网关、CI 与浏览器
审计共享规则，同时能复用 MoonBit 实现的 MQTT 5 类型和 Topic Filter 语义。

**是否是完整 DLP 或 MQTT 一致性产品？**

不是。当前是可运行的消息契约 MVP，不替代身份认证、组织级 DLP 或官方一致性认证。
