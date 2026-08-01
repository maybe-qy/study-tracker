#!/usr/bin/env python3
"""集中配置模块 — 统一管理所有业务常量和参数。

所有模块通过 `from config import *` 或显式导入使用。
修改阈值只需改此文件，无需逐文件搜索。
"""

# ── 高考参考目标（基于 2026 浙江高考各科均衡目标的中点） ──
GAOKAO_TARGETS = {
    "main_special": 341,   # 语数英特控目标 (331~351)
    "main_zd": 382,         # 语数英浙大目标 (378~387)
    "sub_special": 90,      # 选科特控目标 (88~92)
    "sub_zd": 96,           # 选科浙大目标 (95~97)
}

# ── 计算参数 ──
MAIN_MAX = 430        # 语数英等效上限（~143/科）
SUB_MAX = 100         # 选科等效上限
DAMPING = 0.3         # 超过浙大线后的衰减系数
SUBJECT_SUM_DECAY = 0.5    # 单科加总在融合中的衰减因子
CROSS_EXAM_DISCOUNT = 0.9  # 跨次回退固定折扣系数（原 0.85^n 指数衰减）

# ── 置信度体系 ──
CONFIDENCE_WEIGHTS = {"A": 1.0, "B": 0.8, "C": 0.5, "D": 0.0}
ERROR_MARGINS = {"A": 5, "B": 10, "C": 15, "D": 20}
CONFIDENCE_ORDER = {"A": 4, "B": 3, "C": 2, "D": 1}

# ── 学校类型系数 ──
SCHOOL_TYPE_COEFF = {"省重点": 0.3, "市重点": 0.6, "区重点": 1.0, "普通": 1.5}

# ── 考试关键词（用于升级 Sheet 匹配） ──
EXAM_KEYWORDS = ["期末", "期中", "月考", "联考", "模拟", "统考"]

# ── 科目定义 ──
MAIN_SUBJECTS = ["语文", "数学", "英语"]
ELECTIVE_SUBJECTS = ["物理", "化学", "生物", "技术", "历史", "政治", "地理"]
ALL_SUBJECTS = MAIN_SUBJECTS + ELECTIVE_SUBJECTS

# ── 趋势/波动分析参数 ──
TREND_SLOPE_THRESHOLD = 1.5     # 斜率绝对值超过此值判定为上升/下降
VOLATILITY_SIGMA_MULT = 1.5     # 浮动区间 = 均值 ± mult × σ
EWMA_ALPHA = 0.3                # EWMA 平滑系数（趋势分析）
PREDICTION_THRESHOLD = 3        # 预测标签阈值（±3分）
MIN_DATA_FOR_ANALYSIS = 4       # 趋势/波动分析最少数据点
MIN_DATA_FOR_FUSION = 2         # 多方法融合最少方法数

# ── 分歧处理阈值 ──
DIVERGENCE_LOW = 3     # ≤3分：一致
DIVERGENCE_MEDIUM = 5  # 3-5分：以主方法为准

# ── 数据一致性校验 ──
DATA_CONSISTENCY_RATIO = 0.10  # 总人数差异超过10%告警

# ── 满分制 ──
FULL_SCORE = 750
MAIN_FULL_SCORE = 450  # 语数英三科合计满分（150×3）
SUB_FULL_SCORE = 100   # 单科满分
