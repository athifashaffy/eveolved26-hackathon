"""
AutoBiomarker — 2-minute video walkthrough recorder using Playwright.

Records a screen capture navigating through slides, terminal output, and dashboard.
Add your own voiceover on top of the recording.

Usage:
  python record_walkthrough.py
"""

import os
import time
from playwright.sync_api import sync_playwright

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "video")
os.makedirs(OUTPUT_DIR, exist_ok=True)

SLIDES_URL = "http://localhost:8000/slides.html"
DASHBOARD_URL = "http://localhost:8501"

# Read REAL log output from the persistent search
LOG_FILE = os.path.join(os.path.dirname(__file__), "results", "persistent_search_stdout.log")

TERMINAL_STYLE = """
<style>
  body {
    background: #0d1117; color: #c9d1d9; font-family: 'SF Mono', 'Fira Code', 'Menlo', monospace;
    font-size: 14px; line-height: 1.6; padding: 20px 30px; margin: 0;
  }
  .line { white-space: pre; }
  .timestamp { color: #6c7086; }
  .header { color: #58a6ff; font-weight: bold; }
  .significant { color: #3fb950; font-weight: bold; background: #0d1117; }
  .found { color: #f0883e; font-weight: bold; font-size: 16px; }
  .result { color: #3fb950; }
  .dim { color: #6c7086; }
  .tested { color: #c9d1d9; }
  .fdr { color: #f38ba8; }
  .fdr-pass { color: #3fb950; font-weight: bold; }
  .prompt { color: #58a6ff; }
  .cmd { color: #f0883e; }
  .error { color: #6c7086; font-style: italic; }
  pre { margin: 0; }
  #terminal { overflow: hidden; }
</style>
"""


def _read_log_lines():
    """Read the real log file."""
    with open(LOG_FILE, "r") as f:
        return f.readlines()


def _colorize_line(line):
    """Apply syntax highlighting to a real log line."""
    import html as html_mod
    line = html_mod.escape(line.rstrip())

    # Significant findings - brightest
    if "*** SIGNIFICANT ***" in line:
        return f'<span class="significant">{line}</span>'
    if "!!! FOUND" in line:
        return f'<span class="found">{line}</span>'
    if ">>>" in line:
        return f'<span class="result">{line}</span>'
    if "ALL SIGNIFICANT FINDINGS:" in line:
        return f'<span class="found">{line}</span>'
    if line.strip().startswith("1.") or line.strip().startswith("2.") or line.strip().startswith("3."):
        if "rmssd" in line or "lfhf" in line:
            return f'<span class="result">{line}</span>'

    # Headers and separators
    if "=====" in line:
        return f'<span class="header">{line}</span>'
    if "ROUND " in line and "/50" in line:
        return f'<span class="header">{line}</span>'
    if "PERSISTENT SEARCH" in line:
        return f'<span class="header">{line}</span>'

    # FDR lines
    if "FDR correction:" in line:
        if "0/" in line.split("FDR correction:")[1]:
            return f'<span class="fdr">{line}</span>'
        else:
            return f'<span class="fdr-pass">{line}</span>'

    # Tested interactions
    if "Tested interaction" in line or "Tested composite" in line:
        return f'<span class="tested">{line}</span>'

    # Errors (dim)
    if "Error testing" in line:
        return f'<span class="error">{line}</span>'

    # LLM proposed
    if "LLM proposed" in line:
        return f'<span class="dim">{line}</span>'

    # Timestamps dim
    if line.startswith("[2026-"):
        return f'<span class="dim">{line}</span>'

    # Data loading lines
    if "Loaded " in line or "Computed " in line or "Merged " in line or "Extracted " in line:
        return f'<span class="dim">{line}</span>'

    return line


def _build_terminal_html(lines, title=None):
    """Build a terminal HTML page from real log lines."""
    colored = []
    if title:
        colored.append(f'<span class="prompt">$ </span><span class="cmd">{title}</span>')
        colored.append("")
    for line in lines:
        colored.append(_colorize_line(line))
    content = "\n".join(colored)
    return f"""<!DOCTYPE html>
<html><head>{TERMINAL_STYLE}</head>
<body><div id="terminal"><pre>{content}</pre></div></body></html>"""


def build_terminal_screens():
    """Build 4 terminal screens from the real log."""
    lines = _read_log_lines()

    # Screen 1: Pipeline startup + Round 1 (lines 1-30)
    # Shows loading data, 187 features, Round 1 with 0 significant
    screen1_lines = lines[0:30]

    # Screen 2: Rounds 2-25 (all failing) — show the struggle
    # For each target round, grab: separator + round header + FDR result
    import re
    screen2_lines = []
    target_rounds = [2, 5, 10, 15, 20, 25]
    for i, line in enumerate(lines):
        m = re.search(r"ROUND (\d+)/50", line)
        if m and int(m.group(1)) in target_rounds:
            # Separator line is 2 lines before
            if i >= 2 and "====" in lines[i-2]:
                screen2_lines.append(lines[i-2])
            if i >= 1 and "====" in lines[i-1]:
                screen2_lines.append(lines[i-1])
            screen2_lines.append(line)
            # Find the FDR line for this round (within next 15 lines)
            for j in range(i+1, min(i+15, len(lines))):
                if "FDR correction:" in lines[j]:
                    screen2_lines.append(lines[j])
                    break
            screen2_lines.append("\n")

    # Screen 3: Rounds 26-27 — THE DISCOVERY (the dramatic moment)
    # Lines ~418-465: Round 26 finds first significant, Round 27 finds second
    screen3_lines = lines[417:465]

    # Screen 4: Final summary (lines ~822-836)
    screen4_lines = lines[821:836]

    return (
        _build_terminal_html(screen1_lines, "python3 src/run_until_significant.py"),
        _build_terminal_html(screen2_lines, "# Rounds 2-25: searching for signal..."),
        _build_terminal_html(screen3_lines),
        _build_terminal_html(screen4_lines),
    )


def record_video():
    # Build terminal screens from REAL log data
    print("Loading real log data from results/persistent_search_stdout.log...")
    term_startup, term_struggle, term_discovery, term_summary = build_terminal_screens()

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 1920, "height": 1080},
            record_video_dir=OUTPUT_DIR,
            record_video_size={"width": 1920, "height": 1080},
        )
        page = context.new_page()

        # ---- SECTION 1: Title slide (0:00 - 0:08) ----
        print("[0:00] Opening title slide...")
        page.goto(SLIDES_URL, wait_until="networkidle")
        time.sleep(4)

        # ---- SECTION 2: Problem slide (0:08 - 0:18) ----
        print("[0:08] Problem slide...")
        page.keyboard.press("ArrowRight")
        time.sleep(5)

        # ---- SECTION 3: Insight slide with chart (0:18 - 0:30) ----
        print("[0:18] Insight & core finding...")
        page.keyboard.press("ArrowRight")
        time.sleep(7)

        # ---- SECTION 4: Autoresearch engine (0:30 - 0:42) ----
        print("[0:30] Autoresearch engine slide...")
        page.keyboard.press("ArrowRight")
        time.sleep(6)

        # ---- SECTION 5: REAL Terminal — Pipeline startup + Round 1 (0:42 - 0:52) ----
        print("[0:42] REAL terminal: Pipeline loading data, Round 1...")
        page.set_content(term_startup)
        time.sleep(5)
        # Scroll to show Round 1 FDR failure
        page.mouse.wheel(0, 300)
        time.sleep(4)

        # ---- SECTION 6: REAL Terminal — Rounds 2-25 struggling (0:52 - 1:00) ----
        print("[0:52] REAL terminal: Rounds 2-25, all 0 significant...")
        page.set_content(term_struggle)
        time.sleep(5)

        # ---- SECTION 7: REAL Terminal — THE DISCOVERY Rounds 26-27 (1:00 - 1:15) ----
        print("[1:00] REAL terminal: Round 26-27 — SIGNIFICANT FINDINGS!")
        page.set_content(term_discovery)
        time.sleep(5)
        # Scroll to reveal the second finding in Round 27
        page.mouse.wheel(0, 400)
        time.sleep(5)
        page.mouse.wheel(0, 300)
        time.sleep(4)

        # ---- SECTION 8: REAL Terminal — Final summary (1:15 - 1:22) ----
        print("[1:15] REAL terminal: Final summary — 2 unique findings...")
        page.set_content(term_summary)
        time.sleep(7)

        # ---- SECTION 9: Methods & Results slide (1:22 - 1:32) ----
        print("[1:22] Methods & results with volcano plot...")
        page.goto(SLIDES_URL + "#/4", wait_until="networkidle")
        time.sleep(7)

        # ---- SECTION 10: Validation slide (1:32 - 1:42) ----
        print("[1:32] Validation slide with charts...")
        page.goto(SLIDES_URL + "#/5", wait_until="networkidle")
        time.sleep(7)

        # ---- SECTION 11: Streamlit dashboard — Volcano Plot tab (1:42 - 1:50) ----
        print("[1:42] Streamlit dashboard (Volcano Plot tab)...")
        try:
            page.goto(DASHBOARD_URL, wait_until="networkidle", timeout=10000)
            time.sleep(2)
            # Click the "Volcano Plot" tab (2nd tab)
            try:
                volcano_tab = page.locator("button", has_text="Volcano Plot")
                volcano_tab.click()
                time.sleep(4)
            except Exception:
                print("  Could not click Volcano Plot tab, showing default...")
                time.sleep(3)
        except Exception:
            print("  Dashboard not available, skipping...")
            time.sleep(2)

        # ---- SECTION 12: Closing slide (1:50 - 2:00) ----
        print("[1:50] Closing slide...")
        page.goto(SLIDES_URL + "#/9", wait_until="networkidle")
        time.sleep(6)

        # Done
        print("\nRecording complete!")
        context.close()
        browser.close()

        # Find the video file
        videos = [f for f in os.listdir(OUTPUT_DIR) if f.endswith(".webm")]
        if videos:
            video_path = os.path.join(OUTPUT_DIR, videos[-1])
            print(f"\nVideo saved to: {video_path}")
            print(f"Duration: ~2 minutes")
            print(f"\nTo convert to MP4:")
            print(f"  ffmpeg -i {video_path} -c:v libx264 -crf 23 video/walkthrough.mp4")
            print(f"\nAdd voiceover using iMovie, QuickTime, or ScreenFlow.")
        else:
            print("No video file found — check OUTPUT_DIR")


if __name__ == "__main__":
    record_video()
