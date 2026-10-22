# MoonCDDL

MoonBit 原生的标准 CDDL 数据结构模式编译与校验工具，MIT，作者 Rindoncreate，代码与技术文档含 AI 辅助。

状态：0.1.0 本地首版已实现，尚未发布到 Mooncakes、未报名或通过赛事审核。公开仓库和远端 CI 状态见验收记录。

公开源码：[Rindoncreate/mooncddl](https://github.com/Rindoncreate/mooncddl)。这是独立原创项目，之前的产品与上游维护 PR 均不计入本项目成果。

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

## 命令行与可复现示例

需要 MoonBit CLI、Node.js 22+。Node 仅处理文件读写、UTF-8 解码、输出和退出状态；模式分析与全部校验逻辑在 MoonBit 中。

```sh
moon build --target js --deny-warn
node bin/mooncddl.mjs check examples/service/schema.cddl examples/service/valid.json --json
node bin/mooncddl.mjs check examples/device/schema.cddl examples/device/valid.cbor --input cbor --json
node bin/mooncddl.mjs check examples/protocol/schema.cddl examples/protocol/invalid.json --json
```

第三条有意返回退出码 1，错误路径 `/1`；服务消息错误样本定位 `/readings/0/value`。正确返回码为 0；无效模式 2、输入错误 3、资源耗尽 4、命令用法错误 64。`--root NAME` 可选择其他根规则。CLI 不联网、不执行模式代码。

完整本地验证：

```sh
python -m venv .venv
# Windows: .venv/Scripts/python.exe；其他平台: .venv/bin/python
.venv/bin/python -m pip install --only-binary=:all: -r tools/requirements.txt
node tools/verify.mjs
```

Windows 脚本默认选取项目 `.venv/Scripts/python.exe`；其他平台用 `PYTHON` 指定虚拟环境解释器。CI 重新生成独立向量并拒绝漂移，然后运行四后端检查/构建/测试、真实 CLI 正反路径与打包。

当前是 23 个 MoonBit 测试块，其中一个表驱动测试覆盖 134 个规范分区；不能将两个数字相加当作测试数或覆盖率。与固定版本 Rust 参考引擎的结果为 123/134 一致，另 11 项差异保留输入、外部结果及规范解释，见[差异记录](docs/reference-deviations.md)。不宣传全量标准兼容或独立对照全通过。

详细边界见[支持矩阵与资源契约](docs/profile.md)，归属见[第三方说明](THIRD_PARTY.md)，选题依据见[查重记录](docs/selection.md)。

核心校验没有 I/O。`Rindoncreate/mooncddl/cbor` 适配器复用 `2515050242/cbor@0.1.2` 解码，不重复编写 CBOR 编解码库。该适配器在调用依赖前检查输入大小、嵌套、条目数和长度，避免仅在解码后才检查资源。

## 真实用途

1. 服务端收到 JSON 消息时，在业务逻辑前按共享 CDDL 约定验证必填字段、类型和批量上限。
2. 设备或协议工具收到 CBOR 消息时，保留整数键、字节串和标签，按同一标准描述验证结构。
3. 协议库发布前，在 CI 中检查正反样本；不支持的语法必须显式失败，不能静默放行。

这些是预期使用场景，不冒充已有外部用户、生产部署或社区采纳。

## 归属与标准

原创实现，依据 [RFC 8610](https://www.rfc-editor.org/rfc/rfc8610.html) 的公开语义；不复制其他验证器源码。独立差分测试使用 PyCDDL 0.6.4（Rust CDDL 引擎）与 cbor2 5.6.5，均不进入运行时。

此前宠物 App 与 MoonSchedule 维护成果保持独立，不计入本项目代码或提交。本项目的技术说明不是选手人工正式申报书。
