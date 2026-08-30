title: Stop Writing In-app Caches and Start Writing Inherently Cached Apps with CLIPS
description: This article describes some of the caching mechanisms inherent in CLIPS and the Rete Algorithm.
date: 2022-10-26
css: syntax.css
---
### Introduction

Writing in-app caches can be a pain. There's no need for memcache and Redis
when you first start building an application. Database access is fast. Every
time a user navigates your application, you call your database server
directly.

As your userbase and feature set grows, you may notice things slowing down.
You decide to change your strategy a little bit. You pre-fetch common data
records when you start the app. As the amount of common data records loaded
into memory grows, you develop a service to access this data.

This **in-app cache** works at first, but things become difficult when data
gets "stale." The data from your database sometimes updates faster than the
data in cache. As a result, your users see "old" data or worse: your system
sees old data. When your users see old data, that's annoying. When your
system does, your service has errors.

You could continue to expand your in-app cache, but you'd be re-inventing
the wheel. This "stale look-up data" problem is a downstream result of
building software **backwards**, and it is a solved issue.

### Think Forward, not Backward

**Backward chaining** comes naturally to humans. When we determine we want
something, we determine steps towards achieving that thing. We then follow
these steps to reach that goal. Starting backwards from the goal is know as
"backwards chaining." **Forward Chaining** takes the opposite approach. We
first consider all information, and then we determine our achievable goals.

Backward chaining breaks our application down into many layers by
responsibility (or goals). These layers, when executed in the correct order,
run our service. Usually, data is stored in a database layer. This layer is
usually the "lowest" layer in a system. The application receives requests
from users and retrieves data from the database. An in-app cache would
**pre-fetch** this data to prevent heavy load on the database. An in-app
cache brings the data *closer* to the top layer.

When we use forward chaining to build our application, the data *starts*
closer to the top of the stack. Our data first navigates a
[graph](https://en.wikipedia.org/wiki/Graph_(discrete_mathematics))-shaped
[index of data](https://en.wikipedia.org/wiki/Lookup_table) called the
**Rete Network**. Reaching the end of this graph results in our application
logic running. Thus, **instead of writing a cache to augment our
application, our application is the cache**.

### A Brief Overview of the Rete Network

When you use CLIPS, you get [the Rete
Algorithm](https://en.wikipedia.org/wiki/Rete_algorithm) for free. This
algorithm determines the most efficient way to run the "Rules" of your
system. To do this, it builds a [directed acyclic
graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph). This means the
nodes in the graph point in one direction towards other nodes. The
connections between nodes will never form a loop. This graph is known as the
**Rete Network**.

Each node represents a pattern found in the left hand sides (LHS) of your
Rules. Facts are compared to these patterns as they traverse the nodes in
the graph. If a Fact matches a pattern, a reference to that Fact is stored
in the node. Then the Fact moves further into the network. If it doesn't
match, the Fact isn't stored in the node, and it does not travel further.
This process repeats itself until the Fact reaches the end of the graph. The
last nodes in the graph reference Rules. This is how the Rete Algorithm
determines which Facts activate Rules in CLIPS.

### Caching Mechanisms Inherent in the Rete Network

The Rete Network describes an efficiently indexed caching mechanism for the
data entered into your system. When you define Rules, the Rete Algorithm
builds this network of nodes from the patterns that define your Rules. Think
of this as a much more advanced hash table. The keys are patterns defined in
your Rules, and the values are Facts. Rules rely upon these keys to
determine when they should run.

When we add data to our CLIPS application, we "assert Facts." A reference to
a Fact enters the "top" of our Rete Network. It makes its way "down" the
graph when it matches patterns held in nodes. When a Fact reaches the
"bottom" of the graph, it activates Rules. The next time you use `(run)`,
these Rules will fire. CLIPS **pre-computes** whether Rules will run when
data enters your application. This is quite powerful since a node can
represent a pattern found in many different Rules. <p> Finally, even when a
Fact reaches the end of a graph and activates a Rule, the network remembers.
This means Rules will not fire again for a set of previously matched Facts.
It also means CLIPS does not need to re-compute previous matches for these
Facts when you assert more. CLIPS remembers the progress your Facts make
through the Rete Network.

Let's have a look at a few examples in CLIPS that show these caching
mechanisms.

#### Rule Activations

A Rule is "activated" when *all* patterns are matched in its LHS (Left Hand
Side). CLIPS keeps track of an agenda that lists what Rules will fire on the
next `(run)`.

```clips
(watch activations)

(defrule activate-when-a-and-b
  (a)
  (b)
  =>)

(println "before asserting a...")

(assert (a))

(println "after asserting a...")

(assert (b))

(println "after asserting b...")

(agenda)
```

Output

```
before asserting a...
after asserting a...
==> Activation 0      activate-when-a-and-b: f-1,f-2
after asserting b...
0      activate-when-a-and-b: f-1,f-2
For a total of 1 activation.
```


#### Predicate Constraints &amp; Test Conditionals

In CLIPS, patterns are only evaluated once per matching Fact even if used in
more than one Rule. CLIPS evaluates them even for partially matched LHS of
Rules. Finally, CLIPS evaluates constraints/conditionals as soon as you
assert a Fact. In other words: CLIPS caches the results of evaluations
before running your application.

```clips
(watch deffunctions)

(deffunction is-less-than-one (?number)
  (println "testing if " ?number " is less than 1")
  (< ?number 1))

(defrule activates-when-a-less-than-one-and-c
  (a ?a&:(is-less-than-one ?a))
  (c)
  =>)

(defrule activates-for-b-fact-and-a-less-than-one
  (b ?)
  (a ?a&:(is-less-than-one ?a))
  =>)

(println "before asserting a...")
(assert (a 0))

(println "before assert two b facts...")
(assert (b 0) (b 1))
```

Output

```
before asserting a...
DFN >> is-less-than-one ED:1 (0)
testing if 0 is less than 1
DFN << is-less-than-one ED:1 (0)
before assert two b facts...
```

#### Rules Run Once

Rules only run once between runs for given matching Facts. This means CLIPS
remembers which Rules have been `(run)` for Facts that match their LHS. Each
time you use `(run)`, only newly matched LHS patterns will cause a rule to
fire.

```clips

(watch rules)

(defrule greet
  (name ?name)
  =>
  (println "Hi, " ?name))

(defrule depart
  (name ?name)
  (leave ?name)
  =>
  (println "Bye, " ?name))

(println "1. asserting...")
(assert (name Nancy) (name Bob) (name Sue))

(println "2. running...")
(run)

(println "3. running...")
(run)

(println "4. asserting...")
(assert (name Sam) (leave Bob))

(println "5. running...")
(run)
```

Output

```
1. asserting...
2. running...
FIRE    1 greet: f-3
Hi, Sue
FIRE    2 greet: f-2
Hi, Bob
FIRE    3 greet: f-1
Hi, Nancy
3. running...
4. asserting...
5. running...
FIRE    1 depart: f-2,f-5
Bye, Bob
FIRE    2 greet: f-4
Hi, Sam
```

### Conclusion

In the course of a CLIPS Environment's life time, you may choose to `(run)`
your rules engine many times. During this time, when you define Rules and
assert Facts, you are building your Rete Network. This network acts as a
powerful and efficient indexed cache. CLIPS applications are cached and
indexed since all data enters this graph immediately.

In CLIPS, caching is not an afterthought added as another "layer." Caching
is inherent to the way the Rete Algorithm works. CLIPS leverages this
powerful algorithm at its core, so applications get this indexed cache "for
free."

So [give CLIPS a try today](/tour-of-clips.html)! You may just find your new
favorite programming language.

\- ryjo
