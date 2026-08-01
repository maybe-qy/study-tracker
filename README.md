<div align="center">

# study-tracker

**把你的模考成绩换算成高考等效分，看清自己真正的位置**

追踪考试成绩 · 计算等效高考分 · 分析趋势波动 · 一键生成可视化报告

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.9+-green.svg)](https://www.python.org/)
[![Stars](https://img.shields.io/github/stars/maybe-qy/study-tracker?style=social)](https://github.com/maybe-qy/study-tracker)
[![Issues](https://img.shields.io/github/issues/maybe-qy/study-tracker)](https://github.com/maybe-qy/study-tracker/issues)

</div>

---

## 报告预览

<div align="center">

**个人总览** — 等效分、各科拆分、趋势状态、院校定位，一目了然

![个人总览报告](docs/report-personal-demo.png)

**单科追踪** — 语文/数学/英语/选科独立追踪，动态赋分计算

![单科追踪报告](docs/report-trend-demo.png)

</div>

---

## 为什么需要这个工具

每次模考出分，你拿到的是"这次 580 分，校排名 150/600"。但 580 分到底意味着什么？是进步了还是退步了？离你的目标大学还差多远？

**不同考试的难度不一样，原始分无法直接比较。** 这次 580 可能排年级前 20%，下次 590 可能只排前 30%——光看分数，你根本不知道自己是进步还是退步。

study-tracker 做的事情很简单：**把每次模考的分数，换算到同一个标尺——高考等效分。** 这样你就能清清楚楚地看到自己的真实水平变化，而不是被原始分和排名迷惑。

---

## 它能帮你做什么

| 功能 | 说明 |
|------|------|
| **成绩录入** | 告诉 AI 各科分数，自动校验总分一致性，支持原始分和赋分 |
| **等效分计算** | 3 种方法族 + 1 种独立方法，自动选择最优路径，加权融合，标注置信度等级 |
| **趋势分析** | 等效分随时间的变化曲线，自动判断上升/下降/波动，EWMA 预测状态 |
| **单科追踪** | 每科独立追踪，动态赋分计算，哪些科目稳、哪些科目在波动，一目了然 |
| **院校定位** | 设定目标院校，自动计算差距；无目标时按分数段给出层次参考 |
| **HTML 报告** | 2 份报告（个人总览 + 单科追踪）一键生成，浏览器打开即可查看 |

---

## 快速开始（推荐：通过 AI 助手）

把下面这段话复制给你的 AI 助手（豆包/元宝/ChatGPT/Claude 等）：

> 帮我部署运行这个项目：https://github.com/maybe-qy/study-tracker
> 请先阅读 skill/QUICKSTART.md，然后帮我录入成绩。

AI 会自动完成部署、录入成绩、计算等效分、生成报告。全程对话操作，**不需要你碰命令行。**

---

## 手动安装

### 环境要求

- Python 3.9+
- 依赖：openpyxl（Excel 读写）、Jinja2（HTML 模板渲染）

### 安装步骤

```bash
git clone https://github.com/maybe-qy/study-tracker.git
cd study-tracker
pip install -r requirements.txt
```

### 初始化工作区

```bash
python3 src/scripts/setup_workspace.py --workspace .
```

### 录入成绩

```bash
python3 src/scripts/record_exam.py << 'EOF'
{
  "workspace": ".",
  "exam_name": "10月月考",
  "exam_date": "2026-10-15",
  "exam_type": "月考",
  "grade": "高二",
  "total_score": 580,
  "cn_score": 105,
  "math_score": 110,
  "en_score": 115,
  "sub1_name": "物理", "sub1_raw": 78, "sub1_assigned": 85,
  "sub2_name": "化学", "sub2_raw": 72, "sub2_assigned": 88,
  "sub3_name": "生物", "sub3_raw": 68, "sub3_assigned": 82,
  "school_rank": 80,
  "school_total": 835
}
EOF
```

### 计算等效分 + 保存

```bash
python3 src/scripts/calc_equivalent.py << 'EOF' | python3 src/scripts/save_equivalent.py \
  --workspace . \
  --exam-name "10月月考" \
  --exam-date "2026-10-15"
{
  "workspace": ".",
  "exam_name": "10月月考",
  "exam_date": "2026-10-15",
  "total_score": 580,
  "school_rank": 80,
  "school_total": 835,
  "special_line": 542.5,
  "subjects": [
    {"name": "语文", "raw": 105},
    {"name": "数学", "raw": 110},
    {"name": "英语", "raw": 115},
    {"name": "物理", "raw": 78, "assigned": 85},
    {"name": "化学", "raw": 72, "assigned": 88},
    {"name": "生物", "raw": 68, "assigned": 82}
  ]
}
EOF
```

### 生成报告

```bash
python3 src/scripts/generate_reports.py --workspace .
```

报告输出到 `output/` 目录：

| 报告 | 内容 |
|------|------|
| `个人总览.html` | 双 Tab：个人档案（等效分、状态判断、院校定位）+ 高考总分趋势（等效分时间序列、方法切换、交叉验证） |
| `单科追踪.html` | 6 Tab：语文/数学/英语/选科 1/2/3 独立追踪，动态赋分计算 |

---

## 等效分是怎么算的

系统根据你提供的数据，自动选择最优计算路径：

| 方法族 | 子方法 | 置信度 | 需要哪些数据 |
|--------|--------|--------|-------------|
| **族① 校内划线换算** | 双模块完整换算 | A 级 ±5 | 各科特控线 + 浙大线 |
|  | 语数英等比例放大 | B 级 ±10 | 仅语数英划线 |
| **族② 外部参考映射** | 分数线对照法 | A 级 ±5 | 本次模考特控线 |
|  | 排名锚定法 | A 级 ±5 | 全市/联盟排名 |
|  | 校内排名对照法 | A 级 ±5 | 本校高考对照表 |
| **族③ 校内排名映射** | 本校对照表 | A 级 ±5 | 历届高考排名-分数对照表 |
|  | 年级排名映射 | B 级 ±10 | 校内排名 + 总人数 |
| **方法④ 单科排名对照** | 单科排名对照法 | A 级 ±5 | 单科排名-等效分对照表 |

数据越多，精度越高。**只有校排名时不算等效分**，因为误差太大（±15 分以上），没有参考价值。

---

## 在豆包/元宝中使用

### 豆包（任务模式）

豆包的 Python 沙箱不支持 shell 管道和 heredoc，用文件传参方式：

```bash
python src/scripts/record_exam.py --json-file exam_data.json
python src/scripts/calc_equivalent.py --json-file calc_input.json --output eq_result.json
python src/scripts/save_equivalent.py --json-file eq_result.json --workspace . --exam-name "10月月考" --exam-date "2026-10-15"
python src/scripts/generate_reports.py --workspace .
```

### 元宝（超级智能体）

元宝有内置代码执行工具，通过 `subprocess` 调用脚本，见 `skill/YUANBAO_PROMPT.md` 的详细适配说明。

---

## 数据安全

- **完全离线运行**，所有计算在本地完成，零网络请求
- 全部数据存储在本地的 Excel 文件中，不上传任何信息
- `data/personal/` 目录已在 `.gitignore` 中排除，随 Git 操作不会泄露个人数据
- 建议使用前审阅脚本源码

---

## 项目结构

```
study-tracker/
├── src/
│   ├── scripts/               # Python 计算脚本
│   │   ├── config.py          # 集中配置常量
│   │   ├── record_exam.py     # 成绩录入
│   │   ├── calc_equivalent.py # 等效分计算引擎
│   │   ├── save_equivalent.py # 结果保存
│   │   ├── generate_reports.py# HTML 报告生成
│   │   └── excel_utils.py     # Excel 工具函数
│   └── assets/                # 报告模板
├── skill/                     # AI 助手适配文档
│   ├── SKILL.md               # 完整 Skill 定义
│   ├── QUICKSTART.md          # 快速指南
│   ├── DOUBAO_PROMPT.md       # 豆包适配
│   └── YUANBAO_PROMPT.md      # 元宝适配
├── tests/                     # 测试套件
│   └── test_calc_equivalent.py
├── data/                      # 数据目录（Git 忽略个人数据）
│   ├── macro/                 # 宏观数据
│   ├── school/                # 学校招生数据
│   └── personal/              # 个人成绩数据
├── output/                    # 生成的 HTML 报告（Git 忽略）
├── docs/                      # 项目文档
├── pyproject.toml
├── requirements.txt
└── CHANGELOG.md
```

---

## 常见问题

**等效分是预测高考分吗？**

不是。等效分是把校内考试分数换算到高考尺度上的参考值，帮你评估当前水平相对于高考分数线的大致位置。实际高考成绩受多种因素影响，等效分不构成预测。

**没有特控线的校考怎么算？**

系统会自动降级到外部参考映射方法（需要全市/联盟排名）。如果什么划线数据都没有，系统会返回"数据不足"，你需要问老师要一下特控线。

**支持哪些省份？**

当前默认适配浙江新高考（选考赋分制）。其他省份可通过替换一分一段表和特控线来适配，但选考赋分逻辑需用户自行调整。

**数据安全吗？**

全部数据存在本地，不上传不联网。Git 提交时个人数据被 `.gitignore` 排除，不会意外泄露。

---

## 贡献

欢迎提交 Issue 和 Pull Request：

- [报告问题](https://github.com/maybe-qy/study-tracker/issues/new?labels=bug)
- [建议新功能](https://github.com/maybe-qy/study-tracker/issues/new?labels=enhancement)
- [提交代码](https://github.com/maybe-qy/study-tracker/pulls)

---

## 深入阅读

| 文档 | 内容 |
|------|------|
| [完整 Skill 定义](skill/SKILL.md) | 角色定义、交互流程、全部规则 |
| [计算方法详解](skill/references/calculation_methods.md) | 各方法公式与边界条件 |
| [数据字段定义](skill/references/data_schema.md) | 全部 Excel/Markdown 字段说明 |
| [交互示例](skill/references/interaction_examples.md) | 端到端对话流程 |
| [边界案例](skill/references/interaction_scripts.md) | 8 种场景的处理策略 |
| [变更记录](CHANGELOG.md) | 版本历史 |

---

## 协议

[MIT License](LICENSE)

---

<div align="center">

如果这个项目对你有帮助，欢迎 ⭐ Star 支持

</div>