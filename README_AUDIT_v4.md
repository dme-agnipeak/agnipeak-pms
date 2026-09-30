# Agnipeak PMS v4: Audit Report + Update Guide

**Company:** Vinayak Agnipeak LLP · **Version:** 4.0.0 · **Date:** 30 Sep 2026

---

## 1. Go live in 3 steps (about 10 minutes)

1. **Supabase → SQL Editor** → paste all of `supabase_v4_upgrade.sql` and click **Run**.
   - Existing passwords are converted to secure hashes, so **everyone logs in with the same password as before**.
   - It is safe to run more than once. No data is deleted.
2. **Netlify:** upload this **whole folder** (`index.html`, `sw.js`, `manifest.webmanifest`, `_headers`, `icons/`) and drag-drop it as a new deploy.
   - Uploading only `index.html` is not enough. Without `sw.js` and `manifest` the app cannot be installed.
3. **Install on phone:** open the Netlify link in Chrome and tap the green **Install** button (or ⋮ menu → *Install app*).

> **Test first:** open `your-link/index.html?demo=1` to see a full demo with fake data.
> Login: `connect@systemmaster.in` / `Admin@123` (demo only).

---

## 2. Audit: what was wrong

### 🐢 Why the app was slow (fixed)
| Problem | Effect | v4 fix |
|---|---|---|
| Every page downloaded full tables, including **operator photos (base64)** | Every click downloaded MBs of data | Lists now fetch only the needed columns. Photos load only on the batch timeline |
| No caching. The same data was downloaded again on every page change | Every screen took 2–5 seconds | Smart cache: screens show instantly and refresh in the background |
| 4–6 queries ran one after another | Wait times added up | All queries run in parallel |
| Badge count downloaded all batches + steps on every page | Double load | Uses the same cache |
| Saving a step ran 8–12 updates one by one | Save was slow | Updates run in parallel |
| Chart.js loaded on every page | Slow first open | Loads only on pages that have charts |
| No service worker | Everything downloaded fresh on every open | App files are cached on the phone, so it opens in about 1 second |
| No database indexes | Queries get slower as data grows | Indexes added in the SQL file |

### 🐞 Bugs (fixed)
1. **Supabase 1000-row limit:** after 1000 entries, reports, stock and dashboard would quietly go wrong. v4 now fetches all rows page by page.
2. **Stock double counting:** pieces sold at the Packing step (Step 10) were still counted in "Packed" stock. v4: **Final Ready Stock = Packed − sold at packing**.
3. **Rework qty went missing:** rework at steps other than Step 5 was not counted in stock anywhere. v4 shows it separately as **Rework Hold**.
4. **Timezone (IST) bug:** entries made between 12 midnight and 5:30 am were counted on the previous day, which was wrong for the night shift. v4 uses Indian local time.
5. **Planning page** counted Step 8 as output (should be Step 10) and had a fixed target of 10,000. v4 lets Admin set a **daily target**.
6. Language and theme reset on every reload. They are now remembered.
7. Delete errors used to fail silently. They now show a proper message.
8. The same Batch No. could be created twice. There is now a duplicate check.
9. CSV/Excel had no Hindi text support and had a formula-injection risk. Both fixed (UTF-8 BOM + escaping).

### 🔐 Security (serious; fixed with the SQL file)
1. **Passwords were stored as plain text,** and **anyone could read every user's password** using the public key in the HTML. After running the SQL, passwords are stored as a bcrypt hash and the password column can no longer be read at all.
2. Login now goes through a secure function, `pms_login`.
3. After login the password was saved in the phone's storage. Now it is not saved.
4. When a user is switched **Off**, their already-open app logs out automatically.

> ⚠️ **Still pending for later (honest note):** the app uses Supabase's public (anon) key, and all permission checks happen only in the browser. A technical person could still change data directly through the API. The full fix is to move to **Supabase Auth + Row Level Security (RLS)**. That is a larger migration, and we can do it as a Phase 2.

---

## 3. What's new

### 📦 Stock: "which item, how much stock"
- A big **Final Ready Stock** card, broken down by product and color.
- **"Where is the material?"**: step-wise WIP bars, marked red when material has waited 3+ days.
- Total Stock = WIP + Final Ready + Rework Hold (the Moulding queue is shown separately).
- Stock by batch, CSV download and **WhatsApp share**.

### 🤖 AI Assistant (report + analysis)
- **Offline mode (free, instant):** works without any key. Answers stock, today's summary, scrap by step, pending work, batch status, top operators and target questions.
- **ChatGPT / Gemini / Claude:** Admin enters the key in Settings → *AI Assistant*.
  - The key is saved **only on that device**. It is not stored in the database and no other user can see it.
  - Use the *Test connection* button to check the key.
  - The model name can be changed (defaults: `gpt-5-mini`, `gemini-2.5-flash`, `claude-haiku-4-5-20251001`).
- **Reports → AI Report:** one tap gives a summary, problems, stock position and 5 actions for tomorrow. It can be copied, printed/saved as PDF or shared on WhatsApp.
- **Home → "Today's key insights":** automatic alerts for target gap, scrap rising, stuck material and bottlenecks.

### 🎤 Voice control (Chrome / Android)
- Tap the orange 🎤 button in the top bar and speak, e.g. "**stock dikhao**", "**mere task kholo**", "**naya batch**", "**aaj ka summary**", "**scrap kahan zyada hai**", "**dark mode**".
- In AI chat, tap 🎤 to ask a question; the answer is also **read aloud**.
- In a step entry, tap 🎤 and say "**quantity 500 scrap 20**" and the form fills itself.
- Works in both Hindi (hi-IN) and English (en-IN).

### 📱 App (PWA): Chrome install + Android
- A green **Install** button (on login, top bar, Home card and Settings).
- It gets its own icon on the home screen, opens full-screen, and **opens quickly**.
- **Offline:** without internet, the last saved data can still be viewed.
- Long-press the app icon for shortcuts: My Tasks, Stock, New Batch, AI.
- The number of pending tasks shows as a badge on the app icon.
- When a new version is deployed, the app shows an "update" message.

### 🧠 Brain science and user psychology: habit-building features
| Principle | Feature in the app |
|---|---|
| **Goal gradient** (people work faster as a goal gets closer) | Today's target % ring on Home |
| **Streak / loss aversion** (people don't want to lose what they have built) | 🔥 day streak, plus a reminder: "make 1 entry today to keep it alive" |
| **Instant reward (dopamine)** | Confetti, vibration and a new praise message on every step save |
| **Variable reward** | A different praise message each time, plus a special ✨ for zero scrap |
| **Endowed progress** | Achievement badges showing progress towards the next one (e.g. 7/30 days) |
| **Social proof** | Top performers for the last 7 days, with a "You" tag |
| **Zeigarnik effect** (unfinished work stays on the mind) | Pending-task badge, and "you have N tasks pending" |
| **Less friction** | 1-tap Update from task cards, 75%/50%/25% buttons, voice fill, remembered last product/colour/machine, auto shift |
| **Thumb zone** | Bottom navigation on mobile with a big ➕ button in the centre |

### Other improvements
- Default Hindi (one tap switches to English); dark mode follows the phone setting.
- Search and filters on the Batches page, and search on My Tasks.
- **Live refresh:** when another user makes an entry, your screen updates automatically.
- An error screen with a Retry button (instead of a blank screen).

---

## 4. Files
| File | What it does |
|---|---|
| `index.html` | The full app |
| `sw.js` | Offline support, fast opening, install |
| `manifest.webmanifest` | App name, icons, shortcuts |
| `icons/` | App icons |
| `_headers` | Netlify cache settings (so updates reach users quickly) |
| `supabase_v4_upgrade.sql` | Security + speed + settings; **run once** |

## 5. Testing done
- Chrome, phone (390px) and desktop (1366px): every page, step save, new batch, AI chat, AI report, Hindi/English, dark mode, with no JavaScript errors.
- ChatGPT, Gemini and Claude request formats tested against mock servers.
- Live mode: login through `pms_login` and lean parallel queries checked.
- Not tested on your live Supabase or with real API keys (no access from here). After deploying, run the checklist below.

### Checklist after deploying
1. After running the SQL, log in with your existing password.
2. Make one entry on a test batch and check that the Stock page updates.
3. Settings → AI → enter a key → *Test connection*.
4. On an Android phone: Chrome → Install, then try the 🎤 button.

---
Developed By **Sunil Tiwari** · 9027965956 · connect@systemmaster.in · systemmaster.in
