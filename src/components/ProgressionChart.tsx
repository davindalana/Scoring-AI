import React, { useState } from 'react';
import { EndSummaryItem } from '../types';

interface ProgressionChartProps {
  endsSummary: EndSummaryItem[];
}

export const ProgressionChart: React.FC<ProgressionChartProps> = ({ endsSummary }) => {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);

  if (!endsSummary || endsSummary.length === 0) {
    return <div className="text-secondary text-center p-3">No ends to display in progression chart.</div>;
  }

  const paddingLeft = 50;
  const paddingRight = 45;
  const paddingTop = 30;
  const paddingBottom = 40;
  const chartWidth = 720;
  const chartHeight = 260;

  const innerWidth = chartWidth - paddingLeft - paddingRight;
  const innerHeight = chartHeight - paddingTop - paddingBottom;

  const maxCumulative = Math.max(...endsSummary.map(e => e.cumulative_score), 10);
  const maxEndScore = Math.max(...endsSummary.map(e => e.total_score), 10);

  const n = endsSummary.length;
  const stepX = n > 1 ? innerWidth / (n - 1) : innerWidth / 2;

  // Compute points for cumulative line
  const points = endsSummary.map((item, idx) => {
    const x = n > 1 ? paddingLeft + idx * stepX : paddingLeft + innerWidth / 2;
    const y = paddingTop + innerHeight - (item.cumulative_score / maxCumulative) * innerHeight;
    return { x, y, item, idx };
  });

  const linePath = points.reduce((acc, curr, idx) => {
    return idx === 0 ? `M ${curr.x} ${curr.y}` : `${acc} L ${curr.x} ${curr.y}`;
  }, '');

  const areaPath = points.length > 0
    ? `${linePath} L ${points[points.length - 1].x} ${paddingTop + innerHeight} L ${points[0].x} ${paddingTop + innerHeight} Z`
    : '';

  // Bar width calculation
  const barWidth = Math.min(32, Math.max(12, (innerWidth / n) * 0.45));

  return (
    <div style={{ width: '100%', position: 'relative' }}>
      <svg
        viewBox={`0 0 ${chartWidth} ${chartHeight}`}
        style={{ width: '100%', height: 'auto', overflow: 'visible' }}
      >
        <defs>
          <linearGradient id="cumulGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#f59e0b" stopOpacity="0.25" />
            <stop offset="100%" stopColor="#f59e0b" stopOpacity="0.0" />
          </linearGradient>
        </defs>

        {/* Horizontal grid lines */}
        {[0, 0.25, 0.5, 0.75, 1].map((ratio, i) => {
          const y = paddingTop + innerHeight * (1 - ratio);
          const cumulVal = Math.round(maxCumulative * ratio);
          return (
            <g key={i}>
              <line
                x1={paddingLeft}
                y1={y}
                x2={chartWidth - paddingRight}
                y2={y}
                stroke="rgba(255, 255, 255, 0.08)"
                strokeDasharray={ratio === 0 ? 'none' : '3 3'}
              />
              <text
                x={paddingLeft - 8}
                y={y + 4}
                fill="#f59e0b"
                fontSize="10"
                textAnchor="end"
                fontWeight="600"
              >
                {cumulVal}
              </text>
            </g>
          );
        })}

        {/* End score bars */}
        {endsSummary.map((item, idx) => {
          const x = n > 1 ? paddingLeft + idx * stepX : paddingLeft + innerWidth / 2;
          const barHeight = (item.total_score / (maxEndScore * 1.15)) * innerHeight;
          const y = paddingTop + innerHeight - barHeight;
          const isHovered = hoveredIndex === idx;

          return (
            <rect
              key={`bar-${idx}`}
              x={x - barWidth / 2}
              y={y}
              width={barWidth}
              height={Math.max(2, barHeight)}
              rx="4"
              fill={isHovered ? '#7dd3fc' : '#38bdf8'}
              opacity={isHovered ? 1 : 0.85}
              style={{ transition: 'all 0.15s ease', cursor: 'pointer' }}
              onMouseEnter={() => setHoveredIndex(idx)}
              onMouseLeave={() => setHoveredIndex(null)}
            />
          );
        })}

        {/* Cumulative score area fill */}
        {areaPath && <path d={areaPath} fill="url(#cumulGradient)" />}

        {/* Cumulative score line */}
        {linePath && (
          <path
            d={linePath}
            fill="none"
            stroke="#f59e0b"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        )}

        {/* Cumulative points and X axis labels */}
        {points.map((pt, idx) => {
          const isHovered = hoveredIndex === idx;
          return (
            <g key={`pt-${idx}`}>
              <circle
                cx={pt.x}
                cy={pt.y}
                r={isHovered ? 6 : 4}
                fill="#f59e0b"
                stroke="#0a0e17"
                strokeWidth="2"
                style={{ cursor: 'pointer', transition: 'all 0.15s ease' }}
                onMouseEnter={() => setHoveredIndex(idx)}
                onMouseLeave={() => setHoveredIndex(null)}
              />
              <text
                x={pt.x}
                y={chartHeight - 12}
                fill="#94a3b8"
                fontSize="11"
                textAnchor="middle"
                fontWeight="500"
              >
                End {pt.item.end_number}
              </text>
            </g>
          );
        })}
      </svg>

      {/* Floating Tooltip */}
      {hoveredIndex !== null && endsSummary[hoveredIndex] && (
        <div
          style={{
            position: 'absolute',
            top: '8px',
            right: '12px',
            background: 'rgba(17, 24, 39, 0.95)',
            border: '1px solid var(--border-glass)',
            borderRadius: 'var(--radius-md)',
            padding: '0.5rem 0.75rem',
            fontSize: '0.82rem',
            color: '#f8fafc',
            pointerEvents: 'none',
            boxShadow: 'var(--shadow-md)',
          }}
        >
          <div style={{ fontWeight: 700, marginBottom: '2px', color: 'var(--ring-gold)' }}>
            End {endsSummary[hoveredIndex].end_number}
          </div>
          <div>End Score: <strong>{endsSummary[hoveredIndex].total_score}</strong> (X: {endsSummary[hoveredIndex].x_count})</div>
          <div>Cumulative: <strong>{endsSummary[hoveredIndex].cumulative_score}</strong></div>
        </div>
      )}
    </div>
  );
};
