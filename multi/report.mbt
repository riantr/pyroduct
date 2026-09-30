///|
/// 报告层：规则表、场景演示、真理谱系与未解难题。

///|
/// 真理谱系的一条。
pub struct GenealogyEntry {
  tradition : String
  view : String
}

///|
/// 作者自建的中／西／印谱系（外加古埃及）。
pub fn genealogy() -> Array[GenealogyEntry] {
  [
    {
      tradition: "古埃及（第一章，P.13）",
      view: "真理是内在于世界的秩序；它是永恒的，人本来就身在其中，不必寻求。玛阿特女神既是真理之神又是正义之神（P.13 注）。",
    },
    {
      tradition: "古希腊（第一章，P.13-14）",
      view: "真理是永恒的言说（logos），智慧能使人认识它并说将出来，理性灵魂为探寻提供保障。退化史：苏格拉底的对话之路使真理不再是个人之事，柏拉图的回忆削弱了对话者，亚里士多德索性把对话者排除在外、用逻辑学作个人追求真理的保障——对话性的逻各斯被转换为独白性的逻辑。",
    },
    {
      tradition: "中国（前言，P.2 注 2、3）",
      view: "「真理」一词最初出现在佛经翻译中，意旨作为实践智慧的真实不虚的解脱之道；陶弘景《真诰》有「故眞理之既分」，《佛本行集经》有「所有真理，隐之与显」，其意似近于海德格尔所说之解蔽。作者并不同意杨国荣「说『道理』」：「道」通于「一统和」，「理」关乎事象。",
    },
    {
      tradition: "近代西方（第一章，P.14；第五章余论，P.55）",
      view: "澄然的诠释学：以理性为根基，仍留着主体哲学的遗产；形而上学的真理在走过一条异化之路后，其使命亦已终结于科学之中。",
    },
    {
      tradition: "作者方案（第五章余论，P.55）",
      view: "诚然的诠释学：以「诚」（言语内容之契合与行为—意向之契合）为基，与哈贝马斯的「真诚性」相会通，统于自性内照，其后乃能入于无人我、齐万物之境。",
    },
  ]
}

///|
/// 一个未解难题。
pub struct OpenProblem {
  question : String
  note : String
}

///|
/// 作者自认留下的缺口。模型把它们登记为数据，而不是替它们下结论（R2）。
pub fn open_problems() -> Array[OpenProblem] {
  [
    {
      question: "若哈贝马斯最终以理性为根基的命题真实性就是真理，那么如何理解他及法兰克福学派对主—客二分符合论与工具理性的批判？",
      note: "既是作者对两位哲学家的诘问，也标示出其「解蔽事件论」尚未成形的缺口。",
    },
    {
      question: "这种不同于「他之诚」「己之诚」的「诚」，能否与哈贝马斯的「真诚性」相会通？能否由此开出刻有中国印记的「诚然的诠释学」？",
      note: "作者自设的开放问题：本模型把它登记为数据，不替它作结。",
    },
    {
      question: "指向主观世界的商谈能否称作「信仰商谈」，宗教真理能否纳入共识真理理论？",
      note: "作者认为这不失为化解宗教冲突的一条可行途径；本模型只在信仰商谈中把它当作一条带可修订标记的例外。",
    },
  ]
}

///|
/// 场景演示：一小组遭遇，展示规则如何落成决断。
pub fn scenarios() -> Array[(String, EncounterOutcome)] {
  let mid = ValidityClaim::{ kind: Truthfulness, phase: During, }
  let before = ValidityClaim::{ kind: Sincerity, phase: Before, }
  let after = ValidityClaim::{ kind: Legitimacy, phase: After, }
  let mistimed = ValidityClaim::{ kind: Sincerity, phase: During, }
  let here = @sm.Encounter
  [
    (
      "超主体性 × 主体间性（理论商谈·事中真实性）",
      encounter(
        subject(1, here, SuperSubjective, 70, 70, 9),
        subject(2, here, InterSubjective, 70, 70, 9),
        Theoretical,
        mid,
      ),
    ),
    (
      "超主体性 × 超主体性（理论商谈·事中真实性）",
      encounter(
        subject(1, here, SuperSubjective, 70, 70, 9),
        subject(2, here, SuperSubjective, 65, 75, 9),
        Theoretical,
        mid,
      ),
    ),
    (
      "主体间性 × 主体间性（实践商谈·事后正当性）",
      encounter(
        subject(1, here, InterSubjective, 70, 70, 9),
        subject(2, here, InterSubjective, 60, 60, 9),
        Practical,
        after,
      ),
    ),
    (
      "诚然 × 诚然，双诚俱足（表达性商谈·事前真诚性）",
      encounter(
        subject(1, here, ChengRan, 80, 80, 9),
        subject(2, here, ChengRan, 75, 85, 9),
        Aesthetic,
        before,
      ),
    ),
    (
      "诚然 × 诚然，诚未具足",
      encounter(
        subject(1, here, ChengRan, 80, 80, 9),
        subject(2, here, ChengRan, 40, 90, 9),
        Aesthetic,
        before,
      ),
    ),
    (
      "逻各斯 × 逻各斯，诚差很大",
      encounter(
        subject(1, here, Logos, 90, 90, 9),
        subject(2, here, Logos, 30, 30, 9),
        Theoretical,
        mid,
      ),
    ),
    (
      "内在秩序 × 逻各斯",
      encounter(
        subject(1, here, Immanent, 70, 70, 9),
        subject(2, here, Logos, 70, 70, 9),
        Theoretical,
        mid,
      ),
    ),
    (
      "相位错置：以事中位置提出事前真诚性",
      encounter(
        subject(1, here, InterSubjective, 70, 70, 9),
        subject(2, here, InterSubjective, 70, 70, 9),
        Aesthetic,
        mistimed,
      ),
    ),
    (
      "体制相左，但走信仰商谈（作者构想）",
      encounter(
        subject(1, here, SuperSubjective, 70, 70, 9),
        subject(2, here, InterSubjective, 70, 70, 9),
        Faith,
        mid,
      ),
    ),
  ]
}

///|
/// 规则表文本。
pub fn render_rules() -> String {
  let lines : Array[String] = []
  for r in rules() {
    lines.push("\{r.code}　\{r.name}：\{r.text}")
    lines.push("　　依据：\{r.basis}")
    lines.push("　　出处：\{citation_of(r.code)}")
  }
  lines.join("\n")
}

///|
/// 场景表文本。
pub fn render_scenarios() -> String {
  let lines : Array[String] = [
    "场景 | 决断 | 甲 → | 乙 →", "---|---|---|---",
  ]
  for s in scenarios() {
    let (name, o) = s
    lines.push(
      "\{name} | \{o.verdict.label()} | \{o.a.state.designation()} | \{o.b.state.designation()}",
    )
  }
  lines.join("\n")
}

///|
/// 谱系文本。
pub fn render_genealogy() -> String {
  let lines : Array[String] = []
  for g in genealogy() {
    lines.push("- \{g.tradition}：\{g.view}")
  }
  lines.join("\n")
}

///|
/// 未解难题文本。
pub fn render_open_problems() -> String {
  let lines : Array[String] = []
  let ps = open_problems()
  let mut i = 0
  while i < ps.length() {
    lines.push("\{i + 1}. \{ps[i].question}")
    lines.push("   —— \{ps[i].note}")
    i += 1
  }
  lines.join("\n")
}

///|
/// 多主体行为规则总报告。
pub fn render_multi_report() -> String {
  let lines : Array[String] = []
  lines.push("# 多主体行为规则")
  lines.push("")
  lines.push("## 根本判断")
  lines.push(
    "分歧之根不在具体论点，而在**对「主体」的态度**：伽达默尔取超主体性（理解与",
  )
  lines.push(
    "语言均为超主体事件），哈贝马斯取主体间性（真理即主体间有效性主张）。二者都",
  )
  lines.push(
    "批判主观主义，只是路径不同；真正的分水岭是「第三者」由谁扮演。",
  )
  lines.push("")
  lines.push(
    "## 真理体制与出处（第一章／第二章／第四章／第五章）",
  )
  for r in [Immanent, SuperSubjective, InterSubjective, ChengRan, Logos] {
    lines.push("- \{r.label()}：\{r.basis()}")
  }
  lines.push("")
  lines.push("## 规则（R1–R14）")
  lines.push(render_rules())
  lines.push("")
  lines.push(
    "## 场景演示（每个主体从单一状态机的「相遇」出发）",
  )
  lines.push(render_scenarios())
  lines.push("")
  lines.push("## 真理谱系（作者自建）")
  lines.push(render_genealogy())
  lines.push("")
  lines.push("## 未解难题（登记，不作结）")
  lines.push(render_open_problems())
  lines.join("\n")
}
