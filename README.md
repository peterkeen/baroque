# Baroque
## An elegant email client for a more civilized age

Periodically Gmail goes down for maintenance or is otherwise unavailable, and periodically that means I panic until it's back. I don't want this, and neither does anyone else around me. I decided to take up the task of writing a self-hosted Gmail replacement.

Eventually this will encompass four components:

* A generic IMAP fetcher to pull from Gmail and any other IMAP accounts you may have
* An efficient on-disk storage system for all of your email
* An efficient, fast full-text and faceted index
* A web-based email client filled to the brim with AJAXy goodness

As it stands, I have a very specific IMAP fetcher for my own gmail account and the on-disk storage system. This is actually a generic content-addressable storage engine heavily inspired by [Git](http://book.git-scm.com/7_how_git_stores_objects.html) ['ackfiles](http://book.git-scm.com/7_the_packfile.html). I chose not to use git directly mainly for the adventure, but also because `git gc` refuses to pack unlinked blobs, which is what I'm storing the emails as.

