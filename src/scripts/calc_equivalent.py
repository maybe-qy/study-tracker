#!/usr/bin/env python3
"""Calculate equivalent Gaokao score using all available methods.

Priority order (fixed ranking, first available wins as primary):
  1. 双模块换算法 (Two-module) — A/B级
  2. 分数线对照法/等比例放缩法 (Score-line comparison) — A级
  3. 校排阈值估算法 (School threshold estimation) — B级
  4. 校内排名对照法 (School ranking lookup) — A级
  5. 排名锚定法 (Percentile anchoring) — A级，交叉验证
  6. 校排名估算 (School rank estimation) — C级

Confidence is A/B/C/D four levels, determined by data source and method.
All available methods participate in weighted fusion by confidence.
Weights (A=1.0, B=0.8, C=0.5, D=0).

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
        path = os.path.join(workspace, "data", "macro", "宏观数据.xlsx")
    if not os.path.exists(path):
        return None
    wb = load_workbook(path, data_only=True)
    data = {}
    for name in wb.sheetnames:
        data[name] = read_sheet_rows(wb[name])
    return data


def method_score_line(data, macro):
    """Method 1: 分数线对照法（等比例放缩）— A级，最高优先级."""
    special_line_exam = data.get("special_line_exam") or data.get("special_line")
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

    if float(special_line_exam) >= 750:
        return None

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
    estimated_city_rank = min(estimated_city_rank, max_count)  # clamp to avoid percentile overflow
    percentile = 1.0 - (estimated_city_rank / max_count)
    percentile = max(0.0, min(1.0, percentile))  # clamp to [0, 1]

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


def method_two_module(data, macro):
    """Method 0: 双模块独立换算法 — A/B级，最高优先级.

    When school upgrade data (per-subject 特控线+浙大线) is available,
    splits calculation into two independent modules:

    Module 1 (语数英 450pt): proportional scaling between school cutoffs
      and gaokao reference targets (特控340, 浙大378).

    Module 2 (选科 100pt each): per-subject proportional scaling.
      Priority 1: dual-line (特控+浙大) → A级
      Priority 2: single-line (仅特控) → B级
      Priority 3: no line → skip (delegated to fallback methods)

    Total = 语数英等效 + sum(选科等效)
    """
    # Read upgrade sheet directly (non-standard layout)
    workspace = os.path.abspath(data.get("workspace", "."))
    for fname in ("宏观数据_只读.xlsx", "宏观数据.xlsx"):
        path = os.path.join(workspace, "data", "macro", fname)
        if os.path.exists(path):
            break
    else:
        return None

    wb = load_workbook(path, data_only=True)

    # Only match if exam context aligns (期末 exam ↔ 期末 upgrade sheet)
    if "期末" not in data.get("exam_name", ""):
        wb.close()
        return None

    ws = None
    for sn in wb.sheetnames:
        if "期末" in str(sn) and "升级" in str(sn):
            ws = wb[sn]
            break
    if ws is None:
        wb.close()
        return None

    # Parse: find 2028届 cutoffs for all subjects
    # Two sections: 特控线 and 浙大线, each has rows with 5 cols:
    # col0=科目, col1=2027划线, col2=2027上线, col3=2028划线, col4=2028上线
    cutoffs = {}  # {subject: {"special": val, "zd": val or None}}
    current_section = None  # "special" or "zd"

    for row in ws.iter_rows(min_row=1, values_only=True):
        if not row:
            continue
        text_0 = str(row[0]).strip() if row[0] else ""

        if "特控" in text_0 and "分段" in text_0:
            current_section = "special"
            continue
        if "浙大" in text_0 and "分段" in text_0:
            current_section = "zd"
            continue
        if current_section is None or len(row) < 5:
            continue

        subj = text_0
        if subj == "科目" or not subj:
            continue

        try:
            line_2028 = float(row[3]) if row[3] is not None else None
        except (ValueError, TypeError):
            continue

        if line_2028 is None:
            continue

        if subj not in cutoffs:
            cutoffs[subj] = {"special": None, "zd": None}
        cutoffs[subj][current_section] = line_2028

    wb.close()

    # Need at least 语数英综合 special line
    main_data = cutoffs.get("语数英综合", {})
    if main_data.get("special") is None:
        return None

    # Gaokao reference targets
    GK_MAIN_SPECIAL = 340  # 语数英特控目标 (330-350 中点)
    GK_MAIN_ZD = 378       # 语数英浙大目标 (374-383 中点)
    GK_SUB_SPECIAL = 90    # 选科特控目标 (88-92 中点)
    GK_SUB_ZD = 96         # 选科浙大目标 (95-97 中点)

    student_score = float(data.get("_original_total_score", data.get("total_score", 0)))
    score_scale = data.get("score_scale", 750)
    if score_scale == 750:
        student_main = student_score * 450 / 750
    else:
        student_main = student_score

    details = []
    total_equivalent = 0.0
    conf_counts = {"A": 0, "B": 0, "C": 0, "D": 0}  # per-module confidence tally

    # ── Module 1: 语数英 ──
    sch_special = main_data["special"]
    sch_zd = main_data.get("zd")

    if sch_zd and student_main >= sch_special:
        ratio = (student_main - sch_special) / (sch_zd - sch_special)
        main_eq = GK_MAIN_SPECIAL + (GK_MAIN_ZD - GK_MAIN_SPECIAL) * ratio
        conf = "A"
        detail = (f"语数英{student_main:.0f}分, 校特控{sch_special:.0f}/浙大{sch_zd:.0f}"
                  f" → 线上{ratio:.1%} → 等效{main_eq:.1f}")
    elif student_main >= sch_special:
        # Only special line available — single-point scaling
        ratio = student_main / sch_special
        main_eq = GK_MAIN_SPECIAL * ratio
        conf = "B"
        detail = (f"语数英{student_main:.0f}分, 校特控{sch_special:.0f}(无浙大线)"
                  f" → 比例{ratio:.1%} → 等效{main_eq:.1f}")
    else:
        return None  # Below special line, can't use this method

    main_eq = round(main_eq, 1)
    total_equivalent += main_eq
    conf_counts[conf] += 1
    details.append(f"[语数英] {detail}")

    # ── Module 2: 选科 ──
    subjects_input = data.get("subjects", [])
    for subj in subjects_input:
        name = subj.get("name", "")
        if name in ("语文", "数学", "英语"):
            continue  # handled in module 1
        raw = subj.get("raw")
        if raw is None:
            details.append(f"[{name}] 无原始分, 跳过")
            continue

        raw = float(raw)
        sub_cut = cutoffs.get(name, {})

        if sub_cut.get("special") and sub_cut.get("zd") and raw >= sub_cut["special"]:
            # Priority 1: dual-line
            ratio = (raw - sub_cut["special"]) / (sub_cut["zd"] - sub_cut["special"])
            sub_eq = GK_SUB_SPECIAL + (GK_SUB_ZD - GK_SUB_SPECIAL) * ratio
            conf = "A"
            detail = (f"{name}{raw:.0f}分, 校特控{sub_cut['special']:.0f}/浙大{sub_cut['zd']:.0f}"
                      f" → 线上{ratio:.1%} → 等效{sub_eq:.1f}")
        elif sub_cut.get("special") and raw >= sub_cut["special"]:
            # Priority 2: single-line
            ratio = raw / sub_cut["special"]
            sub_eq = GK_SUB_SPECIAL * ratio
            conf = "B"
            detail = (f"{name}{raw:.0f}分, 校特控{sub_cut['special']:.0f}(无浙大线)"
                      f" → 比例{ratio:.1%} → 等效{sub_eq:.1f}")
        elif sub_cut.get("special"):
            # Below special line
            ratio = raw / sub_cut["special"]
            sub_eq = GK_SUB_SPECIAL * ratio
            conf = "C"
            detail = (f"{name}{raw:.0f}分, 低于校特控{sub_cut['special']:.0f}"
                      f" → 比例{ratio:.1%} → 等效{sub_eq:.1f}")
        else:
            # Priority 3: no school cutoff → try existing single-subject fallbacks
            assigned = subj.get("assigned")
            if assigned:
                sub_eq = float(assigned)
                conf = subj.get("confidence", "B")
                detail = f"{name}赋分{assigned}（{conf}级）→ 等效{sub_eq:.0f}分"
            else:
                # Try cross-exam fallback
                prev = _find_previous_subject_data(workspace, name, data.get("exam_name", ""))
                if prev:
                    n = prev.get("exams_skipped", 1)
                    discount = round(0.85 ** n, 3)
                    sub_eq = round(prev["score"] * discount, 1)
                    conf = "C"
                    detail = (f"{name}无校内划线, 回退至{prev['exam']}"
                              f"（{prev['score']}分×{discount:.2f}={sub_eq}分, C级）")
                else:
                    # Use school对照表 or rough estimate
                    sub_eq = round(GK_SUB_SPECIAL * raw / 100, 1) if raw else None
                    conf = "D"
                    detail = f"{name}无任何参照数据 → 粗略估算{sub_eq}分(D级)"
            if sub_eq is None:
                details.append(f"[{name}] 无任何可用数据, 跳过")
                continue

        sub_eq = round(sub_eq, 1)
        total_equivalent += sub_eq
        conf_counts[conf] += 1
        details.append(f"[{name}] {detail}")

    total_equivalent = round(total_equivalent, 1)

    # Overall confidence: A if ≥50% modules are A and no module is D
    total_modules = sum(conf_counts.values())
    if conf_counts.get("D", 0) > 0:
        overall_conf = "C"
    elif conf_counts.get("C", 0) >= 2:
        overall_conf = "B"
    elif conf_counts.get("A", 0) >= total_modules * 0.5:
        overall_conf = "A"
    elif conf_counts.get("A", 0) + conf_counts.get("B", 0) >= total_modules * 0.5:
        overall_conf = "B"
    else:
        overall_conf = "C"

    return {
        "method": "双模块换算法",
        "score": total_equivalent,
        "confidence": overall_conf,
        "detail": " | ".join(details),
    }


def method_school_threshold(data, macro):
    """Method 5: 校排阈值估算法 — B级，交叉验证.

    Reads the升级 Sheet directly (bypasses broken dict-parsing for
    non-standard sheet layout). Uses school-internal 特控线+浙大线
    thresholds to estimate school rank → 一分一段表 → equivalent.
    """
    workspace = os.path.abspath(data.get("workspace", "."))
    for fname in ("宏观数据_只读.xlsx", "宏观数据.xlsx"):
        path = os.path.join(workspace, "data", "macro", fname)
        if os.path.exists(path):
            break
    else:
        return None

    wb = load_workbook(path, data_only=True)

    # Only match if exam context aligns
    if "期末" not in data.get("exam_name", ""):
        wb.close()
        return None

    # Find upgrade sheet
    ws = None
    for sn in wb.sheetnames:
        if "期末" in str(sn) and "升级" in str(sn):
            ws = wb[sn]
            break
    if ws is None:
        wb.close()
        return None

    # Parse with positional access (sheet has title + section header rows)
    # Data rows: col0=科目, col1=2027划线, col2=2027上线, col3=2028划线, col4=2028上线
    te_line = None
    te_rank = None
    zd_line = None
    zd_rank = None

    for row in ws.iter_rows(min_row=1, values_only=True):
        if not row or len(row) < 5:
            continue
        subj = str(row[0]).strip() if row[0] else ""
        if "语数英" not in subj:
            continue
        try:
            line_2028 = float(row[3]) if row[3] is not None else None
            count_2028 = int(row[4]) if row[4] is not None else None
        except (ValueError, TypeError):
            continue
        if line_2028 is None or count_2028 is None:
            continue

        if te_line is None:
            te_line, te_rank = line_2028, count_2028
        else:
            zd_line, zd_rank = line_2028, count_2028

    wb.close()

    if te_line is None or zd_line is None:
        return None

    # Use original score if available (data["total_score"] may be 750-converted)
    student_score = float(data.get("_original_total_score", data.get("total_score", 0)))
    score_scale = data.get("score_scale", 750)
    if score_scale == 750:
        student_450 = student_score * 450 / 750
    else:
        student_450 = student_score

    if not (te_line <= student_450 <= zd_line):
        return None

    ratio = (student_450 - te_line) / (zd_line - te_line)
    estimated_rank = int(te_rank - ratio * (te_rank - zd_rank))

    # Get school total from 结构 sheet (富阳中学默认835，会被sheet数据覆盖)
    school_total = 835
    for key in macro:
        if "期末" in str(key) and "结构" in str(key):
            for row in macro[key]:
                vals = list(row.values())
                if len(vals) >= 2:
                    text = str(vals[0]) if vals[0] else ""
                    if "全校" in text:
                        try:
                            school_total = int(str(vals[1]).replace("人", ""))
                        except (ValueError, TypeError):
                            pass
            break

    school_type = data.get("school_type", "省重点")
    coeff_map = {"省重点": 0.3, "市重点": 0.6, "区重点": 1.0, "普通": 1.5}
    coeff = coeff_map.get(school_type, 1.0)

    score_table = macro.get("一分一段表", [])
    if not score_table:
        return None
    max_count = max(int(r.get("累计人数", 0)) for r in score_table)
    if max_count == 0:
        return None

    estimated_city_rank = int(estimated_rank / school_total * max_count * coeff)
    estimated_city_rank = min(estimated_city_rank, max_count)
    percentile = max(0.0, min(1.0, 1.0 - estimated_city_rank / max_count))

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
        "method": "校排阈值估算法",
        "score": round(best_score, 1),
        "confidence": "B",
        "detail": f"校内特控线{te_line:.0f}分(=第{te_rank}名), 浙大线{zd_line:.0f}分(=第{zd_rank}名) → 学生{student_450:.0f}分估算校内第{estimated_rank}名 → 等效{best_score:.0f}分",
    }


def read_school_subject_data(macro):
    """Extract per-subject rank→score mappings from 本校对照表 sheets.

    Only processes sheets whose names contain 本+对照+总分 (excluding
    the standard 本校对照表_总分 which is handled by method_school_lookup).
    These are subject-level lookup tables mapping school ranks to gaokao scores.
    Returns {subject: {rank_scores: {rank: score, ...}}}.
    """
    result = {}
    subject_names = ["语文", "数学", "英语", "物理", "化学", "生物", "技术", "历史", "政治", "地理"]

    for sheet_key in macro:
        sname = str(sheet_key)
        if not ("本" in sname and "对照" in sname and "总分" in sname):
            continue

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
                    try:
                        rank = int(str(k))
                    except (ValueError, TypeError):
                        m = re.search(r'\d+', str(k))
                        if m:
                            rank = int(m.group())
                        else:
                            continue
                    rank_scores[rank] = float(val)
            if rank_scores:
                result[subj]["rank_scores"] = rank_scores

    return result


def compute_subject_equivalents(data, macro):
    """Compute per-subject equivalent scores.

    Two-pass approach:
    1. Resolve ALL 选科 scores first (赋分直映 → fallback → school lookup).
    2. Compute 语数英 from the remaining equivalent (total − sum of 选科).

    This ensures 语数英 + 选科 ≈ total_equivalent regardless of score scale.
    """
    subjects_input = data.get("subjects", [])
    if not subjects_input:
        return []

    total_equivalent = data.get("_total_equivalent", 0)
    workspace = os.path.abspath(data.get("workspace", "."))
    exam_name = data.get("exam_name", "")

    school_data = read_school_subject_data(macro)
    results = []

    # ── Pass 1: resolve 选科 scores ──
    sum_assigned = 0.0
    sum_main_raw = 0.0

    for subj in subjects_input:
        name = subj.get("name", "")
        raw = subj.get("raw")
        assigned = subj.get("assigned")
        confidence = subj.get("confidence", "B")

        if name in ("语文", "数学", "英语"):
            if raw:
                sum_main_raw += float(raw)
            continue

        # 赋分直映
        if assigned:
            score = float(assigned)
            results.append({
                "subject": name, "score": score, "confidence": confidence,
                "method": "赋分直映法",
                "detail": f"{name}赋分{assigned}（{confidence}级）→ 等效高考{assigned}分",
            })
            sum_assigned += score
            continue

        # 无赋分：尝试跨次回退
        prev = _find_previous_subject_data(workspace, name, exam_name)
        if prev:
            n = prev.get("exams_skipped", 1)
            discount = round(0.85 ** n, 3)
            score = round(prev["score"] * discount, 1)
            discount_pct = f"{discount:.2f}"
            results.append({
                "subject": name, "score": score, "confidence": "C",
                "method": f"数据不足（回退至{prev['exam']}）",
                "detail": f"本次考试缺少{name}数据，回退至{prev['exam']}的数据（{prev['score']}分×{discount_pct}={score}分，C级）。建议补录后重新计算。",
            })
            sum_assigned += score
            continue

        # 无回退：尝试校内对照
        if name in school_data:
            sd = school_data[name]
            if "rank_scores" in sd and sd["rank_scores"]:
                avg_gaokao = sum(sd["rank_scores"].values()) / len(sd["rank_scores"])
                score = round(avg_gaokao, 1)
                results.append({
                    "subject": name, "score": score, "confidence": "C",
                    "method": "校内均值参照法",
                    "detail": f"{name}无赋分无排名→ 参照本校历届{name}均分约{avg_gaokao:.0f}分（C级，仅参考）",
                })
                sum_assigned += score
                continue

        # 完全无数据
        results.append({
            "subject": name, "score": None,
            "confidence": confidence if confidence in ("C", "D") else "D",
            "method": "数据不足",
            "detail": f"{name}无赋分无排名数据，无法计算等效分",
        })

    # ── Pass 2: 语数英 — 从剩余等效分中按比例分配 ──
    remaining = max(0, total_equivalent - sum_assigned)
    for subj in subjects_input:
        name = subj.get("name", "")
        raw = subj.get("raw")
        if name not in ("语文", "数学", "英语"):
            continue
        if raw and sum_main_raw > 0:
            ratio = float(raw) / sum_main_raw
            eq = round(remaining * ratio, 1)
            results.append({
                "subject": name, "score": eq, "confidence": "B",
                "method": "比例折算法",
                "detail": f"总等效{total_equivalent} - 选科贡献{sum_assigned} = {remaining:.1f}(剩余) -> {name}占语数英{ratio:.1%} -> 等效{eq}分",
            })
        else:
            results.append({
                "subject": name, "score": None, "confidence": "D",
                "method": "数据不足",
                "detail": f"{name}无原始分，无法计算等效分",
            })

    return results


def _find_previous_subject_data(workspace, subject_name, current_exam_name):
    """Fallback: find the most recent exam with valid data for a subject.

    Reads 成绩总表.xlsx and looks for previous exams that have
    usable data for the given subject.
    Returns dict with exam, score, field, exams_skipped or None.
    exams_skipped counts how many exam rows were skipped before finding data.
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

        exams_skipped = 0
        for row in rows:
            d = dict(zip(headers, row))
            exam_name = str(d.get("考试名", ""))
            # Skip current exam: fuzzy match on exam name
            if current_exam_name and (current_exam_name in exam_name or exam_name in current_exam_name):
                exams_skipped = 0  # reset counter after passing the current exam
                continue

            # Check if this exam has data for this subject
            if subject_name in ("语文", "数学", "英语"):
                score = d.get(subject_name)
                if score:
                    return {"exam": exam_name, "score": float(score), "field": subject_name, "exams_skipped": exams_skipped}
            else:
                for i in range(1, 4):
                    subj_name = str(d.get(f"选科{i}名称", ""))
                    if subj_name == subject_name:
                        assigned = d.get(f"选科{i}赋分")
                        if assigned:  # 优先赋分
                            return {"exam": exam_name, "score": float(assigned), "field": f"选科{i}赋分", "exams_skipped": exams_skipped}
                        raw = d.get(f"选科{i}原始分")
                        if raw:
                            return {"exam": exam_name, "score": float(raw), "field": f"选科{i}原始分", "exams_skipped": exams_skipped}
            exams_skipped += 1
    except Exception:
        return None
    return None


def compute_independent_subject_sum(data, macro):
    """Compute subject sum independently for fusion.

    Uses 分数线对照法 for 语数英 (independent of primary total method)
    and 赋分直映 for 选科. This produces an estimate that can diverge
    from the total methods, making weighted fusion meaningful.

    Returns dict {"sum": float, "confidences": [str]} or None.
    """
    subjects = data.get("subjects", [])
    total_score = float(data.get("total_score", 0))
    special_line_exam = data.get("special_line_exam") or data.get("special_line")

    if not subjects or not total_score:
        return None

    # 语数英: use 分数线对照法 (same formula as method_score_line)
    main_raw = 0.0
    for subj in subjects:
        name = subj.get("name", "")
        raw = subj.get("raw")
        if name in ("语文", "数学", "英语") and raw is not None:
            main_raw += float(raw)

    if main_raw <= 0:
        return None

    special_lines = macro.get("特控线", [])
    gaokao_sl = None
    latest_year = -1
    for sl in special_lines:
        if sl.get("特控线分数"):
            year = int(sl.get("年份", 0))
            if year > latest_year:
                latest_year = year
                gaokao_sl = float(sl["特控线分数"])

    if not gaokao_sl or not special_line_exam:
        return None

    sl_exam = float(special_line_exam)
    if sl_exam >= 750:
        return None

    # 分数线对照法 applied to total, then allocate 语数英 portion
    if total_score >= 750:
        total_via_sl = 750.0
    else:
        total_via_sl = (750 - gaokao_sl) / (750 - sl_exam) * (total_score - sl_exam) + gaokao_sl

    original_total = data.get("_original_total_score", total_score)
    main_ratio = main_raw / original_total if original_total else 0
    main_eq = main_ratio * total_via_sl

    # 选科: 赋分直映
    subject_sum = main_eq
    confidences = []
    # 语数英 via 分数线对照法 → A级 (3 subjects)
    for subj in subjects:
        name = subj.get("name", "")
        if name in ("语文", "数学", "英语") and subj.get("raw") is not None:
            confidences.append("A")

    for subj in subjects:
        name = subj.get("name", "")
        if name in ("语文", "数学", "英语"):
            continue
        assigned = subj.get("assigned")
        if assigned:
            subject_sum += float(assigned)
            confidences.append("B")

    if not confidences:
        return None

    subject_sum = round(subject_sum, 1)
    if subject_sum > 750:
        return None  # 超满分上限，不参与融合

    return {"sum": subject_sum, "confidences": confidences}


def run(data):
    workspace = os.path.abspath(data.get("workspace", "."))

    # 满分制换算：450分制 → 750分制
    score_scale = data.get("score_scale", 750)
    original_total_score = float(data["total_score"])  # 保存原始制总分，供单科比例计算使用
    if score_scale == 450:
        data = dict(data)
        data["_original_total_score"] = original_total_score
        data["total_score"] = original_total_score * 750 / 450
        if data.get("special_line_exam") or data.get("special_line"):
            sl = data.get("special_line_exam") or data.get("special_line")
            data["special_line_exam"] = float(sl) * 750 / 450

    macro = read_macro_data(workspace)

    if macro is None:
        return {
            "status": "error",
            "reason": "宏观数据_只读.xlsx 不存在，请先完成初始设置",
        }

    methods = []

    # Try methods in priority order: two_module → score_line → school_lookup → percentile → school_estimate
    result = method_two_module(data, macro)
    if result:
        methods.append(result)

    result = method_score_line(data, macro)
    if result:
        methods.append(result)

    result = method_school_threshold(data, macro)
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

    # calculation_detail: primary method as base, fusion appended later if applicable
    calculation_detail = primary.get("detail", "")
    if len(methods) >= 2:
        cv_names = "、".join(m["method"] for m in methods[1:])
        calculation_detail += f"（交叉验证：{cv_names}）"
    calculation_detail = f"[主方法] {calculation_detail}"

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

    # ── 单科等效分（展示用，从总分比例分配，保证各科之和=总分）──
    data["_total_equivalent"] = equivalent_score
    subject_scores = compute_subject_equivalents(data, macro)

    # ── 多方法加权融合 ──
    # 融合公式：所有可用方法 + 单科加总按置信度权重加权平均
    # 单科加总独立计算（语数英用分数线对照法，选科赋分直映），
    # 不与总分法恒等，确保融合产生有意义的交叉校验
    # 单科加总衰减因子 0.5，降低其在融合中的比重
    independent_subj = compute_independent_subject_sum(data, macro)

    components = []  # [(score, weight, label), ...]
    for m in methods:
        w = weights_map.get(m["confidence"], 0)
        if w > 0:
            components.append((m["score"], w, m["method"]))

    if independent_subj:
        subj_confs = independent_subj["confidences"]
        subj_weights = [weights_map.get(c, 0) for c in subj_confs]
        w_subject = (sum(subj_weights) / len(subj_weights) * 0.5) if subj_weights else 0
        if w_subject > 0:
            components.append((independent_subj["sum"], w_subject, "单科加总"))

    if len(components) >= 2:
        weighted_sum = sum(s * w for s, w, _ in components)
        total_weight = sum(w for _, w, _ in components)
        fused = round(weighted_sum / total_weight, 1)

        parts = [f"{label}{score}分(w={w:.2f})" for score, w, label in components]
        calculation_detail += f" | [融合] {' + '.join(parts)} → {fused}分"

        equivalent_score = fused
        # 用融合后的总分重算各科等效分，保证各科加总=总分
        data["_total_equivalent"] = equivalent_score
        subject_scores = compute_subject_equivalents(data, macro)
        # 误差区间基于融合分 ± 最大方法间偏差
        all_scores = [s for s, _, _ in components]
        max_dev = max(abs(fused - s) for s in all_scores)
        error_lower = round(fused - max(margin, max_dev + 3), 1)
        error_upper = round(fused + max(margin, max_dev + 3), 1)

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
