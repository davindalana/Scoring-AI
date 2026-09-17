// Archery Score Pro - Modern Athlete Client Engine
document.addEventListener('DOMContentLoaded', () => {
  // Global State
  const state = {
    currentSession: null,
    athletes: [],
    allSessions: [],
    sessionFilter: 'all',
    sessionSearchQuery: '',
    currentEndNumber: 1,
    currentEndArrows: [], // e.g. [{ arrow_number: 1, score: '10', is_x: false, source: 'manual' }]
    activeSlotIndex: 0,
    progressionChart: null,
    editingEnd: null, // For interactive end correction modal
    editActiveSlotIndex: 0,
    editEndArrows: [],
  };

  // DOM Elements - Views
  const viewHome = document.getElementById('viewHome');
  const viewScoring = document.getElementById('viewScoring');
  const viewSummary = document.getElementById('viewSummary');

  // Navigation
  const navHomeBtn = document.getElementById('navHomeBtn');
  const btnManageAthletes = document.getElementById('btnManageAthletes');
  const btnNewSessionTop = document.getElementById('btnNewSessionTop');

  // Home Screen
  const cardStartTraining = document.getElementById('cardStartTraining');
  const cardStartCompetition = document.getElementById('cardStartCompetition');
  const recentSessionsList = document.getElementById('recentSessionsList');
  const sessionCountBadge = document.getElementById('sessionCountBadge');
  const inputSearchSessions = document.getElementById('inputSearchSessions');
  const tabPills = document.querySelectorAll('.tab-pills .tab-pill');

  // Modals - Session Creation
  const modalCreateSession = document.getElementById('modalCreateSession');
  const btnCloseCreateSession = document.getElementById('btnCloseCreateSession');
  const formCreateSession = document.getElementById('formCreateSession');
  const selectAthlete = document.getElementById('selectAthlete');
  const btnOpenNewAthleteFromSession = document.getElementById('btnOpenNewAthleteFromSession');
  const selectBowCategory = document.getElementById('selectBowCategory');
  const selectSessionType = document.getElementById('selectSessionType');
  const selectDistance = document.getElementById('selectDistance');
  const inputCustomDistance = document.getElementById('inputCustomDistance');
  const selectArrowsPerEnd = document.getElementById('selectArrowsPerEnd');
  const inputTotalEnds = document.getElementById('inputTotalEnds');

  // Modals - Athlete Directory
  const modalAthletes = document.getElementById('modalAthletes');
  const btnCloseAthletes = document.getElementById('btnCloseAthletes');
  const tabAthleteList = document.getElementById('tabAthleteList');
  const tabAthleteNew = document.getElementById('tabAthleteNew');
  const panelAthleteList = document.getElementById('panelAthleteList');
  const panelAthleteNew = document.getElementById('panelAthleteNew');
  const inputSearchAthletes = document.getElementById('inputSearchAthletes');
  const athletesListContainer = document.getElementById('athletesListContainer');
  const formAddAthlete = document.getElementById('formAddAthlete');
  const inputAthleteName = document.getElementById('inputAthleteName');
  const inputAthleteCode = document.getElementById('inputAthleteCode');

  // Modals - Interactive End Editor
  const modalEditEnd = document.getElementById('modalEditEnd');
  const btnCloseEditEnd = document.getElementById('btnCloseEditEnd');
  const btnCancelEditEnd = document.getElementById('btnCancelEditEnd');
  const btnSaveEditEnd = document.getElementById('btnSaveEditEnd');
  const editEndModalTitle = document.getElementById('editEndModalTitle');
  const editEndSlotsContainer = document.getElementById('editEndSlotsContainer');

  // Modals - Confirmation
  const modalConfirm = document.getElementById('modalConfirm');
  const confirmModalTitle = document.getElementById('confirmModalTitle');
  const confirmModalMessage = document.getElementById('confirmModalMessage');
  const btnConfirmCancel = document.getElementById('btnConfirmCancel');
  const btnConfirmOk = document.getElementById('btnConfirmOk');
  const btnDismissConfirm = document.getElementById('btnDismissConfirm');
  let confirmResolve = null;

  // Scoring View Elements
  const scoreAthleteName = document.getElementById('scoreAthleteName');
  const scoreAthleteAvatar = document.getElementById('scoreAthleteAvatar');
  const scoreSessionBadge = document.getElementById('scoreSessionBadge');
  const scoreSessionMeta = document.getElementById('scoreSessionMeta');
  const btnAbandonSession = document.getElementById('btnAbandonSession');
  const btnToggleTargetFace = document.getElementById('btnToggleTargetFace');
  const targetToggleText = document.getElementById('targetToggleText');
  const targetFaceWrapper = document.getElementById('targetFaceWrapper');
  const scoreCurrentEnd = document.getElementById('scoreCurrentEnd');
  const scoreEndTotal = document.getElementById('scoreEndTotal');
  const scoreEndX = document.getElementById('scoreEndX');
  const scoreSessionTotal = document.getElementById('scoreSessionTotal');
  const scoreRunningAvg = document.getElementById('scoreRunningAvg');
  const arrowSlotsContainer = document.getElementById('arrowSlotsContainer');
  const endCompleteBanner = document.getElementById('endCompleteBanner');
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
  const sumGoldPercent = document.getElementById('sumGoldPercent');
  const summaryScorecardBody = document.getElementById('summaryScorecardBody');
  const btnBackHomeFromSummary = document.getElementById('btnBackHomeFromSummary');
  const btnNewSessionFromSummary = document.getElementById('btnNewSessionFromSummary');
  const btnPrintScorecard = document.getElementById('btnPrintScorecard');

  // AI Modal
  const modalAiScan = document.getElementById('modalAiScan');
  const btnCloseAiScan = document.getElementById('btnCloseAiScan');
  const fileDropzone = document.getElementById('fileDropzone');
  const dropzoneClickArea = document.getElementById('dropzoneClickArea');
  const targetImageInput = document.getElementById('targetImageInput');
  const aiScanLoading = document.getElementById('aiScanLoading');
  const aiScanResults = document.getElementById('aiScanResults');
  const aiDetectedChips = document.getElementById('aiDetectedChips');
  const btnCancelAiScan = document.getElementById('btnCancelAiScan');
  const btnApplyAiScores = document.getElementById('btnApplyAiScores');

  let detectedAiArrows = [];

  // ==================== TOAST NOTIFICATION ENGINE ====================
  function showToast(message, type = 'info', duration = 3500) {
    const container = document.getElementById('toastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    let icon = 'ℹ️';
    if (type === 'success') icon = '✓';
    else if (type === 'error') icon = '⚠️';
    else if (type === 'warning') icon = '⚡';

    toast.innerHTML = `
      <span style="font-size:1.1rem;">${icon}</span>
      <span style="flex:1;">${message}</span>
    `;

    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(-10px)';
      setTimeout(() => toast.remove(), 250);
    }, duration);
  }

  // ==================== CUSTOM CONFIRMATION MODAL ====================
  function showConfirm(title, message, okText = 'Confirm', cancelText = 'Cancel') {
    return new Promise(resolve => {
      confirmResolve = resolve;
      confirmModalTitle.textContent = title;
      confirmModalMessage.textContent = message;
      btnConfirmOk.textContent = okText;
      btnConfirmCancel.textContent = cancelText;
      modalConfirm.classList.remove('hidden');
    });
  }

  function closeConfirmModal(result) {
    modalConfirm.classList.add('hidden');
    if (confirmResolve) {
      confirmResolve(result);
      confirmResolve = null;
    }
  }

  btnConfirmOk.addEventListener('click', () => closeConfirmModal(true));
  btnConfirmCancel.addEventListener('click', () => closeConfirmModal(false));
  btnDismissConfirm.addEventListener('click', () => closeConfirmModal(false));

  // ==================== INITIALIZATION ====================
  async function init() {
    setupEventListeners();
    setupKeyboardShortcuts();
    setupTargetFaceInteraction();
    await loadAthletes();
    await loadRecentSessions();
  }

  // ==================== ROUTING / VIEW NAVIGATION ====================
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

  // ==================== ATHLETE DIRECTORY & MANAGEMENT ====================
  async function loadAthletes() {
    try {
      state.athletes = await apiCall('/api/athletes');
      renderAthleteDropdown();
      renderAthletesDirectory();
    } catch (err) {
      console.error('Failed to load athletes', err);
      showToast('Failed to load athletes.', 'error');
    }
  }

  function renderAthleteDropdown() {
    selectAthlete.innerHTML = '<option value="">Select an athlete...</option>';
    state.athletes.forEach(a => {
      const opt = document.createElement('option');
      opt.value = a.id;
      opt.textContent = `${a.name} ${a.athlete_code ? `(${a.athlete_code})` : ''}`;
      selectAthlete.appendChild(opt);
    });
  }

  function renderAthletesDirectory() {
    if (!athletesListContainer) return;
    athletesListContainer.innerHTML = '';

    const query = (inputSearchAthletes.value || '').trim().toLowerCase();
    const filtered = state.athletes.filter(a => {
      const nameMatch = a.name.toLowerCase().includes(query);
      const codeMatch = (a.athlete_code || '').toLowerCase().includes(query);
      return nameMatch || codeMatch;
    });

    if (filtered.length === 0) {
      athletesListContainer.innerHTML = `
        <div class="text-muted text-center p-3">
          ${query ? 'No matching athletes found.' : 'No athletes registered yet.'}
        </div>
      `;
      return;
    }

    filtered.forEach(a => {
      const card = document.createElement('div');
      card.className = 'athlete-dir-card';
      const initials = a.name.split(' ').map(p => p[0]).join('').substring(0, 2).toUpperCase();

      card.innerHTML = `
        <div style="display:flex; align-items:center; gap:0.75rem;">
          <span class="athlete-avatar" style="width:36px; height:36px; font-size:0.95rem;">${initials}</span>
          <div>
            <div style="font-weight:700; font-size:0.95rem;">${a.name}</div>
            <div style="color:var(--text-secondary); font-size:0.8rem;">
              ${a.athlete_code ? `Code: ${a.athlete_code}` : 'No code'}
            </div>
          </div>
        </div>
        <div>
          <button class="btn btn-sm btn-primary btn-select-athlete-shoot" data-id="${a.id}">
            Shoot ➔
          </button>
        </div>
      `;

      card.querySelector('.btn-select-athlete-shoot').addEventListener('click', () => {
        selectAthlete.value = a.id;
        modalAthletes.classList.add('hidden');
        modalCreateSession.classList.remove('hidden');
      });

      athletesListContainer.appendChild(card);
    });
  }

  // ==================== RECENT SESSIONS & FILTERING ====================
  async function loadRecentSessions() {
    try {
      const sessions = await apiCall('/api/sessions?limit=50');
      state.allSessions = sessions || [];
      renderSessionsList();
    } catch (err) {
      recentSessionsList.innerHTML = '<div class="text-center text-secondary p-3">Failed to load sessions.</div>';
    }
  }

  function renderSessionsList() {
    let list = state.allSessions;

    // Filter by status tab
    if (state.sessionFilter !== 'all') {
      list = list.filter(s => s.status === state.sessionFilter);
    }

    // Filter by search query
    if (state.sessionSearchQuery) {
      const q = state.sessionSearchQuery.toLowerCase();
      list = list.filter(s => {
        const ath = (s.athlete_name || '').toLowerCase();
        const bow = (s.bow_category || '').toLowerCase();
        return ath.includes(q) || bow.includes(q);
      });
    }

    sessionCountBadge.textContent = `${list.length} sessions`;

    if (list.length === 0) {
      recentSessionsList.innerHTML = `
        <div style="text-align:center; color:var(--text-secondary); padding:2.5rem; background:var(--bg-card); border-radius:var(--radius-md); border:1px dashed var(--border-glass);">
          ${state.sessionSearchQuery ? 'No matching sessions found.' : 'No sessions recorded yet. Tap <strong>Start Practice</strong> or <strong>+ New Session</strong> to begin.'}
        </div>
      `;
      return;
    }

    recentSessionsList.innerHTML = '';
    list.forEach(s => {
      const item = document.createElement('div');
      item.className = 'session-item';
      const isComplete = s.status === 'completed';
      const dateStr = s.started_at
        ? new Date(s.started_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
        : '';
      const athleteName = s.athlete_name || 'Athlete';
      const initials = athleteName.split(' ').map(p => p[0]).join('').substring(0, 2).toUpperCase();

      item.innerHTML = `
        <div class="session-item-main">
          <div class="session-avatar">${initials}</div>
          <div>
            <div class="session-title">${athleteName}</div>
            <div class="session-sub">
              ${s.bow_category} • ${s.distance} • ${s.arrows_per_end} arr/end • ${dateStr}
            </div>
          </div>
        </div>
        <div class="session-item-right">
          <span class="session-badge ${isComplete ? 'badge-completed' : 'badge-progress'}">
            ${isComplete ? 'Completed' : `End ${s.current_end}/${s.total_ends}`}
          </span>
          <button class="btn-icon-danger btn-delete-session" title="Delete Session" data-id="${s.id}">
            🗑️
          </button>
          <span style="font-size:1.1rem; color:var(--text-muted); margin-left:0.25rem;">➔</span>
        </div>
      `;

      // Click card to open session (unless clicking delete)
      item.addEventListener('click', (e) => {
        if (e.target.closest('.btn-delete-session')) return;
        openSession(s.id);
      });

      // Delete session handler
      const delBtn = item.querySelector('.btn-delete-session');
      delBtn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const confirmed = await showConfirm(
          'Delete Scoring Session',
          `Are you sure you want to permanently delete this ${s.bow_category} session for ${athleteName}? All recorded ends will be removed.`
        );
        if (confirmed) {
          try {
            await apiCall(`/api/sessions/${s.id}`, 'DELETE');
            showToast('Session deleted successfully.', 'success');
            await loadRecentSessions();
          } catch (err) {
            showToast('Failed to delete session: ' + err.message, 'error');
          }
        }
      });

      recentSessionsList.appendChild(item);
    });
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
      showToast('Error loading session: ' + err.message, 'error');
    }
  }

  // ==================== SCORING SETUP ====================
  function setupScoringScreen(details) {
    const s = details.session;
    const athleteName = details.athlete ? details.athlete.name : s.athlete_name || 'Athlete';
    scoreAthleteName.textContent = athleteName;
    scoreAthleteAvatar.textContent = athleteName.split(' ').map(p => p[0]).join('').substring(0, 2).toUpperCase();
    scoreSessionBadge.textContent = s.bow_category;
    scoreSessionMeta.textContent = `${s.distance} • ${s.arrows_per_end} Arrows/End • ${s.session_type.toUpperCase()}`;

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
    let allFilled = true;

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
        allFilled = false;
      }

      slot.addEventListener('click', () => {
        triggerHaptic();
        state.activeSlotIndex = index;
        renderArrowSlots();
      });

      arrowSlotsContainer.appendChild(slot);
    });

    // Show/hide End Complete Banner
    if (allFilled && state.currentEndArrows.length > 0) {
      endCompleteBanner.classList.remove('hidden');
    } else {
      endCompleteBanner.classList.add('hidden');
    }

    calculateLiveEndTotal();
  }

  function calculateLiveEndTotal() {
    let total = 0;
    let xCount = 0;
    let filledCount = 0;

    state.currentEndArrows.forEach(a => {
      if (a.score !== null) {
        filledCount++;
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

    // Running arrow average
    if (filledCount > 0) {
      scoreRunningAvg.textContent = (total / filledCount).toFixed(2);
    } else {
      scoreRunningAvg.textContent = '0.0';
    }
  }

  function updateLiveMetrics(summary) {
    if (summary) {
      scoreSessionTotal.textContent = summary.total_score || 0;
      if (summary.total_arrows > 0) {
        scoreRunningAvg.textContent = summary.average_score_per_arrow.toFixed(2);
      }
    }
  }

  function renderLiveScorecard(ends) {
    liveScorecardBody.innerHTML = '';
    if (!ends || ends.length === 0) {
      liveScorecardBody.innerHTML = '<tr><td colspan="6" class="text-muted">No completed ends yet.</td></tr>';
      return;
    }

    let runningTotal = 0;
    ends.forEach(end => {
      runningTotal += end.total_score;
      const arrowDisplay = (end.arrows || [])
        .map(a => `<span class="arrow-chip-display">${a.is_x ? 'X' : (a.score === 0 ? 'M' : a.score)}</span>`)
        .join('');

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td style="font-weight:700;">#${end.end_number}</td>
        <td>${arrowDisplay}</td>
        <td style="font-weight:700; color:var(--ring-gold);">${end.total_score}</td>
        <td>${end.x_count}</td>
        <td style="font-weight:800;">${runningTotal}</td>
        <td><button class="btn btn-sm btn-secondary btn-edit-end" data-end="${end.end_number}">Edit</button></td>
      `;

      tr.querySelector('.btn-edit-end').addEventListener('click', () => openEditEndModal(end));
      liveScorecardBody.appendChild(tr);
    });
  }

  // ==================== INTERACTIVE END CORRECTION MODAL ====================
  function openEditEndModal(end) {
    state.editingEnd = end;
    state.editActiveSlotIndex = 0;
    state.editEndArrows = (end.arrows || []).map((a, idx) => ({
      arrow_number: idx + 1,
      score: a.is_x ? 'X' : (a.score === 0 ? 'M' : String(a.score)),
      is_x: Boolean(a.is_x),
    }));

    editEndModalTitle.textContent = `Edit End #${end.end_number} Scores`;
    renderEditEndSlots();
    modalEditEnd.classList.remove('hidden');
  }

  function renderEditEndSlots() {
    editEndSlotsContainer.innerHTML = '';
    state.editEndArrows.forEach((arr, idx) => {
      const slot = document.createElement('div');
      slot.className = 'arrow-slot filled';
      if (idx === state.editActiveSlotIndex) slot.classList.add('active');

      const scoreStr = String(arr.score).toUpperCase();
      slot.textContent = arr.is_x ? 'X' : scoreStr;

      if (arr.is_x || scoreStr === 'X') slot.classList.add('score-x');
      else if (scoreStr === '10' || scoreStr === '9') slot.classList.add('score-10');
      else if (scoreStr === '8' || scoreStr === '7') slot.classList.add('score-8');
      else if (scoreStr === '6' || scoreStr === '5') slot.classList.add('score-6');
      else if (scoreStr === '4' || scoreStr === '3') slot.classList.add('score-4');
      else if (scoreStr === '2' || scoreStr === '1') slot.classList.add('score-2');
      else if (scoreStr === 'M' || scoreStr === '0') slot.classList.add('score-m');

      slot.addEventListener('click', () => {
        triggerHaptic();
        state.editActiveSlotIndex = idx;
        renderEditEndSlots();
      });

      editEndSlotsContainer.appendChild(slot);
    });
  }

  function handleEditKeypadInput(val) {
    if (!state.editingEnd || state.editEndArrows.length === 0) return;
    const slot = state.editEndArrows[state.editActiveSlotIndex];
    if (!slot) return;

    if (val === 'X') {
      slot.score = 'X';
      slot.is_x = true;
    } else if (val === 'M') {
      slot.score = 'M';
      slot.is_x = false;
    } else {
      slot.score = val;
      slot.is_x = false;
    }

    if (state.editActiveSlotIndex < state.editEndArrows.length - 1) {
      state.editActiveSlotIndex++;
    }

    renderEditEndSlots();
  }

  document.querySelectorAll('.edit-keypad-btn').forEach(btn => {
    btn.addEventListener('click', () => handleEditKeypadInput(btn.dataset.val));
  });

  btnCloseEditEnd.addEventListener('click', () => modalEditEnd.classList.add('hidden'));
  btnCancelEditEnd.addEventListener('click', () => modalEditEnd.classList.add('hidden'));

  btnSaveEditEnd.addEventListener('click', async () => {
    if (!state.editingEnd) return;
    const payload = {
      arrows: state.editEndArrows.map(a => ({
        arrow_number: a.arrow_number,
        score: a.score,
        is_x: a.is_x,
        source: 'manual',
      })),
    };

    try {
      await apiCall(`/api/sessions/${state.currentSession.id}/ends/${state.editingEnd.end_number}`, 'PUT', payload);
      modalEditEnd.classList.add('hidden');
      showToast(`End #${state.editingEnd.end_number} updated successfully!`, 'success');

      const details = await apiCall(`/api/sessions/${state.currentSession.id}`);
      renderLiveScorecard(details.ends);
      updateLiveMetrics(details.summary);
    } catch (err) {
      showToast('Failed to update end: ' + err.message, 'error');
    }
  });

  // ==================== KEYPAD & INPUT LOGIC ====================
  function handleKeypadInput(value) {
    triggerHaptic();
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

    // Flash target ring highlight
    illuminateTargetRing(value);

    // Auto advance to next slot if available
    if (state.activeSlotIndex < state.currentSession.arrows_per_end - 1) {
      state.activeSlotIndex++;
    }

    renderArrowSlots();
  }

  function handleUndo() {
    triggerHaptic();
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

  function triggerHaptic() {
    if ('vibrate' in navigator) {
      try { navigator.vibrate(15); } catch (_) {}
    }
  }

  // ==================== INTERACTIVE TARGET FACE ====================
  function setupTargetFaceInteraction() {
    document.querySelectorAll('.target-ring').forEach(ring => {
      ring.addEventListener('click', (e) => {
        e.stopPropagation();
        const val = ring.dataset.val;
        if (val) {
          handleKeypadInput(val);
        }
      });
    });

    btnToggleTargetFace.addEventListener('click', () => {
      const isHidden = targetFaceWrapper.classList.toggle('hidden');
      if (isHidden) {
        targetToggleText.textContent = 'Show Target';
      } else {
        targetToggleText.textContent = 'Hide Target';
      }
    });
  }

  function illuminateTargetRing(val) {
    const selector = `.target-ring[data-val="${val}"]`;
    const ring = document.querySelector(selector);
    if (ring) {
      ring.classList.add('lit');
      setTimeout(() => ring.classList.remove('lit'), 350);
    }
  }

  // ==================== DESKTOP KEYBOARD SHORTCUTS ====================
  function setupKeyboardShortcuts() {
    window.addEventListener('keydown', (e) => {
      // Ignore when user is typing in form inputs
      const tag = document.activeElement ? document.activeElement.tagName.toLowerCase() : '';
      if (tag === 'input' || tag === 'select' || tag === 'textarea') return;

      if (!viewScoring.classList.contains('hidden')) {
        const k = e.key.toUpperCase();
        if (k === 'X') {
          e.preventDefault();
          handleKeypadInput('X');
        } else if (k === 'M') {
          e.preventDefault();
          handleKeypadInput('M');
        } else if (k === '0') {
          e.preventDefault();
          handleKeypadInput('10');
        } else if (k >= '1' && k <= '9') {
          e.preventDefault();
          handleKeypadInput(k);
        } else if (e.key === 'Backspace' || e.key === 'Delete') {
          e.preventDefault();
          handleUndo();
        } else if (e.key === 'Enter') {
          e.preventDefault();
          submitCurrentEnd();
        } else if (e.key === 'ArrowLeft') {
          e.preventDefault();
          if (state.activeSlotIndex > 0) {
            state.activeSlotIndex--;
            renderArrowSlots();
          }
        } else if (e.key === 'ArrowRight') {
          e.preventDefault();
          if (state.activeSlotIndex < state.currentSession.arrows_per_end - 1) {
            state.activeSlotIndex++;
            renderArrowSlots();
          }
        }
      }
    });
  }

  // ==================== SUBMIT END ====================
  async function submitCurrentEnd() {
    // Check if all slots are filled
    const unfilled = state.currentEndArrows.filter(a => a.score === null);
    if (unfilled.length > 0) {
      const confirmIncomplete = await showConfirm(
        'Unfilled Arrows Warning',
        `You have ${unfilled.length} unfilled arrow(s) in this end. Unfilled arrows will be recorded as Miss (M, 0 pts). Do you want to proceed?`,
        'Submit as Misses',
        'Keep Scoring'
      );
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
      showToast(`End #${state.currentEndNumber} saved!`, 'success');

      const details = await apiCall(`/api/sessions/${state.currentSession.id}`);

      if (details.session.status === 'completed' || state.currentEndNumber >= state.currentSession.total_ends) {
        renderSummaryScreen(details);
        showView('summary');
      } else {
        setupScoringScreen(details);
      }
    } catch (err) {
      showToast('Failed to save end: ' + err.message, 'error');
    }
  }

  // ==================== SUMMARY SCREEN ====================
  function renderSummaryScreen(details) {
    const s = details.session;
    const sum = details.summary;
    const ath = details.athlete;

    const athleteName = ath ? ath.name : s.athlete_name || 'Athlete';
    summaryAthleteInfo.textContent = `${athleteName} • ${s.bow_category} • ${s.distance} • ${s.session_type.toUpperCase()}`;
    sumFinalScore.textContent = sum.total_score;
    sumTotalX.textContent = sum.total_x;
    sumAvgArrow.textContent = sum.average_score_per_arrow.toFixed(2);
    sumAvgEnd.textContent = sum.average_score_per_end.toFixed(1);
    sumTotalArrows.textContent = sum.total_arrows;

    // Gold percentage (% of 10s and Xs)
    let tenOrXCount = 0;
    (details.ends || []).forEach(end => {
      (end.arrows || []).forEach(arr => {
        if (arr.is_x || arr.score === 10 || String(arr.score).toUpperCase() === '10' || String(arr.score).toUpperCase() === 'X') {
          tenOrXCount++;
        }
      });
    });
    if (sum.total_arrows > 0) {
      sumGoldPercent.textContent = `${Math.round((tenOrXCount / sum.total_arrows) * 100)}%`;
    } else {
      sumGoldPercent.textContent = '0%';
    }

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
        .map(a => `<span class="arrow-chip-display">${a.is_x ? 'X' : (a.score === 0 ? 'M' : a.score)}</span>`)
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
            backgroundColor: 'rgba(245, 158, 11, 0.12)',
            fill: true,
            tension: 0.35,
            yAxisID: 'yCumulative',
            pointBackgroundColor: '#f59e0b',
            pointRadius: 4,
          },
          {
            label: 'End Score',
            data: endScores,
            borderColor: '#38bdf8',
            backgroundColor: '#38bdf8',
            type: 'bar',
            yAxisID: 'yEnd',
            borderRadius: 6,
            barThickness: 24,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            labels: { color: '#f0f6fc', font: { family: 'Inter', weight: 600 } },
          },
        },
        scales: {
          x: {
            ticks: { color: '#8b949e', font: { family: 'Inter' } },
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
      showToast('AI analysis completed! Review detected scores.', 'success');
    } catch (err) {
      aiScanLoading.classList.add('hidden');
      showToast('AI Detection error: ' + err.message, 'error');
    }
  }

  function renderAiDetectedChips() {
    aiDetectedChips.innerHTML = '';
    detectedAiArrows.forEach((arr) => {
      const chip = document.createElement('button');
      chip.type = 'button';
      chip.className = 'btn btn-secondary';
      chip.style.padding = '0.55rem 1rem';
      chip.style.fontWeight = '700';
      chip.innerHTML = `<span>Arrow #${arr.arrow_number}:</span> <span style="color:var(--ring-gold); font-size:1.1rem; margin-left:4px;">${arr.score}</span>`;

      chip.addEventListener('click', async () => {
        const currentScore = arr.score;
        const options = ['X', '10', '9', '8', '7', '6', '5', '4', '3', '2', '1', 'M'];
        const nextIdx = (options.indexOf(currentScore) + 1) % options.length;
        const newScore = options[nextIdx >= 0 ? nextIdx : 0];
        arr.score = newScore;
        arr.is_x = newScore === 'X';
        renderAiDetectedChips();
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
    showToast('AI scores applied to current end!', 'success');
  }

  // ==================== EVENT LISTENERS SETUP ====================
  function setupEventListeners() {
    navHomeBtn.addEventListener('click', () => showView('home'));
    btnBackHomeFromSummary.addEventListener('click', () => showView('home'));

    // Keypad clicks
    document.querySelectorAll('.keypad-grid:not([style*="gap: 0.5rem"]) .keypad-btn').forEach(btn => {
      btn.addEventListener('click', () => handleKeypadInput(btn.dataset.val));
    });

    btnUndoArrow.addEventListener('click', handleUndo);
    btnSubmitEnd.addEventListener('click', submitCurrentEnd);

    btnAbandonSession.addEventListener('click', async () => {
      const confirmLeave = await showConfirm(
        'Exit Session',
        'Leave this scoring round? Your progress and completed ends are saved automatically.',
        'Exit to Home',
        'Stay'
      );
      if (confirmLeave) {
        showView('home');
      }
    });

    // Start Session Buttons
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

    // Session Filters
    tabPills.forEach(pill => {
      pill.addEventListener('click', () => {
        tabPills.forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        state.sessionFilter = pill.dataset.filter;
        renderSessionsList();
      });
    });

    inputSearchSessions.addEventListener('input', (e) => {
      state.sessionSearchQuery = e.target.value.trim();
      renderSessionsList();
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
        showToast('Please select an athlete.', 'warning');
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
        showToast('Scoring session started!', 'success');
        await openSession(created.id);
      } catch (err) {
        showToast('Failed to start session: ' + err.message, 'error');
      }
    });

    // Athlete Management Modal
    btnManageAthletes.addEventListener('click', () => {
      modalAthletes.classList.remove('hidden');
      tabAthleteList.click();
    });

    btnOpenNewAthleteFromSession.addEventListener('click', () => {
      modalCreateSession.classList.add('hidden');
      modalAthletes.classList.remove('hidden');
      tabAthleteNew.click();
    });

    btnCloseAthletes.addEventListener('click', () => modalAthletes.classList.add('hidden'));

    tabAthleteList.addEventListener('click', () => {
      tabAthleteList.classList.add('active');
      tabAthleteNew.classList.remove('active');
      panelAthleteList.classList.remove('hidden');
      panelAthleteNew.classList.add('hidden');
      renderAthletesDirectory();
    });

    tabAthleteNew.addEventListener('click', () => {
      tabAthleteNew.classList.add('active');
      tabAthleteList.classList.remove('active');
      panelAthleteNew.classList.remove('hidden');
      panelAthleteList.classList.add('hidden');
      inputAthleteName.focus();
    });

    inputSearchAthletes.addEventListener('input', renderAthletesDirectory);

    formAddAthlete.addEventListener('submit', async (e) => {
      e.preventDefault();
      const payload = {
        name: inputAthleteName.value.trim(),
        athlete_code: inputAthleteCode.value.trim() || null,
      };

      try {
        const created = await apiCall('/api/athletes', 'POST', payload);
        showToast(`Athlete "${created.name}" registered!`, 'success');
        inputAthleteName.value = '';
        inputAthleteCode.value = '';
        await loadAthletes();
        tabAthleteList.click();
      } catch (err) {
        showToast('Failed to save athlete: ' + err.message, 'error');
      }
    });

    // AI Scan Modal Events
    btnTriggerAiScan.addEventListener('click', openAiScanModal);
    btnCloseAiScan.addEventListener('click', () => modalAiScan.classList.add('hidden'));
    btnCancelAiScan.addEventListener('click', () => modalAiScan.classList.add('hidden'));
    targetImageInput.addEventListener('change', handleTargetImageSelected);
    btnApplyAiScores.addEventListener('click', applyAiScoresToCurrentEnd);

    // Scorecard Print
    btnPrintScorecard.addEventListener('click', () => {
      window.print();
    });
  }

  init();
});
