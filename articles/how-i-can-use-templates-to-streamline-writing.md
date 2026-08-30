title: How I Can Use Templates to Streamline Writing
description: This article describes how I decided my next feature would be generated articles from templates.
date: 2018-11-26
css: syntax.css
---
### Introduction

Mimicry is the basis of learning for humans: a teacher presents their
subject to a student, and the student attempts recreating their actions.
Copying and pasting expedites this process immensely. With the Internet and
search engines, I can find a block of code somewhere reputable, make sure
it's not malicious, and copy it. I can then modify this code to suit my
personal needs, put in debugging statements, and satisfy all of my questions
about how that block of code works.

Copying and pasting code is a great way to begin learning the art of coding.
When you start copying and pasting your own code, that's when it's time for
an upgrade.

### "Dry"jo

As far as this website is concerned, there are a few places in which I'm
copying and pasting. The ones I decided to tackle for this article are:

1. Copying/pasting html files when creating new articles
2. Adding an `li` to the articles list on the index page
3. Manually formatting code blocks for syntax highlighting

On that last point: I know in [my first
article](/articles/how-this-site-gets-deployed.html) I said I would use a
javascript library to do that for me. However, I thought it would be a fun
challenge to figure out a way to do this myself. Fortunately for me, vim has
`:TOhtml` which will automatically convert the code in my editor into HTML.
There's still some manual work here, but I'm pretty satisfied for the time
being.

Instead of copying/pasting HTML from previous articles, I wrote a script
that would generate a bare bones article file. I debated whether or not to
include these scripts inside of [the deploy scripts
repo](https://github.com/mrryanjohnston/ryjo_static_site_deploy_scripts),
but I decided against this. The way I see it, those deploy scripts should be
for general static site deployments. Perhaps at some point I can push a set
of blog development tools that make use of the static tools.

### Templatize Me

It's pretty darned easy to use bash to write a string of text to a file:

```bash
echo "Foo" > foo.txt
```

It's not a far leap to imagine using an HTML string instead of just "Foo:"

```bash
echo "<title>ryjo.codes - My Article</title>" > foo.txt
```

Templates are really useful if you can pass in variables. Bash functions
make this easy enough:

```bash
foo () {
  echo "Hey, $1, how are you?"
}

foo "Ryan"
```

Where should this code go if not the deploy scripts? `ryjo.sh` provides the
functionality I need. I can store the following in `.ryjo.conf`:

```bash
article_template () {
cat << EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="description" content="$2" />
    <meta name="title" content="ryjo.codes - $1" />
    <title>ryjo.codes - $1</title>
    <link rel="stylesheet" type="text/css" href="../index.css" />
    <link rel="stylesheet" type="text/css" href="../bash.css" />
  </head>

  <body>
    <h1><a href="../">ryjo.codes</a></h1>
    <h2>$1</h2>
    <p><time datetime="$3">$4</time></p>
    <h3>Introduction</h3>
  </body>
</html>
EOF
}
```

Now I can write
`ryjo.sh article_template "Article Title" "A description for this article" "2018-11-21" "November 21st, 2018"`
and get a string back. Just add a `&gt; article.html` and boom, I have a new
article file.

### Time is Relative

I have no control over what date it is, so I can write some code to generate
the date values for me. In order to generate the two timestamp strings, I
had to write some code that did some semi-tricky stuff:

```bash
timestamp="$(date)"
datetime_value=$(date -d "$timestamp" +"%F")
day_suffix='th'
case `date -d "$timestamp" +%-d` in
  1|21|31) day_suffix="st";;
  2|22)    day_suffix="nd";;
  3|23)    day_suffix="rd";;
esac
time_content=$(date -d "$timestamp" +"%B %e$day_suffix, %Y")
```

The two important things are `datetime_value` and `time_content`. This let's
me fill in the template variables `$3` and `$4`.

### Content is Subjective

What is my pattern for determining what the filename should be? So far, I've
taken every word of the article title, made all the letters lowercase and
changed all of the spaces to dashes. Bash has this thing called "[Parameter
Expansion](http://wiki.bash-hackers.org/syntax/pe)." To lower the case of a
variable `foo`, I just have to do `echo "${foo,,}"`. Parameter Expansion
also lets me replace all occurrence of a string with another string like:
`echo "${foo// /-}"`.

This is cool, but would make us have to either use two variables (one for
the lower case string, one for the lower case string with dashs) or write
some funky looking code that might be confusing later. Instead, `tr` let's
me do all of the string substitution in one go:

```bash
filename="$(echo "Test Title" | tr ' [:upper:]' '-[:lower:]').html"
```

`tr` is another great example of how smaller tools can be glued together to
make some pretty powerful functionality.

### All Together Now

Pulling the pieces all together, I now have this function:

```bash
create_article () {
  filename="$(echo $1 | tr ' [:upper:]' '-[:lower:]').html"
  if [ -e "articles/$filename" ]
  then
    echo "File already exists at articles/$filename. Canceling creation."
  else
    timestamp="$(date)"
    datetime_value=$(date -d "$timestamp" +"%F")
    day_suffix='th'
    case `date -d "$timestamp" +%-d` in
      1|21|31) day_suffix="st";;
      2|22)    day_suffix="nd";;
      3|23)    day_suffix="rd";;
    esac
    time_content=$(date -d "$timestamp" +"%B %e$day_suffix, %Y")
    echo "$(article_template "$1" "$2" "$datetime_value" "$time_content")" > "articles/$filename"
    article_li=$(article_li_template "$1" "$filename" "$datetime_value" "$time_content")
    sed -i "0,/\(\s*<ul id=\"articles-list\">\\)/s||\1\n${article_li}|" "$PWD/index.html"
  fi
}
```

That last line does something tricky: it looks for a `ul` with and id of
"articles-list." It then spits out the filled in `article_li` text right at
the top of that list.

### Conclusion

I've automated several parts of my workflow with these changes:

1. Naming the article file
2. Copying/pasting old article into new article file
3. Filling in the title and description in both the meta tags and page
   content
4. Adding a list item to the articles list on the index page
5. Code block formatting

All in all, this probably saved about 15 minutes of time total. However, I
argue that making these changes will make writing articles more enjoyable.
Some of the monotony that comes with writing articles is now automated, and
now I can focus on the creative aspect of posting.

\- ryjo
