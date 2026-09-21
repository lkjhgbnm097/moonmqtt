# MoonMQTT Guard Roadmap

路线图只把发布治理能力计为项目差异化；通用客户端能力仅作为参考适配器维护。

## 0.1：消息契约门禁 MVP

- [x] Topic Filter 契约选择与未登记 Topic 默认拒绝；
- [x] Payload、QoS、Retain 联合约束；
- [x] Content Type 和 User Property 用途/Schema 约束；
- [x] Message Expiry 约束；
- [x] Response Topic / Correlation Data 完整性约束；
- [x] 稳定的机器可读拒绝原因；
- [x] 跨目标测试和无 Broker 演示；
- [x] 同类项目差异审计。

## 0.2：可部署策略

- [ ] JSON/TOML 策略加载与严格 Schema；
- [ ] 契约名称和版本冲突检查；
- [ ] 重叠 Topic Filter 的静态诊断；
- [ ] 不包含载荷的审计事件编码；
- [ ] 配置热替换的原子快照 API。

## 0.3：现有客户端适配

- [ ] `Strangelight-Merser/moon-mqtt-client` 发布前 adapter 示例；
- [ ] 参考 NativeClient 的 opt-in 门禁 hook；
- [ ] 浏览器/Wasm 抓包审计演示；
- [ ] CI 批量测试向量格式。

## 0.4：治理验证

- [ ] 基于性质的契约测试；
- [ ] 策略规则 fuzz harness；
- [ ] 多版本 Schema 迁移策略；
- [ ] 脱敏指标与审计完整性测试；
- [ ] 工业遥测和远程命令的端到端案例。

明确不进入路线图：重新实现完整 Broker、与通用客户端竞争更多传输协议，或仅靠增加 MQTT
字段数量主张创新。
