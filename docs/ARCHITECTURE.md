# MoonMQTT Guard 架构设计

## 设计目标

MoonMQTT Guard 将“业务消息是否允许发布”、MQTT 协议语义和平台 I/O 分为三个边界。
发布门禁必须可以脱离网络独立测试；协议适配负责把 MQTT 5 字段变成强类型数据；参考
Native 客户端只验证允许后的消息能够与现有 Broker 互操作。

## 模块边界

### 发布治理层

`release_gate.mbt` 定义 `PublishContract`、`ReleaseDecision` 和稳定的违规枚举。应用把
`PublishPacket` 交给门禁，只有 `Permit` 才继续调用现有 MQTT 客户端。

契约按数组顺序采用首个匹配项，因此优先级显式、可测试。非法 Topic Filter 属于配置错误，
返回 `MqttError`；没有匹配契约或违反消息约束属于正常拒绝，返回包含全部问题的 `Deny`。
门禁不读取网络、文件、系统时间，也不保存业务载荷。

### 协议数据模型

`types.mbt` 和 `packets.mbt` 定义 QoS、报文类型、MQTT 5 属性及控制报文。
公开结构保留协议信息，不混入 socket、计时器或回调函数。

### 二进制层

`binary.mbt` 负责：

- 大端整数；
- MQTT Variable Byte Integer；
- 长度前缀二进制数据；
- MQTT UTF-8 编解码与 Unicode 限制。

所有读取都先检查剩余长度。流输入不足返回 `NeedMoreData`，固定报头已经声明完整长度
但报文体内部不足则转换为 `MalformedPacket`。

### 属性层

`properties.mbt` 根据属性标识符决定字节、双字节、四字节、变长整数、UTF-8、
二进制或 UTF-8 Pair 类型。`validation.mbt` 再按报文上下文检查属性是否允许、
是否可以重复。

这两个阶段分开是有意设计：第一阶段回答“字节能否解析”，第二阶段回答“该属性能否
出现在这种报文中”。

### 报文编解码

`encoder.mbt` 和 `decoder.mbt` 覆盖 MQTT 5 的 15 类控制报文。编码器先校验结构，
再产生字节；解码器先根据 Remaining Length 建立受限子读取器，避免一个畸形报文
越界读取后续报文。

### 流式解码

`PacketStreamDecoder` 保存未完成字节，允许以下输入：

- 一个报文被拆成任意多个网络片段；
- 一个片段中包含多个连续报文；
- 完整报文后还保留下一报文的一部分。

解码完成后只移除实际消费的字节。

### 客户端会话状态机

`ClientSession` 不执行 I/O，只接收或生成 `Packet`：

```text
Disconnected ── CONNECT ──> AwaitingConnAck
      ▲                            │
      │                    success │ reject
      │                            ▼
      └──── transport close ── Connected ── DISCONNECT ──> Disconnecting
```

QoS 1 发送状态：

```text
PUBLISH ──> AwaitingPubAck ── PUBACK ──> complete
```

QoS 2 发送状态：

```text
PUBLISH ──> AwaitingPubRec ── PUBREC ──> PUBREL
PUBREL  ──> AwaitingPubComp ─ PUBCOMP ─> complete
```

QoS 2 接收消息先暂存，重复 PUBLISH 只重新发送 PUBREC；收到 PUBREL 后才向应用交付一次，
随后发送 PUBCOMP。

`handle_incoming` 返回 `SessionOutcome`：

- `responses`：必须写回网络的协议报文；
- `events`：交给应用处理的连接、消息、确认、认证或断线事件。

### Native 参考传输

`native/` 使用 `moonbitlang/async/socket` 和 `moonbitlang/async/tls`。`NativeClient`
只负责：

1. 读取 socket 字节并交给 `PacketStreamDecoder`；
2. 把解码报文交给 `ClientSession`；
3. 发送状态机产生的响应；
4. 向调用方返回应用事件。

Native 层不重新解释 QoS 或属性语义，也不是项目的差异化产品定位。生产环境可以把门禁接到
现有 MoonBit MQTT 客户端或其他传输实现之前。

## 不变量

- 未命中任何发布契约的 Topic 默认拒绝；
- 同一契约与报文在所有目标产生相同、顺序稳定的违规列表；
- 门禁配置错误不得伪装成普通消息拒绝；
- 发布治理核心不得依赖网络和系统时间；

- 包标识符只能取 1 至 65535，且未确认前不得重复分配；
- QoS 0 PUBLISH 不携带包标识符，也不设置 DUP；
- QoS 1/2 PUBLISH 必须携带非零包标识符；
- 非 PUBLISH 报文的固定报头 Flags 必须等于规范值；
- 属性长度读取器必须恰好耗尽；
- QoS 2 消息在 PUBREL 前不交付应用；
- 一个 PINGREQ 未收到 PINGRESP 前不能再发送第二个 PINGREQ。

## 扩展点

优先扩展方向是策略配置加载、重叠契约诊断、无载荷审计事件和现有客户端 adapter。新增传输
协议或完整 Broker 不属于差异化路线；参考传输仍可用于兼容性验证。
