title: CLIPS: An Elevator Pitch
description: Have you heard about CLIPS? In this article, I attempt an elevator pitch for CLIPS
date: 2024-05-30
css: syntax.css
image: https://ryjo.codes/stwawbewwy.png
---
Have you ever found yourself implementing your own indexing, caching, or
database logic inside of your application code? Then surely you know how
painful things become when your team experiences bottlenecked performance
and obscure production bugs that send waves of anxiety across your entire
company.

Perhaps you will be pleased to learn that this wheel has already been
invented. A decent enough "elevator pitch" for CLIPS:

CLIPS is a programming language that provides an indexed and cached database
automatically based on your application logic. It's algorithmically the most
efficient way to implement your application's business logic, full stop.

Have I caught your attention?

### Patterns

I am making these assumptions based on my own experiences working in the
software industry for the last 12-ish years. In that time, I've worked at 7
companies at which I've observed common patterns that arise while building
web applications:

1. A front-end javascript-/html-/css-based application talks to
2. A back-end serving an HTTP API that talks to
3. A SQL database

Has your team implemented a custom:

- In-app cache
- DSL for a Permission Evaluator
- Local data pre-fetching script

How about some common organization-wide issues that arise, such as:

- Slow database queries
- Slow "seed" code that pre-fetches data from the database and indexes it
  for easy, denormalized access in your application
- Stale or Clobbered data in a custom in-house in-application cache

If the answer to these questions is "Yes," allow me to introduce you to
CLIPS by way of an example.

### The Power of CLIPS: An Example

I'll demonstrate why CLIPS is so powerful with a very simple code example:

```
CLIPS> (defrule foo (a $?a) (b $?b) (c $?c&$?a|$?b) =>)
CLIPS> (watch all)
CLIPS> (assert (a 1 2 3 4) (b a b c d) (c a b c d))
==> f-1     (a 1 2 3 4)
==> f-2     (b a b c d)
==> f-3     (c a b c d)
==> Activation 0      foo: f-1,f-2,f-3
<Fact-3>
CLIPS> (assert (a 1 2 5 4) (b a b c l) (c a b c e))
==> f-4     (a 1 2 5 4)
==> Activation 0      foo: f-4,f-2,f-3
==> f-5     (b a b c l)
==> f-6     (c a b c e)
<Fact-6>
```

In the above code, I define a rule `foo` that detects when 3 facts are in
working memory:

1. One that starts with `(a` with 0 or more values `$?a`
2. Another that starts with `(b` with 0 or more values `$?b`
3. And one that starts with `(c` whose values match either `$?a` or `$?b`

We then assert 6 facts into working memory. Already, we see how CLIPS
indexes our data with ids 1-6 and patterns defined in our `foo` rule as
indicated by the `Activation` debug message.

In the first set of 3 facts that we assert, we see that the values `a b c d`
following `(b` and `(c` match.

In the second set, we see that `(a` once again does not match `$?c`. That
means facts 4, 2 and 3 activate rule `foo`.

Thus, the algorithm determines that `foo` needs to run twice based on the
data in our application.

What's more: these are only activations. The rules have not yet run. We can
see what's about to happen with `(agenda)`:

```
CLIPS> (agenda)
0      foo: f-4,f-2,f-3
0      foo: f-1,f-2,f-3
For a total of 2 activations.
```

When we use `(run)`, first `foo` will `FIRE` based on facts 4, 2 and 3, then
it will `FIRE` for 1, 2 and 3:

```
CLIPS> (run)
FIRE    1 foo: f-4,f-2,f-3
FIRE    2 foo: f-1,f-2,f-3
<== Focus MAIN
2 rules fired        Run time is 0.00307297706604004 seconds.
650.834665218403 rules per second.
6 mean number of facts (6 maximum).
0 mean number of instances (0 maximum).
1 mean number of activations (2 maximum).
```

Also, note the (watch all) command. This causes the helpful debugging
messages built into CLIPS to display information about everything happening
within the rules engine. They make it super easy to diagnose what's going on
when something inevitably behaves unexpectedly.

Finally, CLIPS remembers what has already run for which facts in working
memory:

```
CLIPS> (agenda)
CLIPS> (facts)
f-1     (a 1 2 3 4)
f-2     (b a b c d)
f-3     (c a b c d)
f-4     (a 1 2 5 4)
f-5     (b a b c l)
f-6     (c a b c e)
For a total of 6 facts.
```

Asserting a new fact will match on existing facts, but it will not
re-activate for previously matched sets of facts:

```
 CLIPS> (assert (a a b c d))
==> f-7     (a a b c d)
==> Activation 0      foo: f-7,f-2,f-3
==> Activation 0      foo: f-7,f-5,f-3
<Fact-7>
```

This demonstrates a very basic example of the [caching mechanisms inherent
in
CLIPS](https://ryjo.codes/articles/stop-writing-in-app-caches-and-start-writing-inherently-cached-apps-with-clips.html)
provided by the [Rete
algorithm](https://en.wikipedia.org/wiki/Rete_algorithm).

### Conclusion

You should learn CLIPS. You could be writing [web-based applications using
CLIPS](https://github.com/mrryanjohnston/CLIPSockets). However, you're
creating a complex in-app cache, which is causing your production
application to become increasingly sluggish. [Relinquish your iron-tight
grip](https://ryjo.codes/articles/forgoing-implicity-using-abstractions-clips.html)
on your code and take back control of your application.

\- ryjo
