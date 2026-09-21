# MoonMQTT Guard 参赛与发布检查表

## 一、差异化作品本体

- [x] 主定位改为 MQTT 5 消息契约与发布治理，不再申报通用客户端；
- [x] 检索并记录直接相关的 codec、客户端和 Broker；
- [x] 解释与近期 Mooncakes MQTT 客户端的上下层组合关系；
- [x] 实现 Topic、Payload、QoS、Retain、Content Type、User Property 和 TTL 契约；
- [x] 实现 request/response 关联信息门禁；
- [x] 实现未登记 Topic 默认拒绝和完整违规列表；
- [x] 提供无 Broker 的差异化演示与测试；
- [x] 重写 README、申报书、架构、路线图和答辩脚本。

## 二、代码质量门禁

- [x] `moon check --target all --deny-warn` 通过；
- [x] `moon test --target all --deny-warn` 通过；
- [x] Wasm/Wasm-GC/JavaScript 各 43/43，Native 44/44；
- [x] `moon fmt --check` 通过；
- [x] `moon info` 已更新公开接口；
- [x] `moon run examples/release_gate` 实跑通过；
- [x] 仓库忽略工具链、构建产物、密钥和本地环境文件；
- [ ] 推送后 GitHub Actions 全部通过。

## 三、公开发布

- [x] 公开仓库为 <https://github.com/lkjhgbnm097/moonmqtt>；
- [ ] GitHub About 改为“MQTT 5 message-contract and publish-governance gate”；
- [ ] 确认默认分支 `main` 和公开可见性；
- [ ] 确认最新提交的 GitHub Actions；
- [ ] 配置 Mooncakes 命名空间与发布凭据；
- [ ] 在干净目录安装并运行发布包；
- [ ] 创建版本标签和 Release。

不得提交 GitHub Token、Mooncakes Token、Broker 密码、证书私钥或 `.env` 文件。

## 四、演示与报名

- [ ] 按 `docs/DEMO_SCRIPT.zh-CN.md` 录制 5～7 分钟演示；
- [ ] 首先演示 Release Gate，而不是 TCP/TLS 或发布订阅；
- [ ] 同屏展示一个 Permit 和一个多项 Deny；
- [ ] 展示 `docs/DIFFERENTIATION.md` 的同类项目矩阵；
- [ ] 报名项目名填写“MoonMQTT Guard——基于 MoonBit 的 MQTT 5 消息契约与发布治理门禁”；
- [ ] 上传最新版 `docs/PROPOSAL.zh-CN.md`；
- [ ] 填写成员、联系方式、视频和 Mooncakes 链接；
- [ ] 从未登录窗口确认仓库和文档可访问；
- [ ] 保存表单回执与对应 commit SHA。

## 五、文案红线

- 不再用“MoonBit 生态缺少 MQTT 客户端”作为立项依据；
- 不把 TLS、重连、QoS、离线队列写成与现有客户端的差异；
- 不写“完全兼容”“生产级”“官方认证”；
- 明确协议适配底座、原创门禁逻辑和第三方依赖的边界；
- 所有“已完成”必须能由公开代码、测试或演示复现。
