# Borg, B2 and RClone

I've had a little anxiety about not having a running home-server
for a couple months. 
I switched the server off some time during the summer of 2020 because the disks
were hitting 90C and I didn't have the time to sort out fixing that situation.

Today I decided to just check that my backups in Backblaze B2 were okay and that they looked 
in-tact.

I use [Borg](https://www.borgbackup.org/) to back up to a local disk. 
Then I copy the Borg repo to [Backblaze B2](https://www.backblaze.com/b2/cloud-storage.html).

Because Borg backups are encrypted archives, I cant just open the B2 bucket through their web portal and
view my files. I can only view a Borg repo using the Borg command line tool.
So, to check my Backblaze-stored Borg repo was okay, I needed to have some method of pointing the Borg tool to 
the repo.

I've known about [RClone](https://rclone.org/) and was already planning to
transition to it, instead of using Backblaze's B2 CLI tool to push my backups
to B2.
RClone allows me to [mount a B2 bucket](https://rclone.org/b2/) as a filesystem on my local machine.
Thus, I have something that looks like a directory containing my backup repo that I can point the Borg tool at.

Once I had my bucket mounted ( using a Read Only application key, so that I
dont accidentally destroy my backups while testing this workflow out ) I commanded Borg to give me some stats about the repo:
`$ borg info -p -v repo_path/`

The first run of this command failed, because Borg tries to write a sentry file to serve as a lock on the repo. 
But, I was using a read-only key, so that wasnt allowed.
Borg has a `--bypass-lock` command though, which avoids trying to read, or create the file.

That command (with `--bypass-lock`) took about 2 hours to run and gave me a list of archives ( weekly backups ).
Given that it was interrogating a repo containing about 800GB of deduplicated information over a remote connection, that isnt surprising.

Afer it'd finished building some kind of index, further queries of the Borg repo were quite fast.
I could list all the files in an archive promptly.

Next, I attempted extracting a file from the archive ( `$ borg extract -p -v repo_path/::2020_01_01 path/to/file` ). 
However, a caveat of extracting files from Borg repos is that Borg will only
extract the files into a location at the same directory level as the repo
itself.
Because my repo is in a B2 bucket, that means that I can only extract files _into_ the bucket. Despite the repo being mounted with RClone.
So, I havent managed to extract a file, but I know that if I needed too, I'd have to give RClone a Read/Write application key for B2 and then 
I'd have the extracted files available in the bucket to download.

That poses a problem if I ever needed to extract a large amount of files, or a
particularly big file, as I'd expect it to take a long time. I'd need to
spend ages extracting the file into the bucket, then spend another long while
downloading it from B2. Plus, extracting the entire 800GB backup archive into
B2 and then downloading it is likely to cost me a lot of cash.

Perhaps it'd just be faster to download the entire ~800GB Borg repo straight
out of B2 and do the file/archive extraction locally for large files, or
retrieving an entire archive.

I'd like to find a solution that allows me to extract files straight down to my
local machine, but that is unlikely to happen I think.
