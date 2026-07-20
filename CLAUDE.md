# 学业追踪与等效分报告 (Study Tracker)

面向高中学生的学业数据整合 Claude Code Skill。录入考试成绩和排名，计算等效高考分，分析成绩趋势，生成 HTML 报告。

## 红线

- 不诊断错题、不给提分建议、不推荐大学专业、不预测高考
- 不把估算值伪装成精确值 — 所有等效分必须标注置信度和误差区间
- 不对学生的能力、努力、未来做任何评判
- 高一不计算等效分（仅追踪排名和分数趋势）

## 目录结构

```
src/scripts/     # Python 脚本（calc_equivalent, record_exam, generate_reports, save_equivalent, setup_workspace）
src/assets/      # Jinja2 HTML 模板（report_personal, report_trend, report_subject）
src/references/  # 参考文档（计算方法、数据 Schema、交互脚本）
src/tests/       # pytest 测试（35 通过）
data/macro/      # 宏观数据（一分一段表、特控线、对照表等）
data/school/     # 学校招生录取数据
data/personal/   # 个人数据（Git 忽略）
output/          # 生成的 HTML 报告（Git 忽略）
```

## 关键命令

```bash
# 运行所有测试
python -m pytest src/tests/ -v

# 运行集成测试
python -m pytest src/tests/test_integration_real_data.py -v -s

# 手动生成报告
python src/scripts/generate_reports.py --workspace .
```

## 等效分计算优先级

| 优先级 | 方法 | 置信度 |
|--------|------|--------|
| 1 | 百分位排名锚定法 | A 级 — 需全市排名 + 一分一段表 |
| 1 | 等比例放缩法（分数线对照法） | A 级 — 需特控线，与排名锚定法并列 |
| 2 | 校内排名对照法 | C 级 — 需本校高考对照表 |
| 3 | 校排名估算 | C 级 — 无对照表，走升学率折算 |

按数据可用性触发。多种方法可用时，按置信度权重加权融合（A=1.0, C=0.5）。

## 方法分歧处理

| 差异 | 处理 |
|------|------|
| ≤3 分 | 交叉验证一致，可信度较高 |
| 3-5 分 | 方法间存在分歧，以主方法为准 |
| >5 分 | 分歧较大，建议补充数据 |

## 置信度

A/C/D 三级。置信度由数据来源和方法决定，与年级无关。趋势分析权重：A=1.0, C=0.5, D 不参与。

## 深入文档

| 文档 | 内容 |
|------|------|
| [src/SKILL.md](src/SKILL.md) | 完整 Skill 定义与交互流程 |
| [src/references/calculation_methods.md](src/references/calculation_methods.md) | 四大计算方法公式与边界 |
| [src/references/data_schema.md](src/references/data_schema.md) | 全部 Excel/Markdown 字段定义 |
| [src/references/interaction_scripts.md](src/references/interaction_scripts.md) | 边界案例与对话模板 |
| [src/references/interaction_examples.md](src/references/interaction_examples.md) | 完整交互示例 |
| [CHANGELOG.md](CHANGELOG.md) | 版本变更记录 |
