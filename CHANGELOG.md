# Changelog

## 2026-07-19 — v2.0 置信度体系重构 & 目录重组织

### 目录结构重组
- `src/` — 代码层（脚本、模板、参考文档、测试）
- `data/macro/` — 宏观数据（一分一段表、特控线、本校对照表等）
- `data/school/` — 学校招生录取数据
- `data/personal/` — 个人数据（Git 忽略）
- `output/` — 生成的 HTML 报告（Git 忽略）

### 置信度体系重构
- **等比例放缩法**（分数线对照法）：A 级 → **C 级**（无排名数据支撑，误差大）
- **校内排名对照法**：A 级 → **C 级**（需多级折算）
- **百分位排名锚定法**：升为优先级 1，高三 A 级 / 高二 B 级
- **全新年级适配**：高一不计算等效分（grade_blocked），仅追踪排名和分数趋势
- **新增加权计算**：A 级 1.0 / B 级 0.8 / C 级 0.5 / D 级不参与

### 等效分计算优先级（新）
1. 百分位排名锚定法（A/B 级）
2. 校内排名对照法（C 级）
3. 等比例放缩法（C 级）
4. 校排名估算（C 级）

### 新功能
- **波动风格分类**：稳定型 / 波动型 / 趋势型（≥4 次等效分后输出）
- **单科追踪自动填充**：`record_exam.py` 录入时间步写入 6 科追踪
- **等效分持久化**：新增 `save_equivalent.py` 脚本
- **D 级置信度**：CSS 四档完整（绿/黄/灰/红）
- **新测试**：`test_percentile_gaoer`、`test_grade_blocked_gaoyi`、`test_percentile_beats_score_line`

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | 优先级重排、置信度重标、grade 参数、高一拦截 |
| `src/scripts/generate_reports.py` | 加权函数、波动风格、eval_labels 重构、单科 fallback |
| `src/scripts/record_exam.py` | 新增单科追踪同步写入 |
| `src/scripts/save_equivalent.py` | 新建 — 等效分结果持久化 |
| `src/assets/report_*.html` | CSS 四档统一、波动风格区、D 级样式 |
| `src/SKILL.md` | 置信度、优先级、管线流程全部同步 |
| `src/references/calculation_methods.md` | 完整重写（方法重排序、置信度重标） |
| `src/tests/*` | 断言更新 + 3 新测试（35 通过） |
| `基本.md` | 系统指令同步所有设计变更 |

### 数据层
- `data/macro/宏观数据_只读.xlsx`：8 sheets（含一分一段表、特控线、本校对照表、省内高校录取线）
- `data/school/学校招生_只读.xlsx`：深圳大学 47 条专业录取数据
- 个人数据从测试数据完整迁移
