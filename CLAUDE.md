# 学业追踪与等效分报告 (Study Tracker)

面向高中学生的学业数据整合 Claude Code Skill。录入考试成绩和排名，计算等效高考分，分析成绩趋势，生成 HTML 报告。

## 红线

- 不诊断错题、不给提分建议、不推荐大学专业、不预测高考
- 不把估算值伪装成精确值 — 所有等效分必须标注置信度和误差区间
- 不对学生的能力、努力、未来做任何评判

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

| 优先级 | 方法 | 置信度 | 触发条件 |
|:------:|------|:------:|---------|
| 1 | 双模块换算法 | A/B | 校内各科特控线+浙大线数据 |
| 2 | 人数校准法 | B | 校内排名 + 门槛上线人数 + 一分一段表 |
| 3 | 分数线对照法 | A | 模考特控线 + 高考特控线 |
| 4 | 校排阈值估算法 | B | 校内特控线+浙大线阈值 |
| 5 | 校内排名对照法 | A | 本校高考对照表 + 校内排名 |
| 6 | 单科排名对照法 | A | 单科对照表 + 校内单科排名 |
| 7 | 排名锚定法 | A | 全市/联盟排名 + 一分一段表（交叉验证） |
| 8 | 校排名估算 | C | 仅校内排名 + 学校类型 |

按优先级取第一个可用方法作为主方法。所有可用方法（总分法 + 单科加总）按置信度权重加权平均融合。权重：A=1.0, B=0.8, C=0.5, D=0，单科加总额外衰减因子 0.5。

## 人数校准法

v3.2 新增的核心创新方法（B 级）。利用校内门槛上线人数与高考一分一段表的映射关系，将校内排名精确映射到高考排名。

- **校准系数 k** = 高考特控线人数 / 校内特控线上线人数（如 64018/573 ≈ 111.7）
- **重点班校准**：calibrated_rank = school_rank + unexamined_top（补回重点班未参考人数）
- 实测精度：从 C 级平均偏低 81 分提升到与 A 级仅差 5-10 分
- 填补了无校内对照表、无全市排名时的精度缺口

## 双模块换算法

有校内各科划线数据时优先使用。分两个独立模块：

- **语数英模块（450分）**：校特控线/浙大线 → 高考目标 340/378 比例换算
- **选科模块（100分/科）**：优先级1 双线换算(A) → 优先级2 单线换算(B) → 优先级3 跨次回退/赋分(C)

高考参考目标：语数英特控 340、浙大 378（中点）；选科特控 90、浙大 96（中点）。

## 方法分歧处理

| 差异 | 处理 |
|------|------|
| ≤3 分 | 交叉验证一致，可信度较高 |
| 3-5 分 | 方法间存在分歧，以主方法为准 |
| >5 分 | 分歧较大，建议补充数据 |

## 置信度

A/B/C/D 四级。置信度由数据来源和方法决定，与年级无关。趋势/波动分析权重：A=1.0, B=0.8, C=0.5, D=0。

## 深入文档

| 文档 | 内容 |
|------|------|
| [src/SKILL.md](src/SKILL.md) | 完整 Skill 定义与交互流程 |
| [src/references/calculation_methods.md](src/references/calculation_methods.md) | 计算方法公式与边界 |
| [src/references/data_schema.md](src/references/data_schema.md) | 全部 Excel/Markdown 字段定义 |
| [src/references/interaction_scripts.md](src/references/interaction_scripts.md) | 边界案例与对话模板 |
| [src/references/interaction_examples.md](src/references/interaction_examples.md) | 完整交互示例 |
| [CHANGELOG.md](CHANGELOG.md) | 版本变更记录 |
