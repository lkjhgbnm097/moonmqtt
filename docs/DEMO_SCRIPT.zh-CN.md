# MoonMQTT 演示与答辩脚本

## 目标

在 6 至 8 分钟内证明项目不是静态界面，而是一套可复用、可运行、可验证的 MQTT 5
协议基础设施。

## 演示准备

1. 本地启动 Mosquitto 2.x，监听 `127.0.0.1:1883`；
2. 打开两个终端；
3. 在仓库根目录执行 `moon test --target native`，确认全部测试通过。

## 演示流程

### 1. 报文分析器（约 1 分钟）

```bash
moon run --target native cmd/main -- inspect "30 06 00 01 61 00 68 69"
```

说明输出中识别出了 Topic `a`、Payload `hi`、QoS 0 和空属性列表。把固定报头 Flags
改成非法值，展示结构化错误而非崩溃。

### 2. 真实 Broker 发布订阅（约 2 分钟）

终端 A：

```bash
moon run --target native cmd/main -- subscribe \
  --host 127.0.0.1 --qos 2 --count 1 "factory/+/temperature"
```

终端 B：

```bash
moon run --target native cmd/main -- publish \
  --host 127.0.0.1 --qos 2 \
  "factory/line-1/temperature" "23.4"
```

强调连接、订阅、QoS 2 四阶段握手和消息交付都由 MoonBit 代码完成。

### 3. 自动测试（约 1 分钟）

```bash
moon test --target wasm
moon test --target native
```

解释 Wasm 测试验证协议核心的可移植性，Native 测试额外启动内存内模拟 Broker，验证
真实 TCP 字节流。

### 4. 架构和关键决策（约 2 分钟）

展示 `docs/ARCHITECTURE.md`：

- 编解码器不依赖网络；
- 状态机返回响应和应用事件；
- NativeClient 只负责搬运字节；
- QoS 2 消息在 PUBREL 时才交付，重复 PUBLISH 不会重复进入应用。

### 5. 生态价值和路线图（约 1 分钟）

说明 MQTT 是工业物联网、智能家居和边缘计算常用协议；MoonMQTT 为 MoonBit 补上可直接
连接现有 Broker 的基础库。后续重点是重连、流控、WebSocket 和多 Broker 兼容矩阵。

## 常见问答

**为什么不直接绑定 C MQTT 库？**

协议核心使用纯 MoonBit，能够在 Wasm/JS 复用、做确定性测试，也更能验证 MoonBit
处理二进制协议和状态机的能力。

**是否完全符合 MQTT 5.0？**

项目严格参照 OASIS 规范并进行了大量校验，但尚未完成官方一致性认证，因此不做完全
合规承诺。

**与一个简单 Demo 有什么区别？**

项目包含完整报文模型、属性规则、流式解析、QoS 状态机、TCP/TLS、CLI、跨目标测试和
真实 Broker 集成入口，可作为其他 MoonBit 应用的依赖。
