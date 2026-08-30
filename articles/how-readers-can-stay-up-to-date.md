title: How Readers Can Stay Up to Date
description: This article describes how I decided the next feature for this website was an RSS feed and generator.
date: 2018-11-08
css: syntax.css
---
### Introduction

[RSS](https://en.wikipedia.org/wiki/RSS) has been around since 1999-ish. As
far as technologies go, it's one of the simpler ones: it's a standardized
XML document. RSS readers are simply applications that occasionally poll the
RSS feeds they are "subscribed" to. I know, I was a little let down myself.

At first, anyway.

### Beauty in Simplicity

The more I thought about it, though, the more I liked the idea behind RSS.
Blogs already make their content available via an http GET. Not a lot of
extra effort has to go into providing another endpoint that basically acts
as a second index page. There's no "push" technology involved.

Another great advantage is users don't have to sign up for a darned thing.
This benefits me in that I don't have to provide any server-side code, and
users don't have to give their information to yet another service that could
someday be compromised. Win-win!

Third, users can "subscribe to" as many RSS feeds as they'd like. They are
only limited by the restrictions enforced by the RSS reader applications
they choose.

Finally, RSS feeds can be used in a wide varied of use cases; podcasts, news
websites and forums are all obvious candidates for the technology, but
really anything that could have updates could have an RSS feed.

### The "Technical" Details

Just as RSS is flexible and easy to consume, it is also lightweight and easy
to implement. You need a tad bit of boiler plate in the file, but aside from
that, the requirements to describe your website are laughably small: The
only fields necessary are title, description and link. Additionally, when
you add an item to your feed, you need only include either a title **or**
description. Beyond that, you just need to make your feed file accessible
via an http GET request, and suddenly you have an RSS feed.

I mean, come on.

### This Site's Implementation

Honestly, it'd be easy enough to just create the feed by hand and to add
items as I write articles. Since it's such a simple addition, though, I
thought it might be fun to add a script to the deploy scripts repo that
could update the feed automatically when I publish articles. This allows me
to stay in the context of "I'm writing and publishing," abstracting the
technical details of "I must also update the RSS feed file."

The two pieces I wrote are [an init
script](https://github.com/mrryanjohnston/ryjo_static_site_deploy_scripts/blob/master/init_rss_feed.sh)
that will start you off with a bit of boiler plate and [an add item
script](https://github.com/mrryanjohnston/ryjo_static_site_deploy_scripts/blob/master/add_item_to_rss_feed.sh)
that takes one html file as an argument and adds it to the feed.

Ok, so that's great if I wanted to type *two* commands every time I write a
new article. Ugh. I totally don't want to do that. If I settle for this
solution, I must remember to manually update and publish the feed every time
I write something. This extra step makes publishing an article seem like
more work than it is, and may subconsciously convince me to hold off on
writing a little while longer.

For this reason, I created
[ryjo.sh](https://github.com/mrryanjohnston/ryjo_static_site_deploy_scripts/blob/master/ryjo.sh)
which can be used to run arbitrary bash functions. It doesn't do much, but
it's meant to be used to run functions you define in your `.ryjo.conf` file.
This way, if you have custom publishing functionality for your static site,
you can define functions that turn smaller scripts into your own custom
workflow. For example, one of my uses of this static site is a blog, so my
`.ryjo.conf` file looks like this:

```bash
publish_article () {
  if add_item_to_rss_feed.sh $1
  then
    publish.sh index.html $1 $RYJO_RSS_FEED_FILE
  else
    echo "There was a problem adding $1 to the rss feed. Publishing canceled."
    exit 1;
  fi
}
```

Now, instead of typing out:

```bash
add_item_to_rss_feed.sh "articles/how-readers-can-stay-up-to-date.html"
publish.sh "feed.rss" "articles/how-readers-can-stay-up-to-date.html"
```

I only have to type:

```bash
ryjo.sh publish_article "articles/how-readers-can-stay-up-to-date.html"
```

Notice that there is no mention of a feed at all. It's assumed that my loyal
readers will be made aware of my article without any extra effort on my
part. Sweet.

### Just Enough

I really like the addition of an RSS feed; it provides a lot of
functionality with very little effort and very little code. Readers can now
get updates about my site in a way they're probably already familiar with.
Finally, it only requires me to add two new meta tags to each of my blog
posts, and I benefit from SEO by adding them anyway. All wins.

Want to subscribe? [Go ahead.](../feed.rss)

\- ryjo
