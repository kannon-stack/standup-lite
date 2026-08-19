# Standup Lite

A tiny async standup board. The product bet: **people will skip the daily meeting if writing an update takes about a minute and reading the board makes blockers obvious.**

This prototype is the smallest thing that can test that bet. No accounts, no Slack app, no history. One board, today only.

## Live app

**Production:** https://standup-lite.vercel.app

Deployed on Vercel (AGKbuilds team). Clipboard copy works on the live URL — no `file://` workaround needed.

**Dashboard:** https://vercel.com/agk-builds/standup-lite

## How to run locally

Open `index.html` in a browser. Everything saves in local storage on that machine.

If **Copy board** is blocked (common when the file is opened as `file://`), a pane appears so you can select the text and paste it into Slack or Teams.

## What to try

1. **Load sample board** to see the reading experience: blocked people first, then posted, with missing people called out.
2. **Start empty team** to post as yourself. Switch names to simulate teammates on one laptop.
3. **Copy board** and paste into Slack or Teams if the real test is “will people read this instead of meeting?”

## 3-day experiment

- Day 1: roster the team, everyone posts, skip standup, paste the board in chat.
- Day 2: same, notice whether blockers get resolved without a call.
- Day 3: ask: did anyone miss the meeting? Did anyone fail to post? Did reading the board take less than a minute?

If posting or reading fails, the meeting should stay. If both work, the meeting is optional.

## Intentionally missing

Auth, multi-device sync, reminders, video, and past days. Those only matter after this assumption holds.
