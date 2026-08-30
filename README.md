# ryjo.codes

The source of [ryjo.codes](https://ryjo.codes/). The published site is generated
into `build/` by `build.sh` which is POSIX `sh` and `awk`.

```sh
make          # generate the site into build/
make check    # generate it and check the result
make serve    # generate it and serve build/ at http://localhost:8000/
make clean
```

## What is a source and what is generated

    template/index.html     the front page, minus articles and projects lists
    template/article.html   the frame every article page is added into
    template/feed.rss       the rss feed, minus its items
    projects-index          what the Projects section holds, in order
    articles-index          what the Articles section holds, in order
    articles/<slug>.md      one article: front matter, then the body in markdown
    articles/*              the images, video and stylesheets the articles link to
    static/                 published as it stands: static/robots.txt is /robots.txt
    *.css                   published under a content hash, see Stylesheets below
    build/                  the generated site

## Writing an article

An article is a file `articles/<slug>.md`. It starts with metadata: `key:
value` lines closed by a line holding only `---`, followed by the body of the
page in markdown. Everything above the first heading in a finished page - the
doctype, the head, the site heading, the title and the date - comes from
`template/article.html`.

```markdown
title: A* Algorithm Written in CLIPS
description: This article describes the A* Algorithm. It also demonstrates an implementation of the algorithm in CLIPS.
date: 2023-01-10
css: syntax.css articles/a-star-algorithm-written-in-clips.css
---
### Introduction

The [A* (A-star) Algorithm](https://theory.stanford.edu/~amitp/GameProgramming/AStarComparison.html)
is a great way to determine the shortest distance between two points...
```

`title` and `description` are required. `date` is optional and, when given, is
`YYYY-MM-DD` - the "January 10th, 2023" under the heading and the one beside the
link on the front page are both derived from it.
`css` names extra stylesheets by their path from the top of the tree; `styles.css`
is on every page and is never listed. `image` sets an `og:image`. Any other key
is a typo and fails the build.

Dropping the file in `articles/` is all it takes to publish the page. Adding its
slug to `articles-index` is what links it from the front page and puts it in
`feed.rss`, and where in that file the slug sits is where in both lists the
article appears.

Everything else in `articles/` is published untouched.

## The markdown

The dialect is small, because it only has to cover what the prose needs:

    ### heading            #### heading
    a paragraph            blank lines separate blocks
    - item                 1. item      (a line without a marker continues the item above)
    `code`  **bold**  *italic*  [text](url)
    ![alt](src)            an image; [![alt](small)](big) links one to the other
    `[text](url)`          a link inside a code span; nothing else expands there
    \*  \`  \[  \\         a backslash makes the next character literal
    ```bash ... ```        a fenced block, the word after the fence is the class
    ```clips ... ```       the word names the language it is coloured as, below
    ```c focus={2,7-9} ``` the lines the block is about, the rest of it dimmed
    ### heading {#name}    an id for a [link](#name) elsewhere to land on
    > quoted line          a quotation, run together and wrapped as a paragraph

Everything else (raw html) is passed through untouched -
that is what the figures and the grid diagrams are.
An html block runs to the tag that closes it rather than to the
next blank line, so a blank line inside a `<pre>` or a `<figure>` is kept.
Inline tags in a paragraph are left alone too, which is how a `<sup>` gets in.

A link opens in a new tab when it leaves the site: an anchor, a relative path
and a link back to ryjo.codes do not. An asterisk only opens emphasis when a
non-space follows it, so "the A* Algorithm" needs no escaping.

## Highlighting

Every fence on the site is coloured by `build.sh` itself. What each of them
implements is the vim syntax file of the same name, because the colours are the
ones the blocks already in the tree carried and those came out of vim:

    ```clips        syntax/jess.vim, the filetype vim gives a .clp
    ```bash         syntax/sh.vim, as vim reads a file it has decided is bash
    ```c  ```cpp    syntax/c.vim, and the words syntax/cpp.vim lays over it
    ```go  ```ruby  syntax/go.vim and syntax/ruby.vim
    ```json         syntax/json.vim
    ```html         syntax/html.vim, and syntax/javascript.vim for a <script>
    ```javascript   syntax/javascript.vim on its own
    ```make         syntax/make.vim
    ```cmake        syntax/cmake.vim
    ```diff         syntax/diff.vim
    ```sshconfig    syntax/sshconfig.vim
    ```crontab      syntax/crontab.vim
    ```systemd      syntax/dosini.vim
    ```debcontrol   syntax/debcontrol.vim
    ```debchangelog syntax/debchangelog.vim

The colours themselves live in `syntax.css`, which a page lists when it shows a
highlighted block of any kind.

## Heading ids

A heading can name the id it carries, in the braces pandoc spells that with and
most of the other dialects read:

    ### From Scratch, As Usual {#local}

The braces come off the end and the rest is the heading.
An anchor written `[text](#local)` links to this header.
A heading that ends in a brace naming no id stops the
build rather than publishing the braces as text.

## Focus

The word after the fence is the language, and what follows it is an attribute.
To highlight only specific lines and dim the rest:

    ```c focus={2,7-9,14:7-28}

A number is a line and `7-9` a range of them. A colon names the columns of a
line rather than the whole of it: `14:7-28` lights those, `14:7-` lights from
there to the end of the line, and `14:7` that one column. Lines are counted from
1, and so are columns, in characters of the source - a tab is one column and an
escaped quote is one. A line named with columns is lit only there, a line named
without them is lit whole, and a line named nowhere is dimmed whole.

A `focus=` that names a line or a column the block does not have, a range that
runs backwards, or an attribute that is not `focus=` stops the build. So does a
`focus=` on a fence that names no language, there being nothing to dim it
against.

## The feed

`feed.rss` is generated from `articles-index` and the front matter, so it holds
the same articles as the front page, in the same order. An article is dated to
the day, so items are published at midnight UTC, and the channel is dated to the
newest article rather than to the moment of the build - rebuilding without
writing anything leaves the file unchanged.

## Stylesheets

Every stylesheet a page links to is published under a hash of its contents, at
`/assets/<name>.<hash>.css`, and served with a one-year cache. A page therefore
keeps loading the stylesheet it was built against.

The media beside the articles is not content-addressed: an article body names a
screenshot by the plain filename sitting next to it.

## Deploying

`.github/workflows/deploy.yml` builds and checks the site on every push and pull
request, and on `main` uploads it to S3 and invalidates the changed paths in
CloudFront. It assumes AWS role for a repository environment named `production`:

    secrets.AWS_ROLE_ARN                  the role the OIDC token is exchanged for
    secrets.S3_BUCKET                     the bucket behind the distribution
    secrets.CLOUDFRONT_DISTRIBUTION_ID    the distribution to invalidate
    vars.AWS_REGION

Nothing is ever deleted from the bucket. It holds the whole site, including
`/tour-of-clips.html` and `/tour-of-clipsraylib.html`, which the
[tour-of-clips](https://github.com/mrryanjohnston/tour-of-clips) and
[Wasm-CLIPSraylib](https://github.com/mrryanjohnston/Wasm-CLIPSraylib)
repositories publish into it themselves.
