<div align="center">

# 学业追踪与等效分报告

**面向高中学生的学业数据整合工具**

追踪考试成绩 · 计算等效高考分 · 分析趋势波动 · 生成可视化报告

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.9+-green.svg)](https://www.python.org/)
[![Stars](https://img.shields.io/github/stars/maybe-qy/study-tracker?style=social)](https://github.com/maybe-qy/study-tracker)
[![Issues](https://img.shields.io/github/issues/maybe-qy/study-tracker)](https://github.com/maybe-qy/study-tracker/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/maybe-qy/study-tracker/pulls)

</div>

---

## 报告演示

<div align="center">

**个人总览报告** — 双 Tab：个人档案（等效分、各科拆分、趋势状态、院校定位）+ 高考总分趋势（等效分时间序列、置信度颜色编码、波动分析、交叉验证）

![个人总览报告](docs/report-personal-demo.png)

**单科追踪报告** — 6 Tab 整合：语文/数学/英语/选科 1/2/3 独立追踪，动态赋分计算

![趋势报告](docs/report-trend-demo.png)

</div>

---

## 功能一览

| 功能 | 说明 |
|------|------|
| **成绩录入** | 逐字段录入考试科目成绩、排名、特控线，自动校验总分一致性 |
| **等效分计算** | 3 方法族 + 1 独立方法按优先级自动选择，加权融合，标注置信度和误差区间 |
| **趋势分析** | 等效分时间序列追踪，EWMA 预测状态（积极/正常/消极），波动风格分类 |
| **单科追踪** | 语文/数学/英语/选科独立追踪，动态赋分计算 |
| **院校定位** | 目标院校差距分析，院校层次梯队定位 |
| **HTML 报告** | 独立报告一键生成，按日期降序排列（最新在前） |

## 用 AI 助手开始（推荐）

把下面的内容发给你的 AI 助手（豆包、ChatGPT、Claude 等）：

> 帮我部署运行这个项目：https://github.com/maybe-qy/study-tracker
> 请先阅读 skill/QUICKSTART.md，然后帮我录入成绩。

AI 会自动完成部署、录入、计算、生成报告，全程对话操作，无需命令行。

---

## 命令行快速开始

### 安装

```bash
git clone https://github.com/maybe-qy/study-tracker.git
cd study-tracker
pip install -r requirements.txt
```

### 初始化工作区

```bash
python3 src/scripts/setup_workspace.py --workspace .
```

创建目录结构和带表头的 Excel 文件：

```
data/
├── macro/          # 宏观数据（一分一段表、特控线、赋分区间等）
├── school/         # 学校招生录取数据
└── personal/       # 个人数据（成绩总表、等效分记录、单科追踪）
    └── individual/ # 每次考试的 Markdown 不可变存档
```

### 录入第一次成绩

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

### 计算等效分

```bash
python3 src/scripts/calc_equivalent.py << 'EOF'
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

### 保存等效分

将上一步的输出通过管道传给 `save_equivalent.py`：

```bash
python3 src/scripts/calc_equivalent.py < exam_data.json | python3 src/scripts/save_equivalent.py \
  --workspace . \
  --exam-name "10月月考" \
  --exam-date "2026-10-15"
```

### 生成报告

```bash
python3 src/scripts/generate_reports.py --workspace .
```

生成 HTML 报告到 `output/` 目录：

| 报告 | 说明 |
|------|------|
| `个人总览.html` | 双 Tab：个人档案（等效分、状态判断、院校定位）+ 高考总分趋势（等效分时间序列、方法切换、交叉验证） |
| `单科追踪.html` | 6 Tab：语文/数学/英语/选科 1/2/3 独立追踪，动态赋分计算 |

## 在豆包中使用

豆包的 Python 沙箱不支持 shell 管道和 heredoc。提供两种替代方案：

**方案一（推荐）：直接导入模块**

```python
import sys; sys.path.insert(0, "src/scripts")

# 1. 初始化工作区（首次）
from setup_workspace import run as setup; setup(".")

# 2. 录入成绩
from record_exam import run as record
record({"workspace": ".", "exam_name": "10月月考", "exam_date": "2026-10-15",
        "exam_type": "月考", "grade": "高二", "total_score": 580,
        "cn_score": 105, "math_score": 110, "en_score": 115,
        "sub1_name": "物理", "sub1_raw": 78, "sub1_assigned": 85,
        "sub2_name": "化学", "sub2_raw": 72, "sub2_assigned": 88,
        "sub3_name": "生物", "sub3_raw": 68, "sub3_assigned": 82,
        "school_rank": 80, "school_total": 835, "special_line": 542.5})

# 3. 计算等效分
from calc_equivalent import run as calc
eq = calc({"workspace": ".", "total_score": 580, "special_line_exam": 542.5})

# 4. 保存等效分
from save_equivalent import run as save_eq
save_eq(".", "10月月考", "2026-10-15", eq)

# 5. 生成报告
from generate_reports import run as report; report(".")
```

**方案二：JSON 文件传参**

```bash
python src/scripts/record_exam.py --json-file exam_data.json
python src/scripts/calc_equivalent.py --json-file calc_input.json --output eq_result.json
python src/scripts/save_equivalent.py --json-file eq_result.json --workspace . --exam-name "10月月考" --exam-date "2026-10-15"
python src/scripts/generate_reports.py --workspace .
```

## 等效分计算方法

3 方法族 + 1 独立方法按优先级自动选择，加权融合（A=1.0 / B=0.8 / C=0.5）。v5.0 起采用方法族架构，每族只派一个胜出者参与融合。

- **族① 校内划线换算（1A1B）**：选科有独立划线时双模块完整换算（A 级），仅语数英划线时 450→750 等比例放大（B 级）
- **族② 外部参考映射（2A 三选一）**：分数线对照法（A 级，优先），排名锚定法（A 级），校内排名对照法（A 级）
- **族③ 校内排名映射（二选一）**：本校对照表（A 级），年级排名映射（B 级）
- **方法④ 单科排名对照法**：单科对照表独立换算（A 级）

## 目录结构

```
study-tracker/
├── src/
│   ├── scripts/
│   │   ├── config.py               # 集中配置常量
│   │   ├── setup_workspace.py      # 工作区初始化
│   │   ├── record_exam.py          # 成绩录入
│   │   ├── calc_equivalent.py      # 等效分计算（3方法族+1独立）
│   │   ├── save_equivalent.py      # 等效分保存
│   │   ├── generate_reports.py     # HTML报告生成
│   │   └── excel_utils.py          # Excel读写工具函数
│   └── assets/
│       ├── logos/                  # 大学校徽SVG（~95所）
│       ├── report_overview.html    # 个人总览模板（Tab×2）
│       └── report_subjects.html    # 单科追踪模板（Tab×6）
├── skill/
│   ├── SKILL.md                    # 完整 Skill 定义
│   ├── QUICKSTART.md               # AI 助手快速指南
│   └── references/                 # 参考文档
├── tests/                          # pytest 测试
├── docs/                           # 项目介绍与竞品分析
├── data/                           # 数据目录
├── output/                         # 报告输出（Git忽略）
├── 原则/                           # 红线与原则文档
├── 推广/                           # 推广文案
├── requirements.txt
├── requirements-dev.txt
├── pyproject.toml
├── CHANGELOG.md
└── LICENSE
```

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.9+ | 运行环境 |
| openpyxl | 3.1+ | Excel 读写 |
| Jinja2 | 3.1+ | HTML 模板渲染 |

## 权限与安全

- 所有计算在本地完成，**完全离线运行**，无网络请求
- 仅操作用户指定的 workspace 目录，不访问其他路径
- 不收集用户个人信息、浏览器缓存、SSH 密钥等
- 建议执行前审阅 Python 脚本源码

## Roadmap

- [x] 3 方法族 + 1 独立方法架构（v5.0 方法族重构）
- [x] 报告 8→2 Tab 化整合（个人总览 + 单科追踪）
- [x] 跨次回退折扣固定 0.9
- [x] 全盘扫描 10 个 bug 修复（含 1 critical）

## FAQ

**Q: 等效分是预测高考分吗？**

不是。等效分是将校内考试分数换算到高考尺度上的参考值，帮助评估当前水平相对于高考分数线的大致位置。实际高考成绩受多种因素影响，等效分不构成预测。

**Q: 没有特控线的校考怎么计算？**

系统会自动降级到族②外部参考映射（排名锚定法，B 级）。推荐补充排名数据以启用 A 级方法。若无任何 A/B 级方法可用，返回 insufficient_data。

**Q: 支持哪些省份？**

当前适配浙江新高考（选考赋分制）。一分一段表和特控线数据需用户自行导入。其他省份可通过修改宏观数据适配。

**Q: 数据安全吗？**

全部数据存储在本地 Excel 文件中，不上传任何信息到外部服务器。`data/personal/` 目录已在 `.gitignore` 中排除。

## 贡献

欢迎提交 Issue 和 PR：

- [报告问题](https://github.com/maybe-qy/study-tracker/issues)
- [提交 Pull Request](https://github.com/maybe-qy/study-tracker/pulls)

## 深入文档

| 文档 | 内容 |
|------|------|
| [SKILL.md](skill/SKILL.md) | 完整 Skill 定义与交互流程 |
| [计算方法详解](skill/references/calculation_methods.md) | 3 方法族 + 1 独立方法公式与边界条件 |
| [数据字段定义](skill/references/data_schema.md) | 全部 Excel/Markdown 字段说明 |
| [交互示例](skill/references/interaction_examples.md) | 端到端对话示例 |
| [边界案例](skill/references/interaction_scripts.md) | 8 种场景处理策略 |
| [变更记录](CHANGELOG.md) | 版本更新历史 |

## 开源协议

[MIT License](LICENSE) — 自由使用、修改、分发

---

<div align="center">

如果这个项目对你有帮助，欢迎 Star 支持

</div>
