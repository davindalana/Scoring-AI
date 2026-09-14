import pytest
from utils.scoring import (
    parse_arrow_score,
    calculate_end_score,
    calculate_session_score,
)


def test_parse_valid_scores():
    # X scores
    assert parse_arrow_score("X") == (10, True)
    assert parse_arrow_score("10X") == (10, True)
    assert parse_arrow_score("x") == (10, True)

    # Miss score
    assert parse_arrow_score("M") == (0, False)
    assert parse_arrow_score("m") == (0, False)

    # Numeric 10
    assert parse_arrow_score("10") == (10, False)
    assert parse_arrow_score(10) == (10, False)
    assert parse_arrow_score(10, is_x=True) == (10, True)

    # Regular scores 1-9
    for val in range(1, 10):
        assert parse_arrow_score(str(val)) == (val, False)
        assert parse_arrow_score(val) == (val, False)


def test_parse_invalid_scores():
    with pytest.raises(ValueError):
        parse_arrow_score("11")

    with pytest.raises(ValueError):
        parse_arrow_score("-1")

    with pytest.raises(ValueError):
        parse_arrow_score("Invalid")

    with pytest.raises(ValueError):
        parse_arrow_score(None)


def test_spec_example_end_calculation():
    # Example 1 from Section 15: 10X, 10, 9, 8, 7, M -> Total = 44, X = 1
    arrows = [
        {"arrow_number": 1, "score": "10X", "is_x": True},
        {"arrow_number": 2, "score": "10", "is_x": False},
        {"arrow_number": 3, "score": "9", "is_x": False},
        {"arrow_number": 4, "score": "8", "is_x": False},
        {"arrow_number": 5, "score": "7", "is_x": False},
        {"arrow_number": 6, "score": "M", "is_x": False},
    ]
    result = calculate_end_score(arrows)
    assert result["total_score"] == 44
    assert result["x_count"] == 1
    assert result["arrow_count"] == 6
    assert result["average_score"] == round(44 / 6, 2)


def test_spec_example_section_4():
    # Example from Section 4: 10, 10X, 9, 9, 8, 7 -> End score = 53, X count = 1, Average = 8.83
    arrows = [
        {"arrow_number": 1, "score": 10, "is_x": False},
        {"arrow_number": 2, "score": 10, "is_x": True},
        {"arrow_number": 3, "score": 9, "is_x": False},
        {"arrow_number": 4, "score": 9, "is_x": False},
        {"arrow_number": 5, "score": 8, "is_x": False},
        {"arrow_number": 6, "score": 7, "is_x": False},
    ]
    result = calculate_end_score(arrows)
    assert result["total_score"] == 53
    assert result["x_count"] == 1
    assert result["arrow_count"] == 6
    assert result["average_score"] == 8.83


def test_all_x_end():
    arrows = [{"arrow_number": i, "score": "X"} for i in range(1, 7)]
    result = calculate_end_score(arrows)
    assert result["total_score"] == 60
    assert result["x_count"] == 6
    assert result["average_score"] == 10.0


def test_all_m_end():
    arrows = [{"arrow_number": i, "score": "M"} for i in range(1, 4)]
    result = calculate_end_score(arrows)
    assert result["total_score"] == 0
    assert result["x_count"] == 0
    assert result["average_score"] == 0.0


def test_session_score_calculation():
    ends = [
        {
            "end_number": 1,
            "total_score": 53,
            "x_count": 1,
            "arrow_count": 6,
        },
        {
            "end_number": 2,
            "total_score": 58,
            "x_count": 3,
            "arrow_count": 6,
        },
        {
            "end_number": 3,
            "total_score": 45,
            "x_count": 0,
            "arrow_count": 6,
        },
    ]
    summary = calculate_session_score(ends)

    assert summary["total_score"] == 53 + 58 + 45  # 156
    assert summary["total_x"] == 1 + 3 + 0  # 4
    assert summary["total_arrows"] == 18
    assert summary["total_ends"] == 3
    assert summary["average_score_per_arrow"] == round(156 / 18, 2)  # 8.67
    assert summary["average_score_per_end"] == round(156 / 3, 2)  # 52.0
    assert summary["highest_scoring_end"] == {"end_number": 2, "score": 58}
    assert summary["lowest_scoring_end"] == {"end_number": 3, "score": 45}
    assert len(summary["ends_summary"]) == 3
    assert summary["ends_summary"][0]["cumulative_score"] == 53
    assert summary["ends_summary"][1]["cumulative_score"] == 111
    assert summary["ends_summary"][2]["cumulative_score"] == 156
