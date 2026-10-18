// Pyroduct System Model (Container Level)
// Skill: system-modeler + c4model
// Date: 2026-10-11
// Scope: Internal containers/modules with boundaries

systemModel {
    // === State Machine Family ===
    container(stateMachineFamily, "状态机家族", "MoonBit packages", "把中国哲学文本建模为可运行、可测试的状态机族") {
        metadata {
            layer("L3 Component")
            confidence("high")
        }
    }

    container(src, "主体状态机 (src)", "MoonBit package", "34状态·53迁移·11阶段·8驱动槽·执行契约") {
        parent(stateMachineFamily)
        metadata {
            sourceRef("src/moon.pkg")
            confidence("high")
            constraint("零import——不依赖任何第三方或兄弟包")
        }
    }

    container(multi, "多主体规范 (multi)", "MoonBit package", "14条规范规则R1-R14·5种真理体制·4种商谈类型·4种有效性主张") {
        parent(stateMachineFamily)
        metadata {
            sourceRef("multi/moon.pkg")
            confidence("high")
        }
    }

    container(group, "群体状态机 (group)", "MoonBit package", "20状态·44迁移·9阶段·成员配置→涌现") {
        parent(stateMachineFamily)
        metadata {
            sourceRef("group/moon.pkg")
            confidence("high")
            note("无驱动槽——触发即驱动")
        }
    }

    container(society, "社会状态机 (society)", "MoonBit package", "13状态·28迁移·8阶段·生活世界vs系统") {
        parent(stateMachineFamily)
        metadata {
            sourceRef("society/moon.pkg")
            confidence("high")
            note("无驱动槽——触发即驱动；trigger-deterministic")
        }
    }

    // === Agent Layer ===
    container(agentLayer, "智能体层", "MoonBit packages", "演化层与科研协调器") {
        metadata {
            layer("L3 Component")
            confidence("high")
        }
    }

    container(evolution, "演化层 (evolution)", "MoonBit package", "变异空间/适应度/闸门/只追加账本/遗传") {
        parent(agentLayer)
        metadata {
            sourceRef("evolution/moon.pkg")
            confidence("high")
        }
    }

    container(coordinator, "科研协调器 (coordinator)", "MoonBit package", "任务/制品/规划/外部证据/内容记忆/署名/可重放运行时") {
        parent(agentLayer)
        metadata {
            sourceRef("coordinator/moon.pkg")
            confidence("high")
        }
    }

    // === Analysis & Tools ===
    container(analysisTools, "分析与工具", "MoonBit packages", "自研DoubleML、交叉验证、因果诊断、三鉴审计、脉冲沉淀、可视化") {
        metadata {
            layer("L3 Component")
            confidence("high")
        }
    }

    container(ml, "自研DoubleML (ml)", "MoonBit package", "PLR/交叉拟合/正交分数/推断——完全自包含") {
        parent(analysisTools)
        metadata {
            sourceRef("ml/moon.pkg")
            confidence("high")
            constraint("永不import数值库")
        }
    }

    container(dmlref, "外部交叉验证 (dmlref)", "MoonBit package", "与riantr/moonbit_doubleML@0.163.3互校") {
        parent(analysisTools)
        metadata {
            sourceRef("dmlref/moon.pkg")
            confidence("high")
        }
    }

    container(causal, "因果诊断 (causal)", "MoonBit package", "敏感性/多重检验/异质性——0.163.3深用") {
        parent(analysisTools)
        metadata {
            sourceRef("causal/moon.pkg")
            confidence("high")
            constraint("只读——不改判据")
        }
    }

    container(audit, "三鉴审计 (audit)", "MoonBit package", "结构鉴/类型鉴/行为鉴——参考消费者") {
        parent(analysisTools)
        metadata {
            sourceRef("audit/moon.pkg")
            confidence("high")
            constraint("只读——不改判据、不修表")
        }
    }

    container(snnref, "脉冲沉淀实验 (snnref)", "MoonBit package", "49触发→泊松脉冲→STDP→8槽划分恢复") {
        parent(analysisTools)
        metadata {
            sourceRef("snnref/moon.pkg")
            confidence("high")
            constraint("native only")
        }
    }

    container(viz, "可视化 (viz)", "MoonBit package", "三台机Mermaid/HTML——11阶段复合状态·行程视图") {
        parent(analysisTools)
        metadata {
            sourceRef("viz/moon.pkg")
            confidence("high")
        }
    }

    // === CLI Entry Points ===
    container(cliEntryPoints, "CLI入口", "MoonBit executables", "命令行接口") {
        metadata {
            layer("L2 Container")
            confidence("high")
        }
    }

    container(cmdMain, "cmd/main", "WASM executable", "36命名子命令——report/slots/multi/group/society/evolution/cycle/coordinator/mermaid/dot/...") {
        parent(cliEntryPoints)
        metadata {
            sourceRef("cmd/main/moon.pkg")
            confidence("high")
            targets("native+wasm+wasm-gc+js")
        }
    }

    container(cmdCoord, "cmd/coord", "Native executable", "科研协调器CLI——真实磁盘IO——往返一致") {
        parent(cliEntryPoints)
        metadata {
            sourceRef("cmd/coord/moon.pkg")
            confidence("high")
            targets("native only")
        }
    }

    container(cmdIfacescan, "cmd/ifacescan", "Native executable", ".mbti漂移绊线——扫每个真实pkg.generated.mbti") {
        parent(cliEntryPoints)
        metadata {
            sourceRef("cmd/ifacescan/moon.pkg")
            confidence("high")
            targets("native only")
            note("故意不是cmd/main子命令——需要磁盘IO")
        }
    }

    container(cmdJsoncli, "cmd/jsoncli", "JS executable", "JSON桥接——DeepSeek Harness插件 + MiniMax插件") {
        parent(cliEntryPoints)
        metadata {
            sourceRef("cmd/jsoncli/moon.pkg")
            confidence("high")
            targets("js")
            note("31个face——纯spawner/formatter")
        }
    }

    // === Plugin ===
    container(plugin, "MiniMax Code插件", "Node.js MCP server", "本地插件——server.mjs + pyroduct-model skill") {
        metadata {
            layer("L2 Container")
            confidence("high")
            note("源码在plugin/——安装副本在~/.minimax/plugins/pyroduct-model/")
        }
    }

    // === Relationships ===
    // State machine family
    multi -> src {
        type("depends-on")
        description("引用主体机类型")
        confidence("high")
    }

    group -> multi {
        type("depends-on")
        description("引用规范规则")
        confidence("high")
    }

    society -> multi {
        type("depends-on")
        description("引用规范规则")
        confidence("high")
    }

    // Agent layer
    evolution -> src {
        type("depends-on")
        description("位置×驱动槽的执行契约")
        confidence("high")
    }

    evolution -> multi {
        type("depends-on")
        description("行为规则")
        confidence("high")
    }

    evolution -> group {
        type("depends-on")
        description("群体机Open裁决")
        confidence("high")
    }

    evolution -> ml {
        type("depends-on")
        description("DoubleML闸门")
        confidence("high")
    }

    coordinator -> multi {
        type("depends-on")
        confidence("high")
    }

    coordinator -> ml {
        type("depends-on")
        confidence("high")
    }

    coordinator -> evolution {
        type("depends-on")
        confidence("high")
    }

    // Analysis
    dmlref -> ml {
        type("depends-on")
        description("交叉验证自研实现")
        confidence("high")
    }

    causal -> ml {
        type("depends-on")
        confidence("high")
    }

    audit -> src {
        type("depends-on")
        description("主体机表→MachineSpec")
        confidence("high")
    }

    audit -> group {
        type("depends-on")
        confidence("high")
    }

    audit -> society {
        type("depends-on")
        confidence("high")
    }

    snnref -> src {
        type("depends-on")
        confidence("high")
    }

    viz -> src {
        type("depends-on")
        confidence("high")
    }

    viz -> group {
        type("depends-on")
        confidence("high")
    }

    viz -> society {
        type("depends-on")
        confidence("high")
    }

    // CLI
    cmdMain -> src { type("depends-on"); confidence("high") }
    cmdMain -> multi { type("depends-on"); confidence("high") }
    cmdMain -> group { type("depends-on"); confidence("high") }
    cmdMain -> society { type("depends-on"); confidence("high") }
    cmdMain -> evolution { type("depends-on"); confidence("high") }
    cmdMain -> coordinator { type("depends-on"); confidence("high") }
    cmdMain -> ml { type("depends-on"); confidence("high") }
    cmdMain -> dmlref { type("depends-on"); confidence("high") }
    cmdMain -> causal { type("depends-on"); confidence("high") }
    cmdMain -> audit { type("depends-on"); confidence("high") }
    cmdMain -> viz { type("depends-on"); confidence("high") }

    cmdCoord -> coordinator { type("depends-on"); confidence("high") }
    cmdCoord -> moonbitAsync {
        type("depends-on")
        description("native磁盘IO")
        confidence("high")
    }

    cmdIfacescan -> audit { type("depends-on"); confidence("high") }
    cmdIfacescan -> moonbitAsync {
        type("depends-on")
        confidence("high")
    }

    cmdJsoncli -> src { type("depends-on"); confidence("high") }
    cmdJsoncli -> multi { type("depends-on"); confidence("high") }
    cmdJsoncli -> group { type("depends-on"); confidence("high") }
    cmdJsoncli -> society { type("depends-on"); confidence("high") }
    cmdJsoncli -> evolution { type("depends-on"); confidence("high") }
    cmdJsoncli -> coordinator { type("depends-on"); confidence("high") }
    cmdJsoncli -> audit { type("depends-on"); confidence("high") }
    cmdJsoncli -> viz { type("depends-on"); confidence("high") }

    // Plugin
    plugin -> cmdJsoncli {
        type("calls")
        description("MCP桥接——JSON请求→JSON响应")
        protocol("JSON-RPC")
        confidence("high")
    }

    // External dependencies
    src -> moonbitCore {
        type("depends-on")
        description("官方标准库")
        confidence("high")
    }

    dmlref -> moonbitDoubleML {
        type("depends-on")
        description("外部参考实现@0.163.3")
        confidence("high")
    }

    causal -> moonbitDoubleML {
        type("depends-on")
        confidence("high")
    }

    snnref -> moonbitSNN {
        type("depends-on")
        description("脉冲神经网络库@0.155.0")
        confidence("high")
    }

    audit -> moonbitStaticAnalysis {
        type("depends-on")
        description("三鉴库@0.4.29")
        confidence("high")
    }
}
