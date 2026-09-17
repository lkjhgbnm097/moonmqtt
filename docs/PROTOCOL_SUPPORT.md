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
| Keep Alive 报文 | ✅ | PINGREQ/PINGRESP；定时调度由应用驱动 |
| Topic Alias | 编解码 ✅ | Alias 映射表尚未自动维护 |
| Enhanced Authentication | 报文 ✅ | 认证策略由应用驱动 |
| Session Resume | 部分 | Session Present 可见；重连恢复尚未自动化 |
| Receive Maximum 流控 | 属性 ✅ | 发送窗口尚未自动限流 |

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
