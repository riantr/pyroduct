name = "riantr/pyroduct"

version = "0.1.19"

readme = "README.mbt.md"

repository = "https://gitee.com/ren-yongxiang/pyroduct.git"

license = "MIT"

keywords = [
  "state-machine",
  "hermeneutics",
  "multi-agent",
  "causal-inference",
  "research-coordinator",
  "语料建模",
  "科研协调",
  "驱动槽",
  "执行契约",
]

description = "把《伽达默尔与哈贝马斯真理观比较》与《通往宁静之路》建模为可运行、可测试的 MoonBit 状态机族（主体／多主体／群体／双层次社会交往），外加 Agent 状态机（进化层：变异／闸门／只追加账本）与科研 Agent 协调器。"

// 《通往宁静之路》主体状态机（含驱动槽八分与「位置 × 槽」执行契约）→ 多主体行为规则
// → 群体状态机／双层次社会交往模型
// → 进化层（变异／适应度／更新闸门／持久化／遗传，闸门可用 DoubleML 判因果效应；
// 主体循环把驱动槽接到真迁移表上，修习与开放两个候选都过同一个闸门）
// → 科研 Agent 协调器（制品／规划／外部证据／决策分段／内容记忆／署名／运行时）。
// 依赖：moonbitlang/async 仅供 cmd/coord（native）真实落盘；riantr/moonbit_doubleML
// 仅供 dmlref（与外部参考实现互校自研 DoubleML）与 causal（0.75.0 深用诊断层：
// 敏感性／多重检验／异质性，只读）；riantr/snn_mbt（连带 riantr/moonbit_image）
// 仅供 snnref（native 专属的脉冲沉淀实验层）；riantr/moonbit_static_analysis
// 仅供 audit（三鉴自审计：它的 moon.mod 把本仓库点名为参考消费者）。
// 其余包仍不依赖第三方库。
// 见 https://moonbitlang.com 了解 moon.mod。

import {
  "moonbitlang/async@0.22.4",
  "riantr/moonbit_doubleML@0.75.0",
  "riantr/snn_mbt@0.84.0",
  "riantr/moonbit_static_analysis@0.1.0",
}
