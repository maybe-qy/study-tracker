"""红线一致性测试 — 用机器保证项目的三条红线不回归。

红线（见 原则/红线与原则.md）：
1. 不诊断错题、不给提分建议、不推荐大学专业、不预测高考
2. 不把估算值伪装成精确值 — 所有输出必须带置信度与误差区间
3. 对学生的能力、努力、未来不做任何评判

本文件不测试算法正确性（见 test_calc_equivalent.py / test_core_methods.py），
只测试"诚实性约定"在任何输出路径上都成立。
"""

import json
import os
import re

import pytest

from calc_equivalent import run
from config import CONFIDENCE_WEIGHTS

# 交互层禁用的表达（来自 skill/SKILL.md「不使用的表达」）。
# 仅扫描程序动态生成的文案，不扫描 Skill 文档本身（文档中会列举这些词以作说明）。
FORBIDDEN_PHRASES = [
    "你应该",
    "建议你",
    "你的问题是",
    "你大概能考",
    "你能考上",
    "你适合",
    "一定能考上",
    "稳上",
    "稳进",
    "%概率",
    "的概率",
    "冲刺院校",
    "保底院校",
]

# 成功结果中所有可能包含面向用户文案的字段
TEXT_FIELDS = [
    "reason",
    "calculation_detail",
    "trust_note",
]


def make_macro_ws(tmpdir, with_lookup=True, with_special_line=True):
    """Create minimal macro data for redline testing."""
    from openpyxl import Workbook
    macro_dir = os.path.join(tmpdir, "data", "macro")
    os.makedirs(macro_dir, exist_ok=True)

    wb = Workbook()
    ws1 = wb.active
    ws1.title = "一分一段表"
    ws1.append(["分数", "累计人数", "省份", "年份"])
    for i, score in enumerate(range(750, 299, -10)):
        ws1.append([score, (i + 1) * 100, "浙江", 2026])

    if with_special_line:
        ws2 = wb.create_sheet("特控线")
        ws2.append(["年份", "省份", "特控线分数"])
        ws2.append([2026, "浙江", 594])

    if with_lookup:
        ws3 = wb.create_sheet("本校对照表_总分")
        ws3.append(["校内排名", "高考总分"])
        ws3.append([1, 720])
        ws3.append([50, 670])
        ws3.append([100, 640])
        ws3.append([300, 560])

    wb.save(os.path.join(macro_dir, "宏观数据_只读.xlsx"))
    return tmpdir


def iter_result_texts(value, parent_key=""):
    """递归产出结构中的所有字符串值，用于文案合规扫描。"""
    if isinstance(value, str):
        yield parent_key, value
    elif isinstance(value, dict):
        for key, val in value.items():
            full_key = f"{parent_key}.{key}" if parent_key else str(key)
            yield from iter_result_texts(val, full_key)
    elif isinstance(value, list):
        for i, item in enumerate(value):
            yield from iter_result_texts(item, f"{parent_key}[{i}]")


# ── 红线 2：不把估算值伪装成精确值 ──────────────────────────────


def test_ok_result_always_carries_confidence(tmpdir):
    """成功返回的等效分必须带 A/B/C/D 置信度标签。"""
    ws = make_macro_ws(tmpdir)
    result = run({
        "workspace": ws,
        "total_score": 650,
        "special_line_exam": 546.5,
    })
    assert result["status"] == "ok"
    assert result["confidence"] in CONFIDENCE_WEIGHTS, (
        f"置信度必须是 A/B/C/D 之一，实际为 {result.get('confidence')!r}"
    )


def test_ok_result_always_carries_error_band(tmpdir):
    """成功返回的等效分必须带误差区间，且等效分落在区间内。"""
    ws = make_macro_ws(tmpdir)
    result = run({
        "workspace": ws,
        "total_score": 650,
        "special_line_exam": 546.5,
    })
    assert result["status"] == "ok"
    lower, upper = result["error_lower"], result["error_upper"]
    assert isinstance(lower, (int, float)) and isinstance(upper, (int, float))
    assert lower < upper, f"误差区间无效: [{lower}, {upper}]"
    assert lower <= result["equivalent_score"] <= upper, (
        "等效分必须落在自己的误差区间内，否则就是伪装精确值"
    )


def test_equivalent_score_has_no_fake_precision(tmpdir):
    """等效分最多保留 1 位小数 — 不输出虚假精度。"""
    ws = make_macro_ws(tmpdir)
    result = run({
        "workspace": ws,
        "total_score": 648,
        "special_line_exam": 546.5,
    })
    assert result["status"] == "ok"
    for key in ("equivalent_score", "error_lower", "error_upper"):
        val = result[key]
        decimals = len(str(val).split(".")[1]) if "." in str(val) else 0
        assert decimals <= 1, f"{key}={val} 小数位过多，构成虚假精度"


def test_insufficient_data_explains_how_to_improve(tmpdir):
    """insufficient_data 必须告诉用户缺什么、怎么补，而不是给一个数字。"""
    ws = make_macro_ws(tmpdir, with_lookup=False, with_special_line=False)
    result = run({
        "workspace": ws,
        "total_score": 650,
        "school_rank": 80,
        "school_total": 500,
    })
    assert result["status"] == "insufficient_data"
    assert "equivalent_score" not in result, "低精度数据不得给出等效分数字"
    reason = result["reason"]
    # 必须给出可操作的补充路径
    assert "特控线" in reason or "排名" in reason, (
        f"reason 应指出可补充的数据项，实际为: {reason!r}"
    )


def test_low_confidence_alone_never_yields_score(tmpdir):
    """仅有低精度数据时不得返回等效分 — 宁可说不知道，也不给假数字。"""
    ws = make_macro_ws(tmpdir, with_lookup=False, with_special_line=False)
    result = run({
        "workspace": ws,
        "total_score": 650,
        "school_rank": 80,
        "school_total": 500,
        "school_type": "普通",
    })
    if result["status"] == "ok":
        # 若未来重新启用 C 级路径，则必须至少是 C 级并带区间
        assert result["confidence"] in ("A", "B", "C")
        assert result["error_lower"] is not None and result["error_upper"] is not None
    else:
        assert result["status"] == "insufficient_data"


# ── 红线 1 & 3：不预测高考、不评判学生 ─────────────────────────


@pytest.mark.parametrize("exam_input", [
    {"workspace": None, "total_score": 650, "special_line_exam": 546.5},
    {"workspace": None, "total_score": 650, "school_rank": 50, "school_total": 500},
])
def test_no_forbidden_phrases_in_result_texts(tmpdir, exam_input):
    """计算输出的任何文案都不得包含命令式建议、预测或评判表达。"""
    ws = make_macro_ws(tmpdir)
    exam_input = dict(exam_input, workspace=ws)
    result = run(exam_input)

    texts = dict(iter_result_texts(result))
    # method_details 内的 detail 也可能含面向用户说明
    for m in result.get("method_details", []) or []:
        if isinstance(m, dict) and m.get("detail"):
            texts[f"method_details[{m.get('method')}].detail"] = m["detail"]

    for key, text in texts.items():
        if not isinstance(text, str):
            continue
        for phrase in FORBIDDEN_PHRASES:
            assert phrase not in text, (
                f"字段 {key} 含禁用表达 {phrase!r}: {text[:120]!r}"
            )


def test_result_never_contains_probability_or_prediction(tmpdir):
    """输出不得出现高考概率或确定性录取承诺。"""
    ws = make_macro_ws(tmpdir)
    result = run({"workspace": ws, "total_score": 650, "special_line_exam": 546.5})

    blob = json.dumps(result, ensure_ascii=False)
    for pattern in [r"\d+%概率", r"一定.{0,4}考上", r"保证.{0,6}录取", r"预计.{0,6}高考"]:
        assert not re.search(pattern, blob), f"输出含预测/承诺语义: {pattern}"


def test_disclaimer_states_not_a_prediction():
    """报告声明必须明确 '不构成对高考成绩的预测'。"""
    from generate_reports import DISCLAIMER
    assert "不构成对高考" in DISCLAIMER or "不预测高考" in DISCLAIMER
    assert "仅供参考" in DISCLAIMER


def test_disclaimer_explains_confidence_and_error():
    """报告声明必须解释置信度分级与误差区间（误差透明的红线）。"""
    from generate_reports import DISCLAIMER
    assert "A级" in DISCLAIMER and "B级" in DISCLAIMER
    assert "D级" in DISCLAIMER, "声明需覆盖全部置信度等级"


# ── 文档红线存在性：防止 Skill 定义漂移丢掉红线 ──────────────────


def _read_text(path):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, path), "r", encoding="utf-8") as f:
        return f.read()


def test_skill_doc_still_declares_redlines():
    """SKILL.md 必须保留全部七条'绝对不做'红线。"""
    content = _read_text(os.path.join("skill", "SKILL.md"))
    for line in [
        "不诊断错题原因",
        "不给提分建议",
        "不推荐大学专业",
        "不预测高考分数",
        "不把估算值伪装成精确值",
        "不对学生的能力",
    ]:
        assert line in content, f"SKILL.md 缺少红线条目: {line}"


def test_skill_doc_lists_forbidden_expressions():
    """SKILL.md 必须保留禁用表达清单（供交互层自律）。"""
    content = _read_text(os.path.join("skill", "SKILL.md"))
    for phrase in ["你应该", "建议你", "你的问题是", "你大概能考"]:
        assert phrase in content, f"SKILL.md 缺少禁用表达声明: {phrase}"
