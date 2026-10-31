# Pyroduct

![pyroduct](pyroduct.png)

A runnable, tested MoonBit state-machine family modelled from two Chinese
philosophy texts — 《通往宁静之路：个体道德发生论纲要》 (*The Road to
Tranquility: An Outline of the Genesis of Individual Morality*) and its parent
thesis 《伽达默尔与哈贝马斯真理观比较》 (*Gadamer and Habermas on Truth: A
Comparison*, Shanghai Academy of Social Sciences, 2008) — plus a gated agent
state machine and a research-agent coordinator.

One subject: 34 positions · 53 transitions · 11 phases. One group: 20 · 44 · 9.
One society: 13 · 28 · 8. Two subjects: 14 normative rules.

## Features

* Paper-executable, not paraphrased

  Every state, transition and phase is literal data with a source citation:
  `gloss()` carries the text's own wording verbatim, and each construct is tagged
  原文直述 (verbatim from the source) or 模型整理 (model reconstruction). Page
  numbers are not part of that discipline: `P.xx` appears only where the source
  survey actually recorded one — `multi`/`group`/`society` — and never in the
  subject machine's own tables.

* One language, four units

  Subject (主体) / group (群体) / society (社会) share the same state + trigger +
  transition vocabulary at three scales: `src` (34·53·11), `group` (20·44·9,
  member config → emergence with R7 write-back), `society` (13·28·8, lifeworld
  vs. system). `multi` is the normative face: rules R1–R14 for two subjects —
  regime precedence, validity-claim timing, the two-sincerity distinction
  (两诚区分), unconcealment–concealment (解蔽—遮蔽) — each rule citing the thesis.

* Two-character names only

  Position and phase designations name a structural relation — nothing else.
  The discipline is locked by tests and printed by `render_naming_table()`.

* Drive slots and a step contract

  `Trigger::slot` sorts all 49 triggers into eight slots (Occasion 处境 /
  Orientation 取向 / Antecedent 先行 / Act 行动 / Feedback 反馈 / Hold 持存 /
  CoBeing 共在 / Unveil 揭蔽) with an exhaustive match — an unplaced trigger
  fails the build. `step(position, slot)` answers only Moved (迁) / Held (守) /
  Undecided (未定) / Same-destination (同归) / No-way (无路); of 272 position × slot
  combinations, 228 honestly answer No-way. The machine never invents a move — and
  since 0.1.26 it never invents *which sentence* moved it either: on the three
  position × slot pairs where several triggers lead to one target it answers 同归
  (destination known, cause unnamed) instead of naming the first one in the table.
  `step_by_trigger(position, sentence)` takes the sentence as given.

* An agent whose updates must clear a gate

  `evolution` treats an agent's config as `Genome`, enumerates single-step
  candidates (prompt / strategy / memory / code), writes "better" as an
  `Objective`, fences off constitutional invariants, and records every
  accept / reject / revert with its reason in an append-only, serializable
  `Ledger`. Because every trail names the trail it came from, that ledger is
  also a tree — `roots`, `children`, `depth`, `ancestry`, `leaves`, `height`,
  `lineage` — and the lineage it reports is checked, not assumed: a non-root's
  parent must be a root or an accepted change, and differ from it by exactly one
  mutation. Gates come in two grades: hand-written weights, or a DoubleML
  causal effect (θ̂ > 0 and the 95% lower bound > 0). The subject cycle
  `run_cycle` drives real positions by drive slot and puts Cultivation (修习)
  and Opening (开放) through the same gate — no evidence, no advance
  (没有证据就不前进).

* A coordinator that refuses to close

  `coordinator` adds what a research agent needs beyond a state machine: tasks
  and artifacts, planning over a dependency graph, external evidence judged by
  confidence interval (not by votes), content memory that keeps superseded
  findings, credit with IP provenance, and a deliberation / decision split —
  deliverables carry revision marks, residue ownership and reopen conditions.
  The runtime is replayable and persists to disk. (The "think" step is still a
  deterministic stand-in, no LLM yet.)

* Dependency isolation

  Four named third-party dependencies, each confined to its consumer:
  `moonbitlang/async@0.22.7` → `cmd/coord` (native disk I/O) and
  `tools/ifacescan` / `cmd/ifacescan` (the `.mbti` drift tripwire, native);
  `riantr/moonbit_doubleML@0.164.56` → `dmlref` / `causal`;
  `riantr/snn_mbt@0.166.2` → `snnref` (native); `riantr/moonbit_static_analysis@0.4.39`
  → `audit`. Every other package uses official `moonbitlang/*` only.

## What you get

The module is a library, so "what you get" is a set of **data structures and
reports**, not a running service. Concretely:

| You call | You get back | Shape |
|---|---|---|
| `@src.step(position, slot)` | one of five receipts | `Moved` / `Held` / `Open` / `Same` / `Block` |
| `@src.step_by_trigger(position, sentence)` | the same five, but the trigger is named | enum |
| `@src.exitable_slots(position)` | the slots that actually have an edge out of this position | `Array[Slot]` |
| `@src.moving_slots(position)` | the slots whose receipt is `Moved` — the ones that move you | `Array[Slot]` |
| `@src.undecided_at(position)` | whether any slot leaves the destination undecided | `Bool` |
| `@multi.encounter(me, other, discourse, claim)` | a verdict for one exchange | `Verdict` (6 values) |
| `@src.spec_json()` | the whole machine as one document | a ~10 KB JSON string |
| `@src.render_report()` / `render_mermaid()` / `render_dot()` | human-readable renderings | `String` |
| `@evolution.evolve(genome, world, criterion, rounds)` | a ledger of accepted changes | `Ledger` (a tree) |
| `@coordinator.runtime.step(...)` | a replayable checkpoint | `String` (tab-separated) |

Every one of those is a **pure function or an explicit data value**. There is
no hidden global state, no clock, no network: the same inputs give the same
bytes, which is why `moon test` can assert on them and why the gate can check
the repository's own claims.

Two delivery surfaces sit on top:

- **CLI** — `moon run cmd/main -- <face>` prints any layer as a report.
  37 subcommands; an unknown one exits non-zero rather than printing the
  default report.
- **JSON bridge** — `cmd/jsoncli` takes one JSON request and returns one JSON
  reply `{ok, kind, rendered, faces}`. This is what the two agent plugins
  (`plugin/` for MiniMax, `.dsh/` for DeepSeek) spawn; it is the only surface
  an agent needs.

The bridge ships as a **snapshot**, not a checkout: `plugin/vendor/jsoncli.js`
is pinned by SHA-256 in `plugin/vendor/BUILD.json`, so the plugin answers the
same way on a machine with no MoonBit toolchain. Point `PYRODUCT_PROJECT_DIR`
at a checkout and the same tool reads *that* tree instead, and
`pyroduct_gates` runs the gate there.

### Four layers that check the machine itself

Describing a machine is the easy half. Four layers below check it — each one
borrowed from a project that had to solve the same problem in another language.

| Layer | What it pins down | Borrowed from |
|---|---|---|
| `@src.check_contracts()` | the receipt must name **exactly** the edges the transition table has — a `Block` claims a gap that really is one — evaluated at every position × slot | Sismic (design-by-contract) |
| `@multi.derive_chain(...)` | R1–R14 as a rule base, with **precedence (soft) and defeat (hard) kept apart**, and a machine-readable derivation chain for every verdict | defeasible logic / ASPIC+ |
| `@evolution.replay_gate(...)` | the *ruler* a verdict was cut with, and a re-judgement from the ledger's sealed inputs | @metaharness/flywheel |
| `@coordinator.restore(...)` | a content fingerprint for the whole runtime, and a **degradation ledger** naming every forced guess | SDYJ_Multi_Agents |

Two of these exist because the earlier version was *quietly* wrong, and quiet
was the problem. The coordinator's `restore` used to parse a damaged checkpoint
into a runtime that looked fine and was wrong everywhere — an unparseable
number became `0`, an unknown discourse type became "theoretical". It now keeps
a ledger of every forced guess and fails closed. The evolution ledger used to
record *what* was judged but not *with which ruler*; since one of the two
rulers is DoubleML-based (where the seed decides the data, and the data
decides the ruler), two runs could use two different rulers and the ledger
would look identical either way.

The results are printed live by the faces that own them: `loop` prints the
contract verdict and the trace coverage, `multi` prints the derivation chain,
`coordinator` prints the repeat gate and the degradation ledger.

## How this plugs into a running agent

The state machine is not a simulation of an agent; it is a **judgement layer
that an agent calls**. Three seams, in the order an agent meets them.

**1 · Annotate the behaviour.** When an agent acts, the caller maps the
observed utterance to a trigger (`@src.step_by_trigger`) and reads a receipt.
The receipt is the annotation: `Moved` means this sentence actually moved the
agent, `Held` means it was absorbed in place, `Block` means the machine has
no road here and the caller must not pretend otherwise. Of the 272 position ×
slot pairs, 228 answer `Block` — that number is the point. An agent
that says "your action was blocked" is quoting a table, not improvising.

**2 · Feed the outcome back.** `@evolution` scores a configuration by *asking
the machine*, not by asking a model: `evaluate(genome, opponents)` returns
four components — consensus, stability, residue, cost — where the opponents
are subjects and the response is a real `@multi.encounter` verdict. So
"this configuration did better" is a report about two characters meeting,
not a similarity score.

**3 · Gate the self-modification.** A change to the agent's configuration is
a `Candidate` (prompt / strategy / memory / code, one locus at a time). It
passes through `judge`:

- **constitutional** — three invariants (R10 residue ≥ 1; R2/R14 no
  declarative voice; R3 still open to the other) that no score can buy.
  A violation is rejected outright.
- **selection** — either hand-written weights, or a **DoubleML causal
  effect**: accept only if θ̂ > 0 *and* the 95% lower bound > 0.

Then it is written to an append-only `Ledger` that records the reason, and —
because every trail names the trail it came from — the ledger is also a tree
whose `lineage` is checked, not asserted: a non-root's parent must be a root
or an accepted change, and must differ from it by exactly one mutation.

So the loop is: **act → annotate → score → propose → gate → record**, and the
record survives the process (`cmd/coord` round-trips a checkpoint through real
disk I/O and asserts it comes back identical). What is *not* here is a model:
the "think" step is a deterministic stand-in. This layer decides what counts
as an improvement and what may not be changed; the model that does the
thinking plugs in above it.

### A real consumer: MAKED

The three seams above are not a hypothetical. [`riantr/MAKED`](https://github.com/riantr/MAKED)
is a research server that runs them, and it is the reason some of this module
reads the way it does.

**What MAKED drives.** Its five domains (Model, Data, Experience, Attack,
Knowledge) each own *a subject state machine*: 34 positions × 8 drive slots ×
53 transitions, with the group machine (20 states) coordinating across domains
and the society machine (13 positions) holding the collective. A paper
fetched from arXiv is mapped by keyword onto one of the 49 triggers, and that
trigger drives the step:

```
arxiv paper
   │  keyword heuristic
   ▼
a trigger out of the 49                     ← behaviour labelling
   │  @src.step(position, slot)
   ▼
Moved / Held / Open / Same / Block          ← execution feedback
   │  ring pointer advances; group state coordinates the domains
   ▼
DoubleML gate: θ̂ > 0 and the 95% lower bound > 0   ← admission to self-modification
   │  accept / reject / roll back
   ▼
append-only ledger, then the next round
```

**What it takes from this module.** The table's facts and its vocabulary:
`@src.all_states` / `all_slots` / `all_triggers` for the positions, slots and
edges; `label()` and `gloss()` for the table's own Chinese and the `en_*`
family for the reader's own English (MAKED renders every user-visible string
from the English layer and keeps the Chinese because *the Chinese is the
table's*, not a translation of it); `@src.after_open(position, slot, 3)` for
"what could happen next"; `@src.step_by_trigger` to name the sentence behind a
candidate edge; and the `group` and `society` packages for the collective.

**The lesson it paid for, which is the reason this module insists on the
table.** MAKED's five domains each hard-coded a drive slot by *semantic
correspondence* — "the Model domain meets data, so co-being is the natural
slot". Every one of those five slots was `Block` in the table. Eighteen steps
later, not one position had moved, and the page looked completely normal:
the ring pointer rotated, the history grew, and nothing was happening. The
bug was not a crash or a wrong number; it was a system that looked alive and
was inert.

So the rule this module is built around is the one MAKED learned the hard
way: **the output must be a fact of the table, not a wish of the modeller.**
"Does the table have a road from here, in this slot, and where does it go" is
answerable and is answered; "what *should* this position do" is not the
table's question, and a consumer that answers it for the table will be wrong
in a way nothing reports. That is why `Block` is a first-class receipt, why
the machine never picks one of several destinations for you, and why the
receipt a consumer gets is the table's edge and not an inference from it.

### What the causal claim assumes

The DoubleML gate is the one place where a statistical promise is made, so
its preconditions are stated here rather than left implicit.

**What is actually estimated.** `@ml.dml_plr` fits the partially linear model
`Y = θ·T + g(X) + ε` with `E[ε | X, T] = 0`, `T = m(X) + v`, using
Neyman-orthogonal scores and K-fold cross-fitting. It is a *nuisance-adjusted*
effect of treatment `T` on outcome `Y` given covariates `X`.

**What must hold for θ̂ to mean what it says.**

1. **No unmeasured confounding given X** (`E[ε | X, T] = 0`). This is the
   assumption that "find all confounders" cannot deliver — confounders are
   not *discovered* by the estimator, they are *assumed away* by the
   conditioning set. If a confounder is not in `X`, no amount of machine
   learning inside the estimator removes it.
2. **Overlap / positivity** — both treatment states must occur at every
   `X`. The repo's data satisfies it by construction (treatment is a
   continuous function of `X` plus noise), but **the repo does not implement
   an overlap diagnostic** — a real deployment must check it.
3. **A correctly specified or learnable nuisance** `m(X)`. Cross-fitting
   protects against *overfitting* the nuisance; it does not protect against a
   nuisance that cannot be learned from the data at hand.
4. **A well-defined intervention.** `T` must be a manipulable treatment with
   a coherent counterfactual, not a proxy for something else.

**How the repo stays honest about it.** The sensitivity layer
(`@causal`, `rv = |θ̂| / max_bias`) reports how strong an *unobserved*
confounder would have to be to overturn the conclusion — and it reports a
finite number, not a guarantee. Multiple-testing correction (BH /
Bonferroni) is applied because running the gate once per trigger would
inflate the false-positive rate far past 5%. Heterogeneity (BLP) reports
whether the effect varies across covariates. **The `causal` package is
read-only**: its numbers go into the report, never into the gate, so no
diagnostic can quietly change what counts as an accepted change.

**And the honest limit.** The dataset is **synthetic, generated by the state
machine itself** (`@ml.make_dataset`: covariates from `freedom`, phase index,
out-degree and distance-to-tranquility; treatment from those plus a random
walk's 修习 count; truth θ = 1.5 known by construction). So the repo
demonstrates that *the estimator recovers a known truth under known
confounding* — a correctness check on the estimator and on the cross-check
against `riantr/moonbit_doubleML`, **not** evidence that any real-world
intervention would come out this way. Real data brings the assumptions above;
this repo brings the machinery that would let you check them.

## Comparison with the libraries this mirrors

Each face below ports the *semantics* of a mature library in another
language — deliberately not its numbers, and deliberately not its scope.
Measured against the upstream sources (2026-10-30).

| Face | Mirrors | Upstream | What the upstream does that this does not | What this does that the upstream does not |
|---|---|---|---|---|
| `spec` | python-statemachine `io/` | JSON / YAML / SCXML → `StateChartDefinition` → machine class; parser and JSON Schema are asserted equal | **builds** a machine from a document; SCXML conformance; parallel regions and history states; guards, actions, and a callback/listener system; sync + async engines; Django integration | exports **machine → spec** and refuses the reverse direction, because a `spec → machine` constructor would create a second source of truth against its own "data is code" discipline; it carries provenance per construct (原文措辞 vs 模型整理) |
| `algebra` | Ragel | compiles regular expressions / state charts to executable FSMs in C, C++, Go, Rust, JS…; Hopcroft minimization | **generates code**; accepts a regular language as input; ships a scanner mode | reads an *existing* machine and reports its algebra (operator mapping, main-line decomposition, minimal quotient); the machine stays data |
| `aho` | pyahocorasick | Aho-Corasick automaton in C: trie + failure links + output merging, dict-like access | a general-purpose multi-pattern matcher over any strings | builds the automaton over the 49 trigger sentences and reads it as **recall structure** — the failure link is the algorithmic form of falling back on the longest shared past |
| `petri` | CarlAdam | Python Petri nets with immutable (pmap/pset) markings, `enabled_transitions`, an interactive simulator | lets you *author* arbitrary nets, with a browser simulator | reads the subject machine *as* a net (34 places, 53 transitions) and proves token conservation; a colouring boundary is stated, not faked |
| `pathsum` | FiniteStateTransducers.jl | weighted automata over a semiring; `shortest_distance` and `properties` | general weighted-automaton machinery, arbitrary semirings | tropical shortest path **on this machine** — the road-to-tranquility ladder — plus machine properties (determinism per trigger, acyclicity by design) |
| `buchi` | Büchi / ω-automata | ω-automata acceptance, emptiness, liveness | general ω-automata | the machine read as ω-automaton: non-emptiness via lasso, liveness potential, and 11 stall self-loops — 10 rejecting (structure does not enforce liveness) and 宁静's own accepted stall |
| `dmlref` / `causal` | doubleml-for-py | 20 estimator classes (PLR, LPLR, PLPR, PLIV, IRM, IIVM, the DID family, SSM, PQ, QTE, LPQ, APO(S), CVAR, BLP, PolicyTree; RDD appears in this checkout as `RDFlex`) over 91 files / ~32k lines of library, 359 / ~74k with its test suite, built on numpy / pandas / scikit-learn / scipy / statsmodels / optuna | the whole estimator family, panel data, plotting, hyperparameter tuning | **zero third-party dependencies** for the estimator (linear algebra, cross-fitting, orthogonal scores and RNG written from scratch — 1,335 lines for the whole `ml` package) and a *cross-check* against the MoonBit port `riantr/moonbit_doubleML` (22 estimators) — the repo checks itself against an independent implementation rather than shipping one |
| `loop` (contracts) | Sismic | a Python statechart interpreter/checker: macro/micro steps, before/after/always contracts attached to states and transitions, trace coverage | builds **and** runs arbitrary statecharts from YAML/JSON definitions; resolves nondeterminism by explicit priority | checks **this** machine's receipts against **this** table — the receipt must name exactly the edges the table has — evaluated at every position × slot, and reports which table rows no walk ever touched |
| `multi` (derivation chain) | defeasible logic / ASPIC+ | strict vs defeasible rules, explicit defeaters, priority over rules, argumentation semantics with extensions | general rule bases and proof search | R1–R14 as a rule base with **precedence (soft) and defeat (hard) kept apart** — the faith-discourse exception is a *defeater*, not an ordering, because priority cannot say 「除非」 — and a derivation chain per verdict, cross-checked against the encounter layer |
| `evolution` (gate audit) | @metaharness/flywheel | generations of candidates, promotion gates, a lineage bundle, gate fingerprints, and the rule that the gate is re-run rather than its logged verdict trusted | a persistent bundle, arbitrary policy strings, e-process sequential testing | the **ruler** (the weights, or the DoubleML config *including its seed*) is pinned per verdict and the gate is re-run from sealed inputs — a moved ruler, a disagreeing verdict, or an unrecorded ruler all fail closed |
| `coordinator` (replay) | SDYJ_Multi_Agents | record-and-replay: a hash-keyed cache of LLM and tool responses, prompt-hash matching, partial state written on crash, resume from a checkpoint | caching LLM responses across processes; a human-review node | a **content fingerprint** over the whole runtime, a repeat gate that runs the same plan twice, and a **degradation ledger** naming every forced guess during restore — a damaged checkpoint fails closed instead of restoring into a plausible-but-wrong runtime |

Two asymmetries are worth stating plainly. First, **pyroduct's `ml` is one
estimator (PLR) and a cross-check**, not a doubleml-for-py replacement — the
22-estimator port is a separate package that this repo consumes. Second,
the mirrored libraries are *general-purpose* and pyroduct is *not*: they take
your machine as input and give you machinery back, while pyroduct's faces
are read-only views of one particular machine. What pyroduct adds is the
provenance, the discipline that gaps are reported rather than filled, and the
gate that keeps an agent's self-modification inside constitutional bounds.

## Terminology

Every construct carries a two-character Chinese designation, an English enum
identifier, and the original wording (原文) it designates. The tables below are
the complete English rendering of the vocabulary across the three scales
(subject / group / society) and the normative layer.

The **English** column is the *code identifier*: the enum variant you write,
which is also what the published interface exposes. It is frozen — renaming
`Slot::Occasion` would break every caller that passes it to `step`. The
*English reading* is the separate `en_*` layer described further down, and it
is what prose should use. The two are allowed to differ, because they answer
different questions: the identifier names a construct in the source, the
reading names it to someone reading English.

Where the identifier's literal English word is wrong, the reading replaces it
and the reason is recorded in `src/en.mbt`:

* 处境 `Occasion` → **Situation** — an *occasion* is a particular ceremony;
  处境 is the situation one finds oneself in.
* 修习 `Discipline` → **Cultivation** — 修养 is cultivation, and "discipline"
  has to stay free for the group's 规训 `Disciplined`, which means something
  else: binding the group *and* its members and putting freedom away.
* 自缚 `Binding` → **Self-binding** — the 自 is the whole point. You bind
  yourself; the table does not.
* 交织 `Weaving` → **Interweaving** — weaving can be one-sided, 交织 is mutual,
  and it pairs with the `Interweave` trigger.
* 无路 `Block` → **No-way** — a missing road, not a missing edge. 界域
  *frontier* is a core concept in this model and "edge" would collide with it.
* 先行 `Antecedent` → **Antecedent** — kept. It was `Anticipation`, which names
  the attitude the slot produces rather than the structural relation it is.

Two more differ on purpose without the identifier being wrong: 无筹 reads
`NoFuture` / `Aimless` because the identifier names the two-character
designation while the reading names the original wording 浑噩, and 同归 reads
`Same` / `Converge` because `Same` is what pairs with `Moved` and `Held` in
code, while what actually happens is several triggers converging on one target.

One pair looks like an oversight and is not: 反顾 is `Recollection` as a phase
and `Reflection` as a position. Like 立位 (`Natural` / `Standing`), the two
carry different original wording — the phase's is 反思, the position's is 审视
— so the source itself distinguishes them. Where a designation and its source
wording are the *same*, one English word is the right answer; where the source
distinguishes them, it should.

### Phases — subject (11)

| Designation | English | Original |
|---|---|---|
| 立位 | Natural | 本然 |
| 自决 | Release | 自由的发生 |
| 自成 | Becoming | 自身与拣选 |
| 遭遇 | Otherness | 与他者相遇 |
| 归责 | Bondage | 恶感·耻感·罪感·自缚 |
| 受创 | Anguish | 痛苦与失落 |
| 奠基 | Idolatry | 偶像与根基 |
| 献身 | Glory | 崇高·激情·荣誉·敬畏 |
| 反顾 | Recollection | 反思 |
| 范导 | Upbringing | 修养之路 |
| 安位 | Serenity | 宁静 |

### Positions — subject (34)

| Designation | English | Original |
|---|---|---|
| 无忆 | NoPast | 失忆 |
| 无筹 | NoFuture | 浑噩 |
| 立位 | Standing | 站立 |
| 自由 | Freedom | 自由 |
| 紧迫 | Urgency | 紧迫感 |
| 疏离 | Alienation | 疏离感 |
| 空虚 | Emptiness | 空虚 |
| 忙碌 | Busyness | 忙碌 |
| 自身 | Selfhood | 独立的自身 |
| 交织 | Weaving | 图画 |
| 择取 | Choosing | 拣选 |
| 相遇 | Encounter | 相遇 |
| 敞开 | Opening | 敞开 |
| 受挫 | Evil | 恶感 |
| 自归 | Shame | 耻感 |
| 失权 | Guilt | 罪感 |
| 自缚 | Binding | 束缚 |
| 隐没 | Secret | 秘密 |
| 痛苦 | Suffering | 痛苦 |
| 沉落 | Loss | 失落 |
| 投射 | Idol | 偶像 |
| 立序 | Ordered | 秩序 |
| 崇奉 | Sublime | 崇高感 |
| 激情 | Passion | 激情 |
| 受赏 | Honor | 荣誉 |
| 畏怖 | Awe | 敬畏 |
| 惯习 | Habit | 习惯 |
| 反顾 | Reflection | 审视 |
| 眩晕 | Dizziness | 眩晕 |
| 平衡 | Harmony | 和谐 |
| 范型 | Model | 榜样 |
| 图绘 | Marking | 标记 |
| 修习 | Discipline | 修养 |
| 宁静 | Tranquility | 宁静 |

### Drive slots (8) and the 49 triggers

| English | Designation | Count | Triggers |
|---|---|---|---|
| Occasion | 处境 | 6 | TakeStand, FeelFinitude, FeelBoundlessness, FuseFeelings, MustBeBusy, ColdHard |
| Orientation | 取向 | 6 | ChooseMoreLasting, Complexify, SeekMoreJoy, SeekBalance, SeekGoal, TakeModel |
| Antecedent | 先行 | 4 | TouchFuture, TryMethods, Approximate, WaitNext |
| Act | 行动 | 9 | ActInFreedom, BindSelf, Avoid, CutPast, SummonIdol, MarkGoodBad, RedrawMap, Endure, RemoveReefs |
| Feedback | 反馈 | 8 | Sting, BlameSelf, EnactOrder, AbsorbGlory, Reward, Dread, WidenFrontier, Ascend |
| Hold | 持存 | 8 | KeepContinuity, Deposit, TurnToResidue, Interweave, Surprise, Doubt, Linger, Habituate |
| CoBeing | 共在 | 3 | MeetOther, GoodFaith, OpenArms |
| Unveil | 揭蔽 | 5 | AttributeSelf, FillEmptiness, CoolDown, DoubtOneself, ReopenByHorizon |

### Step contract (5 outcomes)

| Receipt | Variant | English | Chinese |
|---|---|---|---|
| moved | `Moved` | Moved | 迁 |
| held | `Held` | Held | 守 |
| undecided | `Open` | Undecided | 未定 |
| same target | `Same` | Converge | 同归 |
| no way | `Block` | No-way | 无路 |

Two rows are worth reading twice, because the **variant name and the English
label differ**: the variant for 未定 is `Open`, not `Undecided`, and the English
for 同归 is `Converge`, not `Same`. A consumer that matches on the English
wording rather than the variant will not compile — and the naming is not
arbitrary: `Open` says the *table* leaves the destination open, while `Undecided`
says the *subject* has not decided, and the machine does not decide for it.

`Same` is what a slot-granular step returns when several triggers leave one
position for one target: the destination is settled, the *sentence* is not named,
so nothing is invented. Use `step_by_trigger` when you need to know which one.

### The other axis of the same table

`exitable_slots(position)` is to a position what `positions_reachable_by(slot)`
is to a slot: **the slots that actually have an edge out of this position**, in
the table's own order. `moving_slots(position)` narrows it to the slots whose
receipt is `Moved` — the ones that take the subject somewhere else rather than
back to where it was. `undecided_at(position)` asks whether any slot leaves the
destination undecided.

Those three are facts of the table, and they are facts a consumer needs *before*
it drives anything. The reason they exist here rather than in each consumer is
that a consumer who rebuilds them has made a second copy of the table, and a
second copy is one that can be wrong without anybody noticing. A downstream
consumer did rebuild all three (`riantr/MAKED`, `Model::exitable_slots` and
friends) before they were here.

On the current table: 44 of the 272 position × slot pairs have an edge, 29 of
those actually move the subject, 8 positions offer more than one slot, and 5
positions offer exactly one slot that **does not move them** — and those five
are exactly the five undecided points (自由 × 处境, 自身 × 持存, 立序 × 反馈,
激情 × 反馈, 平衡 × 取向). The table gives you a road there and refuses to say
which one.

### Group — phases (9)

| Designation | English | Gloss |
|---|---|---|
| 聚散 | Gathering | a crowd with no bonds yet — the group is not yet a subject |
| 成体 | Bodied | common tongue and discourse give the group a body |
| 立序 | Ordering | norms raised from reason or tradition |
| 分歧 | Diverging | difference acknowledged, regimes clash, horizons close |
| 失度 | Excess | the third party handed to the absolute — projection, one voice |
| 自缚 | SelfBound | the group binds itself and its members; the hidden becomes forbidden |
| 受损 | Impaired | collective wounds, dispersal |
| 修习 | Cultivating | return, endure, widen |
| 宁定 | Resting | every pair complete in the two sincerities; nothing absolutized |

### Group — states (20)

| Designation | English | Phase |
|---|---|---|
| 散在 | Scattered | Gathering |
| 趋同 | Converging | Gathering |
| 共语 | CommonTongue | Bodied |
| 商谈 | Discourse | Bodied |
| 规范 | Normed | Ordering |
| 共识 | Consensus | Ordering |
| 歧见 | Dissensus | Diverging |
| 对峙 | Confronting | Diverging |
| 割据 | Partitioned | Diverging |
| 投射 | Projected | Excess |
| 独白 | Monologic | Excess |
| 规训 | Disciplined | SelfBound |
| 遮蔽 | Concealed | SelfBound |
| 创伤 | Wounded | Impaired |
| 离散 | Dispersed | Impaired |
| 复归 | Returning | Cultivating |
| 修习 | Practicing | Cultivating |
| 扩界 | Widening | Cultivating |
| 相契 | Attuned | Resting |
| 宁定 | Settled | Resting |

Group triggers (22): Appear, Attention, SharedMedium, RaiseClaims,
NormFromTradition, NormFromReason, Agree, Differ, Clash, CloseHorizon,
Absolutize, OneVoice, Bind, Suppress, Reopen, BreakUp, TurnBack, RemoveReefs,
Widen, MutualCheng, Settle, Reenter.

### Society — phases (8)

The society machine has no English reading layer — the code identifier *is*
the English here. Its phases name the **theoretical moment**, its states the
**structural position**, so four pairs differ on purpose and every word fits
what it names: 缺口 is `Aporia` (an impasse) as a phase and `Gap` as a position;
系统 is `Instrument` (the instrumental layer) and `System`; 规范 is `Rule` and
`Norm`; 殖民 is `Domination` and `Colony`. 商谈 was the exception and has been
corrected: the phase read `Speech`, which is 言语 rather than the procedure
Habermas compares to a washing machine, and which collided with the adjacent
`Language` phase. It now reads `Discourse`, like the position it contains.

| Designation | English | Gloss |
|---|---|---|
| 生活 | Life | the lifeworld, organized by language |
| 语言 | Language | supra-subjective (Gadamer) vs. intersubjective (Habermas) |
| 商谈 | Discourse | claims raised, filtered, justified, turned into consensus |
| 规范 | Rule | norms set by practical discourse carry a "past tense" label |
| 缺口 | Aporia | the third party is impossible in reality — the utopian fate |
| 系统 | Instrument | the system, mediated by money and power |
| 殖民 | Domination | inner colonization of the lifeworld; distorted communication |
| 复建 | Rebuild | rebuild the distorted communicative realm |

### Society — states (13)

| Designation | English | Phase |
|---|---|---|
| 世界 | World | Life |
| 超体 | Suprasubjective | Language |
| 间性 | Intersubjective | Language |
| 主张 | Claim | Discourse |
| 商谈 | Discourse | Discourse |
| 辩护 | Justification | Discourse |
| 共识 | Consensus | Discourse |
| 规范 | Norm | Rule |
| 缺口 | Gap | Aporia |
| 系统 | System | Instrument |
| 殖民 | Colony | Domination |
| 扭曲 | Distortion | Domination |
| 重建 | Reconstruction | Rebuild |

Society triggers (18): SpeakLanguage, BuildIntersubjective, RaiseClaims,
EnterDiscourse, Filter, Justify, Subsume, Store, EnactNorm, LabelPast,
DemandThird, Serve, Expand, Colonize, Distort, Hinder, Reconstruct, Circulate.

### Truth regimes (5) · discourse types (4) · validity claims (4)

| Designation | English | Gloss |
|---|---|---|
| 内在秩序 | Immanent | truth as an eternal order already in the world (ancient Egypt) |
| 逻各斯 | Logos | truth as eternal speech, guaranteed by the rational soul (ancient Greece) |
| 超主体性 | SuperSubjective | Gadamer: understanding and language are supra-subjective events |
| 主体间性 | InterSubjective | Habermas: truth is intersubjective validity claims, woven into a net |
| 诚然 | ChengRan | the author's own scheme: a hermeneutics of sincerity, unified in self-illumination |

| Designation | English |
|---|---|
| 理论商谈 | Theoretical |
| 实践商谈 | Practical |
| 表达性商谈 | Aesthetic |
| 信仰商谈 | Faith |

| Designation | English | Claim |
|---|---|---|
| 真实性 | Truthfulness | propositional truth — objective world |
| 正当性 | Legitimacy | normative rightness — social world |
| 他之诚 | Authenticity | speech-content congruence (other-sincerity) |
| 己之诚 | Sincerity | act–intention congruence (self-sincerity) |

Claim phases: 事前 Before · 事中 During · 事后 After.

### Normative rules R1–R14

| Code | Designation | English |
|---|---|---|
| R1 | 体制优先 | Regime precedence |
| R2 | 不独断 | No dogmatism |
| R3 | 解蔽—遮蔽 | Unconcealment–concealment |
| R4 | 有效性时序 | Validity-claim timing |
| R5 | 两诚区分 | Two-sincerity distinction |
| R6 | 弃符合论、存方法 | Drop correspondence, keep method |
| R7 | 构成性 | Constitutivity |
| R8 | 第三者 | The third party |
| R9 | 商谈类型 | Discourse types |
| R10 | 谬误残余 | Error residue |
| R11 | 不可闭合 | Never closed |
| R12 | 诚然相契 | ChengRan resonance |
| R13 | 横检纵共 | Horizontal review, vertical commonality |
| R14 | 共识即建议 | Consensus as suggestion |

### Packages

`src` (subject machine) · `multi` (normative rules) · `group` (group emergence) ·
`society` (two-level social model) · `ml` (from-scratch DoubleML) · `evolution`
(agent state machine) · `coordinator` (research-agent runtime) · `dmlref`
(external cross-check) · `causal` (causal diagnostics) · `audit` (three-mirror
static audit of the subject machine, and `fleet`/`mutants` for the group and
society machines plus a mutation net proving the audit can see) · `snnref`
(spike-sediment experiment) · plus the `mbti` face: the repo's **own**
`pkg.generated.mbti` files put through the same three mirrors (repeated
signature / malformed line / unknown type reference). That face scans an
embedded snapshot so it can run under wasm; a native tripwire proves the
snapshot still equals the files on disk.

### Discipline terms

原文直述 *verbatim from the source* · 模型整理 *model reconstruction* · 两诚
*two sincerities* · 解蔽—遮蔽 *unconcealment–concealment* · 没有证据就不前进
*no evidence, no advance* · 双诚之比 *two-sincerity ratio* · 同判·不重裁
*same verdict, not re-adjudicated* · 三鉴 *three mirrors (structure / type /
behavior)* · 往返一致 *round-trips identically*.

### English rendering

Every construct carries an English counterpart alongside the Chinese source
layer: `SubjectState::en_label` / `en_gloss`, `Slot::en_designation` / `en_gloss`,
`Phase::en_label`, `Trigger::en_label`, `Outcome::en_label`, and
`GroupState::en_designation` / `en_gloss` / `GroupPhase::en_label`.

The two layers are deliberately asymmetric. `label()` and `gloss()` are the
record of what the source text said and are never translated; the `en_*` family
is a reading aid for consumers that cannot render Chinese. Where the two
disagree, `label()` is right by definition.

The reading is chosen construct by construct against what the construct
actually is, not by translating the Chinese word for word. One designation gets
one English word wherever it appears: 修习 is `Cultivation` in the subject
machine's state, in the group machine's phase, and in the group machine's state
— which is what forced 规训 to keep `Disciplined` and 修习 to give up
`Discipline`. A phase is named by one word like every other construct, because
the phrase it used to carry ("The Arising of Freedom") went stale the moment a
state joined the phase, and what a phase contains is the members list's job.

No face renders this layer today; it is exported vocabulary for a surface that
needs to read the model in English.

Nothing in the English layer participates in the state machine. A mistake there
can mislabel a transition but cannot invent one. `src/en_test.mbt` asserts the
property that actually matters to a consumer — that every English string is
ASCII (so no Chinese has leaked in) and distinct from the source string it sits
beside — rather than trusting the match statements to be right.

## Quick Start

Add the module, then run the suite:

```
moon add riantr/pyroduct
moon test             # Total tests: 250, passed: 250, failed: 0.
```

From this repository, every layer prints a report:

```
moon run cmd/main -- report        # subject state machine
moon run cmd/main -- slots         # drive slots: 49 triggers → 8 slots
moon run cmd/main -- multi         # normative rules R1–R14 + scenarios
moon run cmd/main -- group         # group state machine
moon run cmd/main -- society       # two-level social model
moon run cmd/main -- evolution     # mutation / fitness / gate / persistence / heredity
moon run cmd/main -- cycle         # subject cycle: position × slot × causal feedback
moon run cmd/main -- coordinator   # research-agent coordinator
moon run --target native cmd/coord # real disk I/O: checkpoint round-trips identically
```

## Example

```moonbit nocheck
// Subject: positions, main line, drive slots, step contract
let states : Array[@src.SubjectState] = @src.all_states()      // 34 of them
let ok     : Bool = @src.reachable(@src.initial(), @src.terminal())
let moved  : @src.Outcome = @src.step(@src.Standing, @src.Occasion) // Moved

// One encounter of two subjects: regime, two sincerities, and claim timing all adjudicate
let me    = @multi.subject(1, @multi.rendezvous(), @multi.InterSubjective, 70, 70, 9)
let other = @multi.subject(2, @multi.rendezvous(), @multi.ChengRan, 80, 80, 9)
let claim : @multi.ValidityClaim = { kind: @multi.Truthfulness, phase: @multi.During }
let out   = @multi.encounter(me, other, @multi.Theoretical, claim)

// Society: two invariants locked by tests
let never_closes : Bool = @society.no_final_closure()

// Agent state machine: enumerate candidates → gate → append-only ledger
let agent  = @evolution.default_agent()
let ledger = @evolution.evolve(agent, @evolution.default_world(),
                               @evolution.Weighted(@evolution.truth_objective()), 3)

// Coordinator: run a demo study, write / read back the checkpoint
let rt   = @coordinator.new_runtime()
ignore(rt.step(@coordinator.demo_tasks(), @coordinator.demo_questions(),
               @coordinator.demo_workers(), @coordinator.demo_datasets(),
               @coordinator.demo_world(), @coordinator.demo_parent(),
               @coordinator.demo_candidate()))
let restored = @coordinator.restore(rt.checkpoint())
let same : Bool = restored.round_trips()
```

## Gates and drift detectors

`moon check`, `moon fmt --check`, `moon test` (250 wasm tests) plus the two
native-only suites (`snnref`, `tools/ifacescan`) are the baseline. Six
detectors run on top, because a green suite says nothing about a claim written
in prose:

| Detector | Catches |
|---|---|
| `python tools/validate_dependencies.py` | a dependency edge drawn in `architecture/*.dot` that the code does not have, or one the code has that the diagram omits; also a DOT file whose `model-version` header disagrees with `moon.mod` |
| `python tools/validate_resolved_deps.py` | a pin in `moon.mod` that does not resolve to the version it names — `moon update` only refreshes the registry index, so nothing else in the build notices that the pin drifted |
| `python tools/validate_cli_faces.py` | the bridge's `faces()`, the CLI's `match` arms, the CLI's usage header and the count the CLI's own error message publishes disagreeing with each other; it found a subcommand the CLI could dispatch but the bridge did not know |
| `python tools/validate_pin_copies.py` | a `package@version` literal in the tree that no longer equals the pin it copies — the two READMEs, `AGENTS.md`, the architecture diagrams, the package doc comments, the plugin's face catalog and both skill copies |
| `python tools/validate_readme_facts.py` | a state / transition / phase / trigger / slot count in these READMEs that no longer matches the source tables, and a wasm test count that disagrees with itself or with the code — published 0.1.31 claimed 205 in one place and 209 in another, and this detector said everything matched, because it had only ever counted model facts |
| `node plugin/tools/validate-plugin.mjs` | plugin drift: face count, test count, model facts and page citations in the agent-facing descriptions |

Each was written after a specific drift went unnoticed — a false edge in the
diagram, a stale test count in a tool description. They run in `gate.yml` on
every push and PR, and again in `publish.yml` before a release.

## Used By

- [`riantr/MAKED`](https://github.com/riantr/MAKED) — a research server that runs
  one subject state machine per domain, the group machine across domains and the
  society machine for the collective; it labels behaviour with the 49 triggers,
  takes the receipts as execution feedback, and gates its own self-modification
  on a DoubleML causal effect. It is also why `exitable_slots` /
  `moving_slots` / `undecided_at` are here rather than in each consumer: MAKED
  rebuilt all three in its own data copy first.
- `cmd/main` — the report entry for every layer above: `report` / `slots` /
  `loop` / `multi` / `group` / `society` / `evolution` / `cycle` / `coordinator`,
  `dmlref` / `causal` / `audit` / `fleet` / `mutants` / `mbti`, plus
  `mermaid` / `dot` / `genesis` / `course` / `naming` / `principle` / `intuition`,
  the five analysis faces `pathsum` / `algebra` / `petri` / `aho` / `buchi`, and
  the presentational `all`.
- `cmd/coord` — a native binary that runs the coordinator and round-trips its
  checkpoint through real disk I/O (`.openseek/`, gitignored).
- `cmd/jsoncli` — the JSON bridge the two agent plugins spawn (31 faces).

## Attribution

- Source text: 任勇祥《伽达默尔与哈贝马斯真理观比较》(Shanghai Academy of
  Social Sciences, 2008) and its appendix 《通往宁静之路：个体道德发生论纲要》.
  Every construct in the model cites the chapter / section / page of that text
  and explicitly distinguishes 原文直述 (verbatim from the source) from 模型整理
  (model reconstruction).
- License: MIT (see `LICENSE`).
