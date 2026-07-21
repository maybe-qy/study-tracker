#!/usr/bin/env python3
"""Save equivalent score calculation results to 等效分记录.xlsx.

Usage:
  python calc_equivalent.py < exam_data.json | python save_equivalent.py --workspace <path>

  Or combined:
  echo '{"workspace":".", "exam_name":"...", ...}' | python calc_equivalent.py | \
    python save_equivalent.py --workspace . --exam-name "..." --exam-date "..." --target "..." --target-line 652

Input JSON fields:
  workspace, exam_name, exam_date — required
  target_university, target_line — optional
  Plus the calc_equivalent output via stdin.
"""

import argparse
import json
import os
import sys
from openpyxl import load_workbook


def run(workspace, exam_name, exam_date, calc_result, target_university=None, target_line=None):
    path = os.path.join(workspace, "data", "personal", "等效分记录.xlsx")
    if not os.path.exists(path):
        return {"status": "error", "reason": f"等效分记录.xlsx 不存在"}

    wb = load_workbook(path)
    ws = wb["等效分记录"]

    # Build cross-validation columns
    cv_method1 = ""
    cv_score1 = ""
    cv_method2 = ""
    cv_score2 = ""
    cross = calc_result.get("cross_validations", [])
    if len(cross) > 0:
        cv_method1 = cross[0].get("method", "")
        cv_score1 = cross[0].get("score", "")
    if len(cross) > 1:
        cv_method2 = cross[1].get("method", "")
        cv_score2 = cross[1].get("score", "")

    gap = None
    if target_line and calc_result.get("equivalent_score"):
        gap = round(calc_result["equivalent_score"] - float(target_line), 1)

    import json as _json

    extra_info = _json.dumps({
        "subject_scores": calc_result.get("subject_scores", []),
        "warnings": calc_result.get("warnings", []),
        "trust_note": calc_result.get("trust_note"),
        "divergence": calc_result.get("divergence"),
        "calculation_detail": calc_result.get("calculation_detail", ""),
    }, ensure_ascii=False)

    ws.append([
        exam_name,
        exam_date,
        calc_result.get("equivalent_score", ""),
        calc_result.get("confidence", ""),
        calc_result.get("primary_method", ""),
        cv_method1, cv_score1,
        cv_method2, cv_score2,
        calc_result.get("error_lower", ""),
        calc_result.get("error_upper", ""),
        target_university or "",
        target_line or "",
        gap or "",
        extra_info,
    ])

    wb.save(path)
    return {
        "status": "ok",
        "row": ws.max_row,
        "score": calc_result.get("equivalent_score"),
        "confidence": calc_result.get("confidence"),
        "method": calc_result.get("primary_method"),
    }


def main():
    parser = argparse.ArgumentParser(description="Save equivalent score to Excel")
    parser.add_argument("--workspace", required=True, help="Workspace root path")
    parser.add_argument("--exam-name", required=True)
    parser.add_argument("--exam-date", required=True)
    parser.add_argument("--target", default=None, help="Target university name")
    parser.add_argument("--target-line", default=None, type=float, help="Target university admission score")
    args = parser.parse_args()

    calc_result = json.loads(sys.stdin.read())
    if calc_result.get("status") not in ("ok",):
        print(json.dumps({"status": "skipped", "reason": calc_result.get("reason", "unknown")}, ensure_ascii=False))
        sys.exit(0)

    result = run(
        os.path.abspath(args.workspace),
        args.exam_name, args.exam_date,
        calc_result,
        args.target,
        args.target_line,
    )
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
