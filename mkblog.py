#! /usr/bin/env python3
import argparse
from datetime import datetime
from subprocess import run
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument("name", help="The title of the blog", action="store")

args = parser.parse_args()

title = args.name
title_dashes = title.replace(" ", "-").replace(",", "")
date = datetime.date(datetime.now())

filename = pathlib.Path(f"{date.year}-{date.month}-{date.day}-{title_dashes}.md")

path = pathlib.Path("public/blog") / filename

with open(path, "w") as f:
    f.write(f"# {title}")

print(path)

run(["vim", path])

