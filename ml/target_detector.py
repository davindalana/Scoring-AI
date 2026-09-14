import math
import os
from typing import List, Dict, Any, Tuple, Optional
import cv2
import numpy as np


class ArcheryTargetDetector:
    """
    Separated Computer Vision pipeline for Archery Target and Arrow Detection.
    World Archery 10-ring target face ratios:
      - Ring 10 / X: innermost gold
      - Ring 9: outer gold
      - Ring 8, 7: red
      - Ring 6, 5: blue
      - Ring 4, 3: black
      - Ring 2, 1: white
      - Outside Ring 1: Miss (M)
    """

    def __init__(self, roboflow_api_key: Optional[str] = None):
        self.roboflow_api_key = roboflow_api_key

    def calculate_score_from_coordinates(
        self,
        arrow_coord: Tuple[float, float],
        target_center: Tuple[float, float],
        target_radius: float,
    ) -> Tuple[int, bool]:
        """
        Calculates arrow score and is_x flag based on Euclidean distance
        from arrow impact position to target center.
        """
        if target_radius <= 0:
            return 0, False

        dx = arrow_coord[0] - target_center[0]
        dy = arrow_coord[1] - target_center[1]
        distance = math.sqrt(dx * dx + dy * dy)
        ratio = distance / target_radius

        # Inner 10 / X ring is typically half of ring 10 (0.05 of full radius)
        if ratio <= 0.05:
            return 10, True
        elif ratio <= 0.10:
            return 10, False
        elif ratio <= 0.20:
            return 9, False
        elif ratio <= 0.30:
            return 8, False
        elif ratio <= 0.40:
            return 7, False
        elif ratio <= 0.50:
            return 6, False
        elif ratio <= 0.60:
            return 5, False
        elif ratio <= 0.70:
            return 4, False
        elif ratio <= 0.80:
            return 3, False
        elif ratio <= 0.90:
            return 2, False
        elif ratio <= 1.00:
            return 1, False
        else:
            return 0, False  # Miss

    def detect_target_center_and_radius(
        self, image: np.ndarray
    ) -> Tuple[Optional[Tuple[float, float]], Optional[float]]:
        """
        Detects circular target using Hough Circles and color-based yellow/gold center centroid.
        """
        h, w = image.shape[:2]
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (9, 9), 2)

        # 1. Try color thresholding to locate yellow bullseye center
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        lower_yellow = np.array([18, 80, 80])
        upper_yellow = np.array([35, 255, 255])
        mask_yellow = cv2.inRange(hsv, lower_yellow, upper_yellow)
        contours, _ = cv2.findContours(mask_yellow, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if contours:
            largest = max(contours, key=cv2.contourArea)
            if cv2.contourArea(largest) > 50:
                ((cx, cy), radius) = cv2.minEnclosingCircle(largest)
                # The yellow zone (10 and 9 rings) is roughly 20% of target radius
                estimated_target_radius = radius * 5.0
                return (float(cx), float(cy)), float(estimated_target_radius)

        # 2. Fallback to Hough Circles
        min_radius = int(min(h, w) * 0.15)
        max_radius = int(min(h, w) * 0.48)
        circles = cv2.HoughCircles(
            blurred,
            cv2.HOUGH_GRADIENT,
            dp=1.2,
            minDist=int(min(h, w) * 0.3),
            param1=100,
            param2=50,
            minRadius=min_radius,
            maxRadius=max_radius,
        )

        if circles is not None and len(circles) > 0:
            circles = np.round(circles[0, :]).astype("int")
            c = circles[0]
            return (float(c[0]), float(c[1])), float(c[2])

        # 3. Fallback to image center if no circle found
        return (float(w / 2), float(h / 2)), float(min(w, h) * 0.42)

    def detect_arrow_points(
        self,
        image: np.ndarray,
        center: Tuple[float, float],
        radius: float,
        max_arrows: int = 6,
    ) -> List[Tuple[float, float, float]]:
        """
        Finds arrow impact positions / shafts using edge/contrast detection.
        Returns list of (x, y, confidence).
        """
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(blurred, 60, 150)

        # Mask within target area + 10% margin
        mask = np.zeros_like(gray)
        cv2.circle(mask, (int(center[0]), int(center[1])), int(radius * 1.1), 255, -1)
        edges = cv2.bitwise_and(edges, edges, mask=mask)

        contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
        candidates = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if 5 < area < 500:
                ((x, y), r) = cv2.minEnclosingCircle(cnt)
                # Keep points inside target radius
                dist = math.sqrt((x - center[0]) ** 2 + (y - center[1]) ** 2)
                if dist <= radius * 1.05:
                    candidates.append((float(x), float(y), 0.75))

        # Cluster nearby points so 1 arrow = 1 impact detection
        merged_points = []
        cluster_threshold = radius * 0.08
        for pt in candidates:
            merged = False
            for i, m in enumerate(merged_points):
                d = math.sqrt((pt[0] - m[0]) ** 2 + (pt[1] - m[1]) ** 2)
                if d < cluster_threshold:
                    # Average position
                    merged_points[i] = (
                        (m[0] + pt[0]) / 2,
                        (m[1] + pt[1]) / 2,
                        max(m[2], pt[2]),
                    )
                    merged = True
                    break
            if not merged:
                merged_points.append(pt)

        # Sort by distance to center
        merged_points.sort(key=lambda p: (p[0] - center[0]) ** 2 + (p[1] - center[1]) ** 2)
        return merged_points[:max_arrows]

    async def detect(
        self,
        image_path: str,
        arrows_per_end: int = 6,
    ) -> Dict[str, Any]:
        """
        Main detection method.
        Returns target information, estimated arrows, and proposed scores for user confirmation.
        """
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found at {image_path}")

        image = cv2.imread(image_path)
        if image is None:
            raise ValueError("Failed to decode image file.")

        h, w = image.shape[:2]
        center, radius = self.detect_target_center_and_radius(image)
        if center is None or radius is None:
            center = (float(w / 2), float(h / 2))
            radius = float(min(w, h) * 0.4)

        raw_points = self.detect_arrow_points(image, center, radius, max_arrows=arrows_per_end)

        detected_arrows = []
        for i in range(arrows_per_end):
            if i < len(raw_points):
                pt = raw_points[i]
                score_num, is_x = self.calculate_score_from_coordinates((pt[0], pt[1]), center, radius)
                score_display = "X" if is_x else ("M" if score_num == 0 else str(score_num))
                confidence = pt[2]
                detected_arrows.append({
                    "arrow_number": i + 1,
                    "score": score_display,
                    "numeric_score": score_num,
                    "is_x": is_x,
                    "confidence": confidence,
                    "x": round(pt[0], 1),
                    "y": round(pt[1], 1),
                    "source": "ai",
                })
            else:
                # Default undetected slot to 0 / M
                detected_arrows.append({
                    "arrow_number": i + 1,
                    "score": "M",
                    "numeric_score": 0,
                    "is_x": False,
                    "confidence": 0.0,
                    "x": None,
                    "y": None,
                    "source": "ai",
                })

        return {
            "target": {
                "detected": True,
                "center_x": round(center[0], 1),
                "center_y": round(center[1], 1),
                "radius": round(radius, 1),
                "image_width": w,
                "image_height": h,
            },
            "detected_arrows": detected_arrows,
            "message": "Target and arrows detected. Please confirm or correct scores before saving.",
        }
