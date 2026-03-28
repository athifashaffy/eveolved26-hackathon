"""Screenshot each slide in slides.html using Playwright for visual QA."""
import os, time
from playwright.sync_api import sync_playwright

SLIDES_PATH = os.path.join(os.path.dirname(__file__), "slides.html")
OUT_DIR = os.path.join(os.path.dirname(__file__), "slide_screenshots")
os.makedirs(OUT_DIR, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1280, "height": 720})
    page.goto(f"file://{os.path.abspath(SLIDES_PATH)}")
    # Wait for Reveal.js to initialize
    page.wait_for_timeout(2000)

    # Get total slide count
    total = page.evaluate("Reveal.getTotalSlides()")
    print(f"Total slides: {total}")

    for i in range(total):
        page.evaluate(f"Reveal.slide({i})")
        page.wait_for_timeout(500)
        # Get slide title for filename
        title = page.evaluate("""
            () => {
                const h = document.querySelector('.present h1, .present h2');
                return h ? h.textContent.trim().substring(0, 40) : 'untitled';
            }
        """)
        safe_title = "".join(c if c.isalnum() or c in " -_" else "" for c in title).strip().replace(" ", "_")
        fname = f"slide_{i+1:02d}_{safe_title}.png"
        page.screenshot(path=os.path.join(OUT_DIR, fname))
        print(f"  [{i+1}/{total}] {fname}")

    browser.close()
    print(f"\nAll screenshots saved to {OUT_DIR}/")
