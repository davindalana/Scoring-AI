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

    def calculate_angle(self, p1: Tuple[float, float], p2: Tuple[float, float]) -> float:
        """Calculates angle in degrees between two points (from AkhilRai28/Arrow-Detection)."""
        return math.atan2(p1[1] - p2[1], p1[0] - p2[0]) * 180.0 / math.pi

    def identify_arrow_tip(
        self,
        approx: np.ndarray,
        hull_indices: np.ndarray,
        target_center: Tuple[float, float],
    ) -> Optional[Tuple[float, float]]:
        """
        Identifies the exact impact tip vertex of an arrow using polygon approximation
        and Convex Hull geometry from AkhilRai28/Arrow-Detection.
        Prioritizes the vertex penetrating closest to the target bullseye center.
        """
        pts = [tuple(p[0]) for p in approx]
        if len(pts) < 3:
            return None

        # Vertices in approx that are not in convex hull or are sharp extrema
        hull_set = set(int(h[0]) if hasattr(h, '__len__') else int(h) for h in hull_indices)
        interior_indices = [i for i in range(len(pts)) if i not in hull_set]

        # Check for chevron / arrowhead tip vertex
        if interior_indices:
            # The tip is typically the sharp inward vertex of the shaft/nock or closest to center
            interior_pts = [pts[i] for i in interior_indices]
            best_tip = min(
                interior_pts,
                key=lambda p: (p[0] - target_center[0]) ** 2 + (p[1] - target_center[1]) ** 2,
            )
            return float(best_tip[0]), float(best_tip[1])

        # If no concave vertex found, pick vertex closest to target center
        closest_pt = min(
            pts,
            key=lambda p: (p[0] - target_center[0]) ** 2 + (p[1] - target_center[1]) ** 2,
        )
        return float(closest_pt[0]), float(closest_pt[1])

    def detect_arrow_points(
        self,
        image: np.ndarray,
        center: Tuple[float, float],
        radius: float,
        max_arrows: int = 6,
    ) -> List[Tuple[float, float, float, float]]:
        """
        Enhanced Arrow Detection based on AkhilRai28/Arrow-Detection:
        - 7x7 Gaussian Blur
        - Canny Edge Detection (50, 150)
        - 3x3 Morphological Closing (2 iterations) to bridge shaft gaps
        - Contour tree extraction with approxPolyDP polygon approximation
        - Convex Hull analysis to localize exact arrow entry tip & shaft angle.
        Returns list of (x, y, confidence, angle_deg).
        """
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (7, 7), 0)
        edges = cv2.Canny(blurred, 50, 150)

        # Morphological Closing: bridges gaps in arrow shaft contours
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        closed_edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel, iterations=2)

        # Mask within target area + 10% margin
        mask = np.zeros_like(gray)
        cv2.circle(mask, (int(center[0]), int(center[1])), int(radius * 1.1), 255, -1)
        masked_edges = cv2.bitwise_and(closed_edges, closed_edges, mask=mask)

        contours, _ = cv2.findContours(masked_edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        candidates = []

        for cnt in contours:
            area = cv2.contourArea(cnt)
            if 15 < area < 1500:
                # Polygonal approximation (Ramer-Douglas-Peucker)
                epsilon = 0.02 * cv2.arcLength(cnt, True)
                approx = cv2.approxPolyDP(cnt, epsilon, True)
                hull_indices = cv2.convexHull(approx, returnPoints=False)

                tip = None
                if hull_indices is not None and len(approx) >= 3:
                    tip = self.identify_arrow_tip(approx, hull_indices, center)

                if tip is not None:
                    tx, ty = tip
                else:
                    ((tx, ty), _) = cv2.minEnclosingCircle(cnt)

                dist = math.sqrt((tx - center[0]) ** 2 + (ty - center[1]) ** 2)
                if dist <= radius * 1.05:
                    angle = self.calculate_angle((tx, ty), center)
                    confidence = 0.82 if len(approx) >= 5 else 0.72
                    candidates.append((float(tx), float(ty), confidence, angle))

        # Cluster nearby points so 1 arrow = 1 impact detection
        merged_points = []
        cluster_threshold = radius * 0.08
        for pt in candidates:
            merged = False
            for i, m in enumerate(merged_points):
                d = math.sqrt((pt[0] - m[0]) ** 2 + (pt[1] - m[1]) ** 2)
                if d < cluster_threshold:
                    merged_points[i] = (
                        (m[0] + pt[0]) / 2,
                        (m[1] + pt[1]) / 2,
                        max(m[2], pt[2]),
                        m[3],
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
                    "angle_deg": round(pt[3], 1) if len(pt) > 3 else 0.0,
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
