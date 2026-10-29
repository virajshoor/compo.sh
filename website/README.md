# Static launch website

Build the upload folder and Cloudflare Pages ZIP:

```sh
python3 scripts/package-website.py
```

Upload `dist/compo.sh-cloudflare.zip` to Cloudflare Pages Direct Upload, or select `dist/website` as the static output folder. `index.html` sits at the archive root. No build command, Node.js, framework, environment variables or server functions are needed.

Download buttons and checksum links point directly to the latest GitHub release. Older builds remain available through All versions. No app binary is embedded in this website package. Legacy `/downloads/` links redirect to GitHub on Cloudflare Pages; other static hosts can configure the two redirects from `_redirects` if needed. Main download buttons work without host-specific redirects.

The site uses standard HTML, CSS and browser JavaScript with system fonts, responsive layouts, native video controls and reduced-motion support. It remains readable and downloadable without JavaScript; the interactive layout preview needs JavaScript. H.264/AAC video includes a download fallback. Browser or OS versions without a needed media codec can download the film instead.

The universal app requires macOS 13+. Instant desktop switching requires macOS 26.6+. A website update cannot change these app requirements. Check each older release's notes for its compatibility.

Assets use relative URLs for root or subdirectory hosting. Canonical and social metadata assume https://compo.sh; update them if deploying to another production domain. `_headers` and `_redirects` are Cloudflare Pages configuration files. If deploying elsewhere, configure their equivalents through that host.
