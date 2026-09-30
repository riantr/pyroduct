name = "moonseek/lava_conduit"

version = "0.1.0"

// 《通往宁静之路》主体状态机 → 多主体行为规则 → 群体状态机／双层次社会交往模型
// → 进化层（变异／适应度／更新闸门／持久化／遗传，闸门可用 DoubleML 判因果效应）
// → 科研 Agent 协调器（制品／规划／外部证据／决策分段／内容记忆／署名／运行时）。
// 依赖：moonbitlang/async 仅供 cmd/coord（native）真实落盘；riantr/moonbit_doubleML
// 仅供 dmlref（与外部参考实现互校自研 DoubleML）。其余包仍不依赖第三方库。
// 见 https://moonbitlang.com 了解 moon.mod。

import {
  "moonbitlang/async@0.22.4",
  "riantr/moonbit_doubleML@0.64.0",
}
