# 参赛者需要掌握的五件事

这份说明含 AI 辅助，用于学习和核对事实，不是人工申报书，也不能代替本人理解。

1. **解决什么问题？**协议约定要求“编号是非负整数、读数至少一条、最多八条”。收到数据后，工具在业务代码前检查约定，指出哪个位置不对。它面向库作者、服务端开发者和协议测试人员。
2. **和 JSON/CBOR 库有什么不同？**编解码库能读出数据；本项目继续检查数据是否符合 CDDL 规则。CDDL 是已有标准，当前项目实现其明确列出的结构子集。CBOR 解码仍归现有依赖作者所有。
3. **核心代码怎样工作？**lexer 把模式文本切成 token，parser 生成私有规则结构并检查引用。validate 按规则遍历数据：数组按顺序匹配，map 不依赖键顺序。最后输出匹配或错误，资源不够则单独报错。
4. **最容易写错什么？**`[* int, int]` 的最后一个 int 是必需的，不能让前面的星号贪心吃完；`tstr .size 3` 中“猫”是三个 UTF-8 字节；重复 JSON 键和 CBOR 大长度必须在错误层处理；浮点舍入不能把分数伪装成整数。
5. **验证能证明到哪一步？**三个本地后端和独立样本已运行，23 是测试块数，134 是语义样本数。Rust 参照有十一项已记录差异，不声称全标准通过。首版不支持任意 IETF CDDL、所有控制符、group/generics，也没有真实外部用户证明。

可以现场演示：先运行 `node bin/mooncddl.mjs check examples/service/schema.cddl examples/service/valid.json --json` 得到 valid；再换成 invalid.json，看错误定位到 `/readings/0/value`。随后解释 `lexer.mbt`、`parser.mbt`、`validate.mbt` 与 `cbor/adapter.mbt` 分工。
