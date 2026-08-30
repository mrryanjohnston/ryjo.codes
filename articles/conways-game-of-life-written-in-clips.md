title: Conway's Game of Life Written in CLIPS
description: This article describes Conway's Game of Life. It also demonstrates an implementation of the game in CLIPS.
date: 2023-01-18
css: syntax.css articles/conways-game-of-life-written-in-clips.css
---
### Introduction

Conway's Game of Life is a "cellular automation" game. You pick squares on a
grid that will start as "alive," then hit play. The game then begins running
by itself. It's not necessarily a winners-and-losers kind-of game; rather
it's an exercise in mathematical beauty.

    <figure id="lifedemo">
      <video controls>
        <source src="conways-game-of-life-written-in-clips-1.webm">
        <source src="conways-game-of-life-written-in-clips-1.mp4">
      </video>
      <figcaption>
        Fig. 1: An example of Conway's Game of Life written in CLIPS by me. See the
        implementation <a href="#lifedemoimplementation">here</a>.
      </figcaption>
    </figure>

In this article, I'll briefly describe how Conway's Game of Life works. I'll
also describe some common patterns that do some interesting stuff, including
the famous "[glider](#gliders)." Finally, I'll provide some
[CLIPS](https://www.clipsrules.net/) code that I wrote implementing this
famous game. Now: let's get started!

### The Rules

To understand any game, we must first understand the rules. The playing
field of Conway's Game of Life is a grid of squares. During a round, a
square can be either **alive** or **dead**. Whether a square is alive or
dead depends on the number of alive squares surrounding that square.

    <figure>
      <div class="grid five">
        <div class="cell alive">
          E
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell alive">
          B
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
          G
        </div>
        <div class="cell alive">
          A
        </div>
        <div class="cell">
          F
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell alive">
          C
        </div>
        <div class="cell alive">
          D
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
      </div>
      <figcaption>
        Fig. 2: A small grid representing a round of Life. The black squares are alive
        while the white squares are dead.
      </figcaption>
    </figure>

The rules are as follows:

1. A dead square becomes alive if surrounded by exactly 3 squares
2. An alive square stays alive if surrounded by 2 or 3 squares
3. An alive square dies if surrounded by less than 2 or more than 3 squares

Look at the currently alive square **A**. In the next round, it will remain
alive due to the surrounding 3 alive squares **B**, **C**, and **D**.
Similarly, the currently dead squares **G** and **F** will become alive.
Squares **B** and **E** will perish. Finally, **C** and **D** will remain
alive as they are surrounded by 2 alive squares.

    <figure>
      <div class="grid five">
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
          H
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell alive">
          G
        </div>
        <div class="cell alive">
          A
        </div>
        <div class="cell alive">
          F
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell alive">
          C
        </div>
        <div class="cell alive">
          D
        </div>
        <div class="cell">
          I
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
      </div>
      <figcaption>
        Fig. 3: Round 2 from the previous grid.
      </figcaption>
    </figure>

This process continues. In the next round, squares **H** and **I** will come
alive. Squares **A** and **D** will die, while the rest will remain alive.

    <figure>
      <div class="grid five">
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell alive">
          H
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell alive">
          G
        </div>
        <div class="cell">
        </div>
        <div class="cell alive">
          F
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell alive">
          C
        </div>
        <div class="cell">
        </div>
        <div class="cell alive">
          I
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
      </div>
      <figcaption>
        Fig. 4: Round 4.
      </figcaption>
    </figure>

We repeat this process again and again for as long as we'd like. At some
point (after 7 rounds, actually), this particular pattern will end with no
squares alive.

    <div id="life-example">
    <figure>
      <div class="grid five">
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell alive">
          H
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell alive">
          G
        </div>
        <div class="cell">
          A
        </div>
        <div class="cell alive">
          F
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
      </div>
      <figcaption>
        Fig. 5: Round 5.
      </figcaption>
    </figure>
    <figure>
      <div class="grid five">
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell alive">
          H
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell alive">
          A
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
      </div>
      <figcaption>
        Fig. 6: Round 6.
      </figcaption>
    </figure>
    <figure class="last">
      <div class="grid five">
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>

        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
        <div class="cell">
        </div>
      </div>
      <figcaption>
        Fig. 7: Round 7. No squares are left alive.
      </figcaption>
    </figure>
    </div>

Seems easy enough! Let's implement it in CLIPS.

### CLIPS Implementation {#lifedemoimplementation}

CLIPS has the ability to call underlying system functions. In this case,
we'll be running this in bash in Ubuntu, so we have access to a few programs
we can use to draw our playing field. Put this in a file called `life.bat`:

```clips
(system "tput civis")
(load* life.clp)
(load* lifedemo.clp)
(reset)
(run)
(system "tput cnorm")
(exit)
```

First, we use `tput` to hide the cursor. This will otherwise just get in the
way when we render our playing field. Next, we'll `load*` up our rules.
We'll separate the generic rules engine and specific playing fields into two
separate files. This will allow us to very quickly swap out different
patterns as we'd like. We'll then `reset` to initialize our `deffacts`,
`run` to play the game, make our cursor visible with `tput cnorm`, and then
`exit`.

Alright, next comes the framework rules for our game. Put this into a
`life.clp` file:

```clips
(deftemplate alive (slot x) (slot y) (slot tick (default -1)))
(deftemplate next  (slot x) (slot y) (slot tick) (slot surrounding))

(deffacts init
  (tick -1)
  (height 24)
  (width 24)
  (max-ticks 25))

(defrule born
  (tick ?tick)
  (next (x ?x) (y ?y) (tick ?tick) (surrounding 3))
  =>
  (assert (alive (x ?x) (y ?y) (tick ?tick))))

(defrule survive
  (tick ?tick)
  (alive (x ?x) (y ?y) (tick ?previous&:(= ?previous (- ?tick 1))))
  (next (x ?x) (y ?y) (tick ?tick) (surrounding 2))
  =>
  (assert (alive (x ?x) (y ?y) (tick ?tick))))

(defrule clean-up
  (tick ?tick)
  ?t <- (tick ?previous&:(= ?previous (- ?tick 1)))
  =>
  (retract ?t)
  (do-for-all-facts ((?n next)) (= ?n:tick ?previous) (retract ?n))
  (do-for-all-facts ((?a alive)) (= ?a:tick ?previous) (retract ?a)))

(defrule render-and-tick
  (declare (salience -1))
  (max-ticks ?max)
  (tick ?tick&:(<= ?tick ?max))
  (height ?height)
  (width ?width)
  =>
  (system "tput clear")
  (bind ?nexttick (+ ?tick 1))
  (loop-for-count (?y ?height)
    (loop-for-count (?x ?width)
      (assert (next (tick ?nexttick)
        (x ?x) (y ?y)
        (surrounding
          (length$
            (find-all-facts ((?a alive))
             (and
              (= ?a:tick ?tick)
              (or (<> ?x ?a:x) (<> ?y ?a:y))
              (or (= ?x ?a:x) (= ?x (- ?a:x 1)) (= ?x (+ ?a:x 1)))
              (or (= ?y ?a:y) (= ?y (- ?a:y 1)) (= ?y (+ ?a:y 1)))))))))
      (if (any-factp ((?a alive)) (and (= ?a:tick ?tick) (= ?a:x ?x) (= ?a:y ?y)))
           then (print " # ")
           else (print "   ")))
    (print crlf))
  (system "sleep 0.2")
  (assert (tick ?nexttick)))
```

First we define a few templates for our facts. `alive` facts will represent
squares that are alive and should be rendered as such with a `#`. The `next`
template is used to represent which squares should be alive in the next
round. We compute this during the current round to capture the number of
surrounding `alive` squares.

We then define some initial facts. `tick` is what we'll use to denote
rounds. Think of this as the ticking of a clock. As time moves forward, so
does Life. `height` and `width` define the size of our playing field.
Finally, `max-ticks` tells us how many rounds long this game will be.

The `born` and `survive` Rules are responsible for determining which squares
will be alive next round. We use `clean-up` to retract previously rendered
`alive` and their corresponding `next` facts.

Finally, `render-and-tick` draws in our terminal. We first clear the
terminal with `tput clear`. We then use nested `loop-for-count` calls to get
each coordinate on the grid. We first assert a `next` fact for the given
coordinate that calculates how many `alive` facts surround it. Then, we
render either a `#` (alive) or a blank space (dead) depending on if there is
an `alive` fact at that coordinate. We use `length$` and `find-all-facts` to
count the surrounding alive facts.

Now we'll create a `lifedemo.clp` file in which we'll define our initially
alive squares:

```clips
(deffacts demo
  (alive (x 6) (y 15))
  (alive (x 7) (y 14))
  (alive (x 7) (y 13))
  (alive (x 8) (y 9))
  (alive (x 8) (y 8))
  (alive (x 8) (y 7))

  (alive (x 10) (y 15))
  (alive (x 9) (y 15))
  (alive (x 8) (y 15))
  (alive (x 10) (y 14))
  (alive (x 9) (y 14))
  (alive (x 8) (y 14))
  (alive (x 1) (y 10))
  (alive (x 1) (y 11))
  (alive (x 2) (y 10))
  (alive (x 1) (y 5))
  (alive (x 9) (y 5))
  (alive (x 9) (y 6))

  (alive (x 12) (y 15))
  (alive (x 11) (y 14))
  (alive (x 12) (y 13))
  (alive (x 11) (y 9))
  (alive (x 12) (y 8))
  (alive (x 12) (y 7))

  (alive (x 18) (y 15))
  (alive (x 19) (y 14))
  (alive (x 20) (y 13))
  (alive (x 21) (y 9))
  (alive (x 20) (y 8))
  (alive (x 18) (y 7))

  (alive (x 18) (y 17))
  (alive (x 19) (y 17))
  (alive (x 18) (y 18))
  (alive (x 19) (y 18))
  (alive (x 15) (y 12))
  (alive (x 16) (y 12))
  (alive (x 14) (y 10))
  (alive (x 15) (y 10))
  (alive (x 18) (y 10))
  (alive (x 18) (y 5))
  (alive (x 19) (y 5))
  (alive (x 20) (y 6))
  (alive (x 21) (y 6))
  (alive (x 21) (y 5))
  (alive (x 21) (y 7))
  (alive (x 22) (y 7))

  (alive (x 17) (y 9))
  (alive (x 24) (y 9))
  (alive (x 23) (y 16))
  (alive (x 23) (y 14))
  (alive (x 23) (y 12))
  (alive (x 24) (y 16))
  (alive (x 24) (y 15))
  (alive (x 24) (y 14))
  (alive (x 24) (y 22))
  (alive (x 24) (y 23))
  (alive (x 23) (y 22))
  (alive (x 22) (y 22))
  (alive (x 17) (y 8)))
```

Now we can run the rules engine with `./clips -f2 life.bat`. We should see
something that looks like [the first video in this article](#lifedemo)!

### Cool Patterns and their Implementations

There are many different patterns and behaviors that emerge in Conway's Game
of Life. Check out the [LifeWiki](https://conwaylife.com/wiki/Main_Page) to
see tons more. We'll showcase a few of them in this article next.

#### Oscillators

    <figure>
      <video controls>
        <source src="conways-game-of-life-written-in-clips-4.webm">
        <source src="conways-game-of-life-written-in-clips-4.mp4">
      </video>
      <figcaption>
        Fig. 8: A couple of Oscillators. From left to right: Blinker, Toad, Beacon
      </figcaption>
    </figure>
```clips

(deffacts oscillators
  (alive (x 3) (y 10))
  (alive (x 4) (y 10))
  (alive (x 5) (y 10))

  (alive (x 10) (y 10))
  (alive (x 11) (y 10))
  (alive (x 12) (y 10))
  (alive (x 11) (y 11))
  (alive (x 12) (y 11))
  (alive (x 13) (y 11))

  (alive (x 17) (y 13))
  (alive (x 18) (y 13))
  (alive (x 17) (y 12))
  (alive (x 18) (y 12))
  (alive (x 19) (y 11))
  (alive (x 20) (y 11))
  (alive (x 19) (y 10))
  (alive (x 20) (y 10)))
```

Blinkers are patterns that repeat themselves for several frames.

    <figure>
      <video controls>
        <source src="conways-game-of-life-written-in-clips-3.webm">
        <source src="conways-game-of-life-written-in-clips-3.mp4">
      </video>
      <figcaption>
        Fig. 9: A complex oscillator called a "pulsar"
      </figcaption>
    </figure>
```clips

(deffacts pulsar
  (alive (x 6) (y 15))
  (alive (x 6) (y 14))
  (alive (x 6) (y 13))
  (alive (x 6) (y 9))
  (alive (x 6) (y 8))
  (alive (x 6) (y 7))

  (alive (x 10) (y 17))
  (alive (x 9) (y 17))
  (alive (x 8) (y 17))
  (alive (x 10) (y 12))
  (alive (x 9) (y 12))
  (alive (x 8) (y 12))
  (alive (x 10) (y 10))
  (alive (x 9) (y 10))
  (alive (x 8) (y 10))
  (alive (x 10) (y 5))
  (alive (x 9) (y 5))
  (alive (x 8) (y 5))

  (alive (x 11) (y 15))
  (alive (x 11) (y 14))
  (alive (x 11) (y 13))
  (alive (x 11) (y 9))
  (alive (x 11) (y 8))
  (alive (x 11) (y 7))

  (alive (x 13) (y 15))
  (alive (x 13) (y 14))
  (alive (x 13) (y 13))
  (alive (x 13) (y 9))
  (alive (x 13) (y 8))
  (alive (x 13) (y 7))

  (alive (x 14) (y 17))
  (alive (x 15) (y 17))
  (alive (x 16) (y 17))
  (alive (x 14) (y 12))
  (alive (x 15) (y 12))
  (alive (x 16) (y 12))
  (alive (x 14) (y 10))
  (alive (x 15) (y 10))
  (alive (x 16) (y 10))
  (alive (x 14) (y 5))
  (alive (x 15) (y 5))
  (alive (x 16) (y 5))

  (alive (x 18) (y 15))
  (alive (x 18) (y 14))
  (alive (x 18) (y 13))
  (alive (x 18) (y 9))
  (alive (x 18) (y 7))
  (alive (x 18) (y 8)))
```

### Spaceships

Spaceships appear to move across the playing field.

#### Gliders {#gliders}

    <figure>
      <video controls>
        <source src="conways-game-of-life-written-in-clips-2.webm">
        <source src="conways-game-of-life-written-in-clips-2.mp4">
      </video>
      <figcaption>
        Fig. 10: Several gliders colliding
      </figcaption>
    </figure>
```clips

(deffacts gliders
  (alive (x 3) (y 1))
  (alive (x 3) (y 2))
  (alive (x 3) (y 3))
  (alive (x 2) (y 3))
  (alive (x 1) (y 2))

  (alive (x 9) (y 3))
  (alive (x 9) (y 4))
  (alive (x 9) (y 5))
  (alive (x 8) (y 5))
  (alive (x 7) (y 4))

  (alive (x 5) (y 19))
  (alive (x 5) (y 20))
  (alive (x 5) (y 21))
  (alive (x 4) (y 19))
  (alive (x 3) (y 20))

  (alive (x 18) (y 19))
  (alive (x 18) (y 20))
  (alive (x 18) (y 21))
  (alive (x 19) (y 19))
  (alive (x 20) (y 20)))
```

#### Light-weight Spaceships

    <figure>
      <video controls>
        <source src="conways-game-of-life-written-in-clips-5.webm">
        <source src="conways-game-of-life-written-in-clips-5.mp4">
      </video>
      <figcaption>
        Fig. 11: Two light-weight spaceships
      </figcaption>
    </figure>
```clips
(deffacts lightweight-space-ship
  (alive (x 2) (y 1))
  (alive (x 4) (y 1))
  (alive (x 5) (y 2))
  (alive (x 5) (y 3))
  (alive (x 5) (y 4))
  (alive (x 5) (y 5))
  (alive (x 2) (y 4))
  (alive (x 3) (y 5))
  (alive (x 4) (y 5))

  (alive (x 7) (y 7))
  (alive (x 7) (y 9))
  (alive (x 8) (y 10))
  (alive (x 9) (y 10))
  (alive (x 10) (y 10))
  (alive (x 11) (y 10))
  (alive (x 11) (y 9))
  (alive (x 11) (y 8))
  (alive (x 10) (y 7)))
```

### Conclusion

Conway's Game of Life can be quite fun to toy around with. It's also a great
way to learn a new programming language. CLIPS once again makes it super
easy to implement something awesome.

\- ryjo
