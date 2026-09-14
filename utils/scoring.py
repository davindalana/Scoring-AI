from typing import Union, Tuple, List, Dict, Any

VALID_STRING_SCORES = {"X", "10X", "10", "9", "8", "7", "6", "5", "4", "3", "2", "1", "M"}


def parse_arrow_score(score_val: Union[str, int], is_x: bool = False) -> Tuple[int, bool]:
    """
    Parses an arrow score input and returns (numeric_score, is_x).
    Valid inputs:
      - 'X' or '10X': 10 points, is_x=True
      - 'M': 0 points, is_x=False
      - 0 to 10 (int or str): numeric points, is_x according to flag
    Raises ValueError on invalid score values.
    """
    if score_val is None:
        raise ValueError("Arrow score cannot be None")

    if isinstance(score_val, str):
        normalized = score_val.strip().upper()
        if normalized in ("X", "10X"):
            return 10, True
        if normalized == "M":
            return 0, False
        if normalized.isdigit():
            num = int(normalized)
            if 0 <= num <= 10:
                return num, (is_x or num == 10 and is_x)
            raise ValueError(f"Numeric score out of range (0-10): {num}")
        raise ValueError(f"Invalid score value: '{score_val}'. Allowed: X, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, M")

    if isinstance(score_val, (int, float)):
        num = int(score_val)
        if 0 <= num <= 10:
            return num, bool(is_x and num == 10)
        raise ValueError(f"Numeric score out of range (0-10): {num}")

    raise ValueError(f"Unsupported score type: {type(score_val)}")


def calculate_end_score(arrows: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Calculates statistics for a single end.
    Input arrows is a list of dicts with keys:
      'arrow_number', 'score' (or 'arrowScore'), 'is_x' (or 'isX')
    Returns:
      {
        'total_score': int,
        'x_count': int,
        'arrow_count': int,
        'average_score': float  # rounded to 2 decimal places
      }
    """
    total_score = 0
    x_count = 0

    if not arrows:
        return {
            "total_score": 0,
            "x_count": 0,
            "arrow_count": 0,
            "average_score": 0.0,
        }

    for arrow in arrows:
        raw_score = arrow.get("score", arrow.get("arrowScore", 0))
        raw_is_x = arrow.get("is_x", arrow.get("isX", False))
        num_score, is_x = parse_arrow_score(raw_score, raw_is_x)

        total_score += num_score
        if is_x:
            x_count += 1

    arrow_count = len(arrows)
    avg_score = round(total_score / arrow_count, 2) if arrow_count > 0 else 0.0

    return {
        "total_score": total_score,
        "x_count": x_count,
        "arrow_count": arrow_count,
        "average_score": avg_score,
    }


def calculate_session_score(ends: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Calculates cumulative session statistics from a list of completed ends.
    Each end dict contains 'end_number', 'total_score', 'x_count', 'arrows' (optional).
    Returns:
      {
        'total_score': int,
        'total_x': int,
        'total_arrows': int,
        'total_ends': int,
        'average_score_per_arrow': float,
        'average_score_per_end': float,
        'highest_scoring_end': {'end_number': int, 'score': int} or None,
        'lowest_scoring_end': {'end_number': int, 'score': int} or None,
        'ends_summary': list
      }
    """
    total_score = 0
    total_x = 0
    total_arrows = 0
    highest_end = None
    lowest_end = None
    ends_summary = []

    for end in ends:
        end_num = end.get("end_number", 0)
        end_score = end.get("total_score", 0)
        end_x = end.get("x_count", 0)
        arrow_count = len(end.get("arrows", [])) if "arrows" in end else end.get("arrow_count", 0)

        total_score += end_score
        total_x += end_x
        total_arrows += arrow_count

        if highest_end is None or end_score > highest_end["score"]:
            highest_end = {"end_number": end_num, "score": end_score}
        if lowest_end is None or end_score < lowest_end["score"]:
            lowest_end = {"end_number": end_num, "score": end_score}

        ends_summary.append({
            "end_number": end_num,
            "total_score": end_score,
            "x_count": end_x,
            "arrow_count": arrow_count,
            "cumulative_score": total_score,
        })

    end_count = len(ends)
    avg_per_arrow = round(total_score / total_arrows, 2) if total_arrows > 0 else 0.0
    avg_per_end = round(total_score / end_count, 2) if end_count > 0 else 0.0

    return {
        "total_score": total_score,
        "total_x": total_x,
        "total_arrows": total_arrows,
        "total_ends": end_count,
        "average_score_per_arrow": avg_per_arrow,
        "average_score_per_end": avg_per_end,
        "highest_scoring_end": highest_end,
        "lowest_scoring_end": lowest_end,
        "ends_summary": ends_summary,
    }
