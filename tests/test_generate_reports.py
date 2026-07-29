"""Test generate_reports.py — report generation."""

import json
import os
import sys
import tempfile

import pytest

from generate_reports import (
    load_data, compute_trend, compute_volatility, prediction_state, eval_labels,
    ewma, classify_volatility_style, parse_eq_detail, filter_weighted,
    compute_volatility_weighted,
)


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


def test_compute_volatility_insufficient():
    sigma, lower, upper = compute_volatility([650, 660, 655])
    assert sigma is None


def test_prediction_state():
    scores = [640, 650, 660, 670, 680]
    state = prediction_state(scores)
    assert state == "积极"  # 递增序列应判定为积极


def test_prediction_state_negative():
    scores = [680, 670, 660, 650, 640]
    state = prediction_state(scores)
    assert state == "消极"  # 递减序列应判定为消极


def test_eval_labels():
    scores = [640, 650, 660, 655, 670, 665, 680, 690]
    labels, sequence = eval_labels(scores)
    assert labels is not None
    assert sequence is not None
    assert labels["积极"] + labels["正常"] + labels["消极"] == len(scores) - 3
    assert len(sequence) == len(scores) - 3


# ── ewma 单元测试 ──

def test_ewma_basic():
    """EWMA: 越近的数据权重越高"""
    result = ewma([600, 620, 640], alpha=0.3)
    # result = 0.3*640 + 0.7*(0.3*620 + 0.7*600) = 0.3*640 + 0.7*(186+420) = 192+424.2 = 616.2
    assert abs(result - 616.2) < 0.1


def test_ewma_empty():
    assert ewma([]) == 0


def test_ewma_single():
    assert ewma([650]) == 650


def test_ewma_alpha_1():
    """alpha=1 时 EWMA = 最后一个值"""
    assert ewma([600, 620, 640, 660], alpha=1.0) == 660


# ── classify_volatility_style 单元测试 ──

def test_classify_volatility_stable():
    """连续正常标签 → 稳定"""
    labels = {"积极": 0, "正常": 5, "消极": 0}
    sequence = ["正常", "正常", "正常", "正常", "正常"]
    result = classify_volatility_style(labels, 5.0, sequence)
    assert result == "分数相对稳定"


def test_classify_volatility_trend():
    """连续3+个积极 → 持续变化趋势"""
    labels = {"积极": 4, "正常": 1, "消极": 0}
    sequence = ["正常", "积极", "积极", "积极", "积极"]
    result = classify_volatility_style(labels, 8.0, sequence)
    assert result == "呈持续变化趋势"


def test_classify_volatility_fluctuating():
    """积极和消极交替 → 波动较大"""
    labels = {"积极": 3, "正常": 0, "消极": 2}
    sequence = ["积极", "消极", "积极", "消极", "积极"]
    result = classify_volatility_style(labels, 10.0, sequence)
    assert result == "分数波动较大"


def test_classify_volatility_normal_not_trend():
    """连续3+个'正常'不应被判为持续变化趋势（回归测试）"""
    labels = {"积极": 0, "正常": 4, "消极": 0}
    sequence = ["正常", "正常", "正常", "正常"]
    result = classify_volatility_style(labels, 3.0, sequence)
    assert result != "呈持续变化趋势"  # 稳定不应被判为趋势


# ── parse_eq_detail 单元测试 ──

def test_parse_eq_detail_valid():
    detail = json.dumps({
        "calculation_detail": "测试详情",
        "subject_scores": [{"subject": "语文", "score": 120}],
    })
    result = parse_eq_detail(detail)
    assert result is not None
    assert result["calculation_detail"] == "测试详情"
    assert len(result["subject_scores"]) == 1


def test_parse_eq_detail_list_detail():
    """calculation_detail 为 list 时应转为 | 分隔字符串"""
    detail = json.dumps({
        "calculation_detail": ["步骤1", "步骤2"],
        "subject_scores": [],
    })
    result = parse_eq_detail(detail)
    assert result is not None
    assert result["calculation_detail"] == "步骤1|步骤2"


def test_parse_eq_detail_empty():
    assert parse_eq_detail("") is None
    assert parse_eq_detail(None) is None


def test_parse_eq_detail_invalid_json():
    assert parse_eq_detail("not json") is None


def test_parse_eq_detail_dict_subject_scores():
    """subject_scores 为 dict 时应转为 list-of-dict"""
    detail = json.dumps({
        "calculation_detail": "test",
        "subject_scores": {"语文": 120, "数学": 130},
    })
    result = parse_eq_detail(detail)
    assert result is not None
    assert len(result["subject_scores"]) == 2


# ── filter_weighted 单元测试 ──

def test_filter_weighted_excludes_d_level():
    records = [
        {"等效分（融合结果）": 650, "置信度": "A"},
        {"等效分（融合结果）": 640, "置信度": "D"},
    ]
    weighted = filter_weighted(records)
    assert len(weighted) == 1  # D级被排除
    assert weighted[0][0] == 650


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
    ws2.append([2026, "浙江", 594])
    wb.save(macro_path)

    # Record an exam
    record_exam({
        "workspace": ws,
        "exam_name": "期末",
        "exam_date": "2026-01",
        "exam_type": "统考",
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
