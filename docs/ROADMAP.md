# Roadmap

## 0.1：协议和可运行客户端

- [x] MQTT 5 控制报文模型；
- [x] 编解码和属性校验；
- [x] 流式拆包/粘包；
- [x] QoS 0/1/2 状态机；
- [x] Native TCP/TLS；
- [x] CLI、示例、CI、模拟 Broker 与 Mosquitto 集成入口。

## 0.2：可靠连接

- [ ] 自动重连和带抖动的指数退避；
- [ ] Session Present 驱动的重发策略；
- [ ] Receive Maximum 发送窗口；
- [ ] Maximum Packet Size 协商；
- [ ] 可配置 Keep Alive 调度器；
- [ ] 离线发送队列及容量策略。

## 0.3：跨端传输

- [ ] Native WebSocket/WSS；
- [ ] 浏览器 WebSocket 适配；
- [ ] Node.js TCP 适配；
- [ ] 统一 Transport 接口；
- [ ] 浏览器协议分析 Playground。

## 0.4：一致性与可观测性

- [ ] MQTT 官方/社区一致性测试语料；
- [ ] Mosquitto、EMQX、HiveMQ 兼容矩阵；
- [ ] 属性和报文生成式测试；
- [ ] 解析器 fuzz harness；
- [ ] 结构化 trace、指标和脱敏日志。

版本里程碑按能力完成情况发布，不承诺固定日期。
