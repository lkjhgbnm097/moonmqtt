# MoonMQTT 公开开发日志

本日志将公开 Git 提交与可验证能力对应起来。它只记录已经进入仓库、能够通过自动测试
复现的工作，不把空提交或仅改时间戳计入开发成果。

## 2026-09-17：0.1.0-rc MVP

- `e1e0474`：完成 MQTT 5.0 报文编解码、会话状态机、Native TCP/TLS、CLI、示例、
  测试与项目文档；
- `8a38ed3`：补充公开仓库地址；
- `4994aca`：修正 SUBACK 成功 Reason Code 的处理；
- `c6c6347`：统一 MoonBit 格式。

这一阶段形成了可构建、可测试、可连接 Broker 的首个 MVP。

## 2026-09-19：可靠连接与资源边界

- `69a7359`：新增 MQTT 主题过滤器匹配，覆盖 `+`、`#`、共享订阅与系统主题；
- `908de4c`：为流式解码器增加单报文大小限制；
- `9ca1d1c`：执行服务端 `Receive Maximum` 发送窗口；
- `eab1c7a`：执行服务端 `Maximum Packet Size` 出站限制；
- `68c31b5`：新增可配置的重连退避、抖动和次数上限；
- `ba97779`：新增确定性 Keep Alive 调度与超时判断；
- `aed979f`：新增有界离线发布队列及两种溢出策略；
- `d862232`：实现 Clean Start / Session Present 驱动的持久会话恢复和重发。

每个功能提交完成后均运行 `moon info`、`moon fmt`、全目标严格检查和全目标测试。
本轮最终结果为 Wasm、Wasm-GC、JavaScript 各 37/37，Native 38/38；协议核心语句
覆盖率为 1315/1623（81.0%）。

## 尚未完成

- 将 `ReconnectPolicy` 接入 Native 自动重连传输循环；
- 连接恢复后自动排空 `OfflinePublishQueue`；
- WebSocket/WSS 与浏览器传输；
- 更多 Broker 兼容性、长时间压力和故障注入测试。

这些内容明确保留在路线图中，避免把基础原语误写成已经完成的端到端能力。
