#! /usr/bin/env python3
import argparse


parser = argparse.ArgumentParser()
parser.add_argument("-name", help="Name of the game entry", action="store")
parser.add_argument("-date", help="The date in dd/mm/yy", action="store")
parser.add_argument("-role", help="The role", action="store")
parser.add_argument("-note", help="Notes", action="append", nargs="*")

args = parser.parse_args()

notes = " ".join(["({})".format(note[0]) for note in args.note])

new_entry = []
new_entry.append("<hr>\n")
new_entry.append(f"#### ***{args.date}*** {args.name} {notes}\n")
new_entry.append(f"**{args.role}**\n")


with open("public/rollerderby", "r+") as f:
    contents = f.readlines()
    new_contents = contents[0:6] + new_entry + contents[6:]
    import pdb;pdb.set_trace()
    f.seek(0)
    f.write("".join(new_contents))




