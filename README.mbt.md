# Pyroduct

A runnable, tested MoonBit state-machine family modelled from two Chinese
philosophy texts — 《通往宁静之路：个体道德发生论纲要》 and its parent thesis
《伽达默尔与哈贝马斯真理观比较》 (Shanghai Academy of Social Sciences, 2008) —
plus a gated agent state machine and a research-agent coordinator.

One subject: 34 positions · 53 transitions · 11 phases. One group: 20 · 42 · 9.
One society: 13 · 26 · 8. Two subjects: 14 normative rules.

## Features

* Paper-executable, not paraphrased

  Every state, transition and phase is literal data with a page citation:
  `gloss()` ends in `P.xx`, and each construct is tagged 原文直述 (straight from
  the text) or 模型整理 (reconstructed by the model).

* One language, four units

  主体／群体／社会 share the same 「状态 + 触发 + 迁移」 vocabulary at three scales:
  `src` (34·53·11), `group` (20·42·9, member config → emergence with R7
  write-back), `society` (13·26·8, lifeworld vs system). `multi` is the
  normative face: rules R1–R14 for two subjects — regime precedence, validity
  claim timing, 两诚区分, 解蔽—遮蔽 — each rule citing the thesis.

* Two-character names only

  Position and phase designations name a structural relation — nothing else.
  The discipline is locked by tests and printed by `render_naming_table()`.

* Drive slots and a step contract

  `Trigger::slot` sorts all 49 triggers into eight slots (处境／取向／先行／行动／
  反馈／持存／共在／揭蔽) with an exhaustive match — an unplaced trigger fails
  the build. `step(位置, 槽)` answers only 迁／守／未定／无路; of 272 position ×
  slot combinations, 228 honestly answer 无路. The machine never invents a move.

* An agent whose updates must clear a gate

  `evolution` treats an agent's config as `Genome`, enumerates single-step
  candidates (prompt／strategy／memory／code), writes 「更好」 as an `Objective`,
  fences off constitutional invariants, and records every accept／reject／revert
  with its reason in an append-only, serializable `Ledger`. Gates come in two
  grades: hand-written weights, or a DoubleML causal effect (θ̂ > 0 and the 95%
  lower bound > 0). The subject cycle `run_cycle` drives real positions by drive
  slot and puts 修习 and 开放 through the same gate — 没有证据就不前进.

* A coordinator that refuses to close

  `coordinator` adds what a research agent needs beyond a state machine: tasks
  and artifacts, planning over a dependency graph, external evidence judged by
  confidence interval (not by votes), content memory that keeps superseded
  findings, credit with IP provenance, and a deliberation／decision split —
  deliverables carry revision marks, residue ownership and reopen conditions.
  The runtime is replayable and persists to disk. (The 「想」 step is still a
  deterministic stand-in, no LLM yet.)

* Dependency isolation

  `moonbitlang/async@0.22.4` is consumed only by `cmd/coord` (native disk I/O);
  every other package uses official `moonbitlang/*` only.

## Quick Start

Add the module, then run the suite:

```
moon add riantr/pyroduct
moon test             # Total tests: 90, passed: 90, failed: 0.
```

From this repository, every layer prints a report:

```
moon run cmd/main -- report        # 主体状态机
moon run cmd/main -- slots         # 驱动槽：49 个触发 → 8 个槽
moon run cmd/main -- multi         # 多主体行为规则 R1–R14 + 场景
moon run cmd/main -- group         # 群体状态机
moon run cmd/main -- society       # 双层次社会交往模型
moon run cmd/main -- evolution     # 变异／适应度／闸门／持久化／遗传
moon run cmd/main -- cycle         # 主体循环：位置 × 驱动槽 × 因果反馈
moon run cmd/main -- coordinator   # 科研 Agent 协调器
moon run --target native cmd/coord # 真实落盘：检查点往返一致 true
```

## Example

```moonbit nocheck
// 主体：位置、主线、驱动槽、执行契约
let states : Array[@src.SubjectState] = @src.all_states()      // 34 个
let ok     : Bool = @src.reachable(@src.initial(), @src.terminal())
let back   : @src.Outcome = @src.step(@src.Standing, @src.Occasion) // 迁

// 两个主体的一次遭遇：体制、两诚、有效性主张的时序都参与裁决
let me    = @multi.subject(1, @multi.rendezvous(), @multi.InterSubjective, 70, 70, 9)
let other = @multi.subject(2, @multi.rendezvous(), @multi.ChengRan, 80, 80, 9)
let claim : @multi.ValidityClaim = { kind: @multi.Truthfulness, phase: @multi.During }
let out   = @multi.encounter(me, other, @multi.Theoretical, claim)

// 社会：两条不变量由测试锁定
let never_closes : Bool = @society.no_final_closure()

// Agent 状态机：枚举候选 → 过闸 → 只追加记账
let agent  = @evolution.default_agent()
let ledger = @evolution.evolve(agent, @evolution.default_world(),
                               @evolution.Weighted(@evolution.truth_objective()), 3)

// 协调器：跑一段示例研究，检查点写下 / 读回
let rt   = @coordinator.new_runtime()
ignore(rt.step(@coordinator.demo_tasks(), @coordinator.demo_questions(),
               @coordinator.demo_workers(), @coordinator.demo_datasets(),
               @coordinator.demo_world(), @coordinator.demo_parent(),
               @coordinator.demo_candidate()))
let back = @coordinator.restore(rt.checkpoint())
let same : Bool = back.round_trips()
```

## Used By

- `cmd/main` — the report entry for every layer above: `report` / `slots` /
  `multi` / `group` / `society` / `evolution` / `cycle` / `coordinator`, plus
  `mermaid` / `dot` / `genesis` / `course` / `naming` / `principle` / `all`.
- `cmd/coord` — a native binary that runs the coordinator and round-trips its
  checkpoint through real disk I/O (`.openseek/`, gitignored).

## Attribution

- Source text: 任勇祥《伽达默尔与哈贝马斯真理观比较》(上海社会科学院, 2008) 及其
  附录《通往宁静之路：个体道德发生论纲要》。模型中的每个构造都标注了该文的
  章／节／页，并对 原文直述 与 模型整理 做了明确区分。
- License: MIT (see `LICENSE`).
