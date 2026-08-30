title: A* Algorithm Written in CLIPS
description: This article describes the A* Algorithm. It also demonstrates an implementation of the algorithm in CLIPS.
date: 2023-01-10
css: syntax.css articles/a-star-algorithm-written-in-clips.css
---
### Introduction

The [A* (A-star)
Algorithm](https://theory.stanford.edu/~amitp/GameProgramming/AStarComparison.html)
is a great way to determine the shortest distance between two points in a
coordinate system. In order to determine whether a coordinate is the next
"step," you measure the distance from the start point as well as the
distance from the end point. You repeat this process until you have found a
complete path between the start and end points.

In this article, I'll talk about one way of implementing the A* Algorithm
with [CLIPS](https://www.clipsrules.net/). We'll extend CLIPS by adding a
custom C function so that we can call it from the precedents of our rules.
We'll also discuss some of the existing functions available out-of-the-box
with CLIPS. Let's dive in!

### Explaining the A* Algorithm

First, let's discuss how the A* Algorithm works. The Algorithm uses two
measurements to determine the next "step" in a path: 1. the distance to the
start node and 2. the distance to the end node. Calculate both, add them
together, and whichever square has the lower number is the next step.

    <figure class="grid-wrapper">
      <div class="grid five">
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell">
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell">
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell end">
          e
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 1: a 5x5 grid. The blue squares are the start (s) and end (e)
      coordinates. The black squares are barriers.</figcaption>
    </figure>

The distance from the start node to a square is referred to as the square's
"g cost." The distance to the end node from a square is its "h cost." The "f
cost" is the sum of these two costs. In the above diagram, the square with
the "s" is our starting point, and the square with the "e" is our end.

    <figure class="grid-wrapper">
      <div class="grid five">
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>50</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>44</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>41</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>42</sup>
          </div>
          <div class="f">
            58
          </div>
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            41
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>36</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>28</sup>
          </div>
          <div class="f">
            38
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            36
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell end">
          e
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 2: Starting at s, open the surrounding squares by calculating their
      g (top left), h (top right), and f (middle) costs.</figcaption>
    </figure>

Start by "opening" the squares that surrounding the starting square. This
means: calculate the cost **to move to** that square, as well as their
distance from the end. The cost to move to that square accumulates from the
square that caused it to open. Moving north, south, east and west will incur
a cost of 10, while moving diagonally will cost 14. This is because of the
way we calculate the distance between two points on a grid. To rehash a bit
of math, the formula to calculate this is
![](./a-star-algorithm-written-in-clips-1.svg). In other words:
subtract the `x` values from both points from one another and square them.
Do the same for the `y` values. Sum the result of these two together, then
find the square root of this sum.

Using the above diagram, our start square is at `(2, 4)`. We want to
calculate the g cost of one of the surrounding squares `(2, 3)`. Our
equation is therefore ![](./a-star-algorithm-written-in-clips-2.svg).
This simplifies to ![](./a-star-algorithm-written-in-clips-3.svg),
then to ![](./a-star-algorithm-written-in-clips-4.svg). The square
root of 1 is 1, so our g cost for moving north, south, east, or west from
any square is 1. Moving diagonally from `(2, 4)` to `(3, 3)` would be
![](./a-star-algorithm-written-in-clips-5.svg). This simplifies to
![](./a-star-algorithm-written-in-clips-6.svg) which is roughly 1.4.
We'll multiply g cost by 10 in our calculations to avoid using decimal
places.

To calculate our h cost, we'll use the same formula. Instead of using the
coordinate of our start node, we use the end node. Once we have both the g
and h cost, we add them together to get the f cost.

    <figure class="grid-wrapper">
      <div class="grid five">
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>50</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>44</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>41</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>42</sup>
          </div>
          <div class="f">
            58
          </div>
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            41
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>36</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>28</sup>
          </div>
          <div class="f">
            38
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            36
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell open">
          <div class="g">
            <sup>28</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell end">
          e
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 3: Close the square with lowest f cost (36). Open surrounding nodes
      that have not already been opened.</figcaption>
    </figure>

Calculate all of the f costs for the open nodes. Once this is done, we'll
"close" the square with the lowest cost. We then repeat this algorithm,
opening the squares that surround our newly closed square. In our above
example, we only have one more opened square `(2, 2)`.

    <figure class="grid-wrapper">
      <div class="grid five">
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>50</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>44</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>41</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>42</sup>
          </div>
          <div class="f">
            58
          </div>
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            41
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>36</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>28</sup>
          </div>
          <div class="f">
            38
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            36
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>24</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>20</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            42
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell end">
          e
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 4: Close the next lowest f cost square. Open surrounding squares.
        Replace lower f-cost open node <code>(2, 2)</code>.
      </figcaption>
    </figure>

Now that we've closed the next lowest f cost square `(2, 3)`, we begin to
open the surrounding squares. One of the squares surrounding this one
`(2, 1)` is newly opened, but look at `(2, 2)`. We've updated its g cost
and, therefore, its f cost. When you close a square and are looking at its
surrounding squares, if a previously opened square would have a lower g cost
had it been opened by this new square, we replace it. Now, we'll track that
`(2, 2)` has an f cost of 42 instead of 50 and was opened by `(2, 3)`
instead of `(3, 3)`.

    <figure class="grid-wrapper">
      <div class="grid five">
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>50</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>44</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>41</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>42</sup>
          </div>
          <div class="f">
            58
          </div>
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            41
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>36</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>28</sup>
          </div>
          <div class="f">
            38
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            36
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>24</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>20</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            42
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell"></div>
        <div class="cell end">
          e
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 5: Repeat the process.</figcaption>
    </figure>

The next square we close is `(3, 4)`. We repeat the algorithm even if it
results in a dead end. We may be able to see that `(3, 4)` will not lead us
to the end square, but our program cannot. Thus it must explore every
possible square according to the rules of the algorithm.

    <div id="a-star-example">
    <figure class="grid-wrapper">
      <div class="grid five">
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>50</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>44</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>41</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>42</sup>
          </div>
          <div class="f">
            58
          </div>
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            41
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>36</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>28</sup>
          </div>
          <div class="f">
            38
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            36
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>24</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>20</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            42
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>34</sup>
          </div>
          <div class="h">
            <sup>30</sup>
          </div>
          <div class="f">
            64
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>30</sup>
          </div>
          <div class="h">
            <sup>20</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>34</sup>
          </div>
          <div class="h">
            <sup>10</sup>
          </div>
          <div class="f">
            44
          </div>
        </div>
        <div class="cell end">
          e
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 6: Repeat the process.</figcaption>
    </figure>

    <figure class="grid-wrapper">
      <div class="grid five">
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>50</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>44</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>41</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>42</sup>
          </div>
          <div class="f">
            58
          </div>
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            41
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>36</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>28</sup>
          </div>
          <div class="f">
            38
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            36
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>24</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>20</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            42
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>34</sup>
          </div>
          <div class="h">
            <sup>30</sup>
          </div>
          <div class="f">
            64
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>30</sup>
          </div>
          <div class="h">
            <sup>20</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>34</sup>
          </div>
          <div class="h">
            <sup>10</sup>
          </div>
          <div class="f">
            44
          </div>
        </div>
        <div class="cell end opened-end">
          <div class="g">
            <sup>44</sup>
          </div>
          <div class="h">
            <sup>0</sup>
          </div>
          <div class="f">
            44
          </div>
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 7: Repeat the process. We "open" the end node.</figcaption>
    </figure>

    <figure class="grid-wrapper last">
      <div class="grid five">
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>50</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>44</sup>
          </div>
          <div class="f">
            54
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>41</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>42</sup>
          </div>
          <div class="f">
            58
          </div>
        </div>
        <div class="cell start">
          s
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            41
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>36</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell complete">
          <div class="g">
            <sup>10</sup>
          </div>
          <div class="h">
            <sup>28</sup>
          </div>
          <div class="f">
            38
          </div>
        </div>
        <div class="cell closed">
          <div class="g">
            <sup>14</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            36
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>24</sup>
          </div>
          <div class="h">
            <sup>31</sup>
          </div>
          <div class="f">
            55
          </div>
        </div>
        <div class="cell complete">
          <div class="g">
            <sup>20</sup>
          </div>
          <div class="h">
            <sup>22</sup>
          </div>
          <div class="f">
            42
          </div>
        </div>
        <div class="cell barrier"></div>
        <div class="cell barrier"></div>
        <div class="cell"></div>

        <div class="cell open">
          <div class="g">
            <sup>34</sup>
          </div>
          <div class="h">
            <sup>30</sup>
          </div>
          <div class="f">
            64
          </div>
        </div>
        <div class="cell open">
          <div class="g">
            <sup>30</sup>
          </div>
          <div class="h">
            <sup>20</sup>
          </div>
          <div class="f">
            50
          </div>
        </div>
        <div class="cell complete">
          <div class="g">
            <sup>34</sup>
          </div>
          <div class="h">
            <sup>10</sup>
          </div>
          <div class="f">
            44
          </div>
        </div>
        <div class="cell end complete">
          e
        </div>
        <div class="cell"></div>
      </div>
      <figcaption>Fig. 8: A completed path.</figcaption>
    </figure>
    </div>

Continue this process until the end node is opened. From here, you may
determine your path. We choose the lowest g cost for squares opened multiple
times. To tie break f costs, choose the square with the lower h cost. The
square that opened a square is the previous step in the path. In our
examples above, our full path is `(2, 4) (2, 3) (2, 2) (3, 1) (4, 1)`.

### Implementation in CLIPS

First, we'll download CLIPS and compile it. We'll [download
it](https://sourceforge.net/projects/clipsrules/files/CLIPS/6.40/), untar
it, and then compile it with `make`:

```
$ wget https://sourceforge.net/projects/clipsrules/files/CLIPS/6.40/clips_core_source_640.tar.gz
# ... truncated output ...
HTTP request sent, awaiting response... 302 Found
Location: https://versaweb.dl.sourceforge.net/project/clipsrules/CLIPS/6.40/clips_core_source_640.tar.gz [following]
--2022-12-11 16:32:46--  https://versaweb.dl.sourceforge.net/project/clipsrules/CLIPS/6.40/clips_core_source_640.tar.gz
Resolving versaweb.dl.sourceforge.net (versaweb.dl.sourceforge.net)... 162.251.232.173
Connecting to versaweb.dl.sourceforge.net (versaweb.dl.sourceforge.net)|162.251.232.173|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1082012 (1.0M) [application/x-gzip]
Saving to: ‘clips_core_source_640.tar.gz’

clips_core_source_640.ta 100%[===============================>]   1.03M  2.97MB/s    in 0.3s    

2022-12-11 16:32:51 (2.97 MB/s) - ‘clips_core_source_640.tar.gz’ saved [1082012/1082012]
$ tar --strip-components=2 -xvf clips_core_source_640.tar.gz
# ... truncated output ...
$ make
```

Now that CLIPS is compiled, we'll define a few templates. In CLIPS,
templates are used to give facts more structure:

```clips
(deftemplate barrier
  (slot x)
  (slot y))

(deftemplate closed
  (slot last-x)
  (slot last-y)
  (slot path))

(deftemplate delta-g
  (slot x)
  (slot y)
  (slot g))

(deftemplate opened
  (slot previous-x)
  (slot previous-y)
  (slot x)
  (slot y)
  (slot g)
  (slot h)
  (slot f))
```

Now we'll use these templates when we define some of our initial facts with
`deffacts`:

```clips
(deffacts config
  (start       2       4)
  (end         4       1)
  (delta-g (x  0)  (y  1)  (g 10))
  (delta-g (x  1)  (y  0)  (g 10))
  (delta-g (x  0)  (y -1)  (g 10))
  (delta-g (x -1)  (y  0)  (g 10))
  (delta-g (x  1)  (y  1)  (g 14))
  (delta-g (x -1)  (y  1)  (g 14))
  (delta-g (x  1)  (y -1)  (g 14))
  (delta-g (x -1)  (y -1)  (g 14))
  (barrier (x  4)  (y  5))
  (barrier (x  4)  (y  4))
  (barrier (x  4)  (y  3))
  (barrier (x  4)  (y  2))
  (barrier (x  3)  (y  2)))
```

Note the difference between the `start` and `end` facts and the template
facts after them. With the template facts, we must specify which named
"slot" the values are for. We can specify them in any order we choose, and
we can even omit them if we don't need them in rule antecedents.

### Our Initial Ruling

We'll begin the process of "closing" our starting node and "opening" the
surrounding nodes:

```clips
(defrule init
  (start ?x  ?y)
  (end   ?ex ?ey)
  (not (closed))
  =>
  (assert (closed (path (str-cat "(" ?x ", " ?y ")")) (last-x ?x) (last-y ?y)))
  (do-for-all-facts ((?d delta-g))
    ;Do not open nodes on a barrier
    (not (any-factp ((?b barrier)) (and (= ?b:x (+ ?x ?d:x)) (= ?b:y (+ ?y ?d:y)))))
    (bind ?xx (+ ?x ?d:x))
    (bind ?yy (+ ?y ?d:y))
    (bind ?h (h ?xx ?yy ?ex ?ey))
    (assert (opened (g ?d:g) (previous-x ?x) (previous-y ?y) (x ?xx) (y ?yy) (h ?h) (f (+ ?d:g ?h))))))
```

The `do-for-all-facts` function lets us do some action for all facts that
match a given query. We specify we want to look at our `delta-g` facts.
These represent the 8 directons one can travel from a square as well as the
g cost of taking those directions. We then use `any-factp` to see if there
is a barrier at the square in this given direction. If there isn't, we open
that square.

Ok, now that we have at least one closed square and opened squares, we can
work on closing our next open node:

```clips
(defrule close-next
  ;There is not a "closed" path ending at the intended end coordinate
  (end ?x ?y)
  (not (closed (last-x ?x) (last-y ?y)))

  ;There is a closed path that opened a coordinate
  (closed (path ?path) (last-x ?px) (last-y ?py))
  (opened (g ?g) (h ?h) (f ?f) (previous-x ?px) (previous-y ?py) (x ?ox) (y ?oy))
  ;that has the lowest "g cost" leading to that specific coordinate
  (not (opened (g ?gg&:(< ?gg ?g)) (x ?ox) (y ?oy)))
  ;and that has the lowest "f cost" of all open coordinates
  (not (opened (f ?ff&:(< ?ff ?f))))
  ;and that has the lowest "h cost" of all open coordinates tied with its "f cost"
  (not (opened (f ?f) (h ?hh&:(< ?hh ?h))))
  =>
  ;Close this coordinate
  (assert (closed (path (str-cat ?path " (" ?ox ", " ?oy ")")) (last-x ?ox) (last-y ?oy)))
  ;Remove all open nodes for this coordinate
  (do-for-all-facts ((?o opened)) (and (= ?o:x ?ox) (= ?o:y ?oy)) (retract ?o))
  ;Open new coordinates
  (do-for-all-facts ((?d delta-g))
    (and
      ;Do not re-open closed nodes
      (not (any-factp ((?c closed)) (and (= ?c:last-x (+ ?ox ?d:x)) (= ?c:last-y (+ ?oy ?d:y)))))
      ;Do not open nodes on a barrier
      (not (any-factp ((?b barrier))     (and (= ?b:x (+ ?ox ?d:x))      (= ?b:y (+ ?oy ?d:y)))))
      ;Do not open more nodes at this coordinate
      ;that would have a higher g cost
      (not (any-factp ((?o opened))      (and (= ?o:x (+ ?ox ?d:x))      (= ?o:y (+ ?oy ?d:y))
            (<= ?o:g (+ ?g  ?d:g))))))
    (bind ?xx (+ ?ox ?d:x))
    (bind ?yy (+ ?oy ?d:y))
    (bind ?hhh (h ?xx ?yy ?x ?y))
    (bind ?ggg (+ ?g ?d:g))
    (assert
      (opened (previous-x ?ox) (previous-y ?oy) (x ?xx) (y ?yy) (g ?ggg) (h ?hhh) (f (+ ?hhh ?ggg))))))
```

We must implement our custom `h` function which calculates the h cost of a
node. CLIPS is an awesome language, but doing heavy math in our rules engine
will make things slow. To avoid this, we'll calculate the h cost in C. We'll
add a function to the file `userfunctions.c`, and then we'll add a call to
`AddUDF` inside of the `UserFunctions` function. This will let us call our
function inside of our rules engine:

```c focus={2,6-19,21-32,49,50:1-2}
#include "clips.h"
#include "math.h"

void UserFunctions(Environment *);

void h(
  Environment *env,
  UDFContext *udfc,
  UDFValue *out)
  {
    UDFValue ox, oy, x, y;
    if (! UDFNextArgument(udfc,NUMBER_BITS,&ox))
    { return; }
    if (! UDFNextArgument(udfc,NUMBER_BITS,&oy))
    { return; }
    if (! UDFNextArgument(udfc,NUMBER_BITS,&x))
    { return; }
    if (! UDFNextArgument(udfc,NUMBER_BITS,&y))
    { return; }

    double floatValue;
    long long oxValue, oyValue, xValue, yValue;
    oxValue = ox.integerValue->contents;
    oyValue = oy.integerValue->contents;
    xValue  = x.integerValue->contents;
    yValue  = y.integerValue->contents;
    floatValue = 10 * sqrt(
        (oxValue - xValue) * (oxValue - xValue) +
        (oyValue - yValue) * (oyValue - yValue)
      );
    out->floatValue = CreateFloat(env, floatValue);
}

/*********************************************************/
/* UserFunctions: Informs the expert system environment  */
/*   of any user defined functions. In the default case, */
/*   there are no user defined functions. To define      */
/*   functions, either this function must be replaced by */
/*   a function with the same name within this file, or  */
/*   this function can be deleted from this file and     */
/*   included in another file.                           */
/*********************************************************/
void UserFunctions(
  Environment *env)
  {
#if MAC_XCD
#pragma unused(env)
#endif
    AddUDF(env, "h", "d", 4, 4, "l", h, "h", NULL);
  }
```

To learn more details about this process, take a look at the excellent
[Advanced Programming
Guide](https://www.clipsrules.net/documentation/v640/apg640.pdf).

Finally, we'll add a rule that'll report a completed path:

```clips

(defrule done
  (end ?x ?y)
  (closed (path ?path) (last-x ?x) (last-y ?y))
  =>
  (println "Done!" crlf "Path: " ?path))
```

Let's create a batch file called `astar.bat`. We'll use this file to load in
the rules and run the rules engine:

```clips
(watch statistics)
(load "astar.clp")
(reset)
(run)
(exit)
```

We also specify that we want to see some statistics around the performance
of our rules engine. We'll run this file with our compiled CLIPS binary:

```
$ ./clips -f2 astar.bat 
%%%%$***
Done!
Path: (2, 4) (2, 3) (2, 2) (3, 1) (4, 1)
8 rules fired        Run time is 0.000307083129882812 seconds.
26051.5776397516 rules per second.
28 mean number of facts (36 maximum).
0 mean number of instances (0 maximum).
1 mean number of activations (1 maximum).
```

Nice! That's the path that we expect, and it's fast!

### Conclusion

I hope that you've found this article useful! CLIPS is such a fun language,
and I feel like I'm only scratching the surface. By the way: in learning
this Algorithm, I found [this YouTube
video](https://www.youtube.com/watch?v=-L-WgKMFuhE) to be quite helpful.

\- ryjo
