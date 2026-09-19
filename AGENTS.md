# AGENTS.md — starry_prompt_compiler

Starry 的提示词编译核心。**纯 Dart,宿主无关**:无 Flutter、无 Riverpod、无 I/O、
无数据库。所有关于"这一轮该注入什么、按什么顺序、占多少预算"的决策都在这里,
上层(主应用、注入服务)只负责提供输入和消费结果。

本包是依赖链的最底层:

```
starry_prompt_compiler          ← 本包,不依赖任何兄弟仓
  └── starry_domain_entities
        └── starry_character_card_codec
              └── starry_injection_service
```

## 1. 架构边界

**三段式装配是主路径**:`buildPlan`(`planner/prompt_execution_planner.dart:20`)
→ `admitWorldInfoUnits`(`worldinfo/world_info_budget_admission.dart:24`)
→ `buildFromExecutionPlan`(`assembler/character_message_assembler_pure.dart:71`)。
新增能力要落进这三步中的某一步,不要在旁边另开一条装配路径。

主应用走完整三段(`Starry-Flutter-Frontend/lib/features/chat_character/
presentation/providers/character_message_assembler_provider.dart:83/89/108`)。

**已知的生产旁路**:`starry_injection_service/lib/src/application/
injection_resolver.dart:400-418` 手工构造 `PromptExecutionPlan`,跳过 `buildPlan`
直接调 `admitWorldInfoUnits`,也不调 `buildFromExecutionPlan`。

这是刻意的架构分工(注入服务只返回扁平 entries,位置由宿主决定),但要清楚它的
代价:`buildPlan` 并非纯组装,还含 `_filterUnits` 的四道筛选门(`:318-371`)、
`_applyOverrides` 的 persona override 决策(`:378-526`)、
`_buildShellSequence`(`:528`)、`_buildOutletMap`(`:584`)与
`_buildHistorySplicePoints`(`:659`)共用的四个排序比较器(`:867`/`:878`/`:911`/`:927`;
另有 `_comparePromptBlocks`@`:1246` 不在此链路)。**绕过它就没有这些决策** ——
改动这些方法时,注入服务那条路径不会自动跟上。

- **匹配、排序、预算准入只有一份实现**。`MacroService` / `RegexService` /
  `WorldInfoMatcher` 是各自领域的唯一真源;上层不得重新实现,只能调用。
- **不引入 I/O 与平台依赖**。`lib/` 下 `dart:io`、`dart:ui`、`package:flutter`
  一律禁止(当前零违反)。`test/` 下有一处例外
  (`text_recall_calibration_test.dart:21` 用 `dart:io` 读标定数据),
  测试侧按需放行,生产代码不行。
- 依赖保持最小:当前仅 `intl`。新增依赖需先确认它也是纯 Dart 且无平台绑定。

## 2. `version` 字段不是兼容层

`SessionPromptContext.version` 默认写 2,但**全仓没有任何按版本分支的读取逻辑**
—— 不同版本走的是同一套语义。

- **不要把它当作已生效的兼容机制**,也不要据此推断"旧版本数据会被特殊处理"。
- 真要做版本分化时,先补分支逻辑和测试,再让字段有意义;在那之前它只是元数据。

## 3. `effectiveOverrides` 有生产写入方

`ExecutionOverrideDecision` / `effectiveOverrides` 容易被误判为死代码:
**生产代码在写入**(`prompt_execution_planner.dart:63`),只是当前**读取方只有
测试**。它是 persona override 的审计出口,不是悬空能力,不要按零引用删。

## 4. 验证

```powershell
dart analyze
dart test
dart format --set-exit-if-changed .
```

三条当前全绿(analyze 无 issue、177 用例全过、40 文件 0 changed；前提是本仓的 format 改动已提交)。

注意本机与 CI 是**同一个 Dart**:主仓四个 workflow 都钉 `flutter-version: 3.44.4`,
它捆绑 Dart 3.12.2,与本机一致。所以本地格式化的结果与 CI 环境一致,不会
反复横跳。但 **CI 目前不检查这四个兄弟包的格式**(workflow 里没有任何
`dart format` 步骤,兄弟包只被 checkout 到 `__siblings/` 供 `pub get` 解析),
格式回潮不会被自动拦住,提交前自己跑。

改动影响上层时,回主工程 `D:\Starry-1.07\Starry-Flutter-Frontend` 跑
`flutter analyze` 与 `flutter test`——本包全绿不代表上层能编译。

## 5. 约定

- 不写墓碑注释("这里删了 X / 待清理"),版本历史可追溯。
- 不为假想的未来场景预埋兼容层、fallback 或双轨逻辑。
- 判断"零调用"时先分清:**生产写入** / 仅测试读取 / 真零引用。三者处置不同。
- 不在工作区根目录 `D:\Starry-1.07` 下创建任何文件,规则见根目录 `AGENTS.md`。
