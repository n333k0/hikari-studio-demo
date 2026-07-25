(function () {
  /* ---------- Modals (gallery lightbox / compartir / medios de envío / AR) ---------- */
  /* A <model-viewer> that boots inside a display:none modal has no size to lay
     out against, and auto-rotate leaves it spun wherever the last visit ended.
     Re-assert the authored framing once the panel is actually on screen, so the
     modal always opens on the same composed shot. */
  function reframeViewer(mv) {
    requestAnimationFrame(function () {
      if (typeof mv.updateFraming !== 'function') return;
      Promise.resolve(mv.updateComplete)
        .then(function () { return mv.updateFraming(); })
        .then(function () {
          if (typeof mv.resetTurntableRotation === 'function') mv.resetTurntableRotation();
          mv.cameraTarget = mv.getAttribute('camera-target');
          mv.cameraOrbit = mv.getAttribute('camera-orbit');
          mv.jumpCameraToGoal();
        });
    });
  }
  function openModal(id) {
    var modal = document.getElementById(id);
    if (!modal) return;
    modal.hidden = false;
    document.body.style.overflow = 'hidden';
    var mv = modal.querySelector('model-viewer');
    if (mv) reframeViewer(mv);
  }
  function closeModal(modal) {
    modal.hidden = true;
    document.body.style.overflow = '';
  }
  document.querySelectorAll('[data-modal-open]').forEach(function (btn) {
    btn.addEventListener('click', function () { openModal(btn.dataset.modalOpen); });
  });
  document.querySelectorAll('.modal').forEach(function (modal) {
    modal.querySelectorAll('[data-modal-close]').forEach(function (el) {
      el.addEventListener('click', function () { closeModal(modal); });
    });
  });
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    document.querySelectorAll('.modal:not([hidden])').forEach(closeModal);
  });

  /* ---------- Pinned scroll gallery: image swaps as you scroll through the
     tall wrapper, small overlaid dots show progress, then it releases into
     the next section (Gantri pattern). Desktop/laptop only — see the
     ≤1024px override in product.css that turns this back into a normal
     static image. ---------- */
  var galleryScroll = document.getElementById('galleryScroll');
  var galleryMain = document.getElementById('galleryMainImg');
  var dots = Array.prototype.slice.call(document.querySelectorAll('.pdp-gallery__dot'));
  var progressLabel = document.getElementById('galleryProgress');
  var photos = dots.map(function (d) { return d.querySelector('img').src; });
  var activeIdx = 0;

  function isGalleryPinned() {
    return window.matchMedia('(min-width: 1025px)').matches;
  }

  if (galleryScroll && dots.length) {
    function setupGalleryHeight() {
      galleryScroll.style.height = isGalleryPinned() ? (dots.length * 90) + 'vh' : '';
    }
    setupGalleryHeight();
    window.addEventListener('resize', setupGalleryHeight);

    function swapTo(idx) {
      if (idx === activeIdx || !galleryMain) return;
      activeIdx = idx;
      galleryMain.classList.add('is-fading');
      setTimeout(function () {
        galleryMain.src = photos[idx];
        galleryMain.classList.remove('is-fading');
      }, 140);
      dots.forEach(function (d, i) { d.classList.toggle('is-active', i === idx); });
      if (progressLabel) progressLabel.textContent = (idx + 1) + ' / ' + dots.length;
    }

    function onGalleryScroll() {
      if (!isGalleryPinned()) return;
      var total = galleryScroll.offsetHeight - window.innerHeight;
      if (total <= 0) return;
      var scrolled = -galleryScroll.getBoundingClientRect().top;
      var progress = Math.min(1, Math.max(0, scrolled / total));
      swapTo(Math.min(dots.length - 1, Math.floor(progress * dots.length)));
    }
    window.addEventListener('scroll', onGalleryScroll, { passive: true });
    onGalleryScroll();

    dots.forEach(function (dot) {
      dot.addEventListener('click', function () {
        var idx = parseInt(dot.dataset.index, 10);
        if (!isGalleryPinned()) { swapTo(idx); return; }
        var total = galleryScroll.offsetHeight - window.innerHeight;
        var targetY = galleryScroll.offsetTop + (idx / dots.length) * total + 10;
        window.scrollTo({ top: targetY, behavior: 'smooth' });
      });
    });
  }

  /* open the gallery lightbox on whatever photo is currently showing */
  var galleryMainBox = document.querySelector('.pdp-gallery__main');
  var lightboxImg = document.querySelector('#modal-gallery img');
  if (galleryMainBox && lightboxImg && galleryMain) {
    galleryMainBox.addEventListener('click', function (e) {
      if (e.target.closest('.pdp-gallery__dot')) return;
      lightboxImg.src = galleryMain.src;
      openModal('modal-gallery');
    });
  }

  /* ---------- Scroll-reveal statement: each word lights up from light-grey
     to dark as the pinned title+paragraph is scrolled past. ---------- */
  document.querySelectorAll('[data-reveal]').forEach(function (el) {
    var words = el.textContent.split(/(\s+)/);
    el.innerHTML = words.map(function (chunk) {
      return /^\s+$/.test(chunk) ? chunk : '<span class="rv-word">' + chunk + '</span>';
    }).join('');
  });
  var revealSection = document.getElementById('descReveal');
  var revealWords = document.querySelectorAll('.rv-word');
  function onRevealScroll() {
    if (!revealSection || !revealWords.length) return;
    var total = revealSection.offsetHeight - window.innerHeight;
    var rect = revealSection.getBoundingClientRect();
    var progress = total > 0 ? Math.min(1, Math.max(0, -rect.top / total)) : (rect.top < 0 ? 1 : 0);
    var activeCount = Math.round(progress * revealWords.length);
    revealWords.forEach(function (w, i) { w.classList.toggle('is-active', i < activeCount); });
  }
  window.addEventListener('scroll', onRevealScroll, { passive: true });
  onRevealScroll();

  /* ---------- Qty stepper ---------- */
  var qty = document.querySelector('.pdp-qty input');
  document.querySelectorAll('.pdp-qty button').forEach(function (btn) {
    btn.addEventListener('click', function () {
      if (!qty) return;
      var v = parseInt(qty.value, 10) || 1;
      v = btn.dataset.step === 'up' ? v + 1 : Math.max(1, v - 1);
      qty.value = v;
    });
  });

  /* ---------- Compartir: native share when available, else the modal ---------- */
  document.querySelectorAll('[data-share]').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      if (navigator.share) {
        e.preventDefault();
        navigator.share({ title: document.title, url: location.href }).catch(function () {});
      }
    });
  });
  var copyBtn = document.querySelector('.modal__copylink button');
  if (copyBtn) {
    copyBtn.addEventListener('click', function () {
      navigator.clipboard.writeText(location.href).then(function () {
        copyBtn.textContent = 'Copiado';
        setTimeout(function () { copyBtn.textContent = 'Copiar'; }, 1600);
      });
    });
  }

  /* ---------- Sticky bottom purchase bar: fades/slides in once the main
     Add to cart button scrolls out of view. It's position:sticky in the
     CSS (last child of <main>) so it naturally stops right above the
     footer on its own — this JS only controls the show/hide, not the
     "stop before the footer" part. ---------- */
  var sticky = document.querySelector('.pdp-sticky');
  var mainAtc = document.querySelector('.pdp-buyrow .btn--primary');
  var waFab = document.getElementById('waFab');
  if (sticky && mainAtc && 'IntersectionObserver' in window) {
    // Plain `!isIntersecting` isn't enough: it's also true before the user
    // has scrolled down to the button at all (e.g. on mobile, where the
    // button starts below the fold under the gallery photo) — that fired
    // "visible" immediately on load. Only show the bar once the button has
    // actually scrolled UP and OUT the top of the viewport.
    var io = new IntersectionObserver(function (entries) {
      var entry = entries[0];
      var visible = !entry.isIntersecting && entry.boundingClientRect.bottom < 0;
      sticky.classList.toggle('is-visible', visible);
      if (waFab) waFab.classList.toggle('is-raised', visible);
    });
    io.observe(mainAtc);
  }

  /* ---------- "Agregar al carrito" (no real cart on this rebuild — same
     no-op pattern as the rest of the site's header cart icon) ---------- */
  document.querySelectorAll('[data-add-to-cart]').forEach(function (btn) {
    btn.addEventListener('click', function (e) { e.preventDefault(); });
  });

  /* ---------- AR modal: real device AR via <model-viewer>, with a real
     client-side QR code (qrcode-generator, MIT) as the desktop fallback so
     you can jump straight to the phone experience instead of a dead end. ---------- */
  var viewer = document.getElementById('arViewer');
  if (viewer) {
    var arBtn = document.getElementById('arActivateBtn');
    var supportedNote = document.getElementById('arSupportedNote');
    var qrBlock = document.getElementById('arQrBlock');
    var qrCodeEl = document.getElementById('arQrCode');
    var desktopNote = document.getElementById('arDesktopNote');
    var qrRendered = false;

    function renderQr() {
      if (qrRendered || !qrCodeEl || typeof qrcode === 'undefined') return;
      var url = location.origin + location.pathname + '?ar=1';
      var qr = qrcode(0, 'M');
      qr.addData(url);
      qr.make();
      qrCodeEl.innerHTML = qr.createSvgTag({ scalable: true });
      qrRendered = true;
    }

    function syncArSupport() {
      var supported = !!viewer.canActivateAR;
      if (arBtn) arBtn.hidden = !supported;
      if (supportedNote) supportedNote.hidden = !supported;
      if (qrBlock) qrBlock.hidden = supported;
      if (desktopNote) desktopNote.hidden = supported;
      if (!supported) renderQr();
    }
    viewer.addEventListener('ar-status', syncArSupport);
    viewer.addEventListener('load', syncArSupport);
    if (arBtn) arBtn.addEventListener('click', function () { viewer.activateAR(); });

    /* loading progress bar (model-viewer's documented progress-bar slot) */
    var progressBar = document.getElementById('mvProgressBar');
    var progressWrap = document.getElementById('mvProgress');
    viewer.addEventListener('progress', function (event) {
      if (progressBar) progressBar.style.width = (event.detail.totalProgress * 100) + '%';
    });
    viewer.addEventListener('load', function () {
      if (progressWrap) progressWrap.classList.add('is-done');
    });

    /* ---------- Cord-length slider (pendants only) ----------
       Lets you drag the shade up and down its cord to see how it would fall in
       a room with a standard 2.40m ceiling — the real question when ordering a
       pendant. It moves the shade rather than the ceiling, because that is what
       a longer cord does.

       Two honest limitations, both deliberate:
       - PREVIEW ONLY. Quick Look and Scene Viewer load a static .usdz/.glb and
         there is no way to hand them a slider value, so the AR session always
         shows the authored length. The hint text under the slider says so.
       - It reaches the three.js scene through model-viewer's internal
         `Symbol(scene)`. The public `model` API exposes materials and variants
         but no scene nodes, so there is no supported alternative. Everything
         below therefore fails soft: any missing symbol, node or geometry just
         leaves the control [hidden] and the page behaves exactly as before.
         The CDN version is pinned in the page <head> for the same reason. */
    function setupCordSlider() {
      var control = document.getElementById('arCordControl');
      var range = document.getElementById('arCordRange');
      var valueOut = document.getElementById('arCordValue');
      var dropOut = document.getElementById('arCordDrop');
      var cordName = viewer.dataset.cordNode;
      if (!control || !range || !cordName) return;

      var sceneSym = Object.getOwnPropertySymbols(viewer).filter(function (s) {
        return String(s) === 'Symbol(scene)';
      })[0];
      var scene = sceneSym && viewer[sceneSym];
      if (!scene || typeof scene.getObjectByName !== 'function') return;

      var cord = scene.getObjectByName(cordName);
      if (!cord || !cord.geometry) return;
      cord.geometry.computeBoundingBox();
      var cordBox = cord.geometry.boundingBox;
      var cordGeomHeight = cordBox.max.y - cordBox.min.y;
      if (!(cordGeomHeight > 0)) return;

      /* Everything that isn't the cord, the canopy or the floor anchor rides
         with the shade. Identifying the shade by exclusion means a new pendant
         only has to name its cord, not paste in a generated mesh id. */
      var fixed = [cordName, viewer.dataset.canopyNode, 'ar_floor_anchor'];
      var movers = [];
      scene.traverse(function (o) {
        if (o.isMesh && o.geometry && fixed.indexOf(o.name) === -1) movers.push(o);
      });
      if (!movers.length) return;

      var ceiling = cord.position.y + cordBox.max.y * cord.scale.y;
      var baseLen = cordGeomHeight * cord.scale.y;
      var cordBottom = ceiling - baseLen;

      var offsets = movers.map(function (m) { return m.position.y - cordBottom; });
      var lowest = Infinity;
      movers.forEach(function (m) {
        m.geometry.computeBoundingBox();
        var y = m.position.y + m.geometry.boundingBox.min.y * m.scale.y;
        if (y < lowest) lowest = y;
      });
      var dropOffset = lowest - cordBottom;   // shade underside, relative to cord end

      function fmtMetres(m) { return m.toFixed(2).replace('.', ','); }

      function apply(lenM) {
        cord.scale.y = lenM / cordGeomHeight;
        cord.position.y = ceiling - cordBox.max.y * cord.scale.y;
        movers.forEach(function (m, i) { m.position.y = (ceiling - lenM) + offsets[i]; });
        if (typeof scene.queueRender === 'function') scene.queueRender();

        var shadeBottom = ceiling - lenM + dropOffset;
        /* Re-centre on the lamp as it drops, or a long cord walks the shade out
           of the bottom of the frame. Written to the ATTRIBUTE, not just the
           property, so reopening the modal (which re-applies the authored
           framing) doesn't snap the camera back off the lamp. */
        viewer.setAttribute('camera-target',
          '0m ' + ((ceiling + shadeBottom) / 2).toFixed(3) + 'm 0m');

        if (valueOut) valueOut.textContent = Math.round(lenM * 100) + ' cm';
        if (dropOut) dropOut.textContent = fmtMetres(shadeBottom) + ' m';
      }

      var minCm = Math.round(parseFloat(viewer.dataset.cordMin || '0.25') * 100);
      var maxCm = Math.round(parseFloat(viewer.dataset.cordMax || '1.00') * 100);
      range.min = minCm;
      range.max = maxCm;
      range.value = Math.round(baseLen * 100);
      range.addEventListener('input', function () { apply(parseInt(range.value, 10) / 100); });
      apply(baseLen);
      control.hidden = false;
    }

    if (viewer.loaded) setupCordSlider();
    viewer.addEventListener('load', setupCordSlider, { once: true });

    /* arriving from a QR scan (?ar=1): jump straight into the AR modal */
    if (new URLSearchParams(location.search).get('ar') === '1') {
      openModal('modal-ar');
    }
  }
})();
