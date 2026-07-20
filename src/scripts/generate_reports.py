#!/usr/bin/env python3
"""Generate 8 HTML reports from Excel data.

Reports:
  1. 个人档案.html — latest equivalent score, status, target gap, personal info
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

4. 数据来源：用户上传。

5. 个人信息：MBTI、职业偏好等信息仅存档展示，不参与任何分数计算或分析。"""


def read_sheet_dicts(ws):
    """Read worksheet rows as dicts. Returns empty list if only headers."""
    if ws.max_row < 2:
        return []
    headers = [str(cell.value) if cell.value is not None else f"col_{i}" for i, cell in enumerate(ws[1])]
    rows = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        d = {}
        for i, val in enumerate(row):
            if i < len(headers):
                d[headers[i]] = val
        rows.append(d)
    return rows


def load_data(workspace):
    """Load all Excel data."""
    data = {"exams": [], "equivalent": [], "subjects": {}, "volatility": []}

    # 成绩总表
    path = os.path.join(workspace, "data", "personal", "成绩总表.xlsx")
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        data["exams"] = read_sheet_dicts(wb["成绩总表"])

    # 等效分记录
    path = os.path.join(workspace, "data", "personal", "等效分记录.xlsx")
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        data["equivalent"] = read_sheet_dicts(wb["等效分记录"])

    # 单科追踪
    path = os.path.join(workspace, "data", "personal", "单科追踪.xlsx")
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        for name in wb.sheetnames:
            data["subjects"][name] = read_sheet_dicts(wb[name])

    # 宏观数据
    path = os.path.join(workspace, "data", "macro", "宏观数据_只读.xlsx")
    data["macro"] = {}
    if os.path.exists(path):
        wb = load_workbook(path, data_only=True)
        for name in wb.sheetnames:
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
    """Extract (score, weight) tuples from equivalent score records, excluding C-level."""
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


def compute_trend_weighted(weighted_scores):
    """Weighted linear trend. weighted_scores: list of (score, weight)."""
    n = len(weighted_scores)
    if n < 2:
        return ("flat", "→", "数据不足")
    scores = [s for s, _ in weighted_scores]
    x_mean = (n - 1) / 2
    y_mean = sum(scores) / n
    num = sum((i - x_mean) * scores[i] for i in range(n))
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
    sequence = []
    labels = {"积极": 0, "正常": 0, "消极": 0}
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
    """Classify volatility style: 稳定型/波动型/趋势型. Returns None if insufficient data."""
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
        return "趋势型"
    if active_ratio >= 0.5 and max_consecutive < 3:
        return "波动型"
    if normal_ratio >= 0.7:
        return "稳定型"
    return "波动型"


# ─── Report generators ─────────────────────────────────────────────────

def render_personal(data, env):
    """Render 个人档案.html."""
    eq_records = data["equivalent"]
    macro = data.get("macro", {})

    if not eq_records:
        template = env.get_template("report_personal.html")
        return template.render(
            generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
            equivalent_score="暂无数据",
            confidence="-",
            method="-",
            error_lower="-",
            error_upper="-",
            has_analysis=False,
            trend_class="flat",
            trend_arrow="→",
            trend_text="等待数据",
            prediction_state="-",
            volatility_lower="-",
            volatility_upper="-",
            sigma="-",
            target_university=None,
            gap_text="",
            gap_class="",
            admission_lines=[],
            hierarchy_refs=None,
            personal_info=None,
            disclaimer=DISCLAIMER,
        )

    latest = eq_records[-1]
    eq_scores = [float(r.get("等效分（融合结果）", 0) or 0) for r in eq_records if r.get("等效分（融合结果）")]
    weighted = filter_weighted(eq_records)

    trend_class, trend_arrow, trend_text = compute_trend(eq_scores)
    sigma, vol_low, vol_high = compute_volatility_weighted(weighted)
    pred = prediction_state(eq_scores)
    has_analysis = len(eq_scores) >= 4
    labels, label_sequence = eval_labels(eq_scores) if len(eq_scores) >= 4 else (None, None)
    volatility_style = classify_volatility_style(labels, sigma, label_sequence) if has_analysis else None

    # Target university
    target_university = None
    admission_lines = []
    gap_text = ""
    gap_class = ""

    if eq_records:
        target_university = latest.get("目标院校")
        target_line = latest.get("目标院校录取线")
        gap = latest.get("差距分数")
        if target_university:
            gap_text = f"+{gap}分" if gap and float(gap) > 0 else f"{gap}分"
            gap_class = "positive" if (gap and float(gap) > 0) else "negative"
            # Find historical lines
            for rec in eq_records:
                if rec.get("目标院校录取线"):
                    admission_lines.append({
                        "year": rec.get("日期", "-"),
                        "score": rec["目标院校录取线"],
                    })

    # Hierarchy references (if no target)
    hierarchy_refs = None
    if not target_university:
        uni_data = macro.get("省内高校录取线", [])
        if uni_data and eq_scores:
            latest_score = eq_scores[-1]
            refs = []
            for uni in uni_data:
                score = float(uni.get("录取最低分", 0))
                if score:
                    gap_val = round(latest_score - score, 1)
                    gap_str = f"差距+{gap_val}分" if gap_val >= 0 else f"差距{gap_val}分"
                    refs.append({"name": uni.get("院校名称", "-"), "score": score, "gap": gap_str})
            if refs:
                hierarchy_refs = sorted(refs, key=lambda r: r["score"], reverse=True)[:5]

    # Personal info (from config)
    personal_info = None
    config_path = os.path.join(data.get("_workspace", ""), "data", "config.json")
    if os.path.exists(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
            parts = []
            if config.get("mbti"):
                parts.append(f"MBTI：{config['mbti']}")
            if config.get("career"):
                parts.append(f"职业兴趣：{config['career']}")
            if config.get("class_type"):
                parts.append(f"班型：{config['class_type']}")
            if config.get("grade"):
                parts.append(f"年级：{config['grade']}")
            if parts:
                personal_info = "  |  ".join(parts)

    template = env.get_template("report_personal.html")
    return template.render(
        generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
        equivalent_score=f"{float(latest['等效分（融合结果）']):.0f} 分" if latest.get("等效分（融合结果）") else "暂无",
        confidence=latest.get("置信度", "-"),
        method=latest.get("主计算方法", "-"),
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
        target_university=target_university,
        gap_text=gap_text,
        gap_class=gap_class,
        admission_lines=admission_lines,
        hierarchy_refs=hierarchy_refs,
        personal_info=personal_info,
        disclaimer=DISCLAIMER,
    )


def render_trend(data, env):
    """Render 高考总分趋势.html."""
    eq_records = data["equivalent"]

    if not eq_records:
        template = env.get_template("report_trend.html")
        return template.render(
            generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
            exams=[],
            has_analysis=False,
            trend_class="flat",
            trend_arrow="→",
            trend_text="等待数据",
            sigma="-",
            volatility_lower="-",
            volatility_upper="-",
            labels={"positive": "-", "normal": "-", "negative": "-"},
            cross_validations=[],
            disclaimer=DISCLAIMER,
        )

    exams = []
    for r in eq_records:
        exams.append({
            "date": r.get("日期", "-"),
            "name": r.get("考试名", "-"),
            "score": r.get("等效分（融合结果）", "-"),
            "confidence": r.get("置信度", "-"),
            "method": r.get("主计算方法", "-"),
        })

    eq_scores = [float(r["等效分（融合结果）"]) for r in eq_records if r.get("等效分（融合结果）")]
    weighted = filter_weighted(eq_records)
    trend_class, trend_arrow, trend_text = compute_trend(eq_scores)
    sigma, vol_low, vol_high = compute_volatility_weighted(weighted)
    has_analysis = len(eq_scores) >= 4
    labels, label_sequence = eval_labels(eq_scores) if len(eq_scores) >= 4 else (None, None)
    volatility_style = classify_volatility_style(labels, sigma, label_sequence) if has_analysis else None

    # Cross validations summary
    cross_validations = []
    for r in eq_records:
        if r.get("交叉验证方法1") and r.get("交叉验证分1"):
            diff = None
            primary = float(r.get("等效分（融合结果）", 0)) if r.get("等效分（融合结果）") else None
            cv_score = float(r["交叉验证分1"])
            if primary:
                diff = f"{cv_score - primary:+.1f}"
            cross_validations.append({
                "method": r["交叉验证方法1"],
                "score": r["交叉验证分1"],
                "diff": diff or "-",
            })

    template = env.get_template("report_trend.html")
    return template.render(
        generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
        exams=exams,
        has_analysis=has_analysis,
        trend_class=trend_class,
        trend_arrow=trend_arrow,
        trend_text=trend_text,
        sigma=f"{sigma}" if sigma else "-",
        volatility_lower=vol_low or "-",
        volatility_upper=vol_high or "-",
        labels={"positive": labels["积极"] if labels else "-", "normal": labels["正常"] if labels else "-", "negative": labels["消极"] if labels else "-"},
        volatility_style=volatility_style or "-",
        cross_validations=cross_validations,
        disclaimer=DISCLAIMER,
    )


def render_subject(data, env, subject_name, sheet_name):
    """Render a single subject tracking HTML.
    Reads from 单科追踪.xlsx first; falls back to 成绩总表.xlsx exam records.
    """
    subject_data = data["subjects"].get(sheet_name, [])
    records = []
    scores = []

    if subject_data:
        for r in subject_data:
            raw = r.get("原始分")
            scores.append(float(raw) if raw else None)
            records.append({
                "date": r.get("日期", "-"),
                "exam": r.get("考试名", "-"),
                "raw": raw or "-",
                "assigned": r.get("赋分") or "-",
                "confidence": r.get("赋分置信度") or "-",
            })
    else:
        # Fallback: extract from exam records (成绩总表)
        for exam in data.get("exams", []):
            raw = None
            assigned = None
            conf = None

            # Main subjects
            if subject_name in ("语文", "数学", "英语"):
                raw = exam.get(subject_name)
                conf = "B"  # 语数英原始分
            else:
                # Check 选科 columns
                for i in range(1, 4):
                    if str(exam.get(f"选科{i}名称", "")) == subject_name:
                        raw = exam.get(f"选科{i}原始分")
                        assigned = exam.get(f"选科{i}赋分")
                        conf = exam.get(f"选科{i}赋分置信度") or "A"
                        break

            if raw is None or raw == "":
                continue

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
        records=records,
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
    if exams:
        latest_exam = None
        for e in reversed(exams):
            latest_exam = e
            break
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
