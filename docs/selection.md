# 选题依据与查重（2026-10-22）

选择：原创 MoonCDDL 标准数据结构模式编译/校验库，走新项目方向。参赛者应能掌握目标、实现和质量；不把 AI 辅助等同于本人已理解。

已重新读取正式赛事章程及官网。项目目标是通用开发工具与协议基础组件，不是单一终端产品；新代码与归属独立，避免第三方维护项目主要贡献者资格不清。

直接 Mooncakes CLI 查询：`cddl`、`concise data definition` 均成功返回空结果。这是当前关键词查询结果，不能据此声称全生态绝对不存在相关项目。

排除方向：

| 方向 | 已有实现 | 取舍 |
| --- | --- | --- |
| OpenAPI 兼容检查 | WeiR-h/moonapi_check 0.1.1 | 不另建重叠工具 |
| MoonBit API 兼容检查 | FidollarinLA/moon_api_guard 0.6.1、hmc11234/mooncompat 0.1.0 | 不另建重叠工具 |
| SARIF | Derk2006/sarifkit、Noverberrain/moonsarif | 不另建重叠工具 |
| Unicode bidi | moonbit-community/unicode、tonyfettes/unicode | 不另建重叠工具 |
| JSON Schema/JTD | mizchi/jsonschema、Xu107-hhh/moonbit-jsonschema、ppyj663/moonjtd 等 | 不再造此类验证器；CDDL 是不同输入标准 |
| CBOR 编解码 | mizchi/cbor、2515050242/cbor | 复用后者当前源码并适配，不将编解码记为本项目原创 |

`2515050242/cbor` 已有手工构建的 ValidationRule API。它的对象字段/业务规则检查不接受 RFC 8610 CDDL 文本，没有本项目的 CDDL lexer、引用检查和数组 occurrence 匹配语义。我们的增量位于标准模式语言一层；不能把“存在 CDDL 文本入口”本身当作价值全部，仍需通过互操作测试和公开支持矩阵证明。

其他语言已有成熟 CDDL：anweiss/cddl（Rust）、PyCDDL、cabo/cddl（Ruby）。CDDL 不是新发明；MoonBit 内嵌、可移植库与标准模式复用是本项目的目标。开发中用 Rust 实现做独立差分参照，不宣称性能优于成熟实现。

必须继续完成：规范行到测试的支持矩阵、对照结果原始记录、三个可运行消费场景、CI、公开历史、Mooncakes 安装验证。官方初审未通过前，不宣称选题一定获准。
