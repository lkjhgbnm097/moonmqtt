# MoonMQTT Guard 同类项目与差异化审计

审计日期：2026-09-21
检索范围：GitHub 公开仓库名称与描述，关键词包括 `mqtt MoonBit`、`moonbit-mqtt`、
`Mooncakes MQTT`、`mqtt5 MoonBit`、`IoT MQTT MoonBit`、`mqtt policy MoonBit`、
`mqtt firewall MoonBit`、`mqtt contract MoonBit`、`mqtt governance MoonBit` 和
`mqtt schema MoonBit`。后五组治理关键词未发现其他直接匹配的 MoonBit 公开仓库。

## 结论

MoonBit 生态已经存在 codec、通用客户端和 Broker。继续以“MQTT 5 客户端”为主定位会与
`Strangelight-Merser/moon-mqtt-client` 高度重叠；增加 TLS、重连、离线队列或更多 QoS 流程
不能构成足够差异。因此本项目将这些能力降级为参考协议适配器，主产品改为 MQTT 5 消息契约
与发布治理门禁。

## 已发现的直接相关仓库

### zbhzs1/moonbit-mqtt

- 链接：<https://github.com/zbhzs1/moonbit-mqtt>
- 定位：MQTT 3.1.1 报文编解码；不含网络传输、客户端运行时、Broker 会话、TLS 和 MQTT 5。
- 重叠：固定头、Remaining Length、常见报文、主题与负载的基础字节处理。
- 差异：MoonMQTT Guard 的验收核心是 MQTT 5 应用层发布契约与拒绝证据，不是 codec 数量。

### Strangelight-Merser/moon-mqtt-client

- 链接：<https://github.com/Strangelight-Merser/moon-mqtt-client>
- 定位：原生异步 MQTT 客户端；TCP/TLS/WS/WSS、连接生命周期、重连、QoS 0/1、SQLite
  durable outbox、MQTT 5 应用子集和实际 Broker 集成。
- 高度重叠的旧能力：Native 连接、TLS、发布/订阅、重连、持久会话、离线/持久队列。
- 处理方式：上述能力不再作为 MoonMQTT Guard 的项目创新声明；文档明确建议将该客户端作为
  门禁之后的传输实现。
- 新增互补点：用途与 Schema User Property、Content Type、TTL、Retain、载荷大小、QoS、
  request/response 关联信息的发送前合同判定。

### ChaonanShen/moonbit-mqtt-broker

- 链接：<https://github.com/ChaonanShen/moonbit-mqtt-broker>
- 定位：MQTT 3.1.1 Broker；路由、QoS 0/1/2、持久会话、保留消息、Will、认证、ACL、指标。
- 重叠：MQTT 语义和主题过滤器。
- 差异：Broker ACL 面向身份/Topic 权限；MoonMQTT Guard 面向单条消息的内容契约，在发送端
  默认拒绝未登记用途，不承担服务端路由或会话。

## 能力矩阵

| 能力 | 3.1.1 codec | 通用客户端 | Broker | MoonMQTT Guard |
|---|:---:|:---:|:---:|:---:|
| 报文编解码 | 核心 | 依赖/包含 | 包含 | 适配底座 |
| TCP/TLS/WS 连接 | — | 核心 | 服务端 | 非核心，可组合 |
| 自动重连/持久 outbox | — | 核心 | 会话侧 | 非核心，可组合 |
| Broker 路由/ACL | — | — | 核心 | — |
| 未登记 Topic 默认拒绝 | — | — | ACL 可部分表达 | **核心** |
| Content Type/Schema/用途契约 | — | — | — | **核心** |
| Payload/QoS/Retain/TTL 联合约束 | — | — | 部分限制 | **核心** |
| Response Topic/Correlation 完整性 | — | — | — | **核心** |
| 一次返回全部机器可读违规项 | — | — | — | **核心** |
| 无网络、跨目标确定性策略测试 | — | — | — | **核心** |

## 防止再次趋同的项目边界

以下内容即使继续维护，也只作为适配或验证，不作为黑客松核心创新：

- 增加更多通用客户端传输；
- 与其他客户端竞争自动重连、连接池或持久 outbox；
- 实现 Broker、服务端路由或管理后台；
- 仅通过支持 MQTT 5 更多字段来主张差异。

后续优先事项必须直接增强发布治理：策略配置加载、决策审计编码、规则冲突检查、契约版本迁移、
对接现有客户端的轻量 adapter，以及不包含业务载荷的隐私安全指标。
