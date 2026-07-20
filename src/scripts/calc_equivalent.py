#!/usr/bin/env python3
"""Calculate equivalent Gaokao score using all available methods.

Priority order (fixed ranking):
  1. 分数线对照法/等比例放缩法 (Score-line comparison) — A级
  2. 校内排名对照法 (School ranking lookup) — A级
  3. 排名锚定法 (Percentile anchoring) — A级，交叉验证
  4. 校排名估算 (School rank estimation) — C级

Confidence is A/B/C/D four levels, determined by data source and method.
Primary method determines the equivalent score; other methods serve as cross-validation.
Weights (A=1.0, B=0.8, C=0.5, D=0) are used only for trend/volatility analysis.

Input: JSON via stdin
Output: JSON with equivalent score, confidence, error range, cross-validations
"""

import json
import os
import sys

from openpyxl import load_workbook


def read_sheet_rows(ws):
    """Read all rows from a worksheet as list of dicts (header row is row 1)."""
    if ws.max_row < 2:
        return []
    headers = [cell.value for cell in ws[1]]
    rows = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        rows.append(dict(zip(headers, row)))
    return rows


def read_macro_data(workspace):
    """Read all macro data sheets."""
    path = os.path.join(workspace, "data", "macro", "宏观数据_只读.xlsx")
    if not os.path.exists(path):
        return None
    wb = load_workbook(path, data_only=True)
    data = {}
    for name in wb.sheetnames:
        data[name] = read_sheet_rows(wb[name])
    return data


def method_score_line(data, macro):
    """Method 1: 分数线对照法（等比例放缩）— A级，最高优先级."""
    special_line_exam = data.get("special_line_exam")
    if not special_line_exam:
        return None

    special_lines = macro.get("特控线", [])
    if not special_lines:
        return None

    # Find the most recent gaokao special line (by year)
    gaokao_sl = None
    latest_year = -1
    for sl in special_lines:
        if sl.get("特控线分数"):
            year = int(sl.get("年份", 0))
            if year > latest_year:
                latest_year = year
                gaokao_sl = float(sl["特控线分数"])

    if not gaokao_sl:
        return None

    total_score = float(data["total_score"])
    if total_score == 750:
        return {
            "method": "分数线对照法",
            "score": 750.0,
            "confidence": "A",
            "detail": f"满分750 → 等效分750",
        }

    es = (750 - gaokao_sl) / (750 - special_line_exam) * (total_score - special_line_exam) + gaokao_sl
    return {
        "method": "分数线对照法",
        "score": round(es, 1),
        "confidence": "A",
        "detail": f"等效分 = (750-{gaokao_sl})/(750-{special_line_exam})×({total_score}-{special_line_exam})+{gaokao_sl} = {es:.1f}",
    }


def method_school_lookup(data, macro):
    """Method 2: 校内排名对照法 — A级."""
    school_rank = data.get("school_rank")
    if not school_rank:
        return None

    school_total = data.get("school_total")
    class_type = data.get("class_type")
    unexamined_top = data.get("unexamined_top_students", 0)

    # Apply class-type calibration
    calibrated_rank = int(school_rank) + int(unexamined_top)

    lookup_sheet = macro.get("本校对照表_总分", [])
    if not lookup_sheet:
        return None

    # Sort by 校内排名
    lookup = sorted(lookup_sheet, key=lambda r: int(r.get("校内排名", 0)))
    if not lookup:
        return None

    ranks = [int(r["校内排名"]) for r in lookup]
    scores = [float(r["高考总分"]) for r in lookup]

    # Exact match
    if calibrated_rank in ranks:
        idx = ranks.index(calibrated_rank)
        score = scores[idx]
    elif calibrated_rank < ranks[0]:
        score = scores[0]
    elif calibrated_rank > ranks[-1]:
        score = scores[-1]
    else:
        # Linear interpolation
        for i in range(len(ranks) - 1):
            if ranks[i] <= calibrated_rank <= ranks[i + 1]:
                ratio = (calibrated_rank - ranks[i]) / (ranks[i + 1] - ranks[i])
                score = scores[i] + ratio * (scores[i + 1] - scores[i])
                break
        else:
            return None

    detail = f"校内排名{calibrated_rank}名"
    if unexamined_top:
        detail += f"（原始排名{school_rank}，补算重点班{unexamined_top}人）"
    detail += f" → 对照表对应高考总分{score:.0f}分"

    return {
        "method": "校内排名对照法",
        "score": round(score, 1),
        "confidence": "A",
        "detail": detail,
    }


def method_percentile(data, macro):
    """Method 3: 百分位排名锚定法 — A级，交叉验证."""
    rank = data.get("city_rank") or data.get("alliance_rank")
    total = data.get("city_total") or data.get("alliance_total")

    if not rank or not total:
        return None

    rank = int(rank)
    total = int(total)

    if rank > total:
        return None

    percentile = 1.0 - (rank / total)
    score_table = macro.get("一分一段表", [])
    if not score_table:
        return None

    # Sort by 分数 descending (higher score = lower cumulative count)
    sorted_table = sorted(score_table, key=lambda r: int(r.get("分数", 0)), reverse=True)

    max_count = max(int(r.get("累计人数", 0)) for r in sorted_table)
    if max_count == 0:
        return None

    target_count = int((1 - percentile) * max_count)

    # Find closest match
    best_score = None
    best_diff = float("inf")
    for row in sorted_table:
        count = int(row.get("累计人数", 0))
        diff = abs(count - target_count)
        if diff < best_diff:
            best_diff = diff
            best_score = float(row["分数"])

    if best_score is None:
        return None

    source = "全市排名" if data.get("city_rank") else "联盟排名"
    return {
        "method": "排名锚定法",
        "score": round(best_score, 1),
        "confidence": "A",
        "detail": f"{source}{rank}/{total} → 百分位{percentile:.3f} → 等效分{best_score:.0f}",
    }


def method_school_estimate(data, macro):
    """Method 4: 校排名估算 — C级.

    仅校内排名、无本校对照表时使用。用学校类型系数估算全市排名，
    再通过一分一段表百分位锚定得到等效分。
    """
    school_rank = data.get("school_rank")
    school_total = data.get("school_total")
    if not school_rank or not school_total:
        return None

    # 有对照表时应走 method_school_lookup
    if macro.get("本校对照表_总分"):
        return None

    score_table = macro.get("一分一段表", [])
    if not score_table:
        return None
    max_count = max(int(r.get("累计人数", 0)) for r in score_table)
    if max_count == 0:
        return None

    # 学校类型系数
    school_type = data.get("school_type", "")
    coeff_map = {"省重点": 0.3, "市重点": 0.6, "区重点": 1.0, "普通": 1.5}
    coeff = coeff_map.get(school_type, 1.0)

    estimated_city_rank = int(int(school_rank) / int(school_total) * max_count * coeff)
    percentile = 1.0 - (estimated_city_rank / max_count)

    sorted_table = sorted(score_table, key=lambda r: int(r.get("分数", 0)), reverse=True)
    target_count = int((1 - percentile) * max_count)
    best_score = None
    best_diff = float("inf")
    for row in sorted_table:
        diff = abs(int(row.get("累计人数", 0)) - target_count)
        if diff < best_diff:
            best_diff = diff
            best_score = float(row["分数"])

    if best_score is None:
        return None

    return {
        "method": "校排名估算",
        "score": round(best_score, 1),
        "confidence": "C",
        "detail": f"校内排名{school_rank}/{school_total}（{school_type or '未知类型'}）→ 估算全市排名~{estimated_city_rank} → 等效分{best_score:.0f}",
    }


def read_school_subject_data(macro):
    """Extract per-subject school-level data from macro sheets.

    Identifies sheets by surviving substring patterns:
      '富'+'特控' → 特控线, '富' only → 本科线, '本'+'对照'+'总分' → 对照表.
    Uses positional column access (keys[3]=2028届划线, keys[4]=2028届排名).
    """
    result = {}
    subject_names = ["语文", "数学", "英语", "物理", "化学", "生物", "技术", "历史", "政治", "地理"]

    for sheet_key in macro:
        sname = str(sheet_key)
        has_fu = "富" in sname
        has_te = "特控" in sname
        has_ben = "本" in sname
        has_dui = "对照" in sname
        has_zong = "总分" in sname

        # 富阳中学_特控线 or 富阳中学_本科线
        if has_fu:
            prefix = "cutoff" if has_te else "benke"
            for row in macro[sheet_key]:
                subj = str(list(row.values())[0]).strip() if row else ""
                if subj not in subject_names:
                    continue
                keys = list(row.keys())
                result.setdefault(subj, {})
                if len(keys) >= 5:
                    result[subj][f"{prefix}_2028"] = float(row.get(keys[3], 0) or 0)
                    result[subj][f"{prefix}_rank_2028"] = int(row.get(keys[4], 0) or 0)

        # 本校对照表_总分
        if has_ben and has_dui and has_zong:
            for row in macro[sheet_key]:
                subj = str(list(row.values())[0]).strip() if row else ""
                if subj not in subject_names:
                    continue
                result.setdefault(subj, {})
                rank_scores = {}
                keys = list(row.keys())
                for k in keys[2:]:  # skip 学科, 参考人数
                    val = row.get(k)
                    if val and str(val).replace(".", "").replace("-", "").isdigit():
                        import re
                        m = re.search(r'\d+', str(k))
                        if m:
                            rank_scores[int(m.group())] = float(val)
                if rank_scores:
                    result[subj]["rank_scores"] = rank_scores

    return result


def compute_subject_equivalents(data, macro):
    """Compute per-subject equivalent scores.

    For 选科 with 赋分: equivalent = 赋分 (already standardized).
    For 选科 without 赋分: try school lookup, mark data insufficient.
    For 语数英: use proportion of total equivalent to total score.

    Returns list of {subject, score, confidence, method, detail}.
    """
    subjects_input = data.get("subjects", [])
    if not subjects_input:
        return []

    total_score = data.get("total_score", 0)
    total_equivalent = data.get("_total_equivalent", 0)

    school_data = read_school_subject_data(macro)
    results = []

    for subj in subjects_input:
        name = subj.get("name", "")
        raw = subj.get("raw")
        assigned = subj.get("assigned")
        confidence = subj.get("confidence", "B")

        # 选科有赋分：赋分直映（赋分已标准化，最简洁可靠）
        if assigned and name not in ("语文", "数学", "英语"):
            results.append({
                "subject": name,
                "score": float(assigned),
                "confidence": confidence,
                "method": "赋分直映法",
                "detail": f"{name}赋分{assigned}（{confidence}级）→ 等效高考{assigned}分",
            })
            continue

        # 语数英：按总分比例折算
        if name in ("语文", "数学", "英语") and total_score and total_equivalent:
            if raw:
                ratio = float(raw) / float(total_score) if float(total_score) > 0 else 0
                eq = round(total_equivalent * ratio, 1)
                results.append({
                    "subject": name,
                    "score": eq,
                    "confidence": "B",
                    "method": "比例折算法",
                    "detail": f"{name}原始分{raw}占总分{total_score}的{ratio:.1%} → 等效{name}约{eq}分",
                })
            continue

        # 选科无赋分：尝试校内对照法
        if name in school_data:
            sd = school_data[name]
            if "rank_scores" in sd and sd["rank_scores"]:
                avg_gaokao = sum(sd["rank_scores"].values()) / len(sd["rank_scores"])
                results.append({
                    "subject": name,
                    "score": round(avg_gaokao, 1),
                    "confidence": "C",
                    "method": "校内均值参照法",
                    "detail": f"{name}无赋分无排名→ 参照本校历届{name}均分约{avg_gaokao:.0f}分（C级，仅参考）",
                })
                continue

        # 完全无数据
        results.append({
            "subject": name,
            "score": None,
            "confidence": confidence if confidence in ("C", "D") else "D",
            "method": "数据不足",
            "detail": f"{name}无赋分无排名数据，无法计算等效分",
        })

    return results


def _find_previous_subject_data(workspace, subject_name, current_exam_name):
    """Fallback: find the most recent exam with valid data for a subject.

    Reads 成绩总表.xlsx and looks for previous exams that have
    usable data for the given subject.
    """
    import os as _os
    path = _os.path.join(workspace, "data", "personal", "成绩总表.xlsx")
    if not _os.path.exists(path):
        return None

    try:
        wb = load_workbook(path, data_only=True)
        ws = wb["成绩总表"]
        headers = [c.value for c in ws[1]]
        rows = list(ws.iter_rows(min_row=2, values_only=True))
        rows.reverse()  # most recent first

        for row in rows:
            d = dict(zip(headers, row))
            exam_name = str(d.get("考试名", ""))
            # Skip current exam: fuzzy match on exam name
            if current_exam_name and (current_exam_name in exam_name or exam_name in current_exam_name):
                continue

            # Check if this exam has data for this subject
            if subject_name in ("语文", "数学", "英语"):
                score = d.get(subject_name)
                if score:
                    return {"exam": exam_name, "score": float(score), "field": subject_name}
            else:
                for i in range(1, 4):
                    subj_name = str(d.get(f"选科{i}名称", ""))
                    if subj_name == subject_name:
                        assigned = d.get(f"选科{i}赋分")
                        if assigned:  # 优先赋分
                            return {"exam": exam_name, "score": float(assigned), "field": f"选科{i}赋分"}
                        raw = d.get(f"选科{i}原始分")
                        if raw:
                            return {"exam": exam_name, "score": float(raw), "field": f"选科{i}原始分"}
    except Exception:
        return None
    return None


def compute_weighted_score(methods):
    """Compute confidence-weighted average from all available methods.

    Weights: A=1.0, B=0.8, C=0.5, D=0.0
    Returns weighted score or None if no valid methods.
    """
    weights = {"A": 1.0, "B": 0.8, "C": 0.5, "D": 0.0}
    total_weight = sum(weights.get(m["confidence"], 0) for m in methods)
    if total_weight == 0:
        return None
    weighted_sum = sum(m["score"] * weights.get(m["confidence"], 0) for m in methods)
    return round(weighted_sum / total_weight, 1)


def compute_error_range(primary, cross_validations):
    """Calculate error range based on cross-validation spread."""
    if not cross_validations:
        default_margin = {"A": 5, "B": 10, "C": 15, "D": 20}
        margin = default_margin.get(primary["confidence"], 10)
        return {
            "lower": round(primary["score"] - margin, 1),
            "upper": round(primary["score"] + margin, 1),
        }

    valid_cv = [cv for cv in cross_validations if cv.get("score")]
    if not valid_cv:
        margin = 5
    else:
        avg_cv = sum(cv["score"] for cv in valid_cv) / len(valid_cv)
        margin = max(3, abs(primary["score"] - avg_cv))

    return {
        "lower": round(primary["score"] - margin, 1),
        "upper": round(primary["score"] + margin, 1),
    }


def compute_weighted_error(methods, weighted_score):
    """Compute error range from confidence-weighted standard deviation across methods."""
    weights_map = {"A": 1.0, "B": 0.8, "C": 0.5, "D": 0.0}
    weights = [weights_map.get(m["confidence"], 0) for m in methods]
    total_weight = sum(weights)
    if total_weight == 0 or len(methods) < 2:
        return 5.0  # default margin for single method
    variance = sum(w * (m["score"] - weighted_score) ** 2 for m, w in zip(methods, weights)) / total_weight
    return max(3.0, round(variance ** 0.5 * 1.5, 1))


def run(data):
    workspace = os.path.abspath(data.get("workspace", "."))

    # 满分制换算：450分制 → 750分制
    score_scale = data.get("score_scale", 750)
    if score_scale == 450:
        data = dict(data)
        data["total_score"] = float(data["total_score"]) * 750 / 450
        if data.get("special_line_exam"):
            data["special_line_exam"] = float(data["special_line_exam"]) * 750 / 450

    macro = read_macro_data(workspace)

    if macro is None:
        return {
            "status": "error",
            "reason": "宏观数据_只读.xlsx 不存在，请先完成初始设置",
        }

    methods = []

    # Try methods in priority order: score_line → school_lookup → percentile → school_estimate
    result = method_score_line(data, macro)
    if result:
        methods.append(result)

    result = method_school_lookup(data, macro)
    if result:
        methods.append(result)

    result = method_percentile(data, macro)
    if result:
        methods.append(result)

    result = method_school_estimate(data, macro)
    if result:
        methods.append(result)

    if not methods:
        return {
            "status": "insufficient_data",
            "reason": "当前数据不足以计算等效分。至少需要以下之一：全市/联盟排名+一分一段表、模考特控线、校内排名+对照表。",
        }

    primary = methods[0]  # Highest priority method
    equivalent_score = primary["score"]
    default_margin = {"A": 5, "B": 10, "C": 15, "D": 20}
    margin = default_margin.get(primary["confidence"], 10)
    error_lower = round(equivalent_score - margin, 1)
    error_upper = round(equivalent_score + margin, 1)

    # Full method details (all methods, for transparency)
    weights_map = {"A": 1.0, "B": 0.8, "C": 0.5, "D": 0.0}
    method_details = []
    for m in methods:
        method_details.append({
            "method": m["method"],
            "score": m["score"],
            "confidence": m["confidence"],
            "weight": weights_map.get(m["confidence"], 0),
            "detail": m.get("detail", ""),
        })

    # calculation_detail: primary method's detail, with cross-validation note if applicable
    calculation_detail = primary.get("detail", "")
    if len(methods) >= 2:
        cv_names = "、".join(m["method"] for m in methods[1:])
        calculation_detail += f"（交叉验证：{cv_names}）"

    # Cross-validations: supplementary methods vs primary
    cross_validations = []
    for m in methods[1:]:
        diff = round(m["score"] - primary["score"], 1)
        cross_validations.append({
            "method": m["method"],
            "score": m["score"],
            "confidence": m["confidence"],
            "difference": diff,
        })

    # ── 方法分歧处理（三档） ──
    trust_note = None
    divergence = None
    if len(methods) >= 2:
        scores = [m["score"] for m in methods]
        max_diff = max(scores) - min(scores)
        if max_diff <= 3:
            trust_note = "交叉验证一致，等效分可信度较高"
            divergence = "low"
        elif max_diff <= 5:
            trust_note = f"方法间存在分歧（最大差异{max_diff:.0f}分），以{primary['method']}为准"
            divergence = "medium"
        else:
            trust_note = f"方法分歧较大（最大差异{max_diff:.0f}分），建议补充排名或特控线数据以提高可靠性"
            divergence = "high"

    # Determine overall confidence: highest among available methods
    conf_order = {"A": 4, "B": 3, "C": 2, "D": 1}
    best_confidence = max(methods, key=lambda m: conf_order.get(m["confidence"], 0))["confidence"]

    # ── 数据一致性校验 ──
    warnings = []
    user_total = data.get("city_total") or data.get("alliance_total")
    if user_total:
        user_total = int(user_total)
        score_table = macro.get("一分一段表", [])
        if score_table:
            max_count = max(int(r.get("累计人数", 0)) for r in score_table)
            if max_count > 0 and user_total > 0:
                ratio = abs(user_total - max_count) / max(max_count, user_total)
                if ratio > 0.10:
                    warnings.append(
                        f"考试总人数({user_total})与一分一段表基数({max_count})差异{ratio:.0%}，"
                        "等效分可能存在偏差"
                    )

    # ── 单科等效分 ──
    data["_total_equivalent"] = equivalent_score
    subject_scores = compute_subject_equivalents(data, macro)

    # ── 跨次数据回退 ──
    for i, ss in enumerate(subject_scores):
        if ss["confidence"] in ("C", "D") and ss["score"] is None:
            prev = _find_previous_subject_data(workspace, ss["subject"], data.get("exam_name", ""))
            if prev:
                fallback_score = round(prev["score"] * 0.85, 1)  # 跨次折扣
                subject_scores[i] = {
                    **ss,
                    "score": fallback_score,
                    "confidence": "C",
                    "method": f"{ss['method']}（回退至{prev['exam']}）",
                    "detail": f"{ss['detail']}。回退至{prev['exam']}的{prev['score']}分×0.85={fallback_score}分",
                }

    # ── 单科加总 + 置信度加权融合 ──
    subject_sum = sum(s["score"] for s in subject_scores if s["score"])
    if subject_scores and subject_sum:
        subject_weights = [weights_map.get(s["confidence"], 0) for s in subject_scores if s["score"]]
        w_subject = (sum(subject_weights) / len(subject_weights) * 0.7) if subject_weights else 0
        w_total = weights_map.get(best_confidence, 1.0)

        if w_subject > 0:
            total_method_score = equivalent_score
            fused = round((equivalent_score * w_total + subject_sum * w_subject) / (w_total + w_subject), 1)

            # 误差区间取两方法中较宽的
            calculation_detail += f" | 单科加总{subject_sum}分(w={w_subject:.2f}) → 融合{fused}分"

            equivalent_score = fused
            error_lower = round(fused - max(margin, abs(fused - total_method_score) + 3), 1)
            error_upper = round(fused + max(margin, abs(fused - subject_sum) + 3), 1)

    result = {
        "status": "ok",
        "primary_method": primary["method"],
        "equivalent_score": equivalent_score,
        "confidence": best_confidence,
        "error_lower": error_lower,
        "error_upper": error_upper,
        "calculation_detail": calculation_detail,
        "method_count": len(methods),
        "method_details": method_details,
        "cross_validations": cross_validations,
        "trust_note": trust_note,
        "divergence": divergence,
        "warnings": warnings,
        "subject_scores": subject_scores,
    }
    return result


def main():
    data = json.loads(sys.stdin.read())
    result = run(data)
    print(json.dumps(result, ensure_ascii=False, default=str))


if __name__ == "__main__":
    main()
