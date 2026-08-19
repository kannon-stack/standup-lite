const STORAGE_KEY = "standup-lite-v1";

const DEMO = {
  teamName: "Harbor Team",
  people: ["Dylan", "Maya", "Jordan", "Priya"],
  you: "Dylan",
  updates: {},
};

function todayKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function prettyDate(date = new Date()) {
  return date.toLocaleDateString(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric",
  });
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function saveState(state) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function isBlocked(post) {
  return Boolean(post?.blockers?.trim());
}

function peopleByBoardOrder(people, posts) {
  const rank = (person) => {
    const post = posts[person];
    if (isBlocked(post)) return 0;
    if (post) return 1;
    return 2;
  };
  return [...people].sort(
    (a, b) => rank(a) - rank(b) || people.indexOf(a) - people.indexOf(b)
  );
}

function seedDemo(state) {
  const day = todayKey();
  const you = state.you;
  state.teamName = DEMO.teamName;
  state.people = [...DEMO.people];
  if (you && !state.people.includes(you)) state.people.unshift(you);
  state.you = you || DEMO.you;
  state.updates[day] = {
    Maya: {
      yesterday: "Shipped the onboarding email and closed two support tickets.",
      today: "Pair on the billing edge cases before noon.",
      blockers: "",
      at: Date.now() - 1000 * 60 * 42,
    },
    Jordan: {
      yesterday: "Reviewed the search ranking change and left comments.",
      today: "Need a decision on whether we keep the old filter UI.",
      blockers: "Waiting on product call about filters — blocked until then.",
      at: Date.now() - 1000 * 60 * 18,
    },
    Priya: {
      yesterday: "Infra: reduced deploy time from 9m to 4m.",
      today: "Watching the canary and writing the runbook.",
      blockers: "",
      at: Date.now() - 1000 * 60 * 7,
    },
  };
  return state;
}

function emptyState() {
  return {
    teamName: "Team",
    people: [],
    you: "",
    updates: {},
    started: false,
  };
}

function ensureDay(state) {
  const day = todayKey();
  state.updates[day] ||= {};
  return state.updates[day];
}

function formatTime(ts) {
  return new Date(ts).toLocaleTimeString(undefined, {
    hour: "numeric",
    minute: "2-digit",
  });
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function boardText(state) {
  const day = todayKey();
  const posts = state.updates[day] || {};
  const posted = state.people.filter((person) => posts[person]);
  const missing = state.people.filter((person) => !posts[person]);
  const blocked = posted.filter((person) => isBlocked(posts[person]));
  const clear = posted.filter((person) => !isBlocked(posts[person]));
  const lines = [
    `${state.teamName} standup — ${prettyDate()}`,
    `${posted.length}/${state.people.length} posted · ${blocked.length} blocked · ${missing.length} missing`,
    "",
  ];

  const writeGroup = (title, names, kind) => {
    if (!names.length) return;
    lines.push(title);
    for (const person of names) {
      const post = posts[person];
      if (kind === "missing") {
        lines.push(`• ${person}: missing`);
        continue;
      }
      lines.push(`• ${person}`);
      if (post.yesterday) lines.push(`  Yesterday: ${post.yesterday}`);
      lines.push(`  Today: ${post.today}`);
      lines.push(`  Blockers: ${post.blockers || "None"}`);
      lines.push("");
    }
  };

  writeGroup("BLOCKED", blocked, "posted");
  writeGroup("POSTED", clear, "posted");
  writeGroup("MISSING", missing, "missing");
  return lines.join("\n").trim();
}

async function copyText(text) {
  try {
    if (navigator.clipboard?.writeText && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return "copied";
    }
  } catch {
    /* file:// and some browsers reject clipboard; fall through */
  }

  const ta = document.createElement("textarea");
  ta.value = text;
  ta.setAttribute("readonly", "");
  ta.style.cssText = "position:fixed;top:0;left:0;width:1px;height:1px;opacity:0";
  document.body.appendChild(ta);
  ta.focus();
  ta.select();
  ta.setSelectionRange(0, text.length);
  let copied = false;
  try {
    copied = document.execCommand("copy");
  } catch {
    copied = false;
  }
  ta.remove();
  if (copied) return "copied";

  showCopyFallback(text);
  return "fallback";
}

function showCopyFallback(text) {
  document.querySelector(".copy-fallback")?.remove();
  const wrap = document.createElement("div");
  wrap.className = "copy-fallback";
  wrap.innerHTML = `
    <div class="copy-fallback-card">
      <p>Clipboard is blocked on this page. Select the text and press Ctrl/⌘ + C, then paste into Slack or Teams.</p>
      <textarea readonly></textarea>
      <button class="btn btn-gold" type="button">Done</button>
    </div>
  `;
  const area = wrap.querySelector("textarea");
  area.value = text;
  wrap.querySelector("button").onclick = () => wrap.remove();
  wrap.addEventListener("click", (event) => {
    if (event.target === wrap) wrap.remove();
  });
  document.body.appendChild(wrap);
  area.focus();
  area.select();
}

const app = document.getElementById("app");
let state = loadState() || emptyState();
let toastTimer;

function toast(message) {
  clearTimeout(toastTimer);
  const existing = document.querySelector(".toast");
  if (existing) existing.remove();
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = message;
  document.body.appendChild(el);
  toastTimer = setTimeout(() => el.remove(), 1800);
}

function persist() {
  saveState(state);
  render();
}

function currentPost() {
  return (state.updates[todayKey()] || {})[state.you] || {
    yesterday: "",
    today: "",
    blockers: "",
  };
}

function renderGate() {
  app.innerHTML = `
    <section class="card gate">
      <p class="kicker">Standup Lite</p>
      <h1>Skip the meeting. Read the room.</h1>
      <p>
        The bet: a 60-second written update can replace the daily standup
        if blockers are obvious and missing people are visible.
      </p>
      <label for="name">Your name</label>
      <input id="name" type="text" maxlength="40" placeholder="Maya" value="${escapeHtml(state.you)}" />
      <div class="row">
        <button class="btn btn-gold" id="start-empty">Start empty team</button>
        <button class="btn" id="start-demo">Load sample board</button>
      </div>
    </section>
  `;

  const start = (demo) => {
    const name = document.getElementById("name").value.trim();
    if (!name) {
      document.getElementById("name").focus();
      return;
    }
    state.started = true;
    state.you = name;
    if (demo) {
      seedDemo(state);
    } else if (!state.people.includes(name)) {
      state.people = [name];
    }
    persist();
  };

  document.getElementById("start-empty").onclick = () => start(false);
  document.getElementById("start-demo").onclick = () => start(true);
  document.getElementById("name").addEventListener("keydown", (event) => {
    if (event.key === "Enter") start(false);
  });
}

function renderApp() {
  const day = todayKey();
  const posts = state.updates[day] || {};
  const posted = state.people.filter((person) => posts[person]);
  const missing = state.people.filter((person) => !posts[person]);
  const blocked = posted.filter((person) => isBlocked(posts[person]));
  const mine = currentPost();
  const ordered = peopleByBoardOrder(state.people, posts);

  const missingBanner = missing.length
    ? `<div class="missing-banner" role="status">Still waiting on ${missing
        .map((person) => escapeHtml(person))
        .join(", ")}</div>`
    : "";

  const cards = ordered
    .map((person) => {
      const post = posts[person];
      if (!post) {
        return `
          <article class="update missing">
            <header>
              <div class="name">${escapeHtml(person)}</div>
              <div class="meta">Missing</div>
            </header>
            <p class="hint">No update yet today.</p>
          </article>
        `;
      }
      return `
        <article class="update ${isBlocked(post) ? "blocked" : ""}">
          <header>
            <div class="name">${escapeHtml(person)}</div>
            <div class="meta">${isBlocked(post) ? "Blocked · " : ""}${formatTime(post.at)}</div>
          </header>
          <div class="fields">
            <div class="field">
              <strong>Yesterday</strong>
              ${escapeHtml(post.yesterday || "—")}
            </div>
            <div class="field">
              <strong>Today</strong>
              ${escapeHtml(post.today)}
            </div>
            <div class="field blockers">
              <strong>Blockers</strong>
              ${escapeHtml(post.blockers?.trim() || "None")}
            </div>
          </div>
        </article>
      `;
    })
    .join("");

  app.innerHTML = `
    <header class="top">
      <div>
        <p class="kicker">Standup Lite</p>
        <h1>${escapeHtml(state.teamName)}</h1>
        <p class="date-line">${prettyDate()} · ${state.people.length} people</p>
      </div>
      <div class="top-actions">
        <button class="btn" id="copy-board">Copy board</button>
        <button class="btn" id="copy-mine">Copy mine</button>
        <button class="btn" id="reset">Reset</button>
      </div>
    </header>

    <div class="stats">
      <div class="stat"><b>${posted.length}/${state.people.length}</b><span>Posted</span></div>
      <div class="stat"><b>${blocked.length}</b><span>Blocked</span></div>
      <div class="stat"><b>${missing.length}</b><span>Missing</span></div>
    </div>

    <div class="layout">
      <section class="card">
        <p class="kicker">Your update</p>
        <div class="who">
          <select id="you">
            ${state.people
              .map(
                (person) =>
                  `<option ${person === state.you ? "selected" : ""}>${escapeHtml(person)}</option>`
              )
              .join("")}
          </select>
        </div>
        <form id="post-form">
          <label for="yesterday">Yesterday</label>
          <textarea id="yesterday" placeholder="What moved?">${escapeHtml(mine.yesterday)}</textarea>
          <label for="today">Today</label>
          <textarea id="today" required placeholder="What will you finish?">${escapeHtml(mine.today)}</textarea>
          <label for="blockers">Blockers</label>
          <textarea id="blockers" placeholder="Leave blank if you’re clear">${escapeHtml(mine.blockers)}</textarea>
          <div class="row">
            <button class="btn btn-gold" type="submit">Post to board</button>
          </div>
          <p class="hint">Ctrl/⌘ + Enter to post. Switch names to post as a teammate.</p>
        </form>

        <label for="team-name">Team name</label>
        <input id="team-name" type="text" value="${escapeHtml(state.teamName)}" />

        <label for="add-person">Roster</label>
        <div class="who">
          <input id="add-person" type="text" placeholder="Add a teammate" />
          <button class="btn" id="add-btn" type="button">Add</button>
        </div>
        <div class="roster">
          ${state.people
            .map(
              (person) =>
                `<span class="chip">${escapeHtml(person)}<button data-remove="${escapeHtml(person)}" aria-label="Remove ${escapeHtml(person)}">×</button></span>`
            )
            .join("")}
        </div>
      </section>

      <section class="board">
        ${missingBanner}
        ${cards || `<div class="card empty">Add teammates, then post. The board is the meeting.</div>`}
      </section>
    </div>
  `;

  document.getElementById("you").onchange = (event) => {
    state.you = event.target.value;
    persist();
  };

  document.getElementById("team-name").onchange = (event) => {
    state.teamName = event.target.value.trim() || "Team";
    persist();
  };

  document.getElementById("add-btn").onclick = addPerson;
  document.getElementById("add-person").addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      addPerson();
    }
  });

  document.querySelectorAll("[data-remove]").forEach((button) => {
    button.onclick = () => {
      const name = button.getAttribute("data-remove");
      state.people = state.people.filter((person) => person !== name);
      if (state.you === name) state.you = state.people[0] || "";
      if (!state.you) state.started = false;
      persist();
    };
  });

  document.getElementById("post-form").onsubmit = (event) => {
    event.preventDefault();
    postUpdate();
  };

  document.getElementById("post-form").addEventListener("keydown", (event) => {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      postUpdate();
    }
  });

  document.getElementById("copy-board").onclick = async () => {
    const result = await copyText(boardText(state));
    if (result === "copied") toast("Board copied");
  };

  document.getElementById("copy-mine").onclick = async () => {
    const post = currentPost();
    const text = [
      `${state.you} — ${prettyDate()}`,
      `Yesterday: ${post.yesterday || "—"}`,
      `Today: ${post.today || "—"}`,
      `Blockers: ${post.blockers || "None"}`,
    ].join("\n");
    const result = await copyText(text);
    if (result === "copied") toast("Your update copied");
  };

  document.getElementById("reset").onclick = () => {
    if (confirm("Clear this board and start over?")) {
      state = emptyState();
      persist();
    }
  };
}

function addPerson() {
  const input = document.getElementById("add-person");
  const name = input.value.trim();
  if (!name || state.people.includes(name)) return;
  state.people.push(name);
  persist();
}

function postUpdate() {
  const today = document.getElementById("today").value.trim();
  if (!today || !state.you) return;
  const day = ensureDay(state);
  day[state.you] = {
    yesterday: document.getElementById("yesterday").value.trim(),
    today,
    blockers: document.getElementById("blockers").value.trim(),
    at: Date.now(),
  };
  persist();
  toast("Posted");
}

function render() {
  if (!state.started || !state.you) {
    renderGate();
    return;
  }
  renderApp();
}

render();
