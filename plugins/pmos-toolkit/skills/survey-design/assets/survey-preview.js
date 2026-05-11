/* survey-preview.js -- standalone fillable preview engine for a /survey-design survey.
 *
 * Reads the survey definition from an inline <script type="application/json" id="survey-data">
 * element (the full survey.json), renders it one section (or one question on narrow viewports)
 * at a time with Back/Next navigation, honours skip_logic, validates required questions, shows a
 * text "Question X of Y" indicator, and ends on a thank-you screen with an optional answers dump.
 *
 * Constraints: vanilla JS, ASCII-only source, no dependencies, no network calls, no browser storage,
 * not an ES module -- works as a plain <script src="survey-preview.js"></script> under file://.
 * The page's preview.html provides the CSS (an inline <style>); this file only touches the DOM.
 */
(function () {
  "use strict";

  var TYPES = {
    SINGLE_SELECT: "single_select",
    MULTI_SELECT: "multi_select",
    FORCED_CHOICE_GRID: "forced_choice_grid",
    RATING: "rating",
    NPS: "nps",
    DICHOTOMOUS: "dichotomous",
    OPEN_SHORT: "open_short",
    OPEN_LONG: "open_long",
    RANKING: "ranking",
    MATRIX: "matrix",
    CONSTANT_SUM: "constant_sum",
    STATEMENT: "statement"
  };

  var survey = null;       // parsed survey.json
  var answers = {};        // { questionId: value }
  var screens = [];        // ordered list of screen descriptors: {kind:"intro"|"section"|"thankyou", sectionIndex?}
  var historyStack = [];   // indices into `screens` already visited (for Back)
  var currentScreen = 0;   // index into `screens`
  var consentChecked = false;
  var root = null;

  // ---------- bootstrap ----------

  function init() {
    root = document.getElementById("survey-root") || document.body;
    var dataEl = document.getElementById("survey-data");
    if (!dataEl) {
      renderError("No <script id=\"survey-data\"> element found on the page.");
      return;
    }
    try {
      survey = JSON.parse(dataEl.textContent);
    } catch (e) {
      renderError("Could not parse survey-data JSON: " + (e && e.message ? e.message : String(e)));
      return;
    }
    if (!survey || !Array.isArray(survey.sections)) {
      renderError("survey-data parsed, but it has no `sections` array.");
      return;
    }
    buildScreenList();
    currentScreen = 0;
    historyStack = [];
    renderCurrent();
  }

  function buildScreenList() {
    screens = [{ kind: "intro" }];
    for (var i = 0; i < survey.sections.length; i++) {
      screens.push({ kind: "section", sectionIndex: i });
    }
    screens.push({ kind: "thankyou" });
  }

  // ---------- path / progress ----------

  // The "active path" is the set of section screens reachable from the current answers, honouring
  // skip_logic. We approximate it forward from screen 0: walk sections in order, and when a section
  // has an answered question with a skip_logic jump, the path continues at the jump target.
  function activeSectionIndices() {
    var path = [];
    var i = 1; // first section screen
    var guard = 0;
    while (i < screens.length && screens[i].kind === "section" && guard < 1000) {
      guard++;
      var sec = survey.sections[screens[i].sectionIndex];
      path.push(screens[i].sectionIndex);
      var jump = sectionJumpTarget(sec);
      if (jump === "__end__") { break; }
      if (jump !== null) {
        var nextScreen = screenIndexForSectionId(jump);
        if (nextScreen > i) { i = nextScreen; continue; }
      }
      i++;
    }
    return path;
  }

  function sectionJumpTarget(sec) {
    if (!sec || !Array.isArray(sec.questions)) { return null; }
    for (var q = 0; q < sec.questions.length; q++) {
      var question = sec.questions[q];
      var sl = question.skip_logic;
      if (!sl) { continue; }
      var ans = answers[question.id];
      if (ans === undefined || ans === null || ans === "") { continue; }
      var rules = Array.isArray(sl) ? sl : [sl];
      for (var r = 0; r < rules.length; r++) {
        var rule = rules[r];
        if (ruleMatches(rule, ans)) {
          if (rule.action === "end_survey") { return "__end__"; }
          if (rule.action === "skip_to" && rule.target_section_id) { return rule.target_section_id; }
        }
      }
    }
    return null;
  }

  function ruleMatches(rule, ans) {
    // Canonical schema field is `on_value` (a single value or an array of values).
    // `value` / `equals` / `when` are tolerated legacy aliases. A rule with none of
    // these matches whenever the question is answered.
    var target = rule.on_value;
    if (target === undefined) { target = rule.value; }
    if (target === undefined) { target = rule.equals; }
    if (target === undefined) { target = rule.when; }
    if (target === undefined) { return true; }
    var accepted = Array.isArray(target) ? target : [target];
    for (var t = 0; t < accepted.length; t++) {
      if (Array.isArray(ans)) {
        if (ans.indexOf(accepted[t]) !== -1) { return true; }
      } else if (String(ans) === String(accepted[t])) {
        return true;
      }
    }
    return false;
  }

  function screenIndexForSectionId(sectionId) {
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].kind === "section" && survey.sections[screens[i].sectionIndex].id === sectionId) { return i; }
    }
    return -1;
  }

  function countableQuestions(sectionIndex) {
    var sec = survey.sections[sectionIndex];
    var n = 0;
    if (sec && Array.isArray(sec.questions)) {
      for (var i = 0; i < sec.questions.length; i++) {
        if (sec.questions[i].type !== TYPES.STATEMENT) { n++; }
      }
    }
    return n;
  }

  function progressText() {
    var path = activeSectionIndices();
    var total = 0, reached = 0;
    var curSecIdx = screens[currentScreen].kind === "section" ? screens[currentScreen].sectionIndex : -1;
    var seenCurrent = false;
    for (var i = 0; i < path.length; i++) {
      var c = countableQuestions(path[i]);
      total += c;
      if (path[i] === curSecIdx) { seenCurrent = true; reached += c; }
      else if (!seenCurrent) { reached += c; }
    }
    if (curSecIdx === -1) { reached = total; }
    if (total === 0) { return ""; }
    return "Question " + Math.min(reached, total) + " of " + total;
  }

  // ---------- rendering ----------

  function clearRoot() { while (root.firstChild) { root.removeChild(root.firstChild); } }

  function el(tag, attrs, text) {
    var node = document.createElement(tag);
    if (attrs) { for (var k in attrs) { if (attrs.hasOwnProperty(k)) { node.setAttribute(k, attrs[k]); } } }
    if (text !== undefined && text !== null) { node.appendChild(document.createTextNode(String(text))); }
    return node;
  }

  function renderError(msg) {
    if (!root) { root = document.getElementById("survey-root") || document.body; }
    clearRoot();
    var box = el("div", { "class": "preview-error", "role": "alert" });
    box.appendChild(el("h2", null, "Preview unavailable"));
    box.appendChild(el("p", null, msg));
    root.appendChild(box);
  }

  function renderCurrent() {
    clearRoot();
    var scr = screens[currentScreen];
    if (scr.kind === "intro") { renderIntro(); }
    else if (scr.kind === "section") { renderSection(scr.sectionIndex); }
    else { renderThankYou(); }
    var top = document.getElementById("survey-root") || document.body;
    if (top && top.scrollIntoView) { try { top.scrollIntoView(); } catch (e) {} }
  }

  function renderIntro() {
    var wrap = el("div", { "class": "preview-screen preview-intro" });
    wrap.appendChild(el("h1", null, survey.title || "Survey"));
    var intro = survey.intro || {};
    if (intro.text) { wrap.appendChild(el("p", { "class": "intro-text" }, intro.text)); }
    var metaBits = [];
    if (survey.mode) { metaBits.push("Mode: " + survey.mode); }
    if (survey.time_budget_min) { metaBits.push("Target: ~" + survey.time_budget_min + " min"); }
    if (survey.estimated_minutes) { metaBits.push("Estimated: " + survey.estimated_minutes + " min"); }
    if (metaBits.length) { wrap.appendChild(el("p", { "class": "intro-meta" }, metaBits.join("  -  "))); }

    if (intro.consent_required) {
      var gate = el("div", { "class": "consent-gate" });
      var label = el("label", null, null);
      var cb = el("input", { type: "checkbox", id: "consent-checkbox" });
      cb.checked = consentChecked;
      cb.addEventListener("change", function () {
        consentChecked = cb.checked;
        var startBtn = document.getElementById("intro-start");
        if (startBtn) { startBtn.disabled = !consentChecked; }
      });
      label.appendChild(cb);
      label.appendChild(document.createTextNode(" I have read the above and agree to take part."));
      gate.appendChild(label);
      wrap.appendChild(gate);
    }

    var nav = el("div", { "class": "preview-nav" });
    var start = el("button", { type: "button", id: "intro-start", "class": "btn-primary" }, "Start");
    if (intro.consent_required && !consentChecked) { start.disabled = true; }
    start.addEventListener("click", function () { goToScreen(1); });
    nav.appendChild(start);
    wrap.appendChild(nav);
    root.appendChild(wrap);
  }

  function renderSection(sectionIndex) {
    var sec = survey.sections[sectionIndex];
    var wrap = el("div", { "class": "preview-screen preview-section" });
    var prog = progressText();
    if (prog) { wrap.appendChild(el("p", { "class": "progress-indicator" }, prog)); }
    if (sec.title) { wrap.appendChild(el("h2", null, sec.title)); }
    if (sec.description) { wrap.appendChild(el("p", { "class": "section-desc" }, sec.description)); }

    var form = el("div", { "class": "section-questions" });
    var questions = Array.isArray(sec.questions) ? sec.questions : [];
    for (var i = 0; i < questions.length; i++) {
      form.appendChild(renderQuestion(questions[i]));
    }
    wrap.appendChild(form);

    var errBox = el("p", { "class": "validation-message", id: "validation-message", "role": "alert" });
    errBox.style.display = "none";
    wrap.appendChild(errBox);

    var nav = el("div", { "class": "preview-nav" });
    var back = el("button", { type: "button", "class": "btn-secondary" }, "Back");
    back.disabled = historyStack.length === 0;
    back.addEventListener("click", goBack);
    nav.appendChild(back);
    var next = el("button", { type: "button", "class": "btn-primary" }, "Next");
    next.addEventListener("click", function () { onNext(sectionIndex); });
    nav.appendChild(next);
    wrap.appendChild(nav);
    root.appendChild(wrap);
  }

  function renderThankYou() {
    var wrap = el("div", { "class": "preview-screen preview-thankyou" });
    var intro = survey.intro || {};
    var msg = intro.thankyou || (survey.thankyou) || "Thank you -- your responses have been recorded.";
    wrap.appendChild(el("h2", null, "Thanks!"));
    wrap.appendChild(el("p", null, msg));

    var toggle = el("button", { type: "button", "class": "btn-secondary" }, "Show my answers (JSON)");
    var dump = el("pre", { "class": "answers-dump" });
    dump.style.display = "none";
    dump.appendChild(document.createTextNode(JSON.stringify(answers, null, 2)));
    toggle.addEventListener("click", function () {
      dump.style.display = (dump.style.display === "none") ? "block" : "none";
    });
    wrap.appendChild(toggle);
    wrap.appendChild(dump);

    var nav = el("div", { "class": "preview-nav" });
    var back = el("button", { type: "button", "class": "btn-secondary" }, "Back");
    back.disabled = historyStack.length === 0;
    back.addEventListener("click", goBack);
    nav.appendChild(back);
    var restart = el("button", { type: "button", "class": "btn-secondary" }, "Restart preview");
    restart.addEventListener("click", function () {
      answers = {}; historyStack = []; consentChecked = false; currentScreen = 0; renderCurrent();
    });
    nav.appendChild(restart);
    wrap.appendChild(nav);
    root.appendChild(wrap);
  }

  // ---------- question rendering, per type ----------

  function renderQuestion(q) {
    var box = el("div", { "class": "question", "data-question-id": q.id, "data-question-type": q.type });
    var stem = el("h3", { id: q.id }, q.stem || q.id);
    if (q.required) { stem.appendChild(el("span", { "class": "required-marker", "aria-hidden": "true" }, " *")); }
    box.appendChild(stem);
    if (q.help_text) { box.appendChild(el("p", { "class": "help-text" }, q.help_text)); }
    if (q.reference_period) { box.appendChild(el("p", { "class": "reference-period" }, "(" + q.reference_period + ")")); }

    var t = q.type;
    if (t === TYPES.STATEMENT) { /* display only -- nothing more */ }
    else if (t === TYPES.SINGLE_SELECT || t === TYPES.DICHOTOMOUS) { box.appendChild(renderChoices(q, false)); }
    else if (t === TYPES.MULTI_SELECT) { box.appendChild(renderChoices(q, true)); }
    else if (t === TYPES.RATING || t === TYPES.NPS) { box.appendChild(renderScale(q)); }
    else if (t === TYPES.OPEN_SHORT) { box.appendChild(renderOpen(q, false)); }
    else if (t === TYPES.OPEN_LONG) { box.appendChild(renderOpen(q, true)); }
    else if (t === TYPES.RANKING) { box.appendChild(renderRanking(q)); }
    else if (t === TYPES.MATRIX) { box.appendChild(renderMatrix(q)); }
    else if (t === TYPES.FORCED_CHOICE_GRID) { box.appendChild(renderForcedChoiceGrid(q)); }
    else if (t === TYPES.CONSTANT_SUM) { box.appendChild(renderConstantSum(q)); }
    else { box.appendChild(el("p", { "class": "unknown-type" }, "[unsupported question type: " + String(t) + "]")); }
    return box;
  }

  function optionLabel(opt) {
    if (opt === null || opt === undefined) { return ""; }
    if (typeof opt === "string") { return opt; }
    return opt.label || opt.text || opt.value || String(opt);
  }
  function optionValue(opt) {
    if (typeof opt === "string") { return opt; }
    return (opt && (opt.value !== undefined ? opt.value : (opt.label || opt.text))) || "";
  }

  function renderChoices(q, multi) {
    var list = el("div", { "class": "choices" });
    var name = "q_" + q.id;
    var opts = Array.isArray(q.options) ? q.options : [];
    var i;
    for (i = 0; i < opts.length; i++) { list.appendChild(choiceRow(q, name, opts[i], multi)); }
    var hasExtra = (q.other_option) || (Array.isArray(q.opt_out_options) && q.opt_out_options.length);
    if (hasExtra) {
      list.appendChild(el("hr", { "class": "opt-out-separator" }));
      if (Array.isArray(q.opt_out_options)) {
        for (i = 0; i < q.opt_out_options.length; i++) {
          list.appendChild(choiceRow(q, name, q.opt_out_options[i], multi));
        }
      }
      if (q.other_option) {
        var row = el("div", { "class": "choice choice-other" });
        var inp = el("input", { type: (multi ? "checkbox" : "radio"), name: name, value: "__other__" });
        var lbl = el("label", null, " Other (please specify): ");
        var txt = el("input", { type: "text", "class": "other-text", "data-other-for": q.id });
        var sync = function () {
          if (multi) {
            var arr = Array.isArray(answers[q.id]) ? answers[q.id].slice() : [];
            arr = arr.filter(function (v) { return String(v).indexOf("Other:") !== 0; });
            if (inp.checked && txt.value) { arr.push("Other: " + txt.value); }
            answers[q.id] = arr;
          } else {
            if (inp.checked) { answers[q.id] = "Other: " + txt.value; }
          }
        };
        inp.addEventListener("change", sync);
        txt.addEventListener("input", function () { if (!inp.checked) { inp.checked = true; } sync(); });
        lbl.insertBefore(inp, lbl.firstChild);
        row.appendChild(lbl);
        row.appendChild(txt);
        list.appendChild(row);
      }
    }
    return list;
  }

  function choiceRow(q, name, opt, multi) {
    var row = el("div", { "class": "choice" });
    var val = optionValue(opt);
    var input = el("input", { type: (multi ? "checkbox" : "radio"), name: name, value: String(val) });
    var existing = answers[q.id];
    if (multi) { if (Array.isArray(existing) && existing.indexOf(val) !== -1) { input.checked = true; } }
    else { if (existing !== undefined && String(existing) === String(val)) { input.checked = true; } }
    input.addEventListener("change", function () {
      if (multi) {
        var arr = Array.isArray(answers[q.id]) ? answers[q.id].slice() : [];
        var idx = arr.indexOf(val);
        if (input.checked && idx === -1) { arr.push(val); }
        if (!input.checked && idx !== -1) { arr.splice(idx, 1); }
        answers[q.id] = arr;
      } else {
        answers[q.id] = val;
      }
    });
    var label = el("label", null, " " + optionLabel(opt));
    label.insertBefore(input, label.firstChild);
    row.appendChild(label);
    return row;
  }

  function renderScale(q) {
    var wrap = el("div", { "class": "scale" });
    var sc = q.scale || {};
    var min = (q.type === TYPES.NPS) ? 0 : (sc.min !== undefined ? sc.min : 1);
    var max = (q.type === TYPES.NPS) ? 10 : (sc.max !== undefined ? sc.max : (sc.points ? (min + sc.points - 1) : 5));
    var labels = sc.labels || {};
    if (labels.min) { wrap.appendChild(el("span", { "class": "scale-label scale-label-min" }, labels.min)); }
    var name = "q_" + q.id;
    for (var v = min; v <= max; v++) {
      var b = el("label", { "class": "scale-point" }, " " + v + " ");
      var input = el("input", { type: "radio", name: name, value: String(v) });
      if (answers[q.id] !== undefined && String(answers[q.id]) === String(v)) { input.checked = true; }
      (function (val) { input.addEventListener("change", function () { answers[q.id] = val; }); })(v);
      b.insertBefore(input, b.firstChild);
      wrap.appendChild(b);
    }
    if (labels.mid) { wrap.appendChild(el("span", { "class": "scale-label scale-label-mid" }, labels.mid)); }
    if (labels.max) { wrap.appendChild(el("span", { "class": "scale-label scale-label-max" }, labels.max)); }
    if (Array.isArray(q.opt_out_options) && q.opt_out_options.length) {
      wrap.appendChild(el("hr", { "class": "opt-out-separator" }));
      for (var i = 0; i < q.opt_out_options.length; i++) {
        wrap.appendChild(choiceRow(q, name, q.opt_out_options[i], false));
      }
    }
    return wrap;
  }

  function renderOpen(q, isLong) {
    var wrap = el("div", { "class": "open-text" });
    var input = isLong ? el("textarea", { rows: "4", "data-question-id": q.id }) : el("input", { type: "text", "data-question-id": q.id });
    if (answers[q.id] !== undefined) { input.value = answers[q.id]; }
    input.addEventListener("input", function () { answers[q.id] = input.value; });
    wrap.appendChild(input);
    return wrap;
  }

  function renderRanking(q) {
    var wrap = el("div", { "class": "ranking" });
    var opts = Array.isArray(q.options) ? q.options : [];
    var n = opts.length;
    for (var i = 0; i < n; i++) {
      var row = el("div", { "class": "rank-row" });
      row.appendChild(el("span", { "class": "rank-label" }, optionLabel(opts[i])));
      var sel = el("select", { "data-rank-for": q.id, "data-rank-option": String(optionValue(opts[i])) });
      sel.appendChild(el("option", { value: "" }, "--"));
      for (var r = 1; r <= n; r++) { sel.appendChild(el("option", { value: String(r) }, String(r))); }
      (function (optVal, selectEl) {
        selectEl.addEventListener("change", function () {
          var cur = (answers[q.id] && typeof answers[q.id] === "object") ? answers[q.id] : {};
          if (selectEl.value === "") { delete cur[optVal]; } else { cur[optVal] = parseInt(selectEl.value, 10); }
          answers[q.id] = cur;
        });
      })(String(optionValue(opts[i])), sel);
      row.appendChild(sel);
      wrap.appendChild(row);
    }
    return wrap;
  }

  function gridTable(q, rows, columns, multi) {
    var table = el("table", { "class": "grid-table" });
    var thead = el("thead"); var htr = el("tr"); htr.appendChild(el("th", null, ""));
    for (var c = 0; c < columns.length; c++) { htr.appendChild(el("th", null, optionLabel(columns[c]))); }
    thead.appendChild(htr); table.appendChild(thead);
    var tbody = el("tbody");
    for (var r = 0; r < rows.length; r++) {
      var rowVal = optionValue(rows[r]);
      var tr = el("tr"); tr.appendChild(el("th", { scope: "row" }, optionLabel(rows[r])));
      var name = "q_" + q.id + "_r" + r;
      for (var ci = 0; ci < columns.length; ci++) {
        var colVal = optionValue(columns[ci]);
        var td = el("td", null, null);
        var input = el("input", { type: (multi ? "checkbox" : "radio"), name: name, value: String(colVal) });
        var existing = (answers[q.id] && typeof answers[q.id] === "object") ? answers[q.id][rowVal] : undefined;
        if (multi) { if (Array.isArray(existing) && existing.indexOf(colVal) !== -1) { input.checked = true; } }
        else { if (existing !== undefined && String(existing) === String(colVal)) { input.checked = true; } }
        (function (rv, cv) {
          input.addEventListener("change", function () {
            var cur = (answers[q.id] && typeof answers[q.id] === "object") ? answers[q.id] : {};
            if (multi) {
              var arr = Array.isArray(cur[rv]) ? cur[rv].slice() : [];
              var idx = arr.indexOf(cv);
              if (input.checked && idx === -1) { arr.push(cv); }
              if (!input.checked && idx !== -1) { arr.splice(idx, 1); }
              cur[rv] = arr;
            } else {
              cur[rv] = cv;
            }
            answers[q.id] = cur;
          });
        })(rowVal, colVal);
        td.appendChild(input);
        tr.appendChild(td);
      }
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    return table;
  }

  function renderMatrix(q) {
    var rows = Array.isArray(q.rows) ? q.rows : [];
    var columns = Array.isArray(q.columns) ? q.columns : (q.scale && q.scale.labels ? scaleColumns(q.scale) : []);
    return gridTable(q, rows, columns, false);
  }

  function scaleColumns(sc) {
    var min = sc.min !== undefined ? sc.min : 1;
    var max = sc.max !== undefined ? sc.max : (sc.points ? min + sc.points - 1 : 5);
    var cols = [];
    for (var v = min; v <= max; v++) { cols.push(String(v)); }
    return cols;
  }

  function renderForcedChoiceGrid(q) {
    var rows = Array.isArray(q.rows) ? q.rows : [];
    var columns = Array.isArray(q.columns) && q.columns.length ? q.columns : ["Yes", "No"];
    return gridTable(q, rows, columns, false);
  }

  function renderConstantSum(q) {
    var wrap = el("div", { "class": "constant-sum" });
    var opts = Array.isArray(q.options) ? q.options : [];
    var total = q.constant_sum_total || 100;
    var totalEl = el("p", { "class": "sum-total" }, "Total: 0 / " + total);
    function recompute() {
      var cur = (answers[q.id] && typeof answers[q.id] === "object") ? answers[q.id] : {};
      var sum = 0;
      for (var k in cur) { if (cur.hasOwnProperty(k)) { sum += (parseFloat(cur[k]) || 0); } }
      totalEl.textContent = "Total: " + sum + " / " + total;
      totalEl.className = "sum-total" + (sum === total ? " sum-ok" : " sum-off");
    }
    for (var i = 0; i < opts.length; i++) {
      var row = el("div", { "class": "csum-row" });
      row.appendChild(el("span", { "class": "csum-label" }, optionLabel(opts[i])));
      var inp = el("input", { type: "number", min: "0", max: String(total), "data-csum-for": q.id });
      (function (optVal, inputEl) {
        inputEl.addEventListener("input", function () {
          var cur = (answers[q.id] && typeof answers[q.id] === "object") ? answers[q.id] : {};
          if (inputEl.value === "") { delete cur[optVal]; } else { cur[optVal] = parseFloat(inputEl.value); }
          answers[q.id] = cur; recompute();
        });
      })(String(optionValue(opts[i])), inp);
      row.appendChild(inp);
      wrap.appendChild(row);
    }
    wrap.appendChild(totalEl);
    return wrap;
  }

  // ---------- navigation ----------

  function isAnswered(q) {
    var a = answers[q.id];
    if (q.type === TYPES.STATEMENT) { return true; }
    if (a === undefined || a === null || a === "") { return false; }
    if (Array.isArray(a)) { return a.length > 0; }
    if (typeof a === "object") {
      for (var k in a) { if (a.hasOwnProperty(k)) { return true; } }
      return false;
    }
    return true;
  }

  function onNext(sectionIndex) {
    var sec = survey.sections[sectionIndex];
    var questions = Array.isArray(sec.questions) ? sec.questions : [];
    var missing = [];
    for (var i = 0; i < questions.length; i++) {
      if (questions[i].required && !isAnswered(questions[i])) { missing.push(questions[i].stem || questions[i].id); }
    }
    var errBox = document.getElementById("validation-message");
    if (missing.length) {
      if (errBox) {
        errBox.textContent = "Please answer the required question(s) before continuing: " + missing.join("; ");
        errBox.style.display = "block";
      }
      return;
    }
    if (errBox) { errBox.style.display = "none"; }

    // Evaluate skip_logic for this section.
    var jump = sectionJumpTarget(sec);
    var nextIndex;
    if (jump === "__end__") {
      nextIndex = screens.length - 1; // thank-you
    } else if (jump !== null) {
      var idx = screenIndexForSectionId(jump);
      nextIndex = (idx > currentScreen) ? idx : currentScreen + 1;
    } else {
      nextIndex = currentScreen + 1;
    }
    if (nextIndex >= screens.length) { nextIndex = screens.length - 1; }
    goToScreen(nextIndex);
  }

  function goToScreen(idx) {
    historyStack.push(currentScreen);
    currentScreen = idx;
    renderCurrent();
  }

  function goBack() {
    if (historyStack.length === 0) { return; }
    currentScreen = historyStack.pop();
    renderCurrent();
  }

  // ---------- start ----------

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
