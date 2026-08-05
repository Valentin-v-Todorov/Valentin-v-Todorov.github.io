# valentin-todorov.com

Personal site of Valentin Todorov - DevOps & Cloud Platform Engineer.

Live at [valentin-todorov.com](https://valentin-todorov.com), served by GitHub Pages
from the `main` branch root.

## Layout

```
index.html            Landing page (hero, about, stack, experience, contact)
projects.html         Projects listing with filters and detail modal
support.js            dc-runtime - parses the page and renders it with React
effects.js            Canvas and text effects, loaded via dynamic import()
vendor/               React 18.3.1 + ReactDOM 18.3.1 UMD builds, served locally
images/valentin.webp  Hero portrait
images/og.png         Open Graph / social share card (1200x630)
favicon.svg           Favicon
apple-touch-icon.png  Home screen icon (180x180)
CNAME                 Custom domain
.nojekyll             Serve files as-is, skip Jekyll processing
```

## How it renders

The pages are authored as `<x-dc>` documents: markup with `{{ }}` bindings plus
`<sc-for>` / `<sc-if>` control-flow elements. `support.js` parses that at load
time and renders it through React.

React and ReactDOM are committed under `vendor/` and loaded by plain `<script>`
tags ahead of `support.js`, so the site does not depend on a third-party CDN
being reachable. The runtime checks `window.React && window.ReactDOM` before it
reaches for unpkg, finds them already present, and skips the network entirely.
`support.js` itself is unmodified - it ships with a `do not edit` header.

Do not swap that for the runtime's `window.__resources` override map. Setting
that map also suppresses a re-fetch the runtime does on boot, and that re-fetch
is what repairs the hero headline after the `data-decrypt` scramble animation
finishes - without it the `<h1>` sticks permanently on a half-scrambled string
such as `VALENTIQ TODORS^`.

## Local preview

Any static file server works, since there is no build step:

```bash
python3 -m http.server 4599
```

Then open <http://localhost:4599>.

## Deploying

Push to `main`. GitHub Pages publishes the root of the branch.
