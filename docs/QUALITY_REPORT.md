# MoonMQTT 0.1.0-rc 质量报告

本报告记录 2026-09-17 至 2026-09-19 完成的本地可重复质量门禁。

## 验证环境

- 操作系统：Windows；
- MoonBit：`moon 0.1.20260915 (2e1a46d 2026-09-15)`；
- 核心目标：Wasm、Wasm-GC、JavaScript、Native；
- 网络测试：进程内模拟 Broker；真实 Mosquitto 由 CI 任务执行。

## 门禁命令

```bash
moon fmt --check
moon info
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native --release
moon coverage analyze -p moonmqtt/moonmqtt
moon coverage report -f summary -p moonmqtt/moonmqtt
moon run examples/codec
moon run --target native cmd/main -- inspect "30 06 00 01 61 00 68 69"
```

## 当前结果

| 门禁 | 结果 |
|---|---|
| 格式与接口生成 | 通过；连续两次 `moon info` 结果一致 |
| Wasm 严格检查/测试 | 通过，37/37 |
| Wasm-GC 严格检查/测试 | 通过，37/37 |
| JavaScript 严格检查/测试 | 通过，37/37 |
| Native 严格检查/测试 | 通过，38/38 |
| Native release 构建 | 通过；第三方 async C 源码有一条 Windows 宏重定义警告 |
| 协议核心覆盖率 | 1315/1623，81.0% |
| 纯协议示例 | 通过 |
| CLI 十六进制解析 | 通过 |
| 真实 Mosquitto 往返 | 本机无 Mosquitto；CI 已配置，公开仓库运行后确认 |

`moon publish --dry-run --frozen` 也已尝试；Moon CLI 在读取包内容前要求登录，当前环境没有
Mooncakes 凭据，因此发布预检保留到项目所有者登录后执行。

## 测试重点

- MQTT Variable Byte Integer 规范向量与非法编码；
- 15 类控制报文编解码往返；
- 全部 MQTT 5 属性的类型、位置、重复和取值约束；
- Reason Code、主题名、主题过滤器、共享订阅与认证字段语义；
- UTF-8 截断、过长编码、禁用标量与十六进制输入错误；
- 网络拆包、粘包和连续报文；
- 流式单报文内存上限和主题过滤器匹配；
- CONNECT/CONNACK、QoS 1、QoS 2、订阅、取消订阅和 Ping 状态机；
- Receive Maximum、Maximum Packet Size 与持久会话恢复；
- 重连退避、Keep Alive 调度和有界离线队列；
- 真实 TCP 上的模拟 Broker 握手、发布、确认与断开。

## 尚未声称

测试通过不等于官方 MQTT 一致性认证。当前版本也未完成第三方安全审计、长时间压力测试、
弱网故障注入或所有 Broker 的兼容性验证。
