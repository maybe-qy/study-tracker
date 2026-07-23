#!/usr/bin/env python3
"""Generate 8 HTML reports from Excel data.

Reports:
  1. 个人档案.html — latest equivalent score, status, target gap
  2. 高考总分趋势.html — equivalent score time series + analysis
  3-8. [语文/数学/英语/选1/选2/选3]追踪.html — single subject tracking

Usage:
  python generate_reports.py --workspace <path>
"""

import argparse
import json
import os
import sys
import statistics
from datetime import datetime

from openpyxl import load_workbook
from jinja2 import Environment, FileSystemLoader

DISCLAIMER = """声明与局限性

1. 等效分方法：
   优先使用分数线对照法（等比例放缩），基于省级特控线固定锚点。
   校内排名对照法（有本校高考对照表时）为 A 级。
   全市/联盟排名锚定法作为交叉验证。
   校排名估算在仅有校内排名无对照表时使用，C 级。
   等效分仅供参考，不构成对高考成绩的预测。

2. 置信度分级：
   A级：分数线对照法、校内排名对照法、全市/联盟排名锚定法、全市/联盟统一赋分。
   B级：主科原始分、全市统考/联盟考试中无独立划线的选科。
   C级：校排名估算（无本校高考对照数据）。
   D级：无排名无分数线分数。
   趋势/波动分析权重：A=1.0, B=0.8, C=0.5, D 不参与。

3. 年级说明：
   等效分置信度由数据来源和方法决定，与年级无关。
   年级影响的是知识范围覆盖度（等效分对高考的预测效度），
   而非等效分计算本身的可靠性。

4. 数据来源：用户上传。"""


# 已知列名关键词集合，用于检测第1行是标题还是表头
_KNOWN_COLUMN_KEYWORDS = {"分数", "排名", "累计人数", "年份", "人数", "特控线", "上线", "下限", "上限", "科目", "得分", "等效分", "原始分", "赋分", "总分", "成绩", "名称", "考试名", "日期", "置信度", "方法", "score", "rank", "count", "year", "name"}


def _is_header_row(row_values):
    """检测第一行是否为表头行（而非标题行）。"""
    if not row_values:
        return False
    hits = 0
    for v in row_values:
        if v is None:
            continue
        sv = str(v).strip()
        if sv in _KNOWN_COLUMN_KEYWORDS:
            hits += 1
        else:
            for kw in _KNOWN_COLUMN_KEYWORDS:
                if kw in sv:
                    hits += 1
                    break
    if hits >= 2:
        return True
    return False


def read_sheet_dicts(ws, skip_title_row=True):
    """Read worksheet rows as dicts. Returns empty list if only headers."""
    if ws.max_row < 2:
        return []
    header_row_idx = 1
    if skip_title_row and ws.max_row >= 3:
        row1_vals = tuple(cell.value for cell in ws[1])
        if not _is_header_row(row1_vals):
            row2_vals = tuple(cell.value for cell in ws[2]) if ws.max_row >= 3 else None
            if row2_vals and _is_header_row(row2_vals):
                header_row_idx = 2
    headers = [str(cell.value) if cell.value is not None else f"col_{i}" for i, cell in enumerate(ws[header_row_idx])]
    rows = []
    for row in ws.iter_rows(min_row=header_row_idx + 1, values_only=True):
        d = {}
        for i, val in enumerate(row):
            if i < len(headers):
                d[headers[i]] = val
        rows.append(d)
    return rows


def load_data(workspace):
    """Load all Excel data."""
    data = {"exams": [], "equivalent": [], "subjects": {}, "volatility": []}

    def sort_by_date(records, reverse=False):
        """按日期排序，默认升序（最旧的在前，便于趋势分析）"""
        def parse_date(d):
            if not d or not isinstance(d, str):
                return ""
            return d.strip()
        return sorted(records, key=lambda r: parse_date(r.get("日期", "")), reverse=reverse)

    # 成绩总表
    path = os.path.join(workspace, "data", "personal", "成绩总表.xlsx")
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        data["exams"] = sort_by_date(read_sheet_dicts(wb["成绩总表"]))

    # 等效分记录
    path = os.path.join(workspace, "data", "personal", "等效分记录.xlsx")
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        data["equivalent"] = sort_by_date(read_sheet_dicts(wb["等效分记录"]))

    # 单科追踪
    path = os.path.join(workspace, "data", "personal", "单科追踪.xlsx")
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        for name in wb.sheetnames:
            data["subjects"][name] = sort_by_date(read_sheet_dicts(wb[name]))

    # 宏观数据
    path = os.path.join(workspace, "data", "macro", "宏观数据_只读.xlsx")
    if not os.path.exists(path):
        path = os.path.join(workspace, "data", "macro", "宏观数据.xlsx")
    data["macro"] = {}
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        # 模糊匹配关键Sheet名
        def _find_sheet(sheets, keyword):
            for name in sheets:
                if keyword.lower() in name.lower():
                    return name
            return None
        _sheet_key_map = {
            "特控线": "特控线", "一分一段": "一分一段表",
            "赋分区间": "赋分区间", "院校层次": "院校层次",
        }
        matched = set()
        for key, display_name in _sheet_key_map.items():
            found = _find_sheet(wb.sheetnames, key)
            if found:
                data["macro"][display_name] = read_sheet_dicts(wb[found])
                matched.add(found)
        for name in wb.sheetnames:
            if name not in matched:
                data["macro"][name] = read_sheet_dicts(wb[name])

    # 学校招生数据
    path = os.path.join(workspace, "data", "school", "学校招生_只读.xlsx")
    data["admission"] = {}
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        for name in wb.sheetnames:
            data["admission"][name] = read_sheet_dicts(wb[name])

    return data


# ─── HTML generation helpers ──────────────────────────────────────────

CONFIDENCE_WEIGHTS = {"A": 1.0, "B": 0.8, "C": 0.5, "D": 0.0}


def filter_weighted(records):
    """Extract (score, weight) tuples from equivalent score records, excluding D-level."""
    weighted = []
    for r in records:
        conf = str(r.get("置信度", "A")).strip()
        weight = CONFIDENCE_WEIGHTS.get(conf, 1.0)
        if weight > 0:
            score = float(r.get("等效分（融合结果）", 0) or 0)
            if score > 0:
                weighted.append((score, weight))
    return weighted


def compute_trend(scores):
    """Determine trend direction: 'up', 'down', or 'flat'. Returns (class, arrow, text)."""
    if len(scores) < 2:
        return ("flat", "→", "数据不足")
    # Simple linear trend on last 4 or all
    recent = scores[-4:] if len(scores) >= 4 else scores
    n = len(recent)
    if n < 2:
        return ("flat", "→", "持平")
    # Slope of best-fit line
    x_mean = (n - 1) / 2
    y_mean = sum(recent) / n
    num = sum((i - x_mean) * (recent[i] - y_mean) for i in range(n))
    den = sum((i - x_mean) ** 2 for i in range(n))
    if den == 0:
        return ("flat", "→", "持平")
    slope = num / den
    if slope > 1.5:
        return ("up", "↑", "上升")
    elif slope < -1.5:
        return ("down", "↓", "下降")
    else:
        return ("flat", "→", "持平")


def compute_volatility(scores):
    """Compute sigma and volatility range. Returns (sigma, lower, upper)."""
    if len(scores) < 4:
        return (None, None, None)
    mean = statistics.mean(scores)
    sigma = statistics.stdev(scores)
    return (round(sigma, 1), round(mean - 1.5 * sigma, 1), round(mean + 1.5 * sigma, 1))


def compute_volatility_weighted(weighted_scores):
    """Weighted sigma and volatility range."""
    if len(weighted_scores) < 4:
        return (None, None, None)
    scores = [s for s, _ in weighted_scores]
    weights = [w for _, w in weighted_scores]
    w_mean = sum(s * w for s, w in zip(scores, weights)) / sum(weights)
    w_var = sum(w * (s - w_mean) ** 2 for s, w in zip(scores, weights)) / sum(weights)
    sigma = w_var ** 0.5
    return (round(sigma, 1), round(w_mean - 1.5 * sigma, 1), round(w_mean + 1.5 * sigma, 1))


def prediction_state(scores):
    """Compute prediction label for latest score. Returns '积极'/'正常'/'消极'."""
    if len(scores) < 4:
        return None
    # HP-filter simplified: use EWMA trend
    alpha = 0.3
    ewma = scores[0]
    residuals = []
    for i in range(len(scores)):
        residuals.append(scores[i] - ewma)
        ewma = alpha * scores[i] + (1 - alpha) * ewma
    residuals = residuals[1:]  # drop first which is unreliable
    if len(residuals) < 2:
        return "正常"
    q75 = sorted(residuals)[int(len(residuals) * 0.75)]
    q25 = sorted(residuals)[int(len(residuals) * 0.25)]
    latest = residuals[-1]
    if latest >= q75:
        return "积极"
    elif latest <= q25:
        return "消极"
    else:
        return "正常"


def eval_labels(scores):
    """Count positive/normal/negative labels + return label sequence for trend detection."""
    if len(scores) < 4:
        return (None, None)
    labels = {"积极": 0, "正常": 0, "消极": 0}
    sequence = []
    alpha = 0.3
    # 预热：用前3个点建立EWMA基线
    ewma = scores[0]
    for s in scores[1:3]:
        ewma = alpha * s + (1 - alpha) * ewma
    # 从第4个点开始标注（EWMA基于前i个点，当前点用于比较）
    for i in range(3, len(scores)):
        if scores[i] > ewma + 3:
            labels["积极"] += 1
            sequence.append("积极")
        elif scores[i] < ewma - 3:
            labels["消极"] += 1
            sequence.append("消极")
        else:
            labels["正常"] += 1
            sequence.append("正常")
        ewma = alpha * scores[i] + (1 - alpha) * ewma
    return (labels, sequence)


def classify_volatility_style(labels, sigma, sequence):
    """Classify volatility pattern. Returns descriptive label or None if insufficient data."""
    if labels is None or sequence is None or sigma is None:
        return None
    total = labels["积极"] + labels["正常"] + labels["消极"]
    if total == 0:
        return None
    normal_ratio = labels["正常"] / total
    active_ratio = (labels["积极"] + labels["消极"]) / total
    # 趋势型: 3+ consecutive same direction
    max_consecutive = 1
    current_run = 1
    for i in range(1, len(sequence)):
        if sequence[i] == sequence[i-1]:
            current_run += 1
            max_consecutive = max(max_consecutive, current_run)
        else:
            current_run = 1
    if max_consecutive >= 3:
        return "呈持续变化趋势"
    if active_ratio >= 0.5 and max_consecutive < 3:
        return "分数波动较大"
    if normal_ratio >= 0.7:
        return "分数相对稳定"
    return "分数波动较大"


# ─── Report generators ─────────────────────────────────────────────────

def render_personal(data, env):
    """Render 个人档案.html."""
    eq_records = data["equivalent"]
    macro = data.get("macro", {})

    exam_records = data.get("exams", [])
    if not eq_records:
        has_exams = len(exam_records) >= 1
        template = env.get_template("report_personal.html")
        return template.render(
            generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
            equivalent_score="暂无数据" if not has_exams else "等待计算",
            latest_equiv=0,
            confidence="-",
            method="-",
            calc_detail="",
            error_lower="-",
            error_upper="-",
            has_analysis=False,
            is_first_record=False,  # 个人档案的首次引导仅在已有1条等效分时触发
            exam_count=len(exam_records),
            trend_class="flat",
            trend_arrow="→",
            trend_text="等待数据",
            prediction_state="-",
            volatility_lower="-",
            volatility_upper="-",
            sigma="-",
            subject_scores=[],
            hierarchy_refs=None,
            tier_info=None,
            volatility_style="-",
            disclaimer=DISCLAIMER,
        )

    latest = eq_records[-1]
    latest_equiv = float(latest.get("等效分（融合结果）", 0)) if latest.get("等效分（融合结果）") else None
    eq_scores = [float(r.get("等效分（融合结果）", 0) or 0) for r in eq_records if r.get("等效分（融合结果）")]
    # 时间加权等效分（EWMA，α=0.6，越近权重越高）
    if len(eq_scores) >= 2:
        alpha = 0.6
        ewma_score = eq_scores[0]
        for s in eq_scores[1:]:
            ewma_score = alpha * s + (1 - alpha) * ewma_score
        ewma_score = round(ewma_score, 1)
    else:
        ewma_score = eq_scores[0] if eq_scores else 0
    weighted = filter_weighted(eq_records)

    trend_class, trend_arrow, trend_text = compute_trend(eq_scores)
    sigma, vol_low, vol_high = compute_volatility_weighted(weighted)
    pred = prediction_state(eq_scores)
    has_analysis = len(eq_scores) >= 4
    is_first_record = len(eq_scores) == 1
    labels, label_sequence = eval_labels(eq_scores) if len(eq_scores) >= 4 else (None, None)
    volatility_style = classify_volatility_style(labels, sigma, label_sequence) if has_analysis else None

    # ── 院校定位 ──
    # 目标院校始终从 latest 提取，不依赖院校层次参考数据
    target_university = latest.get("目标院校")
    target_line = latest.get("目标院校录取线")
    target_gap = latest.get("差距分数")

    tier_info = None
    score = latest_equiv if latest_equiv else (eq_scores[-1] if eq_scores else 0)
    tier_data = macro.get("院校层次参考", [])
    if tier_data and score > 0:
        current_tier = None
        next_tier = None
        all_tiers = []

        for row in tier_data:
            scope = str(row.get("范围", ""))
            name = str(row.get("梯队", ""))
            threshold_str = str(row.get("预估总分门槛", "0"))
            upper_str = str(row.get("预估总分上限", "750"))
            try:
                threshold = float(threshold_str)
                upper = float(upper_str) if upper_str else 750
            except (ValueError, TypeError):
                continue

            tier_entry = {
                "scope": scope,
                "name": name,
                "threshold": threshold,
                "upper": upper,
                "schools": str(row.get("代表院校", "")),
                "is_current": False,
            }

            # Check if student is in this tier
            if threshold <= score <= upper:
                tier_entry["is_current"] = True
                current_tier = tier_entry

            all_tiers.append(tier_entry)

        # Find next tier up
        if current_tier:
            above = [t for t in all_tiers if t["threshold"] > current_tier["upper"]]
            above.sort(key=lambda t: t["threshold"])
            if above:
                next_tier = above[0]
            elif [t for t in all_tiers if t["threshold"] > score]:
                # Student between tiers
                candidates = [t for t in all_tiers if t["threshold"] > score]
                candidates.sort(key=lambda t: t["threshold"])
                next_tier = candidates[0]

        tier_info = {
            "current": current_tier,
            "next": next_tier,
            "next_gap": round(next_tier["threshold"] - score, 0) if next_tier else None,
            "all_tiers": all_tiers,
            "target_university": target_university,
            "target_line": target_line,
            "target_gap": target_gap,
        }

    # 无院校层次参考但有目标院校时，构建最小 tier_info
    if tier_info is None and target_university:
        tier_info = {
            "current": None,
            "next": None,
            "next_gap": None,
            "all_tiers": [],
            "target_university": target_university,
            "target_line": target_line,
            "target_gap": target_gap,
        }

    # Extract calculation detail from latest record
    latest_calc_detail = ""
    latest_subject_scores = []
    detail_str = latest.get("详细信息", "")
    if detail_str:
        try:
            detail_obj = json.loads(detail_str)
            latest_calc_detail = detail_obj.get("calculation_detail", "")
            # 防御：list 转 string
            if isinstance(latest_calc_detail, list):
                latest_calc_detail = "|".join(str(x) for x in latest_calc_detail)
            latest_subject_scores = detail_obj.get("subject_scores", [])
            # 防御：dict 转 list-of-dict
            if isinstance(latest_subject_scores, dict):
                latest_subject_scores = [{"subject": k, "score": v} for k, v in latest_subject_scores.items()]
        except (json.JSONDecodeError, TypeError):
            pass

    template = env.get_template("report_personal.html")
    return template.render(
        generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
        equivalent_score=f"{latest_equiv:.0f} 分" if latest_equiv else "暂无",
        latest_equiv=latest_equiv or 0,
        confidence=latest.get("置信度", "-"),
        method=latest.get("主计算方法", "-"),
        calc_detail=latest_calc_detail,
        error_lower=latest.get("误差区间下限", "-"),
        error_upper=latest.get("误差区间上限", "-"),
        has_analysis=has_analysis,
        trend_class=trend_class,
        trend_arrow=trend_arrow,
        trend_text=trend_text,
        prediction_state=pred or "-",
        volatility_lower=vol_low or "-",
        volatility_upper=vol_high or "-",
        sigma=f"{sigma}分" if sigma else "-",
        volatility_style=volatility_style or "-",
        is_first_record=is_first_record,
        exam_count=len(eq_scores),
        subject_scores=latest_subject_scores,
        hierarchy_refs=None,
        tier_info=tier_info,
        disclaimer=DISCLAIMER,
    )


def render_trend(data, env):
    """Render 高考总分趋势.html."""
    eq_records = data["equivalent"]
    exam_records = data.get("exams", [])

    if not eq_records:
        # 有考试记录但无等效分时，显示首次录入引导
        is_first = len(exam_records) >= 1
        exams_for_display = []
        if is_first:
            for e in exam_records:
                exams_for_display.append({
                    "date": e.get("日期", "-"),
                    "name": e.get("考试名", "-"),
                    "score": "-",
                    "confidence": "-",
                    "method": "等待计算",
                    "method_switch": False,
                    "calc_detail": "",
                    "prev_method": "",
                })
            exams_for_display = list(reversed(exams_for_display))
        template = env.get_template("report_trend.html")
        return template.render(
            generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
            exams=exams_for_display,
            has_analysis=False,
            trend_class="flat",
            trend_arrow="→",
            trend_text="等待数据",
            sigma="-",
            volatility_lower="-",
            volatility_upper="-",
            labels={"positive": "-", "normal": "-", "negative": "-"},
            cross_validations=[],
            volatility_style="-",
            is_first_record=is_first,
            exam_count=len(exam_records),
            disclaimer=DISCLAIMER,
        )

    exams = []
    for r in eq_records:
        # Extract calculation detail from 详细信息 JSON
        calc_detail = ""
        detail_str = r.get("详细信息", "")
        if detail_str:
            try:
                detail_obj = json.loads(detail_str)
                calc_detail = detail_obj.get("calculation_detail", "")
            except (json.JSONDecodeError, TypeError):
                pass

        exams.append({
            "date": r.get("日期", "-"),
            "name": r.get("考试名", "-"),
            "score": r.get("等效分（融合结果）", "-"),
            "confidence": r.get("置信度", "-"),
            "method": r.get("主计算方法", "-"),
            "calc_detail": calc_detail,
            "method_switch": False,  # will be set below
        })

    # I15: 检测方法切换，标记相邻两次考试方法不同的记录
    for i in range(1, len(exams)):
        if exams[i].get("method") != exams[i-1].get("method"):
            exams[i]["method_switch"] = True
            exams[i]["prev_method"] = exams[i-1].get("method", "")

    # 显示时反转为降序（最新的在最上面，方便查看近期趋势）
    exams = list(reversed(exams))

    eq_scores = [float(r["等效分（融合结果）"]) for r in eq_records if r.get("等效分（融合结果）")]
    weighted = filter_weighted(eq_records)
    trend_class, trend_arrow, trend_text = compute_trend(eq_scores)
    sigma, vol_low, vol_high = compute_volatility_weighted(weighted)
    has_analysis = len(eq_scores) >= 4
    is_first_record = len(exams) == 1
    labels, label_sequence = eval_labels(eq_scores) if len(eq_scores) >= 4 else (None, None)
    volatility_style = classify_volatility_style(labels, sigma, label_sequence) if has_analysis else None

    # Cross validations summary — extract both method 1 and method 2
    cross_validations = []
    for r in eq_records:
        for cv_num in ("1", "2"):
            cv_method = r.get(f"交叉验证方法{cv_num}")
            cv_score = r.get(f"交叉验证分{cv_num}")
            if cv_method and cv_score:
                diff = None
                primary = float(r.get("等效分（融合结果）", 0)) if r.get("等效分（融合结果）") else None
                cv_score_f = float(cv_score)
                if primary:
                    diff = f"{cv_score_f - primary:+.1f}"
                cross_validations.append({
                    "exam": r.get("考试名", "-"),
                    "method": cv_method,
                    "score": cv_score,
                    "diff": diff or "-",
                })

    template = env.get_template("report_trend.html")
    return template.render(
        generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
        exams=exams,  # 已按日期升序排序
        has_analysis=has_analysis,
        trend_class=trend_class,
        trend_arrow=trend_arrow,
        trend_text=trend_text,
        sigma=f"{sigma}" if sigma else "-",
        volatility_lower=vol_low or "-",
        volatility_upper=vol_high or "-",
        labels={"positive": labels["积极"] if labels else "-", "normal": labels["正常"] if labels else "-", "negative": labels["消极"] if labels else "-"},
        volatility_style=volatility_style or "-",
        is_first_record=is_first_record,
        exam_count=len(exams),
        cross_validations=cross_validations,
        disclaimer=DISCLAIMER,
    )


def render_subject(data, env, subject_name, sheet_name):
    """Render a single subject tracking HTML.
    Reads per-subject equivalent scores from 等效分记录 first;
    falls back to 成绩总表.xlsx exam records.
    """
    eq_records = data.get("equivalent", [])
    records = []
    scores = []

    # Primary: extract per-subject equivalent scores from saved eq data
    if eq_records:
        for eq in eq_records:
            detail_str = eq.get("详细信息", "")
            if not detail_str:
                continue
            try:
                detail_obj = json.loads(detail_str)
            except (json.JSONDecodeError, TypeError):
                continue
            for s in detail_obj.get("subject_scores", []):
                if s.get("subject") != subject_name:
                    continue
                score = s.get("score")
                if score:
                    scores.append(float(score))
                    records.append({
                        "date": eq.get("日期", "-"),
                        "exam": eq.get("考试名", "-"),
                        "score": f"{score:.1f}",
                        "confidence": s.get("confidence", "-"),
                        "method": s.get("method", "-"),
                    })

    # Fallback: extract from 单科追踪.xlsx or 成绩总表
    if not records:
        subject_data = data["subjects"].get(sheet_name, [])
        if subject_data:
            for r in subject_data:
                raw = r.get("原始分")
                assigned = r.get("赋分")
                if assigned and subject_name not in ("语文", "数学", "英语"):
                    scores.append(float(assigned))
                else:
                    scores.append(float(raw) if raw else None)
                records.append({
                    "date": r.get("日期", "-"),
                    "exam": r.get("考试名", "-"),
                    "raw": raw or "-",
                    "assigned": assigned or "-",
                    "confidence": r.get("赋分置信度") or "-",
                })
        else:
            for exam in data.get("exams", []):
                raw = None
                assigned = None
                conf = None
                if subject_name in ("语文", "数学", "英语"):
                    raw = exam.get(subject_name)
                    conf = "B"
                else:
                    for i in range(1, 4):
                        if str(exam.get(f"选科{i}名称", "")) == subject_name:
                            raw = exam.get(f"选科{i}原始分")
                            assigned = exam.get(f"选科{i}赋分")
                            conf = exam.get(f"选科{i}赋分置信度") or "A"
                            break
                if raw is None or raw == "":
                    continue
                if assigned and subject_name not in ("语文", "数学", "英语"):
                    scores.append(float(assigned))
                else:
                    scores.append(float(raw))
                records.append({
                    "date": exam.get("日期", "-"),
                    "exam": exam.get("考试名", "-"),
                    "raw": raw if raw else "-",
                    "assigned": assigned if assigned else "-",
                    "confidence": conf if conf else "-",
                })

    valid_scores = [s for s in scores if s is not None]
    if not valid_scores:
        # No data for this subject, still render an empty report
        dynamic = "-"
        latest = "-"
        highest = "-"
        trend_class, trend_arrow, trend_text = "flat", "→", "无数据"
    else:
        # EWMA for dynamic score
        alpha = 0.3
        dynamic = valid_scores[0]
        for s in valid_scores[1:]:
            dynamic = alpha * s + (1 - alpha) * dynamic
        dynamic = round(dynamic, 1)
        latest = valid_scores[-1]
        highest = max(valid_scores)
        trend_class, trend_arrow, trend_text = compute_trend(valid_scores)

    is_first_record = len(valid_scores) == 1
    template = env.get_template("report_subject.html")
    return template.render(
        subject=subject_name,
        generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
        dynamic_score=dynamic,
        latest=latest,
        highest=highest,
        trend_class=trend_class,
        trend_arrow=trend_arrow,
        trend_text=trend_text,
        is_first_record=is_first_record,
        exam_count=len(valid_scores),
        records=list(reversed(records)),  # 降序显示（最新在前）
        disclaimer=DISCLAIMER,
    )


def run(workspace):
    data = load_data(workspace)
    data["_workspace"] = workspace

    # Ensure output directory exists
    output_dir = os.path.join(workspace, "output")
    os.makedirs(output_dir, exist_ok=True)

    # Setup Jinja2
    assets_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
    if not os.path.isdir(assets_dir):
        print(json.dumps({"status": "error", "reason": f"模板目录不存在: {assets_dir}"}))
        sys.exit(1)

    env = Environment(loader=FileSystemLoader(assets_dir))
    generated = []

    # 1. 个人档案
    html = render_personal(data, env)
    if html:
        p = os.path.join(workspace, "output", "个人档案.html")
        with open(p, "w", encoding="utf-8") as f:
            f.write(html)
        generated.append(p)

    # 2. 高考总分趋势
    html = render_trend(data, env)
    if html:
        p = os.path.join(workspace, "output", "高考总分趋势.html")
        with open(p, "w", encoding="utf-8") as f:
            f.write(html)
        generated.append(p)

    # 3-8. 单科追踪 x6
    # Determine subject names from exam data
    subject_sheet_map = {
        "语文追踪": "语文",
        "数学追踪": "数学",
        "英语追踪": "英语",
        "选科1追踪": "选科1",
        "选科2追踪": "选科2",
        "选科3追踪": "选科3",
    }

    # Try to get actual subject names from exam data
    exams = data["exams"]
    latest_exam = exams[-1] if exams else None
    if latest_exam:
        sub1_name = latest_exam.get("选科1名称")
        sub2_name = latest_exam.get("选科2名称")
        sub3_name = latest_exam.get("选科3名称")
        if sub1_name:
            subject_sheet_map["选科1追踪"] = str(sub1_name)
        if sub2_name:
            subject_sheet_map["选科2追踪"] = str(sub2_name)
        if sub3_name:
            subject_sheet_map["选科3追踪"] = str(sub3_name)

    for sheet_name, subject_name in subject_sheet_map.items():
        html = render_subject(data, env, subject_name, sheet_name)
        p = os.path.join(workspace, "output", f"{subject_name}追踪.html")
        with open(p, "w", encoding="utf-8") as f:
            f.write(html)
        generated.append(p)

    return {"status": "ok", "files": generated}


def main():
    parser = argparse.ArgumentParser(description="Generate study-tracker HTML reports")
    parser.add_argument("--workspace", required=True, help="Workspace root path")
    args = parser.parse_args()

    workspace = os.path.abspath(args.workspace)
    if not os.path.exists(workspace):
        print(json.dumps({"status": "error", "reason": f"路径不存在: {workspace}"}))
        sys.exit(1)

    result = run(workspace)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
