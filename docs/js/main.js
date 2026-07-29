/**
 * Progressive enhancements for the marketing site: a collapsible nav on narrow
 * viewports and a cinnabar tick marking the section in view. Both degrade to a
 * plain, fully usable page with JavaScript disabled.
 */

const NARROW_VIEWPORT = window.matchMedia("(width < 48rem)");

const toggle = document.querySelector(".nav-toggle");
const links = document.querySelector(".nav-links");

function navIsOpen() {
  return toggle.getAttribute("aria-expanded") === "true";
}

function setNavOpen(open) {
  toggle.setAttribute("aria-expanded", String(open));
  links.hidden = !open;
}

function collapseNavOnNarrowViewports() {
  if (NARROW_VIEWPORT.matches) setNavOpen(false);
  else {
    toggle.setAttribute("aria-expanded", "false");
    links.hidden = false;
  }
}

function watchNavToggle() {
  if (!toggle || !links) return;

  collapseNavOnNarrowViewports();
  NARROW_VIEWPORT.addEventListener("change", collapseNavOnNarrowViewports);

  toggle.addEventListener("click", () => setNavOpen(!navIsOpen()));

  links.addEventListener("click", (event) => {
    if (event.target.matches("a") && NARROW_VIEWPORT.matches) setNavOpen(false);
  });
}

/**
 * Marks the nav link whose section is currently in view, so the header reflects
 * where the reader is on the page.
 */
function watchSectionsInView() {
  const anchors = [...document.querySelectorAll('.nav-links a[href^="#"]')];
  const sections = anchors
    .map((anchor) => document.querySelector(anchor.getAttribute("href")))
    .filter(Boolean);

  if (sections.length === 0) return;

  const highlight = (id) =>
    anchors.forEach((anchor) =>
      anchor.toggleAttribute(
        "data-in-view",
        anchor.getAttribute("href") === `#${id}`,
      ),
    );

  const observer = new IntersectionObserver(
    (entries) => {
      const visible = entries.find((entry) => entry.isIntersecting);
      if (visible) highlight(visible.target.id);
    },
    { rootMargin: "-45% 0px -45% 0px" },
  );

  sections.forEach((section) => observer.observe(section));
}

watchNavToggle();
watchSectionsInView();
