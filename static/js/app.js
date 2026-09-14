// Archery Scoring Application Client
document.addEventListener('DOMContentLoaded', () => {
  // Global State
  const state = {
    currentSession: null,
    athletes: [],
    currentEndNumber: 1,
    currentEndArrows: [], // e.g. [{ arrow_number: 1, score: '10', is_x: false, source: 'manual' }]
    activeSlotIndex: 0,
    progressionChart: null,
  };

  // DOM Elements
  const viewHome = document.getElementById('viewHome');
  const viewScoring = document.getElementById('viewScoring');
  const viewSummary = document.getElementById('viewSummary');

  const navHomeBtn = document.getElementById('navHomeBtn');
  const btnManageAthletes = document.getElementById('btnManageAthletes');
  const btnNewSessionTop = document.getElementById('btnNewSessionTop');
  const cardStartTraining = document.getElementById('cardStartTraining');
  const cardStartCompetition = document.getElementById('cardStartCompetition');
  const recentSessionsList = document.getElementById('recentSessionsList');
  const sessionCountBadge = document.getElementById('sessionCountBadge');

  // Modals
  const modalCreateSession = document.getElementById('modalCreateSession');
  const btnCloseCreateSession = document.getElementById('btnCloseCreateSession');
  const formCreateSession = document.getElementById('formCreateSession');
  const selectAthlete = document.getElementById('selectAthlete');
  const btnOpenNewAthleteModal = document.getElementById('btnOpenNewAthleteModal');
  const selectBowCategory = document.getElementById('selectBowCategory');
  const selectSessionType = document.getElementById('selectSessionType');
  const selectDistance = document.getElementById('selectDistance');
  const inputCustomDistance = document.getElementById('inputCustomDistance');
  const selectArrowsPerEnd = document.getElementById('selectArrowsPerEnd');
  const inputTotalEnds = document.getElementById('inputTotalEnds');

  const modalAddAthlete = document.getElementById('modalAddAthlete');
  const btnCloseAddAthlete = document.getElementById('btnCloseAddAthlete');
  const formAddAthlete = document.getElementById('formAddAthlete');
  const inputAthleteName = document.getElementById('inputAthleteName');
  const inputAthleteCode = document.getElementById('inputAthleteCode');

  // Scoring View Elements
  const scoreAthleteName = document.getElementById('scoreAthleteName');
  const scoreSessionBadge = document.getElementById('scoreSessionBadge');
  const scoreSessionMeta = document.getElementById('scoreSessionMeta');
  const btnAbandonSession = document.getElementById('btnAbandonSession');
  const scoreCurrentEnd = document.getElementById('scoreCurrentEnd');
  const scoreEndTotal = document.getElementById('scoreEndTotal');
  const scoreEndX = document.getElementById('scoreEndX');
  const scoreSessionTotal = document.getElementById('scoreSessionTotal');
  const arrowSlotsContainer = document.getElementById('arrowSlotsContainer');
  const btnUndoArrow = document.getElementById('btnUndoArrow');
  const btnTriggerAiScan = document.getElementById('btnTriggerAiScan');
  const btnSubmitEnd = document.getElementById('btnSubmitEnd');
  const liveScorecardBody = document.getElementById('liveScorecardBody');

  // Summary View Elements
  const summaryAthleteInfo = document.getElementById('summaryAthleteInfo');
  const sumFinalScore = document.getElementById('sumFinalScore');
  const sumTotalX = document.getElementById('sumTotalX');
  const sumAvgArrow = document.getElementById('sumAvgArrow');
  const sumAvgEnd = document.getElementById('sumAvgEnd');
  const sumHighestEnd = document.getElementById('sumHighestEnd');
  const sumLowestEnd = document.getElementById('sumLowestEnd');
  const sumTotalArrows = document.getElementById('sumTotalArrows');
  const summaryScorecardBody = document.getElementById('summaryScorecardBody');
  const btnBackHomeFromSummary = document.getElementById('btnBackHomeFromSummary');
  const btnNewSessionFromSummary = document.getElementById('btnNewSessionFromSummary');

  // AI Modal
  const modalAiScan = document.getElementById('modalAiScan');
  const btnCloseAiScan = document.getElementById('btnCloseAiScan');
  const targetImageInput = document.getElementById('targetImageInput');
  const aiScanLoading = document.getElementById('aiScanLoading');
  const aiScanResults = document.getElementById('aiScanResults');
  const aiDetectedChips = document.getElementById('aiDetectedChips');
  const btnCancelAiScan = document.getElementById('btnCancelAiScan');
  const btnApplyAiScores = document.getElementById('btnApplyAiScores');

  let detectedAiArrows = [];

  // ==================== INITIALIZATION ====================
  async function init() {
    setupEventListeners();
    await loadAthletes();
    await loadRecentSessions();
  }

  // ==================== ROUTING / NAVIGATION ====================
  function showView(viewId) {
    viewHome.classList.add('hidden');
    viewScoring.classList.add('hidden');
    viewSummary.classList.add('hidden');

    if (viewId === 'home') {
      viewHome.classList.remove('hidden');
      loadRecentSessions();
    } else if (viewId === 'scoring') {
      viewScoring.classList.remove('hidden');
    } else if (viewId === 'summary') {
      viewSummary.classList.remove('hidden');
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // ==================== API HELPERS ====================
  async function apiCall(endpoint, method = 'GET', body = null) {
    const options = { method, headers: {} };
    if (body && !(body instanceof FormData)) {
      options.headers['Content-Type'] = 'application/json';
      options.body = JSON.stringify(body);
    } else if (body instanceof FormData) {
      options.body = body;
    }

    try {
      const res = await fetch(endpoint, options);
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.detail || 'API request failed');
      }
      return data;
    } catch (err) {
      console.error(`Error on ${method} ${endpoint}:`, err);
      throw err;
    }
  }

  // ==================== ATHLETE MANAGEMENT ====================
  async function loadAthletes() {
    try {
      state.athletes = await apiCall('/api/athletes');
      selectAthlete.innerHTML = '<option value="">Select an athlete...</option>';
      state.athletes.forEach(a => {
        const opt = document.createElement('option');
        opt.value = a.id;
        opt.textContent = `${a.name} ${a.athlete_code ? `(${a.athlete_code})` : ''}`;
        selectAthlete.appendChild(opt);
      });
    } catch (err) {
      console.error('Failed to load athletes', err);
    }
  }

  // ==================== RECENT SESSIONS ====================
  async function loadRecentSessions() {
    try {
      const sessions = await apiCall('/api/sessions?limit=15');
      sessionCountBadge.textContent = `${sessions.length} sessions`;

      if (!sessions || sessions.length === 0) {
        recentSessionsList.innerHTML = `
          <div style="text-align: center; color: var(--text-muted); padding: 2.5rem; background: var(--bg-card); border-radius: var(--radius-md); border: 1px dashed var(--border-color);">
            No scoring sessions recorded yet. Tap <strong>Start Practice</strong> or <strong>+ New Session</strong> to begin.
          </div>
        `;
        return;
      }

      recentSessionsList.innerHTML = '';
      sessions.forEach(s => {
        const item = document.createElement('div');
        item.className = 'session-item';
        const isComplete = s.status === 'completed';
        const dateStr = s.started_at ? new Date(s.started_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';

        item.innerHTML = `
          <div>
            <div style="font-weight: 700; font-size: 1.05rem;">${s.athlete_name || 'Athlete'}</div>
            <div style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 0.2rem;">
              ${s.bow_category} • ${s.distance} • ${s.arrows_per_end} arr/end • ${dateStr}
            </div>
          </div>
          <div style="display: flex; align-items: center; gap: 0.75rem;">
            <span class="session-badge ${isComplete ? 'badge-completed' : 'badge-progress'}">
              ${isComplete ? 'Completed' : `End ${s.current_end}/${s.total_ends}`}
            </span>
            <span style="font-size: 1.2rem; color: var(--text-muted);">➔</span>
          </div>
        `;
        item.addEventListener('click', () => openSession(s.id));
        recentSessionsList.appendChild(item);
      });
    } catch (err) {
      recentSessionsList.innerHTML = '<div style="color: #f87171; text-align: center;">Failed to load sessions.</div>';
    }
  }

  // ==================== OPEN & RESUME SESSION ====================
  async function openSession(sessionId) {
    try {
      const details = await apiCall(`/api/sessions/${sessionId}`);
      state.currentSession = details.session;
      state.currentSession.athlete = details.athlete;

      if (details.session.status === 'completed') {
        renderSummaryScreen(details);
        showView('summary');
      } else {
        setupScoringScreen(details);
        showView('scoring');
      }
    } catch (err) {
      alert('Error loading session: ' + err.message);
    }
  }

  // ==================== SCORING SETUP ====================
  function setupScoringScreen(details) {
    const s = details.session;
    scoreAthleteName.textContent = details.athlete ? details.athlete.name : s.athlete_name || 'Athlete';
    scoreSessionBadge.textContent = s.bow_category;
    scoreSessionMeta.textContent = `${s.distance} • ${s.arrows_per_end} Arrows/End • ${s.session_type}`;

    state.currentEndNumber = s.current_end;
    state.currentEndArrows = [];
    state.activeSlotIndex = 0;

    // Initialize blank slots
    for (let i = 1; i <= s.arrows_per_end; i++) {
      state.currentEndArrows.push({
        arrow_number: i,
        score: null,
        is_x: false,
        source: 'manual',
      });
    }

    renderArrowSlots();
    renderLiveScorecard(details.ends || []);
    updateLiveMetrics(details.summary);
  }

  function renderArrowSlots() {
    arrowSlotsContainer.innerHTML = '';
    state.currentEndArrows.forEach((arr, index) => {
      const slot = document.createElement('div');
      slot.className = 'arrow-slot';
      if (index === state.activeSlotIndex) slot.classList.add('active');

      if (arr.score !== null) {
        slot.classList.add('filled');
        const scoreStr = String(arr.score).toUpperCase();
        slot.textContent = arr.is_x ? 'X' : scoreStr;

        // Apply ring color class
        if (arr.is_x || scoreStr === 'X') slot.classList.add('score-x');
        else if (scoreStr === '10') slot.classList.add('score-10');
        else if (scoreStr === '9') slot.classList.add('score-9');
        else if (scoreStr === '8') slot.classList.add('score-8');
        else if (scoreStr === '7') slot.classList.add('score-7');
        else if (scoreStr === '6') slot.classList.add('score-6');
        else if (scoreStr === '5') slot.classList.add('score-5');
        else if (scoreStr === '4') slot.classList.add('score-4');
        else if (scoreStr === '3') slot.classList.add('score-3');
        else if (scoreStr === '2') slot.classList.add('score-2');
        else if (scoreStr === '1') slot.classList.add('score-1');
        else if (scoreStr === 'M' || scoreStr === '0') slot.classList.add('score-m');
      } else {
        slot.textContent = index + 1;
      }

      slot.addEventListener('click', () => {
        state.activeSlotIndex = index;
        renderArrowSlots();
      });

      arrowSlotsContainer.appendChild(slot);
    });

    calculateLiveEndTotal();
  }

  function calculateLiveEndTotal() {
    let total = 0;
    let xCount = 0;

    state.currentEndArrows.forEach(a => {
      if (a.score !== null) {
        if (a.is_x || a.score === 'X' || a.score === '10X') {
          total += 10;
          xCount += 1;
        } else if (a.score === 'M') {
          total += 0;
        } else {
          total += parseInt(a.score, 10) || 0;
        }
      }
    });

    scoreEndTotal.textContent = total;
    scoreEndX.textContent = xCount;
    scoreCurrentEnd.textContent = `End ${state.currentEndNumber} / ${state.currentSession.total_ends}`;
  }

  function updateLiveMetrics(summary) {
    if (summary) {
      scoreSessionTotal.textContent = summary.total_score || 0;
    }
  }

  function renderLiveScorecard(ends) {
    liveScorecardBody.innerHTML = '';
    if (!ends || ends.length === 0) {
      liveScorecardBody.innerHTML = '<tr><td colspan="6" style="color: var(--text-muted);">No completed ends yet.</td></tr>';
      return;
    }

    let runningTotal = 0;
    ends.forEach(end => {
      runningTotal += end.total_score;
      const arrowDisplay = (end.arrows || [])
        .map(a => `<span style="display:inline-block; margin:0 2px; padding:2px 6px; border-radius:4px; font-weight:600; background:rgba(255,255,255,0.08);">${a.is_x ? 'X' : (a.score === 0 ? 'M' : a.score)}</span>`)
        .join('');

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td style="font-weight:700;">#${end.end_number}</td>
        <td>${arrowDisplay}</td>
        <td style="font-weight:700; color:var(--ring-gold);">${end.total_score}</td>
        <td>${end.x_count}</td>
        <td style="font-weight:700;">${runningTotal}</td>
        <td><button class="btn btn-secondary btn-edit-end" data-end="${end.end_number}" style="padding:0.25rem 0.6rem; font-size:0.75rem;">Edit</button></td>
      `;

      tr.querySelector('.btn-edit-end').addEventListener('click', () => editPreviousEnd(end));
      liveScorecardBody.appendChild(tr);
    });
  }

  function editPreviousEnd(end) {
    const newScoresStr = prompt(
      `Edit End #${end.end_number} arrow scores (comma-separated, e.g. 10X, 10, 9, 8, 7, M):`,
      (end.arrows || []).map(a => a.is_x ? '10X' : (a.score === 0 ? 'M' : a.score)).join(', ')
    );
    if (!newScoresStr) return;

    const parts = newScoresStr.split(',').map(s => s.trim()).filter(Boolean);
    if (parts.length > state.currentSession.arrows_per_end) {
      alert(`Maximum arrows allowed per end is ${state.currentSession.arrows_per_end}`);
      return;
    }

    const payloadArrows = parts.map((val, idx) => ({
      arrow_number: idx + 1,
      score: val,
      is_x: val.toUpperCase() === 'X' || val.toUpperCase() === '10X',
      source: 'manual',
    }));

    apiCall(`/api/sessions/${state.currentSession.id}/ends/${end.end_number}`, 'PUT', { arrows: payloadArrows })
      .then(async () => {
        const details = await apiCall(`/api/sessions/${state.currentSession.id}`);
        renderLiveScorecard(details.ends);
        updateLiveMetrics(details.summary);
      })
      .catch(err => alert('Failed to update end: ' + err.message));
  }

  // ==================== KEYPAD INPUT ====================
  function handleKeypadInput(value) {
    const slot = state.currentEndArrows[state.activeSlotIndex];
    if (!slot) return;

    if (value === 'X') {
      slot.score = 'X';
      slot.is_x = true;
    } else if (value === 'M') {
      slot.score = 'M';
      slot.is_x = false;
    } else {
      slot.score = value;
      slot.is_x = false;
    }
    slot.source = 'manual';

    // Auto advance to next slot if available
    if (state.activeSlotIndex < state.currentSession.arrows_per_end - 1) {
      state.activeSlotIndex++;
    }

    renderArrowSlots();
  }

  function handleUndo() {
    const slot = state.currentEndArrows[state.activeSlotIndex];
    if (slot && slot.score !== null) {
      slot.score = null;
      slot.is_x = false;
    } else if (state.activeSlotIndex > 0) {
      state.activeSlotIndex--;
      state.currentEndArrows[state.activeSlotIndex].score = null;
      state.currentEndArrows[state.activeSlotIndex].is_x = false;
    }
    renderArrowSlots();
  }

  // ==================== SUBMIT END ====================
  async function submitCurrentEnd() {
    // Check if all slots are filled
    const unfilled = state.currentEndArrows.filter(a => a.score === null);
    if (unfilled.length > 0) {
      const confirmIncomplete = confirm(`You have ${unfilled.length} unfilled arrow(s). Unfilled arrows will be recorded as Miss (M). Proceed?`);
      if (!confirmIncomplete) return;

      state.currentEndArrows.forEach(a => {
        if (a.score === null) {
          a.score = 'M';
          a.is_x = false;
        }
      });
    }

    const payload = {
      end_number: state.currentEndNumber,
      arrows: state.currentEndArrows.map(a => ({
        arrow_number: a.arrow_number,
        score: a.score,
        is_x: Boolean(a.is_x),
        source: a.source || 'manual',
      })),
    };

    try {
      await apiCall(`/api/sessions/${state.currentSession.id}/ends`, 'POST', payload);
      const details = await apiCall(`/api/sessions/${state.currentSession.id}`);

      if (details.session.status === 'completed' || state.currentEndNumber >= state.currentSession.total_ends) {
        renderSummaryScreen(details);
        showView('summary');
      } else {
        setupScoringScreen(details);
      }
    } catch (err) {
      alert('Failed to save end: ' + err.message);
    }
  }

  // ==================== SUMMARY SCREEN ====================
  function renderSummaryScreen(details) {
    const s = details.session;
    const sum = details.summary;
    const ath = details.athlete;

    summaryAthleteInfo.textContent = `${ath ? ath.name : s.athlete_name} • ${s.bow_category} • ${s.distance} • ${s.session_type.toUpperCase()}`;
    sumFinalScore.textContent = sum.total_score;
    sumTotalX.textContent = sum.total_x;
    sumAvgArrow.textContent = sum.average_score_per_arrow.toFixed(2);
    sumAvgEnd.textContent = sum.average_score_per_end.toFixed(1);
    sumTotalArrows.textContent = sum.total_arrows;

    if (sum.highest_scoring_end) {
      sumHighestEnd.textContent = `${sum.highest_scoring_end.score} pts (End ${sum.highest_scoring_end.end_number})`;
    } else {
      sumHighestEnd.textContent = '--';
    }

    if (sum.lowest_scoring_end) {
      sumLowestEnd.textContent = `${sum.lowest_scoring_end.score} pts (End ${sum.lowest_scoring_end.end_number})`;
    } else {
      sumLowestEnd.textContent = '--';
    }

    // Scorecard
    summaryScorecardBody.innerHTML = '';
    (details.ends || []).forEach(end => {
      const arrowDisplay = (end.arrows || [])
        .map(a => `<span style="display:inline-block; margin:0 3px; padding:2px 8px; border-radius:4px; font-weight:700; background:rgba(255,255,255,0.08);">${a.is_x ? 'X' : (a.score === 0 ? 'M' : a.score)}</span>`)
        .join('');

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td style="font-weight:700;">End ${end.end_number}</td>
        <td>${arrowDisplay}</td>
        <td style="font-weight:700; color:var(--ring-gold);">${end.total_score}</td>
        <td>${end.x_count}</td>
        <td style="font-weight:800;">${(sum.ends_summary.find(e => e.end_number === end.end_number) || {}).cumulative_score || end.total_score}</td>
      `;
      summaryScorecardBody.appendChild(tr);
    });

    // Chart.js Progression
    renderProgressionChart(sum.ends_summary || []);
  }

  function renderProgressionChart(endsSummary) {
    const ctx = document.getElementById('progressionChart').getContext('2d');
    if (state.progressionChart) {
      state.progressionChart.destroy();
    }

    const labels = endsSummary.map(e => `End ${e.end_number}`);
    const endScores = endsSummary.map(e => e.total_score);
    const cumulative = endsSummary.map(e => e.cumulative_score);

    state.progressionChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Cumulative Score',
            data: cumulative,
            borderColor: '#f59e0b',
            backgroundColor: 'rgba(245, 158, 11, 0.1)',
            fill: true,
            tension: 0.3,
            yAxisID: 'yCumulative',
          },
          {
            label: 'End Score',
            data: endScores,
            borderColor: '#38bdf8',
            backgroundColor: '#38bdf8',
            type: 'bar',
            yAxisID: 'yEnd',
            borderRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            labels: { color: '#f0f6fc' },
          },
        },
        scales: {
          x: {
            ticks: { color: '#8b949e' },
            grid: { color: 'rgba(255,255,255,0.05)' },
          },
          yCumulative: {
            position: 'left',
            ticks: { color: '#f59e0b' },
            grid: { color: 'rgba(255,255,255,0.05)' },
          },
          yEnd: {
            position: 'right',
            ticks: { color: '#38bdf8' },
            grid: { display: false },
          },
        },
      },
    });
  }

  // ==================== AI TARGET SCAN ====================
  function openAiScanModal() {
    targetImageInput.value = '';
    aiScanLoading.classList.add('hidden');
    aiScanResults.classList.add('hidden');
    detectedAiArrows = [];
    modalAiScan.classList.remove('hidden');
  }

  async function handleTargetImageSelected() {
    const file = targetImageInput.files[0];
    if (!file) return;

    aiScanLoading.classList.remove('hidden');
    aiScanResults.classList.add('hidden');

    const formData = new FormData();
    formData.append('file', file);

    try {
      const result = await apiCall(`/api/sessions/${state.currentSession.id}/detect`, 'POST', formData);
      aiScanLoading.classList.add('hidden');
      aiScanResults.classList.remove('hidden');

      detectedAiArrows = result.detected_arrows || [];
      renderAiDetectedChips();
    } catch (err) {
      aiScanLoading.classList.add('hidden');
      alert('AI Detection error: ' + err.message);
    }
  }

  function renderAiDetectedChips() {
    aiDetectedChips.innerHTML = '';
    detectedAiArrows.forEach((arr, idx) => {
      const chip = document.createElement('button');
      chip.type = 'button';
      chip.className = 'btn btn-secondary';
      chip.style.padding = '0.5rem 1rem';
      chip.style.fontWeight = '700';
      chip.textContent = `Arrow ${arr.arrow_number}: ${arr.score}`;

      chip.addEventListener('click', () => {
        const newScore = prompt(`Correct score for Arrow #${arr.arrow_number} (X, 10, 9..1, M):`, arr.score);
        if (newScore) {
          const norm = newScore.trim().toUpperCase();
          arr.score = norm;
          arr.is_x = norm === 'X' || norm === '10X';
          renderAiDetectedChips();
        }
      });

      aiDetectedChips.appendChild(chip);
    });
  }

  function applyAiScoresToCurrentEnd() {
    detectedAiArrows.forEach(aiArr => {
      const targetSlot = state.currentEndArrows[aiArr.arrow_number - 1];
      if (targetSlot) {
        targetSlot.score = aiArr.score;
        targetSlot.is_x = aiArr.is_x;
        targetSlot.source = 'ai';
      }
    });

    modalAiScan.classList.add('hidden');
    renderArrowSlots();
  }

  // ==================== EVENT LISTENERS ====================
  function setupEventListeners() {
    navHomeBtn.addEventListener('click', () => showView('home'));
    btnBackHomeFromSummary.addEventListener('click', () => showView('home'));

    // Keypad clicks
    document.querySelectorAll('.keypad-btn').forEach(btn => {
      btn.addEventListener('click', () => handleKeypadInput(btn.dataset.val));
    });

    btnUndoArrow.addEventListener('click', handleUndo);
    btnSubmitEnd.addEventListener('click', submitCurrentEnd);
    btnAbandonSession.addEventListener('click', () => {
      if (confirm('Leave this scoring session? Progress is saved automatically.')) {
        showView('home');
      }
    });

    // Start Buttons
    cardStartTraining.addEventListener('click', () => {
      selectSessionType.value = 'training';
      modalCreateSession.classList.remove('hidden');
    });

    cardStartCompetition.addEventListener('click', () => {
      selectSessionType.value = 'competition';
      modalCreateSession.classList.remove('hidden');
    });

    btnNewSessionTop.addEventListener('click', () => {
      modalCreateSession.classList.remove('hidden');
    });

    btnNewSessionFromSummary.addEventListener('click', () => {
      modalCreateSession.classList.remove('hidden');
    });

    // Create Session Form
    btnCloseCreateSession.addEventListener('click', () => modalCreateSession.classList.add('hidden'));
    selectDistance.addEventListener('change', () => {
      if (selectDistance.value === 'Custom') {
        inputCustomDistance.classList.remove('hidden');
        inputCustomDistance.required = true;
      } else {
        inputCustomDistance.classList.add('hidden');
        inputCustomDistance.required = false;
      }
    });

    formCreateSession.addEventListener('submit', async (e) => {
      e.preventDefault();
      const athleteId = parseInt(selectAthlete.value, 10);
      if (!athleteId) {
        alert('Please select an athlete.');
        return;
      }

      const distance = selectDistance.value === 'Custom' ? inputCustomDistance.value.trim() : selectDistance.value;
      const payload = {
        athlete_id: athleteId,
        bow_category: selectBowCategory.value,
        session_type: selectSessionType.value,
        distance: distance || '18m',
        arrows_per_end: parseInt(selectArrowsPerEnd.value, 10),
        total_ends: parseInt(inputTotalEnds.value, 10),
      };

      try {
        const created = await apiCall('/api/sessions', 'POST', payload);
        modalCreateSession.classList.add('hidden');
        await openSession(created.id);
      } catch (err) {
        alert('Failed to start session: ' + err.message);
      }
    });

    // Athlete Management
    btnManageAthletes.addEventListener('click', () => modalAddAthlete.classList.remove('hidden'));
    btnOpenNewAthleteModal.addEventListener('click', () => modalAddAthlete.classList.remove('hidden'));
    btnCloseAddAthlete.addEventListener('click', () => modalAddAthlete.classList.add('hidden'));

    formAddAthlete.addEventListener('submit', async (e) => {
      e.preventDefault();
      const payload = {
        name: inputAthleteName.value.trim(),
        athlete_code: inputAthleteCode.value.trim() || null,
      };

      try {
        const created = await apiCall('/api/athletes', 'POST', payload);
        modalAddAthlete.classList.add('hidden');
        inputAthleteName.value = '';
        inputAthleteCode.value = '';
        await loadAthletes();
        selectAthlete.value = created.id;
      } catch (err) {
        alert('Failed to save athlete: ' + err.message);
      }
    });

    // AI Scan
    btnTriggerAiScan.addEventListener('click', openAiScanModal);
    btnCloseAiScan.addEventListener('click', () => modalAiScan.classList.add('hidden'));
    btnCancelAiScan.addEventListener('click', () => modalAiScan.classList.add('hidden'));
    targetImageInput.addEventListener('change', handleTargetImageSelected);
    btnApplyAiScores.addEventListener('click', applyAiScoresToCurrentEnd);
  }

  init();
});
