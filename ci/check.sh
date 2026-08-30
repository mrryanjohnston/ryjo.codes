#!/bin/sh
# Check the built site in build/ before it is published. Two things are worth
# checking on a site with no code in it: that no placeholder survived the
# templating, and that nothing links to a file that is not in the build - the
# second is how a renamed article or a forgotten entry in static-index turns
# into a 404 that nobody notices for a month.
#
# Usage: sh ci/check.sh   (run from anywhere; paths resolve to the repo)
set -eu
cd "$(dirname "$0")/.."

OUT=build
[ -d "$OUT" ] || { echo "check: no $OUT/ - run 'make' first" >&2; exit 1; }

status=0
fail() { echo "check: $*" >&2; status=1; }

# Paths that are live on the site but published by another repository, so they
# are correct links even though nothing here builds them.
is_elsewhere() {
  case "$1" in
    /tour-of-clips.html|/tour-of-clipsraylib.html) return 0 ;;
    /assets/tour-of-clips.*|/assets/clips-*) return 0 ;;
    *) return 1 ;;
  esac
}

pages=$(find "$OUT" -name '*.html' | LC_ALL=C sort)
[ -n "$pages" ] || { echo "check: no pages in $OUT/" >&2; exit 1; }

# 1. No placeholder survived. @NAME@ is the templating syntax, so one left in
#    the output means a template names something build.sh never filled in.
for p in $pages; do
  left=$(grep -oE '@[A-Z][A-Z_]*@' "$p" | LC_ALL=C sort -u || true)
  [ -z "$left" ] || fail "$p still holds $(echo "$left" | tr '\n' ' ')"
done

# 2. Every link to something inside the site resolves to a file in the build.
#    External urls, fragments and mailto: are somebody else's problem; a leading
#    / is from the top of the build, anything else is relative to the page.
#    The misses go through a file: the scan runs in a pipeline, whose subshell
#    could not set status from in there.
misses=$(mktemp)
trap 'rm -f "$misses" "$misses.ext"' EXIT
for p in $pages; do
  dir=$(dirname "$p")
  # Comments are stripped first, across lines: several articles keep the plain
  # source of a code sample in one, next to the syntax-highlighted copy that is
  # displayed, and the markup in there is not a link the page actually makes.
  awk '
    { line = $0; out = ""
      while (1) {
        if (incomment) {
          p = index(line, "-->")
          if (p == 0) { line = ""; break }
          incomment = 0; line = substr(line, p + 3); continue
        }
        p = index(line, "<!--")
        if (p == 0) { out = out line; break }
        out = out substr(line, 1, p - 1); line = substr(line, p + 4); incomment = 1
      }
      print out }
  ' "$p" |
  grep -oE '(href|src)="[^"]*"' | sed -E 's/^(href|src)="//; s/"$//' | LC_ALL=C sort -u |
  while read -r url; do
    url=${url%%#*}
    case "$url" in
      ''|http://*|https://*|//*|mailto:*|data:*) continue ;;
      /*) if is_elsewhere "$url"; then continue; fi; target="$OUT$url" ;;
      *)  target="$dir/$url" ;;
    esac
    [ -e "$target" ] || echo "$p -> $url" >> "$misses"
  done
done
if [ -s "$misses" ]; then
  while read -r m; do echo "check: broken link $m" >&2; done < "$misses"
  fail "$(wc -l < "$misses") broken link(s)"
fi

# 3. Every published file has an extension the deploy knows how to type. S3
#    serves whatever content-type it is given, and the deploy gives one per
#    extension, so a new kind of file has to be taught to both or it reaches
#    visitors as an octet-stream they are asked to download.
known='html css png jpg ico svg xml txt rss webmanifest mp4 webm md'
find "$OUT" -type f | while read -r f; do
  ext=${f##*.}
  case " $known " in
    *" $ext "*) ;;
    *) echo "$f -> .$ext" >> "$misses.ext" ;;
  esac
done
if [ -s "$misses.ext" ]; then
  while read -r m; do echo "check: no content-type for $m" >&2; done < "$misses.ext"
  fail "$(wc -l < "$misses.ext") file(s) with an extension the deploy does not know"
fi

# 4. Every article named on the front page is really there to be clicked, and is
#    in the feed too - the two are built from the same list, so a slug missing
#    from one of them means the list was read differently by the two.
while read -r slug; do
  case "$slug" in ''|'#'*) continue ;; esac
  [ -f "$OUT/articles/$slug.html" ] || fail "articles-index lists $slug with no page in the build"
  grep -q "articles/$slug.html" "$OUT/index.html" || fail "$slug is in articles-index but not on the front page"
  grep -q "articles/$slug.html" "$OUT/feed.rss" || fail "$slug is in articles-index but not in the feed"
done < articles-index

# 5. The feed parses. It is the one file here nothing renders locally, so a
#    stray & or < in a title would only ever turn up in somebody's reader.
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$OUT/feed.rss" \
    || fail "$OUT/feed.rss is not well-formed xml"
fi

[ $status -eq 0 ] && echo "check: $(echo "$pages" | wc -l) pages ok"
exit $status
