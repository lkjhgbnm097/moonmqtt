# 2026 年 9 月 MoonBit 黑客松项目提案：MoonMQTT

## 一、项目名称

MoonMQTT：跨 Native、JavaScript 与 WebAssembly 的 MQTT 5.0 协议工具包和客户端。

## 二、项目简介

MoonMQTT 使用 MoonBit 实现 MQTT 5.0 报文编解码、属性校验、流式解析、客户端会话
状态机以及 Native TCP/TLS 客户端。项目采用“纯协议核心＋可替换传输”的架构，既能
连接现有 Mosquitto、EMQX、HiveMQ 等 Broker，也能在 Wasm/JavaScript 中复用协议解析
与 QoS 状态逻辑。

项目不是一个特定设备的最终应用，而是供物联网、工业数据、智能家居、边缘计算和协议
测试项目复用的生态基础库。

## 三、方向与通用价值

所属方向：Web 与网络基础设施、物联网协议、开发者工具。

当前 MoonBit 已经具备异步 socket 和 TLS 能力，但生态中缺少结构完整、面向 MQTT 5.0、
包含客户端状态机和测试体系的 MQTT 实现。开发者若要让 MoonBit 程序接入物联网平台，
仍需自行处理二进制协议、属性、QoS 重传和状态转换。

MoonMQTT 将这些高风险重复工作封装为可测试的公共组件，降低 MoonBit 在真实设备和消息
基础设施中的使用门槛。

## 四、完整使用场景

### 场景 1：工业传感器遥测

工厂网关使用 MoonBit 读取温度、振动和能耗数据，通过 MQTT 5.0 QoS 1 发布到现有 EMQX
集群。消息携带 Content Type、单位和设备编号等 User Property；断网恢复后可继续传输。

### 场景 2：设备命令的可靠交付

控制服务向电机、阀门或实验设备发送关键指令，使用 QoS 2 避免重复执行。MoonMQTT 的
确定性状态机处理 PUBLISH、PUBREC、PUBREL、PUBCOMP，并确保接收端只向应用交付一次。

### 场景 3：浏览器和 Wasm 协议分析

开发者把抓包得到的 MQTT 字节粘贴到浏览器工具中，由同一套 MoonBit 协议核心解析报文、
属性和错误位置。由于核心不依赖 socket，可直接编译到 Wasm/JavaScript。

### 场景 4：MoonBit 服务接入既有消息平台

Native MoonBit 服务通过 TCP 或 TLS 连接企业现有 Mosquitto/HiveMQ Broker，完成订阅、
发布、心跳和断线处理，不需要部署新的服务端组件。

## 五、核心功能

1. MQTT 5.0 十五类控制报文模型和编解码；
2. Variable Byte Integer、UTF-8、Binary Data 与完整属性类型；
3. 属性位置、重复、取值和长度校验；
4. TCP 拆包、粘包和增量解析；
5. QoS 0/1/2 发送与接收状态机；
6. 包标识符、订阅确认、取消订阅、Ping 和 Disconnect；
7. Native TCP/TLS 客户端；
8. inspect、publish、subscribe CLI；
9. Wasm、JS、Native 自动测试；
10. 模拟 Broker 和 Mosquitto 互操作测试。

## 六、交付物

- 公开 GitHub 仓库和 Apache-2.0 许可证；
- 发布到 Mooncakes 的 `moonmqtt/moonmqtt` 包；
- 协议核心、Native 客户端和 CLI 源码；
- 至少两个可运行示例；
- CI、规范字节向量、状态机和端到端测试；
- README、架构、支持矩阵、路线图和答辩脚本；
- Mosquitto 真实 Broker 往返演示。

## 七、明确非目标

- 不实现 MQTT Broker；
- 不实现完整物联网云平台或设备管理后台；
- 首版不支持 MQTT 3.1.1；
- 首版不承诺自动重连、持久离线队列和浏览器 WebSocket；
- 未完成一致性认证前不宣称 100% 兼容所有 Broker。

## 八、技术路线

项目分为报文数据模型、二进制层、属性层、编解码层、流式解码器、客户端会话状态机和
Native 传输七层。协议层不调用 socket；状态机输入一个报文，输出待发送响应和应用事件。
这种结构允许使用纯内存数据完整验证 QoS 流程，也能为未来 WebSocket/WASI 传输复用。

测试以 OASIS MQTT 5.0 规范字节格式为依据，并同时覆盖成功路径、非法 Flags、非法属性、
截断报文、UTF-8、重复 QoS 2 报文和真实 TCP 流。

## 九、原创性与参考说明

项目为原创 MoonBit 实现，不复制其他语言 MQTT SDK 源码。协议行为和字段定义参考
OASIS MQTT Version 5.0；网络 I/O 使用官方 `moonbitlang/async`。如后续引入测试向量或
参考实现，将在 NOTICE 中记录来源、许可证和差异。

## 十、验收方式

```bash
moon update
moon check --target native --deny-warn
moon test --target wasm
moon test --target native
moon run examples/codec
moon run --target native cmd/main -- inspect "c0 00"
```

在安装 Mosquitto 后执行：

```bash
moon run --target native integration/mosquitto
```

验收者可以独立完成构建、测试、报文解析和真实 Broker 往返，不依赖未公开数据或服务。
