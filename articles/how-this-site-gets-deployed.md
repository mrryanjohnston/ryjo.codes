title: How This Site Gets Deployed
description: This article describes the process by which I deploy articles and updates to ryjo.codes. It also begins to explain some of my programming philosophies.
date: 2018-10-31
---
### Introduction

I wanted to put as much of myself into my personal website as I could. So,
what better way to do that than build the entire thing by hand?

I'm starting it all off by using a minimal set of tools. I don't really need
a full machine to host my site, since, so far, all of the content is written
in static files. I don't really need a fancy templating engine; I've already
got HTML. CSS precompiler? I have 25 lines of css including white space, so
that's out. Jenkins? Spinnaker? A web browser? Pah.

I'm hoping the articles on this site can illustrate an accurate picture of
how I like to view software development: use as little as you need. With
this in mind, I like to write software for people that provides them just
enough features so they can focus on the thing they actually want to do. In
this case, I get to be both developer and user, so I can add features only
as I need them from both an engineering need as well as a UX need. This
project is just for me.

If you haven't put two and two together yet, I'm overly excited at the
prospect.

### Technologies

Ideally, I don't use any software in my coding workflow that I don't need.
I'll apply the same concept to the development of this website. Animated
menus, commenting sytems and loading spinners are all fun. However, if they
aren't necessary to communicate my points, you won't see them here.

This isn't to say "I will never use Javascript or image tags." In fact,
Javascript will greatly help me in some cases. For example, when I want to
use code blocks in my articles, I'll use
[Rainbow](https://github.com/ccampbell/rainbow) to automatically parse my
code and add HTML tags to it so that they're easier to read. However, I will
only include the library in articles that have code blocks. This is easy to
do since I'm writing each HTML file by hand. Yeah, that's right.

This website is really only static files, and there is [a really good
story](https://docs.aws.amazon.com/AmazonS3/latest/dev/website-hosting-custom-domain-walkthrough.html)
for hosting static websites directly from S3 buckets. I don't need to spin
up and administer EC2 instances, so I won't bother with that. Cloudfront
allows me to upload a certificate and have SSL for my files in S3, so that's
cool. I use [Let's Encrypt](https://letsencrypt.org/) (which is free!) to
issue certs. Luckily, there is a command line tool that makes this process
really easy called
[certbot-s3front](https://github.com/dlapiduz/certbot-s3front).

Additionally, I want something that will let me deploy my code in a way that
doesn't interrupt my flow. Since I do most of my work in the terminal with
[tmux](https://github.com/tmux/tmux) and
[neovim](https://github.com/neovim/neovim), I'd prefer it if my articles
could also be deployed from the command line. Luckily, AWS provides
[aws-cli](https://github.com/aws/aws-cli) that will let me manage all of my
assets in the s3 buckets that host my site.

But hey, I don't want to manage resources in s3 buckets: I want to publish
articles to my site. If I have to manually do the conversion between the
thoughts "I am writing and publishing articles on my website" to "I am
putting html files in my s3 bucket," I'm wasting time as well as valuable
energy with those thoughts.

For this reason, I wrote [a small shell
script](https://github.com/mrryanjohnston/ryjo_static_site_deploy_scripts)
that abstracts the concept of "Upload these files to my s3 bucket." Now, I
can just write
`./publish.sh index.html articles/how-this-site-gets-deployed.html` and
boom, I've published this article as well as a new version of my index page
that has a link to said article.

### Philosophy

It may not seem like much, but consider that this process lets me always
think about my articles as articles rather than objects in an s3 bucket. I
think this is a valuable concept: humans enjoy abstract processes more than
the many technical parts that make up those processes. Therefor, I will be
more inclined to write articles as this abstraction allows me to context
switch less. I can focus on writing the content of the article rather than
thinking about all of the things that come with actually putting the article
out onto the net.

The amount of context switching is lessened even more by the fact that every
part of this process is possible through the use of the command line. I
never have to switch windows while I'm doing work, so I can remain focused
on the task at hand. I find this to be familiar to the flow I feel when
writing and committing code using [git](https://git-scm.com/).

A final awesome thing about using only cli tools is I can easily chain the
individual parts together to compose complex workflows. This is a very
powerful concept; small applications can be written for very specific
purposes. Over time, they can be stacked upon one another until there is a
professional, seamless pipeline that allows me to spend time on the parts of
work I enjoy.

Though, admittedly, I do quite enjoy the process of writing those scripts in
the first place.

\- ryjo
