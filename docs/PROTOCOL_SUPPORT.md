# MQTT 5.0 支持矩阵

## 控制报文

| 报文 | 编码 | 解码 | 会话处理 |
|---|---:|---:|---:|
| CONNECT | ✅ | ✅ | ✅ |
| CONNACK | ✅ | ✅ | ✅ |
| PUBLISH | ✅ | ✅ | ✅ |
| PUBACK | ✅ | ✅ | ✅ |
| PUBREC | ✅ | ✅ | ✅ |
| PUBREL | ✅ | ✅ | ✅ |
| PUBCOMP | ✅ | ✅ | ✅ |
| SUBSCRIBE | ✅ | ✅ | ✅ |
| SUBACK | ✅ | ✅ | ✅ |
| UNSUBSCRIBE | ✅ | ✅ | ✅ |
| UNSUBACK | ✅ | ✅ | ✅ |
| PINGREQ | ✅ | ✅ | ✅ |
| PINGRESP | ✅ | ✅ | ✅ |
| DISCONNECT | ✅ | ✅ | ✅ |
| AUTH | ✅ | ✅ | 事件透传 |

## MQTT 5 属性

已实现 Payload Format Indicator、Message Expiry Interval、Content Type、Response Topic、
Correlation Data、Subscription Identifier、Session Expiry Interval、Assigned Client
Identifier、Server Keep Alive、Authentication Method/Data、Request Problem/Response
Information、Will Delay Interval、Response Information、Server Reference、Reason String、
Receive Maximum、Topic Alias Maximum、Topic Alias、Maximum QoS、Retain Available、User
Property、Maximum Packet Size、Wildcard/Subscription Identifier/Shared Subscription
Available。

属性会同时进行数据类型校验、布尔取值校验、非零约束、报文位置校验和单例重复校验。

## 协议语义校验

- 按报文类型检查 MQTT 5 Reason Code 合法集合；
- 校验 CONNACK 拒绝连接时 `Session Present` 必须为 false；
- 校验 PUBLISH/Will/Response Topic 主题名与通配符限制；
- 空 PUBLISH Topic Name 仅在携带非零 Topic Alias 时允许；
- 校验 `+` 和 `#` 在主题过滤器中的层级位置；
- 校验共享订阅组名、过滤器与 No Local 约束；
- 匹配普通、通配符、共享订阅和 `$SYS` 主题过滤器；
- 校验 Authentication Data 对 Authentication Method 的依赖；
- 校验空 Client Identifier 与 Clean Start 的组合。

## 会话能力

| 能力 | 状态 | 说明 |
|---|---|---|
| Clean Start | ✅ | CONNECT 字段支持 |
| Will Message | ✅ | QoS、Retain、属性和二进制 Payload |
| 用户名/密码 | ✅ | 密码按 Binary Data 编码 |
| QoS 0 | ✅ | 直接交付 |
| QoS 1 | ✅ | PUBLISH/PUBACK |
| QoS 2 | ✅ | 四阶段发送与接收、重复抑制 |
| 多主题订阅 | ✅ | 每项独立订阅选项 |
| 取消订阅 | ✅ | 多主题 Filter |
| Keep Alive 报文与调度 | ✅ | PINGREQ/PINGRESP；`KeepAliveTracker` 可由传输循环驱动 |
| Topic Alias | 编解码 ✅ | Alias 映射表尚未自动维护 |
| Enhanced Authentication | 报文 ✅ | 认证策略由应用驱动 |
| Session Resume | ✅ | Clean Start / Session Present 驱动保留、重发或清理状态 |
| Receive Maximum 流控 | ✅ | 限制未确认的 QoS 1/2 出站 PUBLISH 数量 |
| Maximum Packet Size | ✅ | Session 与 NativeClient 均拒绝超出服务端限制的报文 |
| 重连退避 | 策略 ✅ | 指数退避、抖动与次数上限；传输循环由应用驱动 |
| 离线发布队列 | ✅ | 有界队列，支持拒绝或丢弃最旧消息 |

## 传输

| 传输 | 状态 |
|---|---|
| Native TCP | ✅ |
| Native TLS | ✅，支持系统根证书或测试用跳过校验 |
| WebSocket | 规划中 |
| Browser WebSocket | 规划中 |
| WASI socket | 规划中 |

## 明确非目标

- MQTT 3.1 和 3.1.1；
- MQTT Broker；
- 云端设备管理平台；
- 在协议库内部存储业务消息。
