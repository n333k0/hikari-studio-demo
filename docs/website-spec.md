# Website Spec — Hikari Studio

Durable description of what this site IS. If a change conflicts with this file,
stop and confirm before proceeding.

## Product
Single-page, static marketing site for Hikari Studio (Japanese-style rice-paper
lamps). Built by applying the Gantri design language (../DESIGN.md) to Hikari
content. Stack: index.html + styles.css + one inline <script>. No build step,
no framework. Language: Spanish (es-AR); English brand taglines allowed.

## Design system
- Accent: Hikari red `--accent:#E5381F` (+ `-hover`/`-active`). Actions, links,
  footer background ONLY. Everything else black/white/grey.
- Type: Inter (400 body, 800 for the footer wordmark). Size — not weight —
  carries hierarchy. Mono (Roboto Mono) for eyebrows/labels.
- Shape: pill buttons (radius 40px); square-cornered imagery; no drop shadows;
  flat low-opacity tints for hover.
- Layout: full-bleed. `--container:100%`; gutter 32px desktop / 16px ≤1024px.
- Button variants: `--contrast` (white fill/black text), `--outline` (white
  border/white text), `--primary` (red). Over photos use contrast + outline,
  never red.

## Page structure (order is intentional)
Header (fixed) → Hero (full-screen photo) → Marquee → Novedades (product
carousel) → "Rice & shine" statement + 3 value tiles → Explorá por forma
(category carousel) → Full-width process video → #HikariEnCasa (UGC) →
Footer (red) with edge-to-edge SVG wordmark.
Hidden by default (via `hidden` attr): #historia (mission), #acabado (finish rail).

## Component specs
- Header: grid `1fr auto 1fr`, explicit `grid-column` per child.
  - Desktop: logo left · nav centered · icons right (no hamburger).
  - ≤1024px: hamburger left · logo centered · icons right.
  - Logo = images/logo.png at height 50px (PNG has internal padding), width auto.
  - States: `--over` (transparent, white logo/nav/icons) and `--solid`
    (white bg, black; logo via `filter:brightness(0)`). Solid triggers when the
    marquee's top passes 0.7·innerHeight.
- Hero: full-screen background photo + radial vignette scrim (+ top scrim for
  header legibility). Centered white eyebrow/H1/sub. CTAs contrast + outline,
  stacked and hugging text on mobile.
- Video (#video): media/hikari-720.mp4 (360 fallback), muted autoplay loop,
  full-width, centered white text, ONE CTA (contrast). No "Ver tutoriales".
- Footer: red background, link columns, and a giant edge-to-edge "HIKARI STUDIO"
  wordmark as a self-fitting SVG with equal gutter on left/right/bottom.

## Copy rules
- NEVER claim the lamps are "handmade in Argentina / Buenos Aires" — they are
  not made here. Keep neutral/true claims (inspiración japonesa, papel de arroz,
  teñido en baño de té, envíos a todo el país). The CABA store address in the
  footer legal line is fine.
- Brand statement tagline: "Rice & shine" + "Japanese-inspired forms for modern
  spaces, made with real rice paper." Sentence case, balanced line break.

## Responsive contract
Three breakpoints: desktop (>1024px), tablet (641–1024px), mobile (≤640px).
- **Desktop >1024px:** desktop header (logo left · nav center · icons right);
  hero 100vh; 32px gutter; multi-card carousels; 3-col value tiles; footer 5 cols.
- **Tablet 641–1024px:** mobile header (hamburger); 24px gutter; hero ~86vh;
  hero CTAs side-by-side (hugging text); 3-col value tiles; carousels show ~3
  cards; footer 3 cols. (Dedicated `@media (min-width:641px) and (max-width:1024px)`
  block, placed after the ≤1024 rules so it overrides them.)
- **Mobile ≤640px:** mobile header; 16px gutter; hero CTAs stacked + hug text;
  value tiles single column; ~1 card per carousel view; footer 2 cols.
- The ≤1024px block holds the shared mobile+tablet baseline; the ≤640px and the
  641–1024px blocks specialize it. All widths: zero horizontal overflow; hero +
  wordmark keep equal side gutters.
- H1 hero title uses `clamp(4.6rem, 9vw, 11.6rem)` — ~116px cap on desktop,
  scales down to fit mobile.

## Deploy
Repo n333k0/hikari-studio-demo (public), GitHub Pages main/root.
Live: https://n333k0.github.io/hikari-studio-demo/
Deploy = commit + push main; Pages auto-builds. Never publish as a Claude Artifact
(real brand assets).
