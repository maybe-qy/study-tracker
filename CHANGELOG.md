# Changelog

## 2026-07-22 — v3.1.3 全面审计修复：融合空操作修正 + 文档同步 (13项)

### 严重修复
- 融合逻辑修正：新增 `compute_independent_subject_sum()`，单科加总独立于总分法计算（语数英用分数线对照法，选科赋分直映），打破 subject_sum ≡ total_equivalent 的数学恒等式
- 多方法融合扩展：不再依赖 subject_sum 存在才融合，任意 ≥2 个方法即可加权融合

### 文档重排
- `calculation_methods.md` 完整重写：方法编号按优先级统一（方法一~六），消除重复编号和嵌套错误
- `calc_equivalent.py` docstring 更新：从4方法扩展为6方法

### 数据展示修复
- 个人报告等效分改为显示 latest 测量值（非 EWMA），与误差区间一致
- 目标院校在无院校层次参考数据时也能展示
- 趋势报告交叉验证同时提取方法1和方法2

### 残留清理
- 删除所有"个人信息"功能残留引用（SKILL.md、DISCLAIMER、interaction_examples.md）
- 删除 SKILL.md 未实现的"最低分"展示承诺
- 更新 interaction_examples.md 过时的方法描述

### 代码清理
- 删除 `method_two_module` 中冗余的 raw 变量覆盖
- 删除 `method_school_threshold` 中冗余的 `.rstrip("人")`
- 添加 `school_total=835` 默认值的注释说明

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | 融合重构、docstring更新、冗余代码清理 |
| `src/scripts/generate_reports.py` | EWMA→latest、目标院校展示、交叉验证2、DISCLAIMER清理 |
| `src/assets/report_personal.html` | 目标院校独立展示（不依赖院校层次数据）|
| `src/SKILL.md` | 个人信息残留删除、最低分描述删除 |
| `src/references/calculation_methods.md` | 完整重写（方法编号统一）|
| `src/references/interaction_examples.md` | 个人信息对话删除、方法描述更新 |
| `CHANGELOG.md` | v3.1.x 版本记录补全 |

## 2026-07-21 — v3.1.2 个人档案展示计算过程

- 个人档案报告展示等效分计算详情（`calculation_detail` 字段）
- 从 latest 记录的"详细信息" JSON 中提取计算过程

## 2026-07-21 — v3.1.1 趋势报告展示计算过程 & 富阳Sheet命名规范 & 期末Context匹配

- 趋势报告展示每次考试的等效分计算详情
- 升级 Sheet 命名规范化：支持"富阳"前缀匹配
- 期末 Context 匹配：双模块换算法和校排阈值法仅在期末考试时触发

## 2026-07-21 — v3.1 双模块换算法重构：语数英+选科独立换算 & 多方法加权融合

### 双模块换算法（新增，优先级1）
- 拆分语数英（450分）和选科（100分/科）两个独立模块
- 模块一：语数英用校内特控线/浙大线 → 高考目标 340/378 比例换算
- 模块二：选科三级优先级（双线换算A→单线换算B→跨次回退/赋分C）
- 高考参考目标基于 2025 浙江高考各科均衡目标的中点

### 校排阈值估算法（新增，优先级3）
- 利用校内特控线+浙大线对应的校内排名，线性插值反推学生排名
- 学校类型系数估算全市排名 → 一分一段表 → 等效分

### 单科等效分体系
- 选科：赋分直映 → 校内对照 → 跨次回退（0.85折扣因子）
- 语数英：从总等效分减去选科贡献后，按原始分比例分配

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | 双模块换算法、校排阈值法、单科等效分重构 |
| `src/scripts/generate_reports.py` | 计算详情展示、置信度展示 |
| `src/SKILL.md` | 双模块换算法文档、新优先级表 |
| `src/references/calculation_methods.md` | 新增双模块、校排阈值方法文档 |
| `CLAUDE.md` | 优先级表更新、双模块换算法说明 |

## 2026-07-21 — v3.0 置信度体系重构: 4级(A/B/C/D) + 单一主方法 + 单科等效分

### 置信度扩展为四级
- 从 A/C/D 三级扩展为 A/B/C/D 四级
- B 级：主科原始分、全市统考中无独立划线的选科
- 权重更新：A=1.0, B=0.8, C=0.5, D=0.0

### 单一主方法架构
- 按优先级取第一个可用方法作为主方法
- 最终等效分 = 主方法分数 + 单科加总法分数按置信度加权融合
- 新增校排名估算方法（P4，C级）

### 单科等效分
- 语数英：比例折算法
- 选科有赋分：赋分直映法
- 选科无赋分：校内对照法
- 跨次数据回退支持

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | 校排名估算、单科等效分、数据一致性校验、A/B/C/D四级 |
| `src/SKILL.md` | 置信度表重写、单一主方法规则、展示规则 |
| `src/references/calculation_methods.md` | 权重更新、校排名估算方法 |
| `CLAUDE.md` | 优先级表重新排序 |

## 2026-07-20 — v2.2 深度审查修正：一致性修复 & A/B/C 重命名

### 核心修正
- 校内排名对照法：B 级恢复为 A 级（有对照表时数据来源可靠）
- 排名锚定法与分数线对照法解耦，排名锚定法降为交叉验证（P3）
- 多方法分歧处理从加权融合改为三档标注
- 置信度 B 级重新引入（权重 0.8）
- CHANGELOG 和 README 与代码完全同步

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | 优先级重排、B级重引入、三档分歧 |
| `src/SKILL.md` | 置信度表、优先级表全部重写 |
| `CLAUDE.md` | 优先级表、方法分歧规则同步 |

## 2026-07-20 — v2.1 置信度体系修正 & 加权融合

### 多方法置信度加权融合
- 多种计算方法可用时，等效分不再只取优先级最高的方法
- 改为按置信度权重加权平均：A 级 1.0，C 级 0.5
- 新增 `method_details` 字段，输出各方法分数、权重、计算详情
- 误差区间基于加权标准差计算

### 等比例放缩法升为 A 级
- 与排名锚定法并列优先级 1，按数据可用性触发
- 理由：特控线和一分一段表均为省级官方数据，可靠性同级
- 两者都可用时交叉验证，排名锚定法为主方法

### 删除年级分级
- 置信度仅由数据来源和方法决定，不再因年级降级
- 移除高一 `grade_blocked`（现可正常计算等效分）
- 移除高二 B 级降级（百分位锚定统一 A 级）
- 年级知识覆盖差异在报告中单独标注，不参与置信度计算和权重

### 移除 B 级置信度
- 简化为 A/C/D 三级：A 级权重 1.0，C 级 0.5，D 级不参与

### 方法分歧处理（三档）
- ≤3 分：交叉验证一致，可信度较高
- 3-5 分：方法间存在分歧，以主方法为准
- >5 分：方法分歧较大，建议补充数据

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | 等比例放缩 C→A、移除年级参数、三档分歧逻辑 |
| `src/scripts/generate_reports.py` | DISCLAIMER 重写、CONFIDENCE_WEIGHTS 移除 B 级 |
| `src/SKILL.md` | 置信度体系、优先级表、声明模板全部同步 |
| `src/references/calculation_methods.md` | 完整重写（方法并列、三档分歧、去年级化） |
| `src/tests/test_calc_equivalent.py` | 断言更新（C→A、B→A、grade_blocked→ok） |
| `CLAUDE.md` | 优先级表、分歧规则、置信度缩写同步 |

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
