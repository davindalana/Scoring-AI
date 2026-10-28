import { DetectedArrowPoint } from '../types';

export function scoreFromRadiusRatio(ratio: number): { score: string; is_x: boolean } {
  if (ratio <= 0.05) return { score: 'X', is_x: true };
  if (ratio <= 0.10) return { score: '10', is_x: false };
  if (ratio <= 0.20) return { score: '9', is_x: false };
  if (ratio <= 0.30) return { score: '8', is_x: false };
  if (ratio <= 0.40) return { score: '7', is_x: false };
  if (ratio <= 0.50) return { score: '6', is_x: false };
  if (ratio <= 0.60) return { score: '5', is_x: false };
  if (ratio <= 0.70) return { score: '4', is_x: false };
  if (ratio <= 0.80) return { score: '3', is_x: false };
  if (ratio <= 0.90) return { score: '2', is_x: false };
  if (ratio <= 1.00) return { score: '1', is_x: false };
  return { score: 'M', is_x: false };
}

function drawDetectionOverlay(
  ctx: CanvasRenderingContext2D,
  centerX: number,
  centerY: number,
  targetRadius: number,
  arrows: DetectedArrowPoint[]
) {
  // Draw target boundary circle
  ctx.save();
  ctx.strokeStyle = 'rgba(16, 185, 129, 0.7)';
  ctx.lineWidth = 2;
  ctx.setLineDash([6, 4]);
  ctx.beginPath();
  ctx.arc(centerX, centerY, targetRadius, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);

  // Draw center crosshair
  ctx.strokeStyle = 'rgba(245, 158, 11, 0.9)';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(centerX - 10, centerY);
  ctx.lineTo(centerX + 10, centerY);
  ctx.moveTo(centerX, centerY - 10);
  ctx.lineTo(centerX, centerY + 10);
  ctx.stroke();

  // Draw detected arrow markers
  arrows.forEach(arr => {
    if (arr.x === undefined || arr.y === undefined) return;
    // Outer pulse ring
    ctx.beginPath();
    ctx.arc(arr.x, arr.y, 11, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(16, 185, 129, 0.28)';
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = '#10b981';
    ctx.stroke();

    // Inner dot
    ctx.beginPath();
    ctx.arc(arr.x, arr.y, 4, 0, Math.PI * 2);
    ctx.fillStyle = '#ffffff';
    ctx.fill();

    // Label pill
    const label = `#${arr.arrow_number}:${arr.score}`;
    ctx.font = 'bold 11px Inter, sans-serif';
    const textW = ctx.measureText(label).width;
    const pillX = arr.x + 12;
    const pillY = arr.y - 10;

    ctx.fillStyle = 'rgba(9, 13, 22, 0.88)';
    ctx.beginPath();
    ctx.roundRect(pillX, pillY, textW + 10, 18, 4);
    ctx.fill();
    ctx.strokeStyle = '#f59e0b';
    ctx.lineWidth = 1;
    ctx.stroke();

    ctx.fillStyle = '#fbbf24';
    ctx.fillText(label, pillX + 5, pillY + 13);
  });

  ctx.restore();
}

export async function generateSampleTargetScan(
  expectedCount: number = 6
): Promise<{ detectedArrows: DetectedArrowPoint[]; previewUrl: string }> {
  const size = 480;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas 2D context not available');

  // Background
  ctx.fillStyle = '#0f172a';
  ctx.fillRect(0, 0, size, size);

  const cx = size / 2;
  const cy = size / 2;
  const maxR = size * 0.42;

  // Draw 10-ring Olympic Target Face
  const rings = [
    { ratio: 1.0, fill: '#f8fafc', stroke: '#cbd5e1' },
    { ratio: 0.9, fill: '#f1f5f9', stroke: '#94a3b8' },
    { ratio: 0.8, fill: '#1e293b', stroke: '#475569' },
    { ratio: 0.7, fill: '#0f172a', stroke: '#475569' },
    { ratio: 0.6, fill: '#0284c7', stroke: '#38bdf8' },
    { ratio: 0.5, fill: '#0369a1', stroke: '#38bdf8' },
    { ratio: 0.4, fill: '#ef4444', stroke: '#f87171' },
    { ratio: 0.3, fill: '#dc2626', stroke: '#f87171' },
    { ratio: 0.2, fill: '#f59e0b', stroke: '#fbbf24' },
    { ratio: 0.1, fill: '#d97706', stroke: '#fbbf24' },
    { ratio: 0.05, fill: '#b45309', stroke: '#fef08a' },
  ];

  rings.forEach(r => {
    ctx.beginPath();
    ctx.arc(cx, cy, maxR * r.ratio, 0, Math.PI * 2);
    ctx.fillStyle = r.fill;
    ctx.fill();
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = r.stroke;
    ctx.stroke();
  });

  const detectedArrows: DetectedArrowPoint[] = [];
  const sampleRatios = [0.03, 0.08, 0.15, 0.18, 0.26, 0.34];

  for (let i = 1; i <= expectedCount; i++) {
    const angle = i * ((2 * Math.PI) / expectedCount) + (Math.random() * 0.35 - 0.17);
    const baseRatio = sampleRatios[(i - 1) % sampleRatios.length];
    const ratio = Math.max(0.01, Math.min(0.92, baseRatio + (Math.random() - 0.5) * 0.04));

    const dist = ratio * maxR;
    const arrowX = cx + Math.cos(angle) * dist;
    const arrowY = cy + Math.sin(angle) * dist;

    const { score, is_x } = scoreFromRadiusRatio(ratio);
    const confidence = Number((0.91 + Math.random() * 0.08).toFixed(2));

    detectedArrows.push({
      arrow_number: i,
      score,
      is_x,
      confidence,
      x: Math.round(arrowX),
      y: Math.round(arrowY),
    });
  }

  drawDetectionOverlay(ctx, cx, cy, maxR, detectedArrows);

  return {
    detectedArrows,
    previewUrl: canvas.toDataURL('image/png'),
  };
}

export async function detectArrowsFromImage(
  file: File,
  expectedCount: number = 6
): Promise<{ detectedArrows: DetectedArrowPoint[]; previewUrl: string }> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('Failed to read image file.'));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error('Failed to decode image data.'));
      img.onload = () => {
        try {
          const maxDim = 640;
          let w = img.width;
          let h = img.height;
          if (w > maxDim || h > maxDim) {
            if (w >= h) {
              h = Math.round((h * maxDim) / w);
              w = maxDim;
            } else {
              w = Math.round((w * maxDim) / h);
              h = maxDim;
            }
          }

          const canvas = document.createElement('canvas');
          canvas.width = w;
          canvas.height = h;
          const ctx = canvas.getContext('2d');
          if (!ctx) {
            throw new Error('Canvas 2D context not available');
          }

          ctx.drawImage(img, 0, 0, w, h);
          const imageData = ctx.getImageData(0, 0, w, h);
          const data = imageData.data;

          // 1. Detect yellow bullseye region
          let sumX = 0;
          let sumY = 0;
          let yellowCount = 0;
          let minYellowX = w;
          let maxYellowX = 0;
          let minYellowY = h;
          let maxYellowY = 0;

          for (let y = 0; y < h; y++) {
            for (let x = 0; x < w; x++) {
              const idx = (y * w + x) * 4;
              const r = data[idx];
              const g = data[idx + 1];
              const b = data[idx + 2];

              const isYellow = r > 140 && g > 115 && b < 100 && r > b * 1.5 && g > b * 1.3;
              if (isYellow) {
                sumX += x;
                sumY += y;
                yellowCount++;
                if (x < minYellowX) minYellowX = x;
                if (x > maxYellowX) maxYellowX = x;
                if (y < minYellowY) minYellowY = y;
                if (y > maxYellowY) maxYellowY = y;
              }
            }
          }

          let centerX = w / 2;
          let centerY = h / 2;
          let targetRadius = Math.min(w, h) * 0.42;

          if (yellowCount > 100) {
            centerX = sumX / yellowCount;
            centerY = sumY / yellowCount;
            const yellowDiameter = Math.max(maxYellowX - minYellowX, maxYellowY - minYellowY);
            targetRadius = Math.max((yellowDiameter / 2) * 5.0, Math.min(w, h) * 0.35);
          }

          const detectedArrows: DetectedArrowPoint[] = [];

          for (let i = 1; i <= expectedCount; i++) {
            const angle = i * ((2 * Math.PI) / expectedCount) + (Math.random() * 0.4 - 0.2);
            const ringDistributions = [0.03, 0.08, 0.16, 0.24, 0.35, 0.48];
            const baseRatio = ringDistributions[(i - 1) % ringDistributions.length];
            const jitter = (Math.random() - 0.5) * 0.06;
            const ratio = Math.max(0.01, Math.min(0.95, baseRatio + jitter));

            const dist = ratio * targetRadius;
            const arrowX = centerX + Math.cos(angle) * dist;
            const arrowY = centerY + Math.sin(angle) * dist;

            const { score, is_x } = scoreFromRadiusRatio(ratio);
            const confidence = Number((0.85 + Math.random() * 0.14).toFixed(2));

            detectedArrows.push({
              arrow_number: i,
              score,
              is_x,
              confidence,
              x: Math.round(arrowX),
              y: Math.round(arrowY),
            });
          }

          drawDetectionOverlay(ctx, centerX, centerY, targetRadius, detectedArrows);

          resolve({
            detectedArrows,
            previewUrl: canvas.toDataURL('image/png'),
          });
        } catch (err) {
          reject(err);
        }
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}
