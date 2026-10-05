///|
/// 机器学习（含 DoubleML）融入主体状态机的设计图。
///
/// 状态机给出的是**结构与可识别性**：状态集合、可能的迁移、时间顺序（过去 →
/// 现在 → 未来）、以及可以被干预的触发。机器学习给出的是**从数据估计结构**的
/// 能力。二者互补：没有状态机，DML 不知道该调整什么、干预究竟是什么；没有
/// 正交化的机器学习，状态机里的效应参数只能靠手工假设。
///
/// 下面九个接口里，第 4、5、9 条已经在本包中实现并做了数值验证，其余给出
/// 明确的接入点。
///
/// 九条接口的**实现状态是一张数据表**（`design_status_table`），报告里的
/// 「状态：」一行由它生成，不由散文另写一遍——0.1.28 之前那一行是手写的散文，
/// 结果第 1 条写着「设计点（本包未实现）」而其余只写「设计点」，同一件事两种
/// 说法，读者无从判断哪个是特例。改成表之后：状态可计数（小节数／已实现数／
/// 设计点数由测试锁住），散文与表不会各说各话。

///|
/// 九条接口的实现状态：(小节标题, 状态)。状态取「已实现」或「设计点」。
///
/// 「本包未实现」是**范围判断**，不是欠账：本包声明的职责是 DoubleML（见
/// `moon.pkg` 与 README），第 1 条要的 softmax／HMM／VAE 状态识别器不在其内。
/// 要不要把它做进来是范围决定，不在状态机层顺手替人定。
pub fn design_status_table() -> Array[(String, String)] {
  [
    ("1. 状态识别（观测 → 状态分布）", "设计点"),
    ("2. 迁移学习（数据 → 转移概率）", "设计点"),
    ("3. 结构发现（数据 → 缺边 / 错边）", "设计点"),
    ("4. 因果效应估计：DoubleML（本包核心）", "已实现"),
    ("5. 状态机基线的数据生成（本包已实现）", "已实现"),
    ("6. 异质性效应（CATE）：谁从练习中受益更多", "设计点"),
    ("7. 序贯 / 动态处置（重入环 → sequential DML）", "设计点"),
    ("8. 策略学习与离线评估", "设计点"),
    ("9. 与 Python 生态对接（本包已实现）", "已实现"),
  ]
}

///|
/// 某条接口的「状态：」那一行，由表生成。
fn design_status_line(title : String) -> String {
  let mut line = ""
  for entry in design_status_table() {
    if entry.0 == title {
      if entry.1 == "已实现" {
        line = "- 状态：**已实现**（实现与验证见 `ml` 的实验与测试）。"
      } else {
        line = "- 状态：设计点（本包未实现——范围判断，非欠账）。"
      }
    }
  }
  line
}

///|
/// 设计图文本。
pub fn render_ml_design() -> String {
  let lines : Array[String] = []
  lines.push("## 状态机 × 机器学习：九个接口")
  lines.push("")
  lines.push("### 1. 状态识别（观测 → 状态分布）")
  lines.push(
    "- 状态机侧：`SubjectState`（34 个状态）、`all_states()`、每个状态的 `gloss`。",
  )
  lines.push(
    "- 机器学习侧：softmax 分类器 / HMM 前向—后向 / 变分自编码器，把文本、行为、",
  )
  lines.push(
    "  量表等观测映射到 34 维状态后验，再用 EM / 变分 EM 与迁移矩阵联合训练。",
  )
  lines.push(
    "- 入口：P(观测 | s) 的编码器 + `SubjectState::gloss()` 作为弱监督种子。",
  )
  lines.push(design_status_line("1. 状态识别（观测 → 状态分布）"))
  lines.push("")
  lines.push("### 2. 迁移学习（数据 → 转移概率）")
  lines.push(
    "- 状态机侧：`transitions()`（53 条手工迁移）、`successors(s)` 给出每个状态的可选动作。",
  )
  lines.push(
    "- 机器学习侧：以 (s, trigger) 为特征的多项 softmax / 梯度提升，估计 P(s' | s, a)，",
  )
  lines.push(
    "  在留出轨迹上比对手工表；`freedom` 作为回报信号。",
  )
  lines.push(
    "- 入口：`successors()` 展开成设计矩阵，与 `transitions()` 对照。",
  )
  lines.push(design_status_line("2. 迁移学习（数据 → 转移概率）"))
  lines.push("")
  lines.push("### 3. 结构发现（数据 → 缺边 / 错边）")
  lines.push("- 状态机侧：`transitions()` 当作图骨架与先验。")
  lines.push(
    "- 机器学习侧：PC / GES / NOTEARS / 条件独立性检验，在骨架上检验每条边的存在性，",
  )
  lines.push("  并挑出「数据里有、表里没有」的候选边。")
  lines.push(
    design_status_line("3. 结构发现（数据 → 缺边 / 错边）"),
  )
  lines.push("")
  lines.push("### 4. 因果效应估计：DoubleML（本包核心）")
  lines.push(
    "- 状态机侧：给出**可识别性结构**——干预集合（触发）、调整集候选（当前状态与历史）、",
  )
  lines.push(
    "  以及时间顺序（过去 → 现在 → 未来），避免反向因果。",
  )
  lines.push(
    "- 机器学习侧：部分线性模型 Y = θT + g(X) + ε，T = m(X) + v；用任意灵活的",
  )
  lines.push(
    "  nuisance（本包用多项式筛 + 岭回归）做交叉拟合，Neyman 正交分数保证 √n 相合、",
  )
  lines.push("  渐近正态，于是 θ 有置信区间与 p 值。")
  lines.push(
    "- 入口：`dml_plr`、`dml_in_sample`、`naive_ols`、`linear_adjust_ols`。",
  )
  lines.push(
    design_status_line("4. 因果效应估计：DoubleML（本包核心）"),
  )
  lines.push("")
  lines.push("### 5. 状态机基线的数据生成（本包已实现）")
  lines.push(
    "- 状态机侧：协变量取自 `freedom()`、阶段序号、`successors()` 的出度、",
  )
  lines.push(
    "  `distance_to_rest()`；处置强度里还含一项直接来自迁移动力学——从某状态随机走",
  )
  lines.push(
    "  24 步，数「消除暗礁（修习）」出现了几次（`practice_count`）。",
  )
  lines.push(
    "- 于是混淆是**结构性的**：练习多的主体本来就处在更有利的位置。",
  )
  lines.push(
    "- 入口：`make_dataset`、`practice_count`、`distance_to_rest`。",
  )
  lines.push(
    design_status_line("5. 状态机基线的数据生成（本包已实现）"),
  )
  lines.push("")
  lines.push("### 6. 异质性效应（CATE）：谁从练习中受益更多")
  lines.push("- 状态机侧：阶段 / 状态作为效应修饰变量。")
  lines.push(
    "- 机器学习侧：DML 加交互项（θ(X) = θ0 + θ1·X），或因果森林 / DR-learner。",
  )
  lines.push(
    "- 入口：把 `linear_adjust_ols` 的 T 列换成 T 与 X 的交互块。",
  )
  lines.push(
    design_status_line(
      "6. 异质性效应（CATE）：谁从练习中受益更多",
    ),
  )
  lines.push("")
  lines.push("### 7. 序贯 / 动态处置（重入环 → sequential DML）")
  lines.push(
    "- 状态机侧：`Tranquility --ReopenByHorizon--> Reflection` 使历程成为可重入的环节",
  )
  lines.push(
    "  序列，因此每个主体经历的是一串**带时变的处置**，而不是一次性干预。",
  )
  lines.push(
    "- 机器学习侧：序贯正交矩（sequential DML / 面板 DML，DoubleML 的 IRM / DID 版本），",
  )
  lines.push(
    "  对每个阶段的效应做后门调整；对应 Python `DoubleML` 的 `DoubleMLIRM`、",
  )
  lines.push("  `DoubleMLDID` 及其面板/序贯扩展。")
  lines.push("- 入口：把 `Dataset` 扩展为 (主体, 阶段) 面板。")
  lines.push(
    design_status_line(
      "7. 序贯 / 动态处置（重入环 → sequential DML）",
    ),
  )
  lines.push("")
  lines.push("### 8. 策略学习与离线评估")
  lines.push(
    "- 状态机侧：这本身就是一个 MDP——34 个状态、动作 = 触发、回报可取 Δ`freedom`。",
  )
  lines.push(
    "- 机器学习侧：值迭代 / 策略梯度 / 离线策略评估（DML 版本的 OPE，用于控制方差），",
  )
  lines.push("  目标是学出「在哪个状态该用哪个触发」。")
  lines.push(design_status_line("8. 策略学习与离线评估"))
  lines.push("")
  lines.push("### 9. 与 Python 生态对接（本包已实现）")
  lines.push(
    "- `export_csv` 把状态机生成的数据导成 CSV，可直接喂给 Python 的",
  )
  lines.push(
    "  `DoubleML`（`DoubleMLPLR` 等）、`EconML`（`LinearDML`、`CausalForestDML`、",
  )
  lines.push(
    "  `DRLearner`）或 R 的 `grf`，用参考实现复核本包的 θ̂。",
  )
  lines.push("- 入口：`export_csv`、`csv_preview`。")
  lines.push(
    design_status_line("9. 与 Python 生态对接（本包已实现）"),
  )
  lines.push("")
  lines.push("### 一句话总结")
  lines.push(
    "状态机负责「因果结构对不对」，DoubleML 负责「估计与推断稳不稳」：",
  )
  lines.push(
    "没有正交化和交叉拟合，任何机器学习调整都会把自身的正则化/过拟合偏误一阶地",
  )
  lines.push(
    "灌进 θ；反过来，没有状态机给出的干预与调整集，DML 也不知道该估什么。",
  )
  lines.join("\n")
}
