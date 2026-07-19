"""Test generate_reports.py — report generation."""

import json
import os
import sys
import tempfile

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
from generate_reports import load_data, compute_trend, compute_volatility, prediction_state, eval_labels


def test_compute_trend_up():
    trend_class, arrow, text = compute_trend([600, 620, 640, 660])
    assert trend_class == "up"
    assert arrow == "↑"


def test_compute_trend_down():
    trend_class, arrow, text = compute_trend([660, 640, 620, 600])
    assert trend_class == "down"
    assert arrow == "↓"


def test_compute_trend_flat():
    trend_class, arrow, text = compute_trend([650, 652, 648, 651])
    assert trend_class == "flat"
    assert arrow == "→"


def test_compute_trend_insufficient():
    trend_class, arrow, text = compute_trend([650])
    assert trend_class == "flat"
    assert text == "数据不足"


def test_compute_volatility():
    scores = [640, 660, 650, 670, 655, 665]
    sigma, lower, upper = compute_volatility(scores)
    assert sigma is not None
    assert sigma > 0
    assert lower < upper
    assert lower < upper


def test_compute_volatility_insufficient():
    sigma, lower, upper = compute_volatility([650, 660, 655])
    assert sigma is None


def test_prediction_state():
    scores = [640, 650, 660, 670, 680]
    state = prediction_state(scores)
    assert state in ("积极", "正常", "消极")


def test_eval_labels():
    scores = [640, 650, 660, 655, 670, 665, 680, 690]
    labels, sequence = eval_labels(scores)
    assert labels is not None
    assert sequence is not None
    assert labels["积极"] + labels["正常"] + labels["消极"] == len(scores) - 3
    assert len(sequence) == len(scores) - 3


def test_load_data_empty(tmpdir):
    """Test loading data from empty workspace."""
    # Setup minimal workspace
    from setup_workspace import run as setup_ws
    ws = str(tmpdir)
    setup_ws(ws)
    data = load_data(ws)
    assert data["exams"] == []
    assert data["equivalent"] == []
    assert len(data["subjects"]) == 6  # 6 empty subject sheets


def test_generate_reports_empty_workspace(tmpdir):
    """Test that generate_reports runs without error on empty workspace."""
    from setup_workspace import run as setup_ws
    from generate_reports import run as gen_reports

    ws = str(tmpdir)
    setup_ws(ws)
    result = gen_reports(ws)
    assert result["status"] == "ok"
    # 8 files should be generated (even if some are empty)
    assert len(result["files"]) == 8


def test_generate_reports_with_data(tmpdir):
    """Test full pipeline: setup -> record -> calc -> generate."""
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
    from setup_workspace import main as setup_main
    from record_exam import run as record_exam
    from generate_reports import run as gen_reports

    # Setup
    sys.argv = ["setup_workspace.py", "--workspace", str(tmpdir)]
    # Can't easily test main() due to argparse, so use run() directly
    ws = str(tmpdir)
    from setup_workspace import run as setup_run
    setup_run(ws)

    # Add macro data manually for testing
    from openpyxl import Workbook
    macro_path = os.path.join(ws, "data", "macro", "宏观数据_只读.xlsx")
    wb = Workbook()
    ws1 = wb.active
    ws1.title = "一分一段表"
    ws1.append(["分数", "累计人数", "省份", "年份"])
    for i, score in enumerate(range(750, 299, -10)):
        ws1.append([score, (i + 1) * 100, "浙江", 2026])
    ws2 = wb.create_sheet("特控线")
    ws2.append(["年份", "省份", "特控线分数"])
    ws2.append([2026, "浙江", 592])
    wb.save(macro_path)

    # Record an exam
    record_exam({
        "workspace": ws,
        "exam_name": "期末",
        "exam_date": "2026-01",
        "exam_type": "全市统考",
        "grade": "高一",
        "total_score": 650,
        "cn_score": 118, "math_score": 135, "en_score": 128,
        "sub1_name": "物理", "sub1_raw": 78, "sub1_assigned": 91, "sub1_confidence": "A",
        "sub2_name": "化学", "sub2_raw": 82, "sub2_assigned": 88, "sub2_confidence": "A",
        "sub3_name": "生物", "sub3_raw": 85, "sub3_assigned": 90, "sub3_confidence": "A",
        "alliance_rank": 3200, "alliance_total": 21000,
        "special_line": 546.5,
    })

    # Generate reports
    result = gen_reports(ws)
    assert result["status"] == "ok"
    assert len(result["files"]) == 8

    # Verify each file exists and has content
    for f in result["files"]:
        assert os.path.exists(f), f"Missing: {f}"
        size = os.path.getsize(f)
        assert size > 100, f"File too small: {f} ({size} bytes)"
