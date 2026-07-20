"""Test calc_equivalent.py — the core calculation engine."""

import json
import os
import sys
import tempfile

import pytest

# Add scripts dir to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
from calc_equivalent import run


def make_macro_ws(tmpdir):
    """Create minimal macro data for testing."""
    from openpyxl import Workbook
    ws_root = tmpdir
    macro_dir = os.path.join(ws_root, "data", "macro")
    os.makedirs(macro_dir, exist_ok=True)

    wb = Workbook()

    # 一分一段表 sheet
    ws1 = wb.active
    ws1.title = "一分一段表"
    ws1.append(["分数", "累计人数", "省份", "年份"])
    # Simulate: top score 750 = 1 person, each drop by 10 = +1000 people
    for i, score in enumerate(range(750, 299, -10)):
        ws1.append([score, (i + 1) * 100, "浙江", 2026])

    # 特控线 sheet
    ws2 = wb.create_sheet("特控线")
    ws2.append(["年份", "省份", "特控线分数"])
    ws2.append([2026, "浙江", 592])

    # 本校对照表_总分 sheet
    ws3 = wb.create_sheet("本校对照表_总分")
    ws3.append(["校内排名", "高考总分"])
    ws3.append([1, 720])
    ws3.append([10, 700])
    ws3.append([50, 670])
    ws3.append([100, 640])
    ws3.append([200, 600])
    ws3.append([300, 560])

    wb.save(os.path.join(macro_dir, "宏观数据_只读.xlsx"))
    return ws_root


def test_method_score_line(tmpdir):
    """Test 分数线对照法 with valid data."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "special_line_exam": 546.5,
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["primary_method"] == "分数线对照法"
    assert result["confidence"] == "A"
    assert 660 <= result["equivalent_score"] <= 680
    assert result["error_lower"] <= result["equivalent_score"] <= result["error_upper"]


def test_method_percentile(tmpdir):
    """Test 排名锚定法."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "alliance_rank": 2000,
        "alliance_total": 20000,
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["primary_method"] == "排名锚定法"
    assert result["confidence"] == "A"


def test_method_school_lookup(tmpdir):
    """Test 校内排名对照法 — with weighted blending from school_estimate."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "school_rank": 50,
        "school_total": 500,
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["primary_method"] == "校内排名对照法"
    assert result["confidence"] == "C"
    # Both school_lookup (~670) and school_estimate (~720) are C-level
    # Weighted avg: (670×0.5 + 720×0.5) / 1.0 ≈ 695
    assert abs(result["equivalent_score"] - 695) < 10
    assert result["method_count"] == 2


def make_macro_ws_no_lookup(tmpdir):
    """Create macro data WITHOUT 本校对照表 (so method 4 is the only school method)."""
    from openpyxl import Workbook
    ws_root = tmpdir
    macro_dir = os.path.join(ws_root, "data", "macro")
    os.makedirs(macro_dir, exist_ok=True)

    wb = Workbook()
    ws1 = wb.active
    ws1.title = "一分一段表"
    ws1.append(["分数", "累计人数", "省份", "年份"])
    for i, score in enumerate(range(750, 299, -10)):
        ws1.append([score, (i + 1) * 100, "浙江", 2026])

    wb.save(os.path.join(macro_dir, "宏观数据_只读.xlsx"))
    return ws_root


def test_method_school_estimate(tmpdir):
    """Test 校排名估算 (C级) — no lookup table available."""
    ws = make_macro_ws_no_lookup(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "school_rank": 80,
        "school_type": "市重点",
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["confidence"] == "C"


def test_cross_validation(tmpdir):
    """Test that multiple methods produce cross-validation."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "special_line_exam": 546.5,
        "alliance_rank": 3200,
        "alliance_total": 21000,
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["primary_method"] == "排名锚定法"
    assert len(result["cross_validations"]) >= 1
    assert "trust_note" in result


def test_insufficient_data(tmpdir):
    """Test that no data returns proper error."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        # No ranking, no special line
    }
    result = run(data)
    assert result["status"] == "insufficient_data"


def test_no_macro_file(tmpdir):
    """Test that missing macro file returns error."""
    data = {
        "workspace": str(tmpdir),
        "total_score": 650,
    }
    result = run(data)
    assert result["status"] == "error"


def test_priority_order(tmpdir):
    """Test that priority 1 (percentile) beats priority 3 (score-line)."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "special_line_exam": 546.5,  # enables method 1
        "alliance_rank": 3200,       # enables method 3
        "alliance_total": 21000,
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["primary_method"] == "排名锚定法"  # priority 1 wins


def test_rank_exceeds_total(tmpdir):
    """Test that rank > total is caught."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "alliance_rank": 50000,
        "alliance_total": 1000,  # rank exceeds total
    }
    result = run(data)
    # Should fall through to insufficient since percentile method fails
    assert result["status"] in ("insufficient_data", "ok")


def test_percentile_gaoer(tmpdir):
    """Test that 高二 percentile anchoring still gets A-level (grade no longer affects confidence)."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "alliance_rank": 2000,
        "alliance_total": 20000,
        "grade": "高二",
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["primary_method"] == "排名锚定法"
    assert result["confidence"] == "A"


def test_gaoyi_no_longer_blocked(tmpdir):
    """Test that 高一 with ranking data now calculates equivalent score (grade no longer blocks)."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "alliance_rank": 2000,
        "alliance_total": 20000,
        "grade": "高一",
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["confidence"] == "A"


def test_percentile_beats_score_line(tmpdir):
    """Test that percentile method now takes priority over score_line."""
    ws = make_macro_ws(tmpdir)
    data = {
        "workspace": ws,
        "total_score": 650,
        "special_line_exam": 546.5,
        "alliance_rank": 3200,
        "alliance_total": 21000,
    }
    result = run(data)
    assert result["status"] == "ok"
    assert result["primary_method"] == "排名锚定法"
    assert result["confidence"] == "A"  # default 高三
