/* ============================================================
   CivicCare Documentation — Interactive Functionality
   ============================================================ */

function runDocInit() {
  'use strict';

  /* ---------- DOM refs ---------- */
  var header = document.getElementById('siteHeader');
  var sidebar = document.getElementById('sidebar');
  var overlay = document.getElementById('sidebarOverlay');
  var menuBtn = document.getElementById('mobileMenuBtn');
  var backToTop = document.getElementById('backToTop');
  var searchInput = document.getElementById('searchInput');
  var searchResults = document.getElementById('searchResults');
  var mainContent = document.getElementById('mainContent');

  /* ---------- Scroll-aware header ---------- */
  function onScroll() {
    var y = window.scrollY || window.pageYOffset;
    if (header) header.classList.toggle('scrolled', y > 10);
    if (backToTop) backToTop.classList.toggle('visible', y > 400);
    updateActiveSidebarLink();
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---------- Back to top ---------- */
  if (backToTop) {
    backToTop.addEventListener('click', function () {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }

  /* ---------- Mobile sidebar ---------- */
  function openSidebar() {
    if (sidebar) sidebar.classList.add('open');
    if (overlay) overlay.classList.add('active');
    document.body.style.overflow = 'hidden';
  }

  function closeSidebar() {
    if (sidebar) sidebar.classList.remove('open');
    if (overlay) overlay.classList.remove('active');
    document.body.style.overflow = '';
  }

  if (menuBtn) {
    menuBtn.addEventListener('click', function () {
      if (sidebar && sidebar.classList.contains('open')) {
        closeSidebar();
      } else {
        openSidebar();
      }
    });
  }

  if (overlay) overlay.addEventListener('click', closeSidebar);

  if (sidebar) {
    var sideLinks = sidebar.querySelectorAll('.sidebar-link, .sidebar-sub-link');
    for (var i = 0; i < sideLinks.length; i++) {
      sideLinks[i].addEventListener('click', function () {
        if (window.innerWidth < 768) closeSidebar();
      });
    }
  }

  /* ---------- Active sidebar link on scroll ---------- */
  var sidebarLinks = sidebar ? sidebar.querySelectorAll('.sidebar-link[data-section]') : [];
  var sections = [];

  for (var i = 0; i < sidebarLinks.length; i++) {
    var id = sidebarLinks[i].getAttribute('data-section');
    var el = document.getElementById(id);
    if (el) sections.push({ id: id, el: el, link: sidebarLinks[i] });
  }

  function updateActiveSidebarLink() {
    var scrollY = (window.scrollY || window.pageYOffset) + 120;
    var current = sections[0];

    for (var j = 0; j < sections.length; j++) {
      if (sections[j].el.offsetTop <= scrollY) current = sections[j];
    }

    for (var k = 0; k < sidebarLinks.length; k++) {
      sidebarLinks[k].classList.remove('active');
    }
    if (current) current.link.classList.add('active');
  }

  /* ---------- Tabs (event delegation for reliability) ---------- */
  document.body.addEventListener('click', function (e) {
    var btn = e.target.closest('.tab-btn');
    if (!btn) return;

    var targetId = btn.getAttribute('data-tab');
    if (!targetId) return;

    var tabsContainer = btn.closest('.tabs');
    if (!tabsContainer) return;

    var allBtns = tabsContainer.querySelectorAll('.tab-btn');
    var allPanels = tabsContainer.querySelectorAll('.tab-panel');

    for (var x = 0; x < allBtns.length; x++) allBtns[x].classList.remove('active');
    for (var x = 0; x < allPanels.length; x++) allPanels[x].classList.remove('active');

    btn.classList.add('active');
    var panel = document.getElementById(targetId);
    if (panel) panel.classList.add('active');
  });

  /* ---------- Accordion (event delegation) ---------- */
  document.body.addEventListener('click', function (e) {
    var trigger = e.target.closest('.accordion-trigger');
    if (!trigger) return;

    var item = trigger.closest('.accordion-item');
    if (!item) return;

    var content = item.querySelector('.accordion-content');
    if (!content) return;

    var wasOpen = item.classList.contains('open');
    if (wasOpen) {
      content.style.maxHeight = '0px';
      item.classList.remove('open');
    } else {
      item.classList.add('open');
      var h = content.scrollHeight;
      if (h <= 0) h = 600;
      content.style.maxHeight = h + 'px';
    }
  });

  /* ---------- Endpoint toggle (event delegation) ---------- */
  document.body.addEventListener('click', function (e) {
    var header = e.target.closest('.endpoint-header');
    if (!header) return;
    var endpoint = header.closest('.endpoint');
    if (endpoint) {
      endpoint.classList.toggle('open');
    }
  });

  /* ---------- Code copy ---------- */
  var copyBtns = document.querySelectorAll('.code-copy');
  for (var c = 0; c < copyBtns.length; c++) {
    copyBtns[c].addEventListener('click', function () {
      var btn = this;
      var block = btn.closest('.code-block');
      if (!block) return;
      var pre = block.querySelector('pre');
      if (!pre) return;
      var code = pre.textContent;

      function onCopied() {
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(function () {
          btn.textContent = 'Copy';
          btn.classList.remove('copied');
        }, 2000);
      }

      try {
        if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
          navigator.clipboard.writeText(code).then(onCopied).catch(function () {
            fallbackCopy(code, onCopied);
          });
        } else {
          fallbackCopy(code, onCopied);
        }
      } catch (err) {
        fallbackCopy(code, onCopied);
      }
    });
  }

  function fallbackCopy(text, cb) {
    var textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.left = '-9999px';
    document.body.appendChild(textarea);
    textarea.select();
    try { document.execCommand('copy'); } catch (e) { /* ignore */ }
    document.body.removeChild(textarea);
    if (cb) cb();
  }

  /* ---------- Intersection Observer for fade-in ---------- */
  var animTargets = document.querySelectorAll('.fade-in, .stagger');

  function enableAnimations() {
    document.body.classList.add('anim-ready');

    if ('IntersectionObserver' in window) {
      var observer = new IntersectionObserver(
        function (entries) {
          for (var i = 0; i < entries.length; i++) {
            if (entries[i].isIntersecting) {
              entries[i].target.classList.add('visible');
              observer.unobserve(entries[i].target);
            }
          }
        },
        { threshold: 0.05, rootMargin: '0px 0px 0px 0px' }
      );

      for (var i = 0; i < animTargets.length; i++) {
        observer.observe(animTargets[i]);
      }

      /* Safety: force-show everything after 2s in case observer fails */
      setTimeout(function () {
        for (var i = 0; i < animTargets.length; i++) {
          animTargets[i].classList.add('visible');
        }
      }, 2000);
    } else {
      /* No IntersectionObserver — show everything immediately */
      for (var i = 0; i < animTargets.length; i++) {
        animTargets[i].classList.add('visible');
      }
    }
  }

  /* Delay animation setup slightly to let layout settle */
  requestAnimationFrame(function () {
    requestAnimationFrame(enableAnimations);
  });

  /* ---------- Search ---------- */
  var searchIndex = [];

  function buildSearchIndex() {
    if (!mainContent) return;
    var sectionEls = mainContent.querySelectorAll('.doc-section[id]');
    for (var s = 0; s < sectionEls.length; s++) {
      var section = sectionEls[s];
      var sectionId = section.id;
      var heading = section.querySelector('h2');
      var sectionTitle = heading ? heading.textContent.trim() : sectionId;

      searchIndex.push({
        section: sectionTitle,
        title: sectionTitle,
        id: sectionId,
        type: 'section',
      });

      var headings = section.querySelectorAll('h3, h4');
      for (var h = 0; h < headings.length; h++) {
        searchIndex.push({
          section: sectionTitle,
          title: headings[h].textContent.trim(),
          id: sectionId,
          type: 'heading',
        });
      }

      var paras = section.querySelectorAll('p, li, td');
      for (var p = 0; p < paras.length; p++) {
        var text = paras[p].textContent.trim();
        if (text.length > 20 && text.length < 300) {
          searchIndex.push({
            section: sectionTitle,
            title: text.slice(0, 100) + (text.length > 100 ? '...' : ''),
            id: sectionId,
            type: 'content',
          });
        }
      }
    }
  }

  function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function performSearch(query) {
    if (!query || query.length < 2) {
      searchResults.classList.remove('active');
      return;
    }

    var q = query.toLowerCase();
    var results = [];
    var seen = {};

    for (var i = 0; i < searchIndex.length; i++) {
      if (results.length >= 8) break;
      var item = searchIndex[i];
      var matchTitle = item.title.toLowerCase().indexOf(q) !== -1;
      var matchSection = item.section.toLowerCase().indexOf(q) !== -1;

      if (matchTitle || matchSection) {
        var key = item.id + ':' + item.title.slice(0, 40);
        if (!seen[key]) {
          seen[key] = true;
          results.push(item);
        }
      }
    }

    if (results.length === 0) {
      searchResults.innerHTML = '<div class="search-result-item"><div class="result-title" style="color:var(--text-secondary);">No results found</div></div>';
    } else {
      var html = '';
      for (var r = 0; r < results.length; r++) {
        var highlighted = results[r].title.replace(
          new RegExp('(' + escapeRegex(query) + ')', 'gi'),
          '<mark>$1</mark>'
        );
        html += '<div class="search-result-item" data-target="' + results[r].id + '">' +
          '<div class="result-section">' + results[r].section + '</div>' +
          '<div class="result-title">' + highlighted + '</div>' +
          '</div>';
      }
      searchResults.innerHTML = html;
    }

    searchResults.classList.add('active');

    var resultItems = searchResults.querySelectorAll('.search-result-item[data-target]');
    for (var ri = 0; ri < resultItems.length; ri++) {
      resultItems[ri].addEventListener('click', function () {
        var target = document.getElementById(this.getAttribute('data-target'));
        if (target) {
          target.scrollIntoView({ behavior: 'smooth' });
          searchResults.classList.remove('active');
          searchInput.value = '';
          if (window.innerWidth < 768) closeSidebar();
        }
      });
    }
  }

  if (searchInput) {
    searchInput.addEventListener('input', function () { performSearch(this.value); });
    searchInput.addEventListener('focus', function () {
      if (this.value.length >= 2) performSearch(this.value);
    });
  }

  document.addEventListener('click', function (e) {
    if (!e.target.closest('.search-wrapper') && searchResults) {
      searchResults.classList.remove('active');
    }
  });

  /* ---------- Keyboard shortcut (Cmd+K) ---------- */
  document.addEventListener('keydown', function (e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      if (searchInput) { searchInput.focus(); searchInput.select(); }
    }
    if (e.key === 'Escape') {
      if (searchResults) searchResults.classList.remove('active');
      if (searchInput) searchInput.blur();
    }
  });

  /* ---------- Smooth scroll for anchor links ---------- */
  var anchors = document.querySelectorAll('a[href^="#"]');
  for (var an = 0; an < anchors.length; an++) {
    anchors[an].addEventListener('click', function (e) {
      var href = this.getAttribute('href');
      var target = document.querySelector(href);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth' });
        history.pushState(null, '', href);
      }
    });
  }

  /* ---------- Handle URL hash on load ---------- */
  if (window.location.hash) {
    var hashTarget = document.querySelector(window.location.hash);
    if (hashTarget) {
      setTimeout(function () {
        hashTarget.scrollIntoView({ behavior: 'smooth' });
      }, 300);
    }
  }

  /* ---------- Init ---------- */
  buildSearchIndex();
  updateActiveSidebarLink();
}

/* Run when DOM is ready (handles late script load) */
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', runDocInit);
} else {
  runDocInit();
}

/* ---------- Global functions for inline onclick (guaranteed to work) ---------- */
function switchInstallTab(btn) {
  var targetId = btn.getAttribute('data-tab');
  if (!targetId) return;
  var tabsContainer = btn.closest('.tabs');
  if (!tabsContainer) return;
  var allBtns = tabsContainer.querySelectorAll('.tab-btn');
  var allPanels = tabsContainer.querySelectorAll('.tab-panel');
  for (var i = 0; i < allBtns.length; i++) allBtns[i].classList.remove('active');
  for (var i = 0; i < allPanels.length; i++) allPanels[i].classList.remove('active');
  btn.classList.add('active');
  var panel = document.getElementById(targetId);
  if (panel) panel.classList.add('active');
}

function toggleAccordionItem(trigger) {
  var item = trigger.closest('.accordion-item');
  if (!item) return;
  var content = item.querySelector('.accordion-content');
  if (!content) return;
  var wasOpen = item.classList.contains('open');
  if (wasOpen) {
    content.style.maxHeight = '0px';
    item.classList.remove('open');
  } else {
    item.classList.add('open');
    var h = content.scrollHeight;
    if (h <= 0) h = 600;
    content.style.maxHeight = h + 'px';
  }
}

function toggleEndpointRow(headerEl) {
  var endpoint = headerEl.closest('.endpoint');
  if (endpoint) endpoint.classList.toggle('open');
}
