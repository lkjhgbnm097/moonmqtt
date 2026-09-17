# MoonMQTT 架构设计

## 设计目标

MoonMQTT 将 MQTT 协议语义与平台 I/O 分离，确保协议核心可以独立测试、复用和移植。
网络读取到的每个字节都必须经过同一条解析路径；模拟测试、Native 客户端和未来的
WebSocket 传输不得各自实现一套协议逻辑。

## 模块边界

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

### Native 传输

`native/` 使用 `moonbitlang/async/socket` 和 `moonbitlang/async/tls`。`NativeClient`
只负责：

1. 读取 socket 字节并交给 `PacketStreamDecoder`；
2. 把解码报文交给 `ClientSession`；
3. 发送状态机产生的响应；
4. 向调用方返回应用事件。

Native 层不重新解释 QoS 或属性语义。

## 不变量

- 包标识符只能取 1 至 65535，且未确认前不得重复分配；
- QoS 0 PUBLISH 不携带包标识符，也不设置 DUP；
- QoS 1/2 PUBLISH 必须携带非零包标识符；
- 非 PUBLISH 报文的固定报头 Flags 必须等于规范值；
- 属性长度读取器必须恰好耗尽；
- QoS 2 消息在 PUBREL 前不交付应用；
- 一个 PINGREQ 未收到 PINGRESP 前不能再发送第二个 PINGREQ。

## 扩展点

未来传输只需实现“读字节、写完整字节、关闭”三项能力。WebSocket、WASI socket 或
嵌入式 HAL 不需要修改编解码与会话状态机。
