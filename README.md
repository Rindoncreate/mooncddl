# MoonCDDL

MoonBit 原生的标准 CDDL 数据结构模式编译与校验工具，MIT，作者 Rindoncreate，代码与技术文档含 AI 辅助。

状态：0.1.0 开发中，尚未发布、未报名或通过赛事审核。

CDDL 是 RFC 8610 定义的数据描述语言，不是本项目自创语言。输入一份模式，重复检查 JSON 或 CBOR 数据；输出匹配结果或带路径的错误。JSON Schema 验证器不直接解析 CDDL，CBOR 编解码器不自动提供 CDDL 的规则引用、重复项和结构匹配语义。

## 当前范围

语义标识：`rfc8610-structural-v1`，是公开限定的 RFC 8610 子集，**不是完整 RFC 8610 实现**。

- 规则定义与引用、类型选择 `/`、整数闭/半开区间、文本/整数/布尔/null 字面量。
- `any`、`uint`、`nint`、`int`、`float`、`bool`、`tstr/text`、`bstr/bytes`。
- 数组顺序、可选/重复项 `? * + n*m`；记录、可选成员、整数或文本键、类型键 `=>`、闭合/开放结构。
- 有消耗的递归类型；拒绝无消耗引用环；UTF-8 字节 `.size`、uint 容量 `.size N`、`#6.n(type)` 标签。
- 明确区分不匹配、无效模式、输入错误和预算耗尽。编译规则私有，不把可变 AST 暴露给调用者。

不支持 group choice `//`、独立 group 引用/展开、generics、sockets、扩展赋值、浮点宽度类型、字节字面量、任意控制运算符或网络加载。`.regexp` 不用宿主正则冒充标准 XSD 正则。

Value/CBOR 整数为有符号 64 位域；JSON 适配器只接收精确安全整数，超出时显式报错。CBOR 键限定文本/整数，记录最多 128 个成员。不是全量 CBOR 语义验证器。

## 库调用

```moonbit
let schema = @mooncddl.compile("message = { id: uint, readings: [1*8 int] }")
let result = schema.validate_json("{\"id\":1,\"readings\":[12,13]}")
// None 表示匹配；Some(Diagnostic) 表示数据不匹配；模式/资源错误抛 CddlError。
```

```sh
moon check --target js --deny-warn
moon test --target js --deny-warn
```

核心校验没有 I/O。`Rindoncreate/mooncddl/cbor` 适配器复用 `2515050242/cbor@0.1.2` 解码，不重复编写 CBOR 编解码库。该适配器在调用依赖前检查输入大小、嵌套、条目数和长度，避免仅在解码后才检查资源。

## 真实用途

1. 服务端收到 JSON 消息时，在业务逻辑前按共享 CDDL 约定验证必填字段、类型和批量上限。
2. 设备或协议工具收到 CBOR 消息时，保留整数键、字节串和标签，按同一标准描述验证结构。
3. 协议库发布前，在 CI 中检查正反样本；不支持的语法必须显式失败，不能静默放行。

这些是预期使用场景，不冒充已有外部用户、生产部署或社区采纳。

## 归属与标准

原创实现，依据 [RFC 8610](https://www.rfc-editor.org/rfc/rfc8610.html) 的公开语义；不复制其他验证器源码。独立差分测试使用 PyCDDL 0.6.4（Rust CDDL 引擎）与 cbor2 5.6.5，均不进入运行时。

此前宠物 App 与 MoonSchedule 维护成果保持独立，不计入本项目代码或提交。本项目的技术说明不是选手人工正式申报书。
