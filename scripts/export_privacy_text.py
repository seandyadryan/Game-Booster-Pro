from html.parser import HTMLParser
from pathlib import Path


class PolicyText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_main = False
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag == 'main':
            self.in_main = True
        if self.in_main and tag == 'br':
            self.parts.append('\n')

    def handle_endtag(self, tag):
        if self.in_main and tag in ('p', 'h2', 'li'):
            self.parts.append('\n\n')
        if tag == 'main':
            self.in_main = False

    def handle_data(self, text):
        if self.in_main:
            self.parts.append(text if text.strip() else '')


root = Path(__file__).resolve().parent.parent
parser = PolicyText()
parser.feed((root / 'docs' / 'index.html').read_text(encoding='utf-8'))
text = 'Game Tools - Privacy Policy\nPT Deploy Dulu Pulang Nanti\n\n'
text += ''.join(parser.parts).strip() + '\n'
(root / 'assets' / 'privacy-policy.txt').write_text(text, encoding='utf-8')
print('Exported the policy text for in-app access.')
