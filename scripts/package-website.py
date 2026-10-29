"""Validate and package the static landing page without stale app downloads."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
source = root / 'website'
output = root / 'dist' / 'website'
assets = ['index.html', '404.html', 'style.css', 'demo.js', 'logo.svg',
          'social.png', 'robots.txt', 'sitemap.xml', '_headers', '_redirects',
          'compo-launch.mp4', 'launch-poster.jpg']

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, 'Duplicate ID'
            self.ids.add(attrs['id'])
        for key in ['href', 'src', 'poster']:
            if key in attrs:
                self.links.append(attrs[key])

html = (source / 'index.html').read_text()
parsed = Links()
parsed.feed(html)
for link in parsed.links:
    url = urlsplit(link)
    if url.scheme or url.netloc:
        continue
    if url.path and url.path != './':
        assert unquote(url.path).lstrip('/') in assets, f'Missing asset: {link}'
    if url.fragment:
        assert url.fragment in parsed.ids, f'Missing section: {link}'
assert 'http-equiv="refresh"' not in html
assert 'releases/latest/download/compo.sh-macOS.zip' in html
assert 'releases/latest/download/SHA256SUMS.txt' in html
assert '/downloads/' not in html
assert 'media-src \'self\'' in (source / '_headers').read_text()
assert not any(line.startswith('/* ') for line in (source / '_redirects').read_text().splitlines())
assert 'noindex' not in html
for name in assets:
    assert (source / name).is_file(), f'Missing file: {name}'
if output.exists():
    shutil.rmtree(output)
output.mkdir(parents=True)
for name in assets:
    shutil.copy2(source / name, output / name)
archive = root / 'dist' / 'compo.sh-cloudflare.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    for name in assets:
        package.write(output / name, name)
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    assert sorted(package.namelist()) == sorted(assets)
print(f'Validated {len(parsed.links)} links and {len(assets)} assets.')
print(f'Upload folder: {output}')
print(f'Upload ZIP: {archive}')
