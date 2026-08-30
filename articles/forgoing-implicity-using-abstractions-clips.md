title: Forgoing Implicity and Using Abstractions: CLIPS
description: This article describes the term higher level programming languages and explores what makes CLIPS one.
date: 2024-04-29
css: syntax.css
---
### Introduction

In this article, I'll attempt to describe how the "higher level" programming
language CLIPS compares to Ruby, another "higher level" language.

### Higher Level Programming Languages

When I started professionally programming, I was hired to write web
applications in PHP. PHP is an example of what some programmers refer to as
a "higher level" programming language.

The term "High Level" can take on a few different meanings, but I'll refer
to them as the following for the sake of this article: **languages that
provide frameworks on top of complex functionality normally delegated to the
developer to implement in lower level languages**.

In other words: **developers use these languages to prevent re-inventing the
wheel**.

### Ruby as a High Level Language

After my time writing PHP, I got a job writing Ruby. Ruby is also a "higher
level programming language," meaning "you can write *a-cool-feature* in Ruby
in *x*% less code."

For Ruby, one might argue those cool features could include:

- object lifecycle hooks - handles allocating and freeing computer memory
  to avoid introducing memory leaks
- pass by object reference - taking a "middle ground" approach to pass by
  reference and pass by value
- an elaborate standard library - trivializes [very
  specific](https://ruby-doc.org/core-2.7.0/Enumerable.html#method-i-tally)
  or otherwise [complex
  functionality](https://ruby-doc.org/core-2.7.0/Enumerable.html#method-i-max_by)

### Rules Engines: `whenever`

Eventually I got a job writing Rules Engines in Ruby. This was an
eye-opening experience: Not only did we have the power of Ruby, **the
developers also had the power of a rules-based "language"** implemented on
top of Ruby.

In addition to traditional `if`, `else`, or `for` keywords, a rules-based
programming language provides the concept of `whenever`. How? Rules engines
are "run," and thus exposes the ability to write code that runs "when
conditions are met while our rules engine is running."

You might think of a rules engine as a bunch of nested `if` and `goto`
statements all wrapped up in a `while(should_run)` loop. In other words:
**rules engines provide a framework for making data-driven run loops**.

### Comparing Ruby to CLIPS

This brings me to [CLIPS](https://www.clipsrules.net/). Working directly
with home-grown rules engines taught me a lot. Rules Engines are complex,
and, like Ruby's elaborate standard library, provide the developer an
extremely powerful tool set containing "things you're going to try to write
yourself anyway." <p> CLIPS provides the same abstractions that Ruby does
plus the added functionality of a rules engine **in C**, so it implements
those same "higher level" functionalities in the "lower level" speedy C.

### CLIPS Features

Some of those functionalities include things like:

1. [automatic caching for commonly evaluated conditions in
   code](https://ryjo.codes/articles/stop-writing-in-app-caches-and-start-writing-inherently-cached-apps-with-clips.html)
2. Built-in query language DSLs for Instances and Facts
3. Ability to fine-tune, optimize and compile your Rules Engine into a
   single binary

Working with applications that expose relational databases like MySQL,
PostgreSQL, and SQLite means that one must translate tabular data into
business logic using a non-rules-based imperative language. This translation
can be expensive, so developers often implement a cache of some kind to
"pre-fetch" the data and index it. If you have to "bootstrap" your
application, this might be part of what is happening during that process.

CLIPS provides a caching mechanism due to its underlying use of the Rete
Algorithm, interweaving your data into your running application. It creates
a [directional acyclic
graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph) of nodes
representing conditions in the rules in your rules engine. The moment you
put data into the system, the Rete Algorithm feeds the data into the graph
it created from the Rules you defined. The data traverses these nodes,
continuing on to a node's children if the data evaluates true for a
condition. The leaves of the graph are your rules, and the data that makes
it to a leaf of the graph triggers the rule represented by that leaf. In
this way, the data is "passed in" to the rule like one might pass an
argument into a function, and thus business rules are executed.

### Conclusion

CLIPS is a programming language that can provide a lot of value to your
developers in the same way that moving to a "higher level" language does. It
abstracts common and complex functionality so that the developer does not
need to write these things over again, allowing them to focus their efforts
on writing business logic. I hope you were able to relate to this article
somehow, and that maybe it's sparked at least a tiny bit of interest in
checking out CLIPS. If it did, you might find the [Basic Programming
Guide](https://www.clipsrules.net/documentation/v641/bpg641.pdf) and the
[Advanced Programming
Guide](https://www.clipsrules.net/documentation/v641/apg641.pdf) interesting
to read. Afterall, it's the next layer of abstraction, the next "higher
level" language.

\- ryjo
