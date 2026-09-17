# MoonMQTT

MoonMQTT 是一个以 MoonBit 编写的 MQTT 5.0 协议工具包和客户端。它把协议编解码、
会话状态机与平台网络 I/O 分离：同一套协议核心可以运行在 Native、JavaScript 和
WebAssembly，Native 包则通过官方 `moonbitlang/async` 提供 TCP/TLS 客户端。

项目当前处于 **0.1.0 开发阶段**。协议核心和主要客户端流程已经可用，但尚未宣称为
生产级 MQTT SDK；请先阅读[已知边界](#已知边界)。

## 为什么做 MoonMQTT

MoonBit 很适合构建跨端、低开销的协议组件，但目前生态中缺少一个结构清晰、可测试、
能连接真实 Broker 的 MQTT 5.0 客户端。MoonMQTT 面向以下实际场景：

- 工业传感器遥测、设备告警和远程控制；
- 智能家居、边缘网关和实验室设备接入；
- Native 服务与 EMQX、Mosquitto、HiveMQ 等现有 Broker 集成；
- 在浏览器或 Wasm 应用中复用 MQTT 报文解析与会话逻辑；
- 教学、抓包分析、协议测试和模糊测试。

## 当前能力

- MQTT 5.0 全部 15 类控制报文的数据模型；
- 严格的固定报头、Remaining Length 和属性编解码；
- CONNECT、Will、PUBLISH、SUBSCRIBE、UNSUBSCRIBE、AUTH 等完整负载；
- MQTT UTF-8 校验，包括过长编码、代理项、U+0000 和非字符；
- 属性位置、单例属性和合法取值校验；
- 报文 Reason Code、主题名、主题过滤器和共享订阅约束校验；
- 流式解码，可处理拆包和连续粘包；
- 确定性客户端会话状态机；
- QoS 0、QoS 1 和 QoS 2 发送/接收握手；
- 重复 QoS 2 PUBLISH 抑制；
- 包标识符分配、订阅确认、取消订阅、Ping 和断线状态；
- Native TCP/TLS 客户端；
- `inspect`、`publish`、`subscribe` 命令行工具；
- Wasm、JavaScript、Windows、Linux 和 macOS CI；
- 模拟 Broker 端到端测试及 Mosquitto 真实 Broker CI。

## 安装

发布到 Mooncakes 后可使用：

```bash
moon add moonmqtt/moonmqtt@0.1.0
```

从源码运行：

```bash
# 下载或克隆当前仓库后进入项目目录
moon update
moon test --target native
```

公开仓库：<https://github.com/lkjhgbnm097/moonmqtt>。

## 快速体验

运行纯协议示例，不需要 Broker：

```bash
moon run examples/codec
```

解析抓包中的十六进制 MQTT 报文：

```bash
moon run --target native cmd/main -- inspect "30 06 00 01 61 00 68 69"
```

输出中会显示结构化 PUBLISH 报文和规范化后的 wire bytes。

连接本地 Broker 并发布消息：

```bash
moon run --target native cmd/main -- publish \
  --host 127.0.0.1 --port 1883 --qos 1 \
  sensors/temperature "23.4"
```

订阅一条消息后退出：

```bash
moon run --target native cmd/main -- subscribe \
  --host 127.0.0.1 --port 1883 --qos 1 --count 1 \
  "sensors/+"
```

使用 TLS：

```bash
moon run --target native cmd/main -- publish \
  --host broker.example.com --port 8883 --tls --qos 1 \
  devices/status online
```

`--insecure` 会关闭证书校验，只能用于本地测试。

## 作为协议库使用

```moonbit
let packet = @mqtt.Packet::PublishPacket({
  topic: "factory/line-1/temperature",
  payload: @mqtt.encode_mqtt_utf8("23.4").unwrap(),
  qos: @mqtt.QoS::AtLeastOnce,
  retain: false,
  duplicate: false,
  packet_id: Some(7),
  properties: [
    @mqtt.Property::PayloadFormatIndicator(1),
    @mqtt.Property::ContentType("text/plain"),
    @mqtt.Property::UserProperty("unit", "Cel"),
  ],
})

let wire = @mqtt.encode_packet(packet).unwrap()
let decoded = @mqtt.decode_exact_packet(wire).unwrap()
```

流式输入使用 `PacketStreamDecoder`：

```moonbit
let decoder = @mqtt.PacketStreamDecoder::new()
let first = decoder.feed(b"\xc0")       // 暂无完整报文
let second = decoder.feed(b"\x00\xd0\x00") // PINGREQ + PINGRESP
```

## 作为 Native 客户端使用

```moonbit
let client = @native.NativeClient::connect(
  @native.NativeOptions::new("127.0.0.1", port=1883),
  @mqtt.ConnectPacket::new("sensor-7"),
).unwrap()

defer client.close()

client.publish(
  "factory/line-1/temperature",
  @mqtt.encode_mqtt_utf8("23.4").unwrap(),
  qos=@mqtt.QoS::AtLeastOnce,
)
```

完整示例位于 [`examples/`](examples/)。

## 架构

```text
Application / CLI
        │
        ▼
NativeClient ─── TCP / TLS (moonbitlang/async)
        │
        ▼
ClientSession ── packet id / QoS / subscription / ping state
        │
        ▼
Packet codec ─── fixed header / properties / payload validation
        │
        ▼
Bytes / stream decoder
```

核心设计原则：

1. 协议核心不依赖网络和操作系统；
2. 编解码不隐式修改会话状态；
3. 状态机根据输入返回明确的响应报文和应用事件；
4. 非法输入返回结构化 `MqttError`，而不是静默容错；
5. QoS 2 的应用消息只在 PUBREL 阶段交付一次。

更详细的模块说明见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

## 支持矩阵

| 能力 | 状态 |
|---|---|
| MQTT 5.0 报文编解码 | 已实现 |
| QoS 0/1/2 会话流程 | 已实现 |
| TCP 客户端 | 已实现，Native |
| TLS 客户端 | 已实现，Native |
| 流式拆包/粘包 | 已实现 |
| 用户名/密码认证 | 已实现 |
| Enhanced Authentication 报文 | 已实现，应用层流程需自行驱动 |
| 自动重连 | 规划中 |
| 离线发送队列 | 规划中 |
| WebSocket 传输 | 规划中 |
| 浏览器网络客户端 | 规划中；协议核心已支持 JS/Wasm |
| MQTT 3.1.1 | 非目标 |
| Broker 实现 | 非目标 |

逐报文能力见 [`docs/PROTOCOL_SUPPORT.md`](docs/PROTOCOL_SUPPORT.md)。

## 测试与质量门禁

```bash
# 跨平台协议核心
moon test --target wasm
moon test --target js

# Native 客户端和模拟 Broker 端到端测试
moon test --target native

# 格式与公开接口
moon fmt --check
moon info

# 本地有 Mosquitto 时执行真实 Broker 往返
moon run --target native integration/mosquitto
```

测试包含规范字节向量、所有控制报文往返、属性约束、非法报文、UTF-8、拆包/粘包、
客户端生命周期、QoS 1/2 状态机以及 TCP 端到端流程。协议核心当前语句覆盖率为
`1160/1447`（80.2%）。

## 已知边界

- `moonbitlang/async` 的 API 仍在演进，Native 网络包可能需要随工具链升级调整；
- 当前客户端适合单任务顺序驱动；多任务同时调用同一个客户端尚未提供并发保护；
- 自动重连、持久会话恢复、离线队列和流控窗口将在后续版本实现；
- TLS 依赖系统信任根；`--insecure` 不应在生产环境使用；
- 本项目尚未通过官方 MQTT 5.0 一致性认证，因此不会宣称完全合规。

安全问题请按照 [`SECURITY.md`](SECURITY.md) 私下报告。

## 项目文档

- [参赛项目提案](docs/PROPOSAL.zh-CN.md)
- [架构设计](docs/ARCHITECTURE.md)
- [协议支持矩阵](docs/PROTOCOL_SUPPORT.md)
- [演示与答辩脚本](docs/DEMO_SCRIPT.zh-CN.md)
- [路线图](docs/ROADMAP.md)
- [参赛与发布检查表](docs/COMPETITION_CHECKLIST.zh-CN.md)
- [质量报告](docs/QUALITY_REPORT.md)
- [项目状态](PROJECT_STATUS.md)
- [贡献指南](CONTRIBUTING.md)

## 标准与致谢

实现以 [OASIS MQTT Version 5.0](https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html)
为规范依据；网络层使用 Apache-2.0 许可的
[`moonbitlang/async`](https://github.com/moonbitlang/async)。具体归属见 [`NOTICE`](NOTICE)。

## 许可证

Apache License 2.0。详见 [`LICENSE`](LICENSE)。
