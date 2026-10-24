// Pyroduct System Context Diagram
// Skill: system-modeler + c4model
// Date: 2026-10-11
// Scope: System boundary, external actors, and major relationships

systemContext {
    person(researcher, "研究者", "使用状态机模型进行哲学文本分析的研究人员")
    person(agentDeveloper, "Agent 开发者", "通过 JSON CLI 或插件访问模型的开发者")

    system(pyroduct, "Pyroduct", "MoonBit 状态机族：把中国哲学文本建模为可运行、可测试的主体/群体/社会状态机，加上演化层和科研协调器") {
        metadata {
            location("External")
            repository("https://gitee.com/ren-yongxiang/pyroduct.git")
            version("0.1.29")
        }
    }

    system(moonbitCore, "moonbitlang/core", "MoonBit 官方标准库") {
        metadata {
            location("External")
        }
    }

    system(moonbitAsync, "moonbitlang/async", "MoonBit 异步库（native 磁盘 IO）") {
        metadata {
            location("External")
            version("0.22.5")
        }
    }

    system(moonbitDoubleML, "riantr/moonbit_doubleML", "外部 DoubleML 参考实现") {
        metadata {
            location("External")
            version("0.164.34")
        }
    }

    system(moonbitSNN, "riantr/snn_mbt", "脉冲神经网络库（native 专属）") {
        metadata {
            location("External")
            version("0.166.2")
        }
    }

    system(moonbitStaticAnalysis, "riantr/moonbit_static_analysis", "静态分析库（三鉴审计）") {
        metadata {
            location("External")
            version("0.4.33")
        }
    }

    system(minimaxDesktop, "MiniMax Code Desktop", "插件宿主环境") {
        metadata {
            location("External")
        }
    }

    researcher -> pyroduct {
        description("运行 CLI 命令生成报告、可视化、审计")
        protocol("命令行")
    }

    agentDeveloper -> pyroduct {
        description("通过 JSON CLI 或 MCP 插件访问模型")
        protocol("JSON-RPC / MCP")
    }

    pyroduct -> moonbitCore {
        description("依赖")
        metadata {
            confidence("high")
        }
    }

    pyroduct -> moonbitAsync {
        description("依赖（仅 cmd/coord, tools/ifacescan, cmd/ifacescan）")
        metadata {
            confidence("high")
            constraint("native only")
        }
    }

    pyroduct -> moonbitDoubleML {
        description("交叉验证（仅 dmlref, causal）")
        metadata {
            confidence("high")
            constraint("isolated consumers")
        }
    }

    pyroduct -> moonbitSNN {
        description("脉冲沉淀实验（仅 snnref）")
        metadata {
            confidence("high")
            constraint("native only, isolated consumer")
        }
    }

    pyroduct -> moonbitStaticAnalysis {
        description("三鉴自审计（仅 audit）")
        metadata {
            confidence("high")
            constraint("isolated consumer")
        }
    }

    minimaxDesktop -> pyroduct {
        description("加载本地插件")
        protocol("MCP")
        metadata {
            confidence("high")
        }
    }
}
