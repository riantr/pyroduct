# AGENTS.md

Guidance for AI coding agents working in **riantr/pyroduct** — a pure-MoonBit module that
turns two Chinese philosophy texts into runnable, tested state machines (subject / group /
society / multi-agent), plus an evolution layer, a research-agent coordinator, a
from-scratch DoubleML, and a cross-check against the published `riantr/moonbit_doubleML`.

Long-form context lives in `README.mbt.md` (English) and `README.zh.mbt.md`
(Chinese); read it before non-trivial changes.

## Commands

```console
moon test                              # all tests (default target: wasm); currently
                                       # 129/129 on wasm + 2 snnref tests on native
moon test --target native snnref       # spike-sediment experiment (native only)
moon check                             # type/warn check
moon info                              # regenerates every pkg.generated.mbti (tracked)
moon fmt                               # format; `moon fmt --check` must stay clean
moon run cmd/main -- report            # CLI: report (default) | multi | group | society |
                                       # evolution | cycle | coordinator | dmlref | causal |
                                       # audit | mermaid | dot | genesis | course |
                                       # naming | slots | loop | principle | intuition |
                                       # ml | ml-export | all | society-mermaid |
                                       # group-mermaid | nested-mermaid | journey |
                                       # viz | spec | association | pathsum |
                                       # algebra | petri | aho | buchi
                                       # (`intuition` = 直觉读法：备忘录读成背景直觉的仓库）
                                       # (`causal` = 0.75.0 深用：敏感性／多重检验／异质性）
                                       # (`audit` = 三鉴自审计（结构鉴／类型鉴／行为鉴）：主体机当程序读）
                                       # (`slots` = 驱动槽归位表, `loop` = 位置 × 槽的执行契约)
                                       # (`nested-mermaid` = 嵌套视图：11 阶段为复合状态容器)
                                       # (`journey` = 行程视图：一次行走的局部图 + 样式标注)
                                       # (`spec` = 规格导出：主体机即 JSON 数据，词汇表防漂移)
                                       # (`association` = 未定的软关联（JPDA 面镜像）：β 权重/熵/argmax 一致性)
                                       # (`pathsum` = 泛半环路径和：tropical 最短路 + 性质谓词，参照 FiniteStateTransducers.jl)
                                       # (`algebra` = 机器代数（Ragel 面）：算子映射/主线分解/最小商——三对孪生)
                                       # (`petri` = Petri 网面（CarlAdam 镜像）：库所/变迁/标识/发火/守恒，多托肯并发)
                                       # (`aho` = 回忆结构（Aho-Corasick 面）：触发句前缀树/失败链/输出合并)
                                       # (`buchi` = ω-视角（Büchi 面）：非空性/活性潜势/停滞词——结构不强迫活性)
moon run examples/plr                  # also: examples/irm, examples/cross_check,
                                       # examples/consumer,
                                       # moon run --target native examples/sediment
moon run --target native cmd/coord     # coordinator CLI with real disk I/O; writes
                                       # .openseek/coordinator-state.txt (gitignored)
```

- After changing dependencies in `moon.mod`, run `moon update` first.
- CI-equivalent gate before you finish: `moon check`, `moon test`, `moon fmt --check` all
  clean.
- **`moon fmt` cannot rewrite files in this sandbox** (in-place writes to existing files
  are denied; only the agent's file tools may modify them). To get canonical formatting,
  run `moon fmt --check` — it writes formatted copies under
  `_build/wasm-gc/release/format/<pkg>/<file>` — then diff each touched file against its
  copy (`git diff --no-index <file> _build/wasm-gc/release/format/<pkg>/<file>`) and apply
  the hunks with the file tools.
- `_build/` is a build artifact directory (gitignored); `pkg.generated.mbti` files are
  generated interfaces — never hand-edit them. `moon info`'s final copy step (overwriting
  the tracked `.mbti` files) hits the same sandbox denial as `moon fmt`; the workaround is
  the same: diff each regenerated package against its fresh copy under
  `_build/wasm/debug/check/<pkg>/<name>.mbti` and apply the changes with the file tools.
- Sandbox note: `moon update` and the first dependency download write to the MoonBit
  registry cache under the user profile (`~/.moon/registry`), outside this workspace; they
  may need elevated file access once. Everything else (build, test, run, format) works
  inside the workspace.

## Layout

| Package | Unit | Contents |
|---------|------|----------|
| `src` | one subject | Subject state machine (34 states · 53 transitions · 11 phases) + drive slots (8, `slot.mbt`) + step contract (`loop.mbt`: `step` → 迁/守/未定/无路, `Trace::detailed` per-step provenance) + adjacency index (`index.mbt`) + durability manifest (`durability.mbt`) + rendering (`render.mbt`: report/dot/mermaid/nested/journey) + spec export (`spec.mbt`: machine as JSON data, `spec_vocabulary` anti-drift; port of python-statemachine's io/neutral-IR, direction inverted for data-as-code) + pathsum & properties (`paths.mbt`: tropical `min_steps`/`distance_to` — the road-to-tranquility ladder; `is_deterministic` per-trigger, `is_acyclic` = false by design; port of FiniteStateTransducers.jl's shortest_distance/properties, marked 模型整理) + machine algebra (`algebra.mbt`: operator mapping, main-line decomposition via `course()`, partition-refinement `minimal_quotient` — 31 blocks = course length with three designed twin pairs 无忆≡无筹/紧迫≡疏离/受赏≡畏怖; port of Ragel's minimization, marked 模型整理) + Petri net face (`petri.mbt`: places=34 states, transitions=53 table rows (one-to-one, token-conserving), immutable `PetriMarking` with `enabled`/`fire` returning Consume/Produce effects, multi-token concurrency demo, 未定 = structural conflict, coloring = genome noted not implemented; port of CarlAdam's marking/occurrence semantics, marked 模型整理) + Aho-Corasick face (`aho.mbt`: the 49 trigger sentences as a keyword trie with failure links and output merging — 失败链 = the algorithmic form of remembering (fall back to the longest shared past), textbook-example tests; port of pyahocorasick, marked 模型整理) + Büchi face (`buchi.mbt`: the machine read as an ω-automaton — no finals + the R11 re-entry loop make the natural acceptance condition Büchi's (recurrence of 宁静); nonemptiness via lasso, liveness potential via distance_to, 11 stall self-loops: 10 rejecting (structure does not enforce liveness — fairness lives in the genome) + 宁静's own 静待下一刻 loop as the one accepted stall; marked 模型整理) |
| `multi` | two subjects | Normative rules R1–R14, `TruthRegime`, claim schemas, `encounter` verdicts |
| `group` | one group | Emergence state machine (20 states), member config → group state, R7 write-back |
| `society` | one society | Two-level social model from the thesis (13 states), lifeworld vs. system |
| `ml` | — | From-scratch DoubleML (PLR, cross-fitting, orthogonal scores, inference), RNG, linear algebra |
| `evolution` | one agent | `Genome`, mutations, `Objective`, update gates (weighted or DoubleML-based), append-only `Ledger`, heredity; subject cycle (`cycle.mbt`: `run_cycle` drives `@sm.step` by slot and judges 修习/开放 candidates through the gate); decision memo (`replay.mbt`: one judgement per (parent, candidate) pair per cycle, repeats annotated 同判·不重裁); backdating (`gate.mbt`: zero-diff candidates → Tie without re-running the estimator); intuition reading (`intuition.mbt`: memo read as background-intuition repository, marked 模型整理); soft association for 未定 (`association.mbt`: JPDA-flavoured β weights + entropy over co-existing candidates — argmax-consistent with the 两诚 hard rule, diagnostic only, no sampling; port of PDA-JPDA, marked 模型整理) |
| `coordinator` | research agents | Tasks/artifacts, planning, external evidence by confidence interval, content memory, credit, deliberation/decision split, replayable runtime |
| `dmlref` | — | Cross-check of our DoubleML against `riantr/moonbit_doubleML@0.75.0` |
| `causal` | one dataset | 0.75.0-deep diagnostics (read-only, data from the state machine): sensitivity (Cinelli–Hazlett `rv = \|θ̂\|/max_bias`), multiple-testing correction (BH/Bonferroni — naive OLS also passes, significance ≠ evidence), BLP heterogeneity (residualized treatment × centered covariates, HC0 se; d̃ recovers θ̂); marked 模型整理 |
| `audit` | one machine | Three-lens static audit of the real subject machine (`riantr/moonbit_static_analysis/src/statecheck`; the library's moon.mod names pyroduct its reference consumer): real tables → plain-data `MachineSpec` → structural (states are bindings) / type (slots placed, no silent Block) / behavior (course abstractly executed) lenses; findings split 已知设计（无忆／无筹 only-exit, verified 0.1.2）vs 未预期（must stay 0 — live tripwire）; marked 模型整理 |
| `snnref` | one experiment | Spike-sediment experiment (native only): 49 triggers → Poisson spike trains with slot-correlated rates → Gerstner STDP (CSR, library defaults) → does the sedimented weight structure recover the 8-slot partition? Means, hit rate vs. chance baseline, per-slot table; marked 模型整理 |
| `viz` | — | Presentation-only: all three state machines as Mermaid `stateDiagram-v2` source plus one self-contained HTML page (`page()` embeds all three plus the subject machine's nested view — 11 phases as composite states — and the demo journey view with styling for now/gap/undecided; mermaid.js CDN loaded at view time — build/run stay offline). Delegates to the per-machine renderers; declares ASCII node ids with Chinese labels everywhere |
| `cmd/main` | — | wasm CLI (33 named subcommands, incl. `all`, + the default report) |
| `cmd/coord` | — | native CLI with real disk I/O (`supported_targets = "+native"`) |
| `tools/pdfdump` | — | read-only survey records of the source PDF |
| `examples/*` | — | one runnable example per package: `plr`, `irm`, `cross_check`, `consumer`, `sediment` (native) |

Each package directory contains a `moon.pkg` whose first lines are a comment explaining the
package's purpose — those comments are package-level docs, keep them accurate.

## Dependency rule (enforced by convention; keep it)

- Outside the four exceptions below, packages may only use official `moonbitlang/*`
  (mostly `moonbitlang/core`); no third-party libraries.
- `moonbitlang/async@0.22.4` — sole consumer `cmd/coord` (native disk I/O).
- `riantr/moonbit_doubleML@0.75.0` — consumers `dmlref` (cross-check of our
  from-scratch estimator) and `causal` (0.75.0-deep diagnostics: sensitivity,
  multiple-testing correction, BLP heterogeneity — read-only, no gate).
- `riantr/snn_mbt@0.84.0` (pulls `riantr/moonbit_image@0.3.4`) — sole consumer `snnref`
  (spike-sediment experiment, cross-check only). `snn_mbt` declares native as its only
  target, so `snnref` and `examples/sediment` are `+native`: the wasm gate skips them,
  run `moon test --target native snnref` separately.
- `riantr/moonbit_static_analysis@0.1.0` — sole consumer `audit` (three-lens
  static audit of the subject machine: the library's moon.mod names pyroduct
  its reference consumer; `src` stays zero-import — `audit` converts the real
  tables into a plain-data `MachineSpec` above it).
- `ml`'s DoubleML is fully self-contained: never import a numerics library into `ml`.
- First-party imports stay minimal and point downward only (`evolution` imports `src` as
  `@sm` for the cycle). `src/moon.pkg` has **zero imports** — never add an environment,
  RNG, or numerics dependency to `src`; producers of slot content live above it.

## Code conventions

- **Language**: code identifiers, type names and doc comments are Chinese + English mixed;
  doc comments (`///`) explaining provenance are typically Chinese. Follow the surrounding
  file.
- **MoonBit style**: `///|` marker before each top-level definition; `pub`/`pub(all)` for
  the exported surface; explicit `extend T with Eq::{equal, not_equal}` instead of relying
  on implicit Eq promotion; `derive(Eq, Debug)` on data enums/structs.
- **Data-as-code**: models are literal data tables (states, transitions, phases) with a
  source citation attached to every construct (`gloss` text ending in `P.xx` page refs).
  Distinguish 原文直述 (direct from the text) from 模型整理 (model reconstruction) when
  adding constructs.
- **Naming discipline**: state and phase names are exactly two characters (designations in
  `general.mbt`); keep new names in that register and structural only. Drive slots
  (`src::Slot`) follow the same rule.
- **Drive-slot discipline**: new `Trigger`s must be placed by `Trigger::slot` (exhaustive
  match — the compiler enforces it); 共在 (`CoBeing`) is never merged into 处境/行动
  (the other is not part of the environment); 先行 (`Antecedent`) carries no numbers —
  probabilities live in `ml`/`evolution`. `src::step` returns only 迁/守/未定/无路;
  `未定` is resolved by the genome (双诚之比) in `evolution`, never inside `src`, and
  `Block` outcomes must never be papered over into a fabricated move.
- **Tests are black-box**: test files (e.g. `*_test.mbt`) exercise only the package's public
  API via `@pkg.…` and lock invariants — e.g. `no_final_closure()` (no terminal state, gap
  always reachable), residue always positive, constitutional clauses, `decision_ok()`.
  When you change a model, extend the invariant tests, not just snapshots.
- **Determinism**: all randomness goes through fixed seeds (`ml`'s splitmix64 `Rng`,
  evolution round seeds, external `seed=3141`). Never introduce unseeded randomness.
- **Report symmetry**: each layer has a `report`-style renderer (`render_report` /
  `report.mbt`); new user-facing constructs should appear there and in the matching
  `cmd/main` subcommand.

## When you change a model

1. Update the data tables and any rendered reports together.
2. Keep counts consistent: state/transition/phase totals appear in tests, README tables,
   and `moon.mod` description — update all of them. `README.mbt.md` (English) and
   `README.zh.mbt.md` (Chinese) follow the `moonbit-community/rabbita` README style
   and deliberately present only the
   state-machine family (`src`/`multi`/`group`/`society`), the agent layer (`evolution`)
   and the coordinator — `ml`, `dmlref` and `examples` are not presented there.
3. Run the full gate (`moon check` + `moon test` + `moon fmt --check`) and, for
   coordinator/evolution changes, `moon run --target native cmd/coord` to confirm the
   checkpoint round-trips (`往返一致 true`).
