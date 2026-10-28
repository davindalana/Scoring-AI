import React from 'react';

interface KeypadProps {
  onKeyPress: (val: string) => void;
  onUndo: () => void;
  onTriggerAiScan: () => void;
  onSubmitEnd: () => void;
}

export const Keypad: React.FC<KeypadProps> = ({
  onKeyPress,
  onUndo,
  onTriggerAiScan,
  onSubmitEnd,
}) => {
  return (
    <div className="keypad-container">
      <div className="keypad-grid">
        <button
          type="button"
          className="keypad-btn key-x"
          onClick={() => onKeyPress('X')}
          title="Press X"
        >
          <span className="key-val">X</span>
          <span className="key-sub">10 pts</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-10"
          onClick={() => onKeyPress('10')}
          title="Press 0 or 10"
        >
          <span className="key-val">10</span>
          <span className="key-sub">Gold</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-9"
          onClick={() => onKeyPress('9')}
          title="Press 9"
        >
          <span className="key-val">9</span>
          <span className="key-sub">Gold</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-m"
          onClick={() => onKeyPress('M')}
          title="Press M"
        >
          <span className="key-val">M</span>
          <span className="key-sub">Miss</span>
        </button>

        <button
          type="button"
          className="keypad-btn key-8"
          onClick={() => onKeyPress('8')}
          title="Press 8"
        >
          <span className="key-val">8</span>
          <span className="key-sub">Red</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-7"
          onClick={() => onKeyPress('7')}
          title="Press 7"
        >
          <span className="key-val">7</span>
          <span className="key-sub">Red</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-6"
          onClick={() => onKeyPress('6')}
          title="Press 6"
        >
          <span className="key-val">6</span>
          <span className="key-sub">Blue</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-5"
          onClick={() => onKeyPress('5')}
          title="Press 5"
        >
          <span className="key-val">5</span>
          <span className="key-sub">Blue</span>
        </button>

        <button
          type="button"
          className="keypad-btn key-4"
          onClick={() => onKeyPress('4')}
          title="Press 4"
        >
          <span className="key-val">4</span>
          <span className="key-sub">Black</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-3"
          onClick={() => onKeyPress('3')}
          title="Press 3"
        >
          <span className="key-val">3</span>
          <span className="key-sub">Black</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-2"
          onClick={() => onKeyPress('2')}
          title="Press 2"
        >
          <span className="key-val">2</span>
          <span className="key-sub">White</span>
        </button>
        <button
          type="button"
          className="keypad-btn key-1"
          onClick={() => onKeyPress('1')}
          title="Press 1"
        >
          <span className="key-val">1</span>
          <span className="key-sub">White</span>
        </button>
      </div>

      <div className="end-action-bar">
        <button
          type="button"
          className="btn btn-secondary flex-1"
          onClick={onUndo}
          title="Backspace"
        >
          <span>⌫ Undo</span>
        </button>
        <button
          type="button"
          className="btn btn-ai flex-1"
          onClick={onTriggerAiScan}
          title="Upload target photo for AI detection"
        >
          <span>📸 AI Scan</span>
        </button>
        <button
          type="button"
          className="btn btn-primary flex-1"
          onClick={onSubmitEnd}
          title="Press Enter"
        >
          <span>Save End ➔</span>
        </button>
      </div>
    </div>
  );
};
