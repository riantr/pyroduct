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
                                       # 197/197 on wasm + 2 snnref on native
                                       # + 4 ifacescan on native
moon test --target native snnref       # spike-sediment experiment (native only)
moon test --target native tools/ifacescan  # .mbti drift tripwire (native only)
moon run --target native cmd/ifacescan # scan every tracked .mbti (reads the disk)
python tools/gen_iface_data.py         # refresh audit/iface_data.mbt from the real
                                       # .mbti files — run it after `moon info`
moon check                             # type/warn check
moon info                              # regenerates every pkg.generated.mbti (tracked)
moon fmt                               # format; `moon fmt --check` must stay clean
moon run cmd/main -- report            # CLI: report (default) | multi | group | society |
                                       # evolution | cycle | coordinator | dmlref | causal |
                                       # audit | fleet | mutants | mbti | mermaid | dot |
                                       # genesis |
                                       # course |
                                       # naming | slots | loop | principle | intuition |
                                       # ml | ml-export | all | society-mermaid |
                                       # group-mermaid | nested-mermaid | journey |
                                       # viz | spec | association | pathsum |
                                       # algebra | petri | aho | buchi
                                       # (`intuition` = 直觉读法：备忘录读成背景直觉的仓库）
                                       # (`causal` = 0.75.0 深用：敏感性／多重检验／异质性）
                                       # (`audit` = 三鉴自审计（结构鉴／类型鉴／行为鉴）：主体机当程序读）
                                       # (`fleet` = 同一套三鉴扩到群体机与社会机：两台机无槽无终点）
                                       # (`mutants` = 迁移表变异网：三台机×六族破坏 18 处逐处被抓）
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
python tools/apply_fmt.py              # copy `moon fmt --check`'s canonical copies back
                                       # (byte-for-byte: `moon fmt` cannot rewrite files
                                       # in this sandbox, and a binary copy cannot mangle
                                       # encoding the way Get-Content/Set-Content does)
python tools/mutate_review.py          # review harness: mutation table for all five
                                       # Loops plus the predicate census
                                       # (48 mutations, counted from the table —
                                       # don't hardcode it). Each entry reverts one
                                       # construct to its old/wrong shape, re-runs
                                       # `moon test`, and the criteria MUST go red.
                                       # `python tools/mutate_review.py loop5` runs one
                                       # group. Exit 0 only if every mutation turned a
                                       # criterion red — so it can gate CI rather than
                                       # depend on someone reading the output. Verdicts
                                       # are also written to tools/mutation_review_log.md
                                       # (committed) so the claim is auditable without
                                       # re-running a working-tree-mutating pass.
                                       # A compile error is NOT a catch (reported as
                                       # COMPILE-ERROR) — a mutation rejected by the
                                       # compiler proves the syntax, not the criteria.
                                       # Surviving mutations must be classified as
                                       # equivalent or a named gap.
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

## MiniMax Code plugin (`plugin/`)

The module ships as a local MiniMax plugin. `plugin/` is the source of truth; the
installed copy in the Desktop data dir (`~/.minimax/plugins/pyroduct-model/`) is what the
runtime loads, and the two are kept in agreement explicitly:

```console
node plugin\tools\sync-install.mjs push            # repo -> installed copy (install step)
node plugin\tools\sync-install.mjs pull            # installed copy -> repo (capture edits made there)
node plugin\tools\sync-install.mjs push <checkout> # install, then rebuild + re-pin + regression
```

- Editing the plugin means editing `plugin/`, then pushing. If you edited inside the data dir
  instead, `pull` first. Never hand-maintain both trees: `push`/`pull` delete files the source
  no longer has, so a rename cannot leave a stale `server.mjs` or skill reference behind.
- `plugin/vendor/jsoncli.js` is a build artifact (gitignored). It is produced by
  `moon build --target js` and pinned by SHA-256 in `plugin/vendor/BUILD.json`; `push` refuses
  to install when the recorded hash and the file disagree. Refresh it with
  `node <installed>\tools\update-bundle.mjs <checkout>`, which also rewrites the pin from
  `moon.mod` and re-runs `tools/validate-plugin.mjs`.
- After any plugin change run the package's own net: `node <installed>\tools\validate-plugin.mjs`
  (26 checks: the pin, a real MCP handshake, all 31 faces, the model-count invariants including
  `audit`'s 「未预期 0 条」 tripwire, a page-citation anti-drift rule, and a positive control that
  fires the checkout guard). The plugin's SemVer in `.minimax-plugin/plugin.json` is independent
  of the module's `moon.mod` version — bump it by hand.
- The plugin holds **no model facts**: every fact comes from the module through
  `cmd/jsoncli`. If you add a fact to the plugin, it belongs in the module instead.
- A live MCP server keeps the old code until it restarts, so a description fix shows up in the
  next session, not the current one.

## Layout

| Package | Unit | Contents |
|---------|------|----------|
| `src` | one subject | Subject state machine (34 states · 53 transitions · 11 phases) + drive slots (8, `slot.mbt`) + step contract (`loop.mbt`: `step` → 迁/守/未定/同归/无路, `step_by_trigger` for trigger granularity, `candidates` as the single source for "what can happen here", `Outcome::forks_from` for programmable branching at 未定, `expand` for all continuations of a slot script, `after_open` for all positions reachable after an 未定 without presuming the next slot, `open_points` listing the 5 未定 points, `Trace::detailed` per-step provenance) + adjacency index (`index.mbt`) + durability manifest (`durability.mbt`) + rendering (`render.mbt`: report/dot/mermaid/nested/journey) + spec export (`spec.mbt`: machine as JSON data, `spec_vocabulary` anti-drift; port of python-statemachine's io/neutral-IR, direction inverted for data-as-code) + pathsum & properties (`paths.mbt`: tropical `min_steps`/`distance_to` — the road-to-tranquility ladder; `is_deterministic` per-trigger, `is_acyclic` = false by design; port of FiniteStateTransducers.jl's shortest_distance/properties, marked 模型整理) + machine algebra (`algebra.mbt`: operator mapping, main-line decomposition via `course()`, partition-refinement `minimal_quotient` — 31 blocks = course length with three designed twin pairs 无忆≡无筹/紧迫≡疏离/受赏≡畏怖; port of Ragel's minimization, marked 模型整理) + Petri net face (`petri.mbt`: places=34 states, transitions=53 table rows (one-to-one, token-conserving), immutable `PetriMarking` with `enabled`/`fire` returning Consume/Produce effects, multi-token concurrency demo, 未定 = structural conflict, coloring = genome with `petri_coloring_status()` stating the boundary and a test locking the claim; port of CarlAdam's marking/occurrence semantics, marked 模型整理) + Aho-Corasick face (`aho.mbt`: the 49 trigger sentences as a keyword trie with failure links and output merging — 失败链 = the algorithmic form of remembering (fall back to the longest shared past), textbook-example tests; port of pyahocorasick, marked 模型整理) + Büchi face (`buchi.mbt`: the machine read as an ω-automaton — no finals + the R11 re-entry loop make the natural acceptance condition Büchi's (recurrence of 宁静); nonemptiness via lasso, liveness potential via distance_to, 11 stall self-loops: 10 rejecting (structure does not enforce liveness — fairness lives in the genome) + 宁静's own 静待下一刻 loop as the one accepted stall; marked 模型整理) |
| `multi` | two subjects | Normative rules R1–R14, `TruthRegime`, claim schemas, `encounter` verdicts |
| `group` | one group | Emergence state machine (20 states), member config → group state, R7 write-back; **execution contract** (`loop.mbt`, 0.1.27): no drive slots, so the trigger *is* the driver — `step(state, trigger)` → 迁/守/未定/无路, `walk`, `open_pairs`, `no_dead_end`; the table holds exactly one **one-trigger-two-destinations** pair (`Converging × Attention` → 共语 or 商谈) which the machine reports as `Open` rather than picking — a data question for the author, not for the machine |
| `society` | one society | Two-level social model from the thesis (13 states), lifeworld vs. system; **execution contract** (`loop.mbt`, 0.1.27): same four receipts, and `one_edge_per_trigger()` asserts the table is trigger-deterministic, so `Open` is unreachable there (arm kept as the landing place if the table ever changes) |
| `ml` | — | From-scratch DoubleML (PLR, cross-fitting, orthogonal scores, inference), RNG, linear algebra |
| `evolution` | one agent | `Genome`, mutations, `Objective`, update gates (weighted or DoubleML-based), append-only `Ledger`, heredity; subject cycle (`cycle.mbt`: `run_cycle` drives `@sm.step` by slot and judges 修习/开放 candidates through the gate); decision memo (`replay.mbt`: one judgement per (parent, candidate) pair per cycle, repeats annotated 同判·不重裁); backdating (`gate.mbt`: zero-diff candidates → Tie without re-running the estimator); intuition reading (`intuition.mbt`: memo read as background-intuition repository, marked 模型整理); soft association for 未定 (`association.mbt`: JPDA-flavoured β weights + entropy over co-existing candidates — argmax-consistent with the 两诚 hard rule, diagnostic only, no sampling; port of PDA-JPDA, marked 模型整理) |
| `coordinator` | research agents | Tasks/artifacts, planning, external evidence by confidence interval, content memory, credit, deliberation/decision split, replayable runtime |
| `dmlref` | — | Cross-check of our DoubleML against `riantr/moonbit_doubleML@0.75.0` |
| `causal` | one dataset | 0.75.0-deep diagnostics (read-only, data from the state machine): sensitivity (Cinelli–Hazlett `rv = \|θ̂\|/max_bias`), multiple-testing correction (BH/Bonferroni — naive OLS also passes, significance ≠ evidence), BLP heterogeneity (residualized treatment × centered covariates, HC0 se; d̃ recovers θ̂); marked 模型整理 |
| `audit` | one machine | Three-lens static audit of the real subject machine (`riantr/moonbit_static_analysis/src/statecheck`; the library's moon.mod names pyroduct its reference consumer): real tables → plain-data `MachineSpec` → structural (states are bindings) / type (slots placed, no silent Block) / behavior (course abstractly executed) lenses; findings split 已知设计（无忆／无筹 only-exit, verified 0.2.0）vs 未预期（must stay 0 — live tripwire）; marked 模型整理. 0.2.0 起另加**接口面**（`mbti.mbt`）：把本仓库**自己的** `pkg.generated.mbti` 交给库的 `src/moonfiles` 审（重复签名／畸形行／未知类型引用）。wasm／JS 读不了盘，故真扫靠 `iface_data.mbt` 这份**内嵌快照**（由 `tools/gen_iface_data.py` 逐字节生成）；正控是三段坏片段必被抓 + 干净样本必为 0 |
| `audit` fleet + mutants | two more machines | 0.1.28: the same three lenses over the group machine (20 states · 44 transitions · 397 无路) and the society machine (13 · 28 · 206) — `fleet.mbt`. Two 口径 differ and are stated up front: **no drive slots** (the trigger *is* the driver, so lens 2's slot layer is skipped via an empty `slot_names`) and **no terminal** (`no_dead_end` holds everywhere; filling one would misreport 不封闭 as a defect). 未预期 is 0 with a known-design exemption opened on **exactly one cell** (`Converging × Attention`, key-matched on machine+state+trigger, not on the family) — measured, not assumed. `mutants.mbt` is the standing answer to "can it even see?": 3 machines × 6 breakages = 18, each must be caught **and** report the expected family; `split_fleet`/`probe_finding` exist so the layering itself is testable (three narrowness criteria cover the exemption); marked 模型整理 |
| `snnref` | one experiment | Spike-sediment experiment (native only): 49 triggers → Poisson spike trains with slot-correlated rates → Gerstner STDP (CSR, library defaults) → does the sedimented weight structure recover the 8-slot partition? Means, hit rate vs. chance baseline, per-slot table; marked 模型整理 |
| `viz` | — | Presentation-only: all three state machines as Mermaid `stateDiagram-v2` source plus one self-contained HTML page (`page()` embeds all three plus the subject machine's nested view — 11 phases as composite states — and the demo journey view with styling for now/gap/undecided; mermaid.js CDN loaded at view time — build/run stay offline). Delegates to the per-machine renderers; declares ASCII node ids with Chinese labels everywhere |
| `cmd/main` | — | wasm CLI (36 named subcommands, incl. `all`, + the default report) |
| `cmd/coord` | — | native CLI with real disk I/O (`supported_targets = "+native"`) |
| `cmd/ifacescan` | — | native CLI entry for the `.mbti` scan — **deliberately not** a `cmd/main` subcommand: it needs disk IO, so it cannot be a wasm face. The agent-visible `mbti` face scans the embedded snapshot instead |
| `cmd/jsoncli` | — | JSON bridge for both agent plugins — the DeepSeek Harness one (`riantr/dsh-plugin-pyroduct`) and the MiniMax Code one (`plugin/`) (js target: `moon build --target js` → `_build/js/debug/build/cmd/jsoncli/jsoncli.js`): one JSON request arg `{ "kind": ... }` → one-line JSON reply `{ok, kind, rendered, faces}`. Kinds mirror the model-facing subcommands (31 faces, listed in the bridge's `faces()`); viz composites and `all` stay CLI-only. The bridge is a pure spawner/formatter — all model semantics stay in the renderers it calls |
| `tools/pdfdump` | — | read-only survey records of the source PDF |
| `tools/ifacescan` | — | **`.mbti` 漂移绊线（native 专属）**：走盘读回每个真实的 `pkg.generated.mbti`，逐行（剥 `\r`，与库的 `normalize` 同一口径）比对 `audit::iface_snapshot()` 的内嵌快照。快照过期就变红——这是内嵌快照能成立的全部理由。顺带是接口面唯一的「真读盘」实扫。marked 模型整理 |
| `plugin/` | — | **not a MoonBit package** — the MiniMax Code local plugin (`.minimax-plugin/plugin.json` + `server.mjs` MCP server + the `pyroduct-model` skill + `tools/`). This tree is the source of truth; the installed copy lives in the Desktop data dir (`~/.minimax/plugins/pyroduct-model/`, `.mavis` is a junction to it) and is what the runtime loads. `vendor/jsoncli.js` is a build artifact, gitignored and regenerated |
| `examples/*` | — | one runnable example per package: `plr`, `irm`, `cross_check`, `consumer`, `sediment` (native) |

Each package directory contains a `moon.pkg` whose first lines are a comment explaining the
package's purpose — those comments are package-level docs, keep them accurate.

## Dependency rule (enforced by convention; keep it)

- Outside the four exceptions below, packages may only use official `moonbitlang/*`
  (mostly `moonbitlang/core`); no third-party libraries.
- `moonbitlang/async@0.22.4` — consumers `cmd/coord` (native disk I/O, the
  coordinator checkpoint) and `tools/ifacescan` + `cmd/ifacescan` (the `.mbti`
  drift tripwire and its CLI; also native disk I/O).
- `riantr/moonbit_doubleML@0.75.0` — consumers `dmlref` (cross-check of our
  from-scratch estimator) and `causal` (0.75.0-deep diagnostics: sensitivity,
  multiple-testing correction, BLP heterogeneity — read-only, no gate).
- `riantr/snn_mbt@0.84.0` (pulls `riantr/moonbit_image@0.3.4`) — sole consumer `snnref`
  (spike-sediment experiment, cross-check only). `snn_mbt` declares native as its only
  target, so `snnref` and `examples/sediment` are `+native`: the wasm gate skips them,
  run `moon test --target native snnref` separately.
- `riantr/moonbit_static_analysis@0.2.0` — sole consumer `audit` (three-lens
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
  source citation attached to every construct — `gloss` holds the text's own wording
  verbatim. There is no page-number field: `P.xx` appears only where the pdfdump survey
  really recorded one (`multi`/`group`/`society`, plus three spots in `evolution`), never in
  `src`. Do not claim a page ref the table does not carry. Distinguish 原文直述 (direct from
  the text) from 模型整理 (model reconstruction) when adding constructs.
- **Naming discipline**: state and phase names are exactly two characters (designations in
  `general.mbt`); keep new names in that register and structural only. Drive slots
  (`src::Slot`) follow the same rule.
- **Drive-slot discipline**: new `Trigger`s must be placed by `Trigger::slot` (exhaustive
  match — the compiler enforces it); 共在 (`CoBeing`) is never merged into 处境/行动
  (the other is not part of the environment); 先行 (`Antecedent`) carries no numbers —
  probabilities live in `ml`/`evolution`. `src::step` returns only 迁/守/未定/同归/无路;
  `未定` is resolved by the genome (双诚之比) in `evolution`, never inside `src`, and
  `Block` outcomes must never be papered over into a fabricated move. The same
  discipline holds in `group`/`society`, which have no drive slots at all: their
  `step(state, trigger)` takes 迁/守/未定/无路 and **no** `同归` (the shape needs
  slots), plus `Open` for one-trigger-two-destinations. group has exactly one such
  pair and it is flagged in the report as a **data question** — never resolve it
  inside the machine.
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
