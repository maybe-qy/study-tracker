# Changelog

## 2026-07-23 — v3.3.0 豆包/通用AI适配 + 首次体验优化 + 预置数据

### 新增
- **QUICKSTART.md**：面向豆包/ChatGPT等通用AI助手的简化引导指令，对话式录入，不输出技术命令
- **预置浙江宏观数据**：仓库内置一分一段表、特控线、赋分区间，新用户clone后开箱可用
- **推广文案模板**：docs/推广文案_微信笔记.md，诚实描述功能和使用门槛

### 优化
- **首次录入体验**：1次考试时显示"基准分已建立"引导，替代空洞的"数据不足"
- **单科报告首次适配**：单次记录时显示"基准分/本次"两框 + 引导文案，隐藏无意义的"最高=本次"
- **README新增AI助手入口**：推荐用户通过AI助手使用，降低使用门槛

### 修复
- **单科报告CSS布局Bug**：统计框字号不一致导致grid错位 → 统一28px + flex等高布局
- **.gitignore修正**：data/ → data/personal/，放开宏观数据和学校数据供新用户使用

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/QUICKSTART.md` | 新建 — AI助手快速指南 |
| `data/macro/宏观数据_只读.xlsx` | 替换为干净模板（省级数据+空学校模板） |
| `data/school/学校招生_只读.xlsx` | 空模板（仅表头） |
| `.gitignore` | data/ → data/personal/ |
| `src/assets/report_personal.html` | 新增首次体验区块 |
| `src/assets/report_trend.html` | 新增首次体验引导 |
| `src/assets/report_subject.html` | CSS修复 + 首次记录适配 |
| `src/scripts/generate_reports.py` | 3个render函数增加is_first_record逻辑 |
| `README.md` | 新增AI助手入口 |
| `CLAUDE.md` | 文档表新增QUICKSTART.md |
| `docs/推广文案_微信笔记.md` | 新建 — 推广文案模板 |



## 2026-07-22 — v3.2.2 第二次模型审查修复（5个P1问题）

### 严重修复
- **人数校准法缺失重点班校准**：`method_population_calibration` 未像 `method_school_lookup` 那样补回重点班未参考人数 → 新增 `calibrated_rank = int(school_rank) + unexamined_top`
- **单科数据读取匹配错误Sheet**：`read_school_subject_data` 会误匹配 `本校对照表_总分` → 新增 `if sname == "本校对照表_总分": continue` 并要求 Sheet 名包含"单科"
- **独立选科求和未过滤None**：`compute_independent_subject_sum` 中特控线数据含 None 导致崩溃 → 新增 `_filter_numeric_rows(..., "特控线分数")`
- **Sheet名不匹配**：`_SHEET_KEY_MAP` 中"省内高校录取线"无法匹配"院校层次"关键词 → 重命名为 `院校层次_录取线`
- **create_excel非幂等**：重复运行会追加表头 → 新增 `load_workbook(read_only=True)` 检查 `ws.max_row > 1`

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | 重点班校准、单科Sheet过滤、None过滤、Sheet名修正 |
| `src/scripts/setup_workspace.py` | Sheet重命名、create_excel幂等性 |

## 2026-07-22 — v3.2.1 全盘检查修复（10个问题）

### 严重修复
- **build_row()元素数不匹配**：返回28个元素但EXCEL_COLS有30列 → 补充 `school_type`、`rank_type` 映射
- **单科排名对照法数据结构错误**：访问 `subject_rank_data[name]` 但实际结构为 `{"rank_scores": {...}}` → 改为 `.get("rank_scores", {})`
- **_SHEET_KEY_MAP键名不匹配**：`"对照": "对照"` 但消费方使用 `macro.get("本校对照表_总分")` → 修正映射为 `"对照": "本校对照表_总分"`
- **_json未定义NameError**：`except (_json.JSONDecodeError, TypeError)` 引用未导入的 `_json` → 改为 `json.JSONDecodeError`
- **排序方向冲突（I4）**：`reverse=True` 导致 `eq_records[-1]` 取到最旧记录而非最新 → 改为内部升序 `reverse=False`，仅在展示时反转

### 数据展示修复
- 趋势报告展示前反转考试列表（最新在前），内部分析保持升序
- 个人报告使用 `eq_records[-1]` 取最新记录（依赖升序排序）
- 单科报告展示前反转记录列表

### 代码清理
- 清理 `save_equivalent.py` 中重复的 `import json as _json`，统一使用模块级 `import json`
- 所有 `json.JSONDecodeError` 统一引用

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/record_exam.py` | build_row()补全30列 |
| `src/scripts/calc_equivalent.py` | 单科数据结构修复、_SHEET_KEY_MAP修正、_json修复 |
| `src/scripts/save_equivalent.py` | import清理、JSON异常统一 |
| `src/scripts/generate_reports.py` | 排序方向修正、展示反转逻辑 |

## 2026-07-22 — v3.2.0 16条Issue全量修复 + 人数校准法 + 单科排名对照法

### 新增计算方法
- **人数校准法（优先级2，B级）**：利用校内门槛上线人数与高考一分一段表的映射关系，校准系数 k = 高考特控线人数/校内特控线上线人数。实测精度从C级平均偏低81分提升到与A级仅差5-10分
- **单科排名对照法（优先级6，A级）**：利用单科对照表将校内单科排名映射到高考单科等效分

### 严重修复（16条Issue）
- **I1 Sheet名硬编码**：`read_macro_data()` 使用精确Sheet名 → 新增 `find_sheet()` 模糊匹配 + `_SHEET_KEY_MAP` 映射表
- **I2 None值崩溃**：一分一段表含元数据行导致 `int(None)` → 新增 `_filter_numeric_rows(rows, key_field)` 过滤
- **I3 标题行错位**：真实Excel标题在第1行、表头在第2行 → 新增 `_is_header_row()` 检测 + `_KNOWN_COLUMN_KEYWORDS`
- **I5 置信度"级"重复**：存储"B级"且模板追加"级" → 存储为"B"，模板渲染时追加"级"
- **I6 calculation_detail类型不一致**：计算模块输出list，模板调用 `.split('|')` → 统一为字符串，用 `|` 分隔
- **I7 subject_scores结构不一致**：save模块允许dict，render期望list-of-dict → 两端统一类型转换
- **I8-I16**：报告排序、目标院校展示、置信度颜色编码、method_switch检测等

### 更新文件
| 文件 | 变更 |
|------|------|
| `src/scripts/calc_equivalent.py` | find_sheet()、_filter_numeric_rows()、_is_header_row()、人数校准法、单科排名对照法 |
| `src/scripts/save_equivalent.py` | 置信度去"级"、calculation_detail统一、subject_scores统一 |
| `src/scripts/generate_reports.py` | 类型防御检查、method_switch检测、展示排序反转 |
| `src/scripts/record_exam.py` | EXCEL_COLS扩展至30列 |
| `src/scripts/setup_workspace.py` | HEADERS扩展至30列、MACRO_SHEETS更新 |
| `src/assets/report_trend.html` | 置信度颜色CSS、method_switch徽章 |



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
