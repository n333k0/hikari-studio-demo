(function () {
  // Sticky header: transparent-over-hero -> solid on scroll.
  // Pages without a dark hero (e.g. product pages) start with only
  // header--solid and skip this entirely — nothing to toggle.
  var header = document.getElementById('header');
  if (header && header.classList.contains('header--over')) {
    var marquee = document.querySelector('.marquee');
    var onScroll = function () {
      // go solid once the marquee (just below the hero) scrolls up into view
      var solid = marquee
        ? marquee.getBoundingClientRect().top <= window.innerHeight * 0.7
        : window.scrollY > 300;
      header.classList.toggle('header--solid', solid);
      header.classList.toggle('header--over', !solid);
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  // Carousel chevrons
  document.querySelectorAll('[data-scroll]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var track = document.getElementById(btn.dataset.target);
      if (!track) return;
      var amount = Math.round(track.clientWidth * 0.8);
      track.scrollBy({ left: btn.dataset.scroll === 'next' ? amount : -amount, behavior: 'smooth' });
    });
  });

  // Disable chevrons at ends
  document.querySelectorAll('.track').forEach(function (track) {
    function update() {
      var prev = document.querySelector('[data-scroll="prev"][data-target="' + track.id + '"]');
      var next = document.querySelector('[data-scroll="next"][data-target="' + track.id + '"]');
      if (prev) prev.disabled = track.scrollLeft <= 4;
      if (next) next.disabled = track.scrollLeft + track.clientWidth >= track.scrollWidth - 4;
    }
    track.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    update();
  });
})();
