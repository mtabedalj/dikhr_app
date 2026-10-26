#!/usr/bin/env python3
"""Convert Athkar content plists to JSON data for Dikhr.
Audio file names are preserved (recordings live in Resources/Audio). The
recordings themselves are the original developer's property; only suitable to
bundle for personal/local testing."""
import plistlib, json, os

SRC = "/Applications/Athkar.app/Wrapper/athkar.app"
OUT = "/Users/mabedalj/athkari_app/Dikhr/Dikhr/Resources"
os.makedirs(OUT, exist_ok=True)

def load(name): return plistlib.load(open(os.path.join(SRC, name), "rb"))

pages = load("athkarList.plist")
pages_out = pages
json.dump(pages_out, open(f"{OUT}/athkar_pages.json","w"), ensure_ascii=False)

mix = load("mixList.plist")
json.dump(mix, open(f"{OUT}/mix.json","w"), ensure_ascii=False)

small = load("smallList.plist")
json.dump(small, open(f"{OUT}/small.json","w"), ensure_ascii=False)

content = load("Content.plist")
json.dump(content, open(f"{OUT}/content.json","w"), ensure_ascii=False)

more = load("moreList.plist")
json.dump(more, open("/Users/mabedalj/athkari_app/Dikhr/DikhrCore/Resources/prayer_methods.json","w"), ensure_ascii=False)

print("written to", OUT)
for f in sorted(os.listdir(OUT)): print(" ", f)