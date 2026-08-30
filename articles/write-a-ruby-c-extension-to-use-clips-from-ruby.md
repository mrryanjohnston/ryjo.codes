title: Write a Ruby C Extension to Use CLIPS from Ruby: Part 1
description: This article describes writing a C extension for Ruby to access CLIPS.
date: 2023-04-25
css: syntax.css
---
### Introduction

There's [plenty](https://silverhammermba.github.io/emberb/c/)
[of](https://docs.ruby-lang.org/en/2.4.0/extension_rdoc.html)
[info](https://www.rubyguides.com/2018/03/write-ruby-c-extension/) online
about writing Ruby C Extensions, but why would you want to do so? C is
extremely fast, especially when it comes to math. Ruby: not so fast at math.
Of course, developer happiness is at the heart of Ruby rather than speed. So
then, aside from the perhaps "superficial" reasons of improved speed, one
might want to write a C extension to interact with a library already written
in C.

In this article, we're going to look at how to write a Ruby C extension that
lets the user interact with [CLIPS](https://www.clipsrules.net/), a
programming language used to create Rules Engines and Expert Systems. We'll
also discuss some of the things that make Ruby great, including why I think
that **Ruby is like a framework for the C programming language**.

### Getting Started with `mkmf`

We'll use
`[mkmf](https://ruby-doc.org/stdlib-2.5.1/libdoc/mkmf/rdoc/MakeMakefile.html)`
to create a `Makefile` for us that'll compile our Ruby C Extension alongside
CLIPS. First, we'll download CLIPS into the current directory, extract it,
and delete the `makefile`s that come with it:

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

$ rm makefile*
```

Now create a file named `extconf.rb` that looks like this:

```ruby
require 'mkmf'
create_makefile('clipsruby')
```

We'll now create a `clipsruby.c` file that looks like this:

```c
#include "clips.h"
#include "ruby.h"

void Init_clipsruby(void)
{
  VALUE rbCLIPS = rb_define_module("CLIPS");
}
```

Now run `ruby extconf.rb`. This creates a `Makefile`. Easy so far. Run
`make` and watch the extension compile. Once it's done, fire up `irb` to
make sure we can `require_relative` our new extension:

```
$ irb
irb(main):001:0> require_relative('./clipsruby')
=> true
irb(main):002:0> CLIPS
=> CLIPS
```

Sweet. We can now bring in our C extension, and our Ruby environment knows
about the `CLIPS` module we defined in our `Init_clipsruby` function by
calling `rb_define_module`.

### Interacting With CLIPS

Let's interact with CLIPS via Ruby. For starters, we'll implement
`CreateEnvironment` from CLIPS. This will create a new CLIPS environment
that we can assert Facts into, define Rules in, and run. We'll write some C
code so that we can run `CLIPS.create_environment`. Normally in C world,
`CreateEnvironment` would return a pointer to a C struct `Environment`. In
Ruby, you take C structs and "wrap" them. This wrapping provides the ability
to specify "setup" and "clean up" functionality that must run when Ruby's
Garbage Collector frees up unused memory. This is what I might consider the
defining characteristic of Ruby: it provides safety around underlying memory
management that would normally be left to the developer to take care of.

Lets define our "wrapping" code for the `Environment` struct provided by the
CLIPS C library:

```c focus={4-7,9-12,14-20,22-25,30-31}
#include "clips.h"
#include "ruby.h"

void environment_free(void *data)
{
  DestroyEnvironment((Environment*) data);
}

size_t environment_size(const void *data)
{
  return MemUsed((Environment*) data);
}

static const rb_data_type_t Environment_type = {
  .function = {
    .dfree = environment_free,
    .dsize = environment_size
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY
};

VALUE environment_alloc(VALUE self)
{
  return TypedData_Wrap_Struct(self, &Environment_type, CreateEnvironment());
}

void Init_clipsruby(void)
{
  VALUE rbCLIPS = rb_define_module("CLIPS");
  VALUE rbEnvironment = rb_define_class_under(rbCLIPS, "Environment", rb_cObject);
  rb_define_alloc_func(rbEnvironment, environment_alloc);
}
```

The first thing we will note is our usage of `rb_define_class_under` to
define `CLIPS::Environment` as a class under the `CLIPS` module. We tell it
to inherit from Ruby's `Object` class, referred to by `rb_cObject`.

Next, we define an "allocation" function called `environment_alloc`. When we
create our CLIPS environment with `CreateEnvironment`, CLIPS allocates
memory. Remember that Ruby is awesome at wrapping C structs and representing
them as Ruby Objects? That's because it provides lifecycle "hooks" that we
can use to do something during the instantiation and garbage collection of
an Object. In this way, **Ruby is like a framework for the C programming
language**.

You'll note that we pass the address of `Environment_type` as the second
argument to this function. This struct provides a way for us to "hook into"
the lifecycle of an Object in Ruby. In it, we define our memory freeing
functionality, as well as a way to check the size of the struct we are
wrapping. `.flags` specifies something that gives us a slight performance
boost if we do not [unlock the
GVL](https://silverhammermba.github.io/emberb/c/#c-in-ruby-threads) (which
we won't in this article). There are [other things we can specify in this
struct](https://docs.ruby-lang.org/en/2.4.0/extension_rdoc.html#label-C+struct+to+Ruby+object),
but in this particular case, they're not needed.

We define our `environment_free` and `environment_size` functions above as
wrappers around the CLIPS library functions `DestroyEnvironment` and
`MemUsed` respectively.

So far, the code we've written will only allow us to instantiate a
`CLIPS::Environment` object using `CLIPS::Environment.new` in our Ruby code.
We haven't yet defined our static `CLIPS.create_environment` method, so
let's do that now in `clipsruby.c`:

```c focus={28-31,36,38:1-2}

#include "clips.h"
#include "ruby.h"

void environment_free(void *data)
{
  DestroyEnvironment((Environment*) data);
}

size_t environment_size(const void *data)
{
  return MemUsed((Environment*) data);
}

static const rb_data_type_t Environment_type = {
  .function = {
    .dfree = environment_free,
    .dsize = environment_size
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY
};

VALUE environment_alloc(VALUE self)
{
  return TypedData_Wrap_Struct(self, &Environment_type, CreateEnvironment());
}

static VALUE create_environment(VALUE self)
{
  return environment_alloc(rb_const_get(self, rb_intern("Environment")));
}

void Init_clipsruby(void)
{
  VALUE rbCLIPS = rb_define_module("CLIPS");
  rb_define_module_function(rbCLIPS, "create_environment", create_environment, 0);

  VALUE rbEnvironment = rb_define_class_under(rbCLIPS, "Environment", rb_cObject);
  rb_define_alloc_func(rbEnvironment, environment_alloc);
}

```

`rb_intern` lets us pass a C string and returns an
`[ID](https://docs.ruby-lang.org/en/2.4.0/extension_rdoc.html#label-ID+or+Symbol)`.
This is an internal Ruby thing, and it's used to keep track of Ruby
"identifiers." If you're familiar with Ruby's concept of
`[Symbol](http://silverhammermba.github.io/emberb/c/#symbol)`s,
think of `ID`s as the C integer corresponding to the `Symbol` in Ruby.
`rb_const_get` takes a `VALUE` which corresponds to a Ruby Class or Module.
It also takes an `ID` that exists within the `VALUE` we passed as the first
argument. The argument passed in to our C function `create_environment` will
be the Class, Module, Object, etc. that the method was invoked on. In our
case, we'll be doing `CLIPS.create_environment`, so that'll be `self` in our
function. Thus, we pass the Ruby constant `CLIPS::Environment` to
`environment_alloc` in our `create_environment` C function. It follows that,
when called from Ruby, this function will return an instance of
`CLIPS::Enviornment`. Beautiful. Finally, we use `rb_define_module_function`
to define a function in our `CLIPS` module named `create_environment` which
calls our `create_environment` C function and passes 0 arguments.

For easier testing purposes, let's create a `main.rb` file that we'll use to
quickly test our extension:

```ruby
require_relative("./clipsruby")

p CLIPS::Environment.new
p CLIPS.create_environment
```

Running `make` will detect changes to the `clipsruby.c` which is nice. We
won't have to re-compile CLIPS each time we make changes to our extension!
We can test things out by doing `ruby main.rb`. We should see output that
looks like this:

```
$ ruby main.rb
#<CLIPS::Environment:0x00007f5cab9f4070>
#<CLIPS::Environment:0x00007fa4739b7688>
```

### Asserting Facts

We'll define two methods that we'll use to wrap CLIPS's `AssertString` C
function. One will be a "class method" for the `CLIPS::Environment` class,
and the other will be an "instance method" for **instances** of the
`CLIPS::Environment` class. We'll return a new Ruby Object from these
methods of the class `CLIPS::Environment::Fact` that will wrap `Fact`
structs defined in the CLIPS C library.

Update your `clipsruby.c` file's `Init_clipsruby` function so that it looks
like this:

```c focus={8-9,11}
void Init_clipsruby(void)
{
  VALUE rbCLIPS = rb_define_module("CLIPS");
  rb_define_module_function(rbCLIPS, "create_environment", create_environment, 0);

  VALUE rbEnvironment = rb_define_class_under(rbCLIPS, "Environment", rb_cObject);
  rb_define_alloc_func(rbEnvironment, environment_alloc);
  rb_define_singleton_method(rbEnvironment, "assert_string", clips_environment_static_assert_string, 2);
  rb_define_method(rbEnvironment, "assert_string", clips_environment_assert_string, 1);

  VALUE rbFact = rb_define_class_under(rbEnvironment, "Fact", rb_cObject);
}
```

We use `rb_define_singleton_method` and `rb_define_method` to define a class
method and instance method on `CLIPS::Environment` respectively. The first
method will take two arguments: the first will be an instance of
`CLIPS::Environment`, the second will be a `String` holding a Fact. It'll
look something like `"(foo bar)"`. The second method is an instance method.
This means we can call it on an instance of `CLIPS::Environment`. Since we
call it on an instance, we already have the Environment in which to assert
our Fact, so we only need 1 argument for the `String`.

We also use `rb_define_class_under` to define our `Fact` class.

Alright, let's write our `clips_environment_assert_string` and
`clips_environment_static_assert_string` functions. Add these lines above
your `Init_clipsruby` function in `clipsruby.c`:

```c
static VALUE clips_environment_assert_string(VALUE self, VALUE string)
{
  Environment *env;

  TypedData_Get_Struct(self, Environment, &Environment_type, env);

  Fact *fact = AssertString(env, StringValueCStr(string));

  VALUE rb_fact =
    TypedData_Wrap_Struct(rb_const_get(CLASS_OF(self), rb_intern("Fact")), &Fact_type, fact);

  rb_iv_set(rb_fact, "@environment", self);

  return rb_fact;
}

static VALUE clips_environment_static_assert_string(VALUE self, VALUE rbEnvironment, VALUE string)
{
  return clips_environment_assert_string(rbEnvironment, string);
}
```

We'll look at `clips_environment_assert_string` first. The first argument is
the instance of the `CLIPS::Environment` we are calling this on. We'll
"unwrap" the Ruby object to get the `Environment` struct inside using
`TypedData_Get_Struct`. In order to "unwrap" the object, we must pass:

1. The Ruby Object itself
2. The identifier of the underlying struct
3. A pointer to the struct we created earlier with metadata for memory
   setup/teardown
4. A declared pointer variable that'll receive the unwrapped `Environment`

We then use the unwrapped `Environment` to assert the string passed as the
second argument to `clips_environment_assert_string`. We use
`StringValueCStr` to convert the Ruby string to a C string.

Just like in `environment_alloc`, we'll use `TypedData_Wrap_Struct` to
create our newly asserted `Fact` struct. We want to use the class we created
in our `Init_clipsruby` function called `CLIPS::Environment::Fact`, so we
make use of `rb_const_get` again. This time, though, we must use `CLASS_OF`
to convert the variable `self` into a Ruby class. Right now, `self` is the
*instance* of a `CLIPS::Environment`, and `rb_const_get` expects a *class*.

You'll note we assume a struct called `Fact_type` exists. We'll create this
in our next step. For now, let's finish reading through this function.

`rb_iv_set` provides a way for us to set an instance variable on our newly
wrapped `CLIPS::Environment::Fact` instance. We'll store the environment in
which the fact is asserted as the instance variable `@environment` on the
`CLIPS::Environment::Fact` object.

A somewhat neat pattern emerges when we want to create a static method on
the `CLIPS::Environment` class. We can call the
`clips_environment_assert_string` function we just wrote in
`clips_environment_static_assert_string`. This is the same pattern that can
be used in Ruby for writing static wrapping class functions that take an
instance of the class as its first argument sort-of like this:

```ruby
class Foo
  def self.bar(foo)
    foo.bar
  end

  def bar
    p "Bar!"
  end
end

Foo.bar(Foo.new)
```

Alright, let's implement `Fact_type`. Write this in your `clipsruby.c` above
the previous two functions.

```c
size_t fact_size(const void *data)
{
  return sizeof(Fact);
}

static const rb_data_type_t Fact_type = {
  .function = {
    .dsize = fact_size
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY
};
```

This struct is much simpler than our `Environment_type` struct. That's
because the memory used to store the Fact is managed by CLIPS, so we don't
need to specify any kind of clean up functionality. We define `fact_size`
here to get the size of the `Fact` struct, but this may not be the best
approach. At any rate, [we don't necessarily *need* to specify
`.dsize`](https://docs.ruby-lang.org/en/2.4.0/extension_rdoc.html#label-C+struct+to+Ruby+object),
so if you don't like this approach, just remove the `.function` block
altogether. From the official Ruby website:

> You can pass 0 as dsize if it is hard to implement such a function. But
> it is still recommended to avoid 0.

Let's test this out. Update your `main.rb` so that it looks like this:

```ruby
require_relative("./clipsruby")

env = CLIPS::Environment.new
p env.assert_string("(foo bar)")
p CLIPS::Environment.assert_string(env, "(baz bat)")
```

Run this with `ruby main.rb` and your console output should look something
like this:

```
$ ruby main.rb
#<CLIPS::Environment::Fact:0x00007f75aea4f0f8 @environment=#<CLIPS::Environment:0x00007f75aea4f2d8>>
#<CLIPS::Environment::Fact:0x00007f75aea4e9a0 @environment=#<CLIPS::Environment:0x00007f75aea4f2d8>>
```

### Checking Our Work

We can assert facts, but how do we see which facts are in our environment?
We'll wrap the `Facts` function. This acts like `(facts)` in CLIPS, and it
will write out to STDOUT all of the facts in our environment. Update the
`Init_clipsruby` function in your `clipsruby.c` file like so:

```c focus={10-11,13:1-2}
void Init_clipsruby(void)
{
  VALUE rbCLIPS = rb_define_module("CLIPS");
  rb_define_module_function(rbCLIPS, "create_environment", create_environment, 0);

  VALUE rbEnvironment = rb_define_class_under(rbCLIPS, "Environment", rb_cObject);
  rb_define_alloc_func(rbEnvironment, environment_alloc);
  rb_define_singleton_method(rbEnvironment, "assert_string", clips_environment_static_assert_string, 2);
  rb_define_method(rbEnvironment, "assert_string", clips_environment_assert_string, 1);
  rb_define_singleton_method(rbEnvironment, "facts", clips_environment_static_facts, 1);
  rb_define_method(rbEnvironment, "facts", clips_environment_facts, 0);

  VALUE rbFact = rb_define_class_under(rbEnvironment, "Fact", rb_cObject);
}
```

Now we need to implement `clips_environment_static_facts` and
`clips_environment_facts` above our `Init_clipsruby` function:

```c
static VALUE clips_environment_facts(VALUE self)
{
  Environment *env;

  TypedData_Get_Struct(self, Environment, &Environment_type, env);

  Facts(env, "stdout", NULL, -1, -1, -1);

  return self;
}

static VALUE clips_environment_static_facts(VALUE self, VALUE rbEnvironment)
{
  return clips_environment_facts(rbEnvironment);
}
```

Update your `main.rb` file so that it looks like this:

```ruby
require_relative("./clipsruby")

env = CLIPS::Environment.new
env.assert_string("(foo bar)")
CLIPS::Environment.assert_string(env, "(baz bat)")
env.facts
CLIPS::Environment.facts(env) 
```

Now running `ruby main.rb` should look something like this:

```
$ ruby main.rb
f-1     (foo bar)
f-2     (baz bat)
For a total of 2 facts.
f-1     (foo bar)
f-2     (baz bat)
For a total of 2 facts.
```

Nice, looks like our class and instance methods work as expected. Note that
we do not have to use Ruby's `p` method to print out our facts. We've
implemented our `facts` method to print to stdout from CLIPS.

### Getting Slots and their Values from `CLIPS::Environment::Fact` Objects

Let's explore some ways in which we can shuttle the value of Fact slots
between Ruby and CLIPS. Since both languages are written in C, we can use
the C space to translate the underlying C values into objects that their
respective languages understand.

We'll start with something easy: let's write functionality to return the
name of a Fact's Deftemplate. In CLIPS, a Deftemplate is named by the first
word in a Fact. Something like `(foo a b c)` would have `foo` as the name of
its Deftemplate. Update your `Init_clipsruby` function in your `clipsruby.c`
file:

```c focus={14-15}
void Init_clipsruby(void)
{
  VALUE rbCLIPS = rb_define_module("CLIPS");
  rb_define_module_function(rbCLIPS, "create_environment", create_environment, 0);

  VALUE rbEnvironment = rb_define_class_under(rbCLIPS, "Environment", rb_cObject);
  rb_define_alloc_func(rbEnvironment, environment_alloc);
  rb_define_singleton_method(rbEnvironment, "assert_string", clips_environment_static_assert_string, 2);
  rb_define_method(rbEnvironment, "assert_string", clips_environment_assert_string, 1);
  rb_define_singleton_method(rbEnvironment, "facts", clips_environment_static_facts, 1);
  rb_define_method(rbEnvironment, "facts", clips_environment_facts, 0);

  VALUE rbFact = rb_define_class_under(rbEnvironment, "Fact", rb_cObject);
  rb_define_singleton_method(rbFact, "deftemplate_name", clips_environment_fact_static_deftemplate_name, 1);
  rb_define_method(rbFact, "deftemplate_name", clips_environment_fact_deftemplate_name, 0);
}
```

We're using a naming scheme here for our function names;
`clips_environment_fact_static_deftemplate_name` is a mouthful, but it
clearly describes "we are making a static method on the
`CLIPS::Environment::Fact` class called `deftemplate_name`." This clarity
will only help us in the future.

Speaking of long-winded function names: let's implement
`clips_environment_fact_static_deftemplate_name` and
`clips_environment_fact_deftemplate_name` above our `Init_clipsruby`
function:

```c
static VALUE clips_environment_deftemplate_name(VALUE self)
{
  Fact *fact;

  TypedData_Get_Struct(self, Fact, &Fact_type, fact);

  return ID2SYM(rb_intern(DeftemplateName(FactDeftemplate(fact))));
}

static VALUE clips_environment_static_deftemplate_name(VALUE self, VALUE rbFact)
{
  return clips_environment_deftemplate_name(rbFact);
}
```

`FactDeftemplate` and `DeftemplateName` are provided by the CLIPS C library.
`FactDeftemplate` takes an argument `Fact*` and returns a `Deftemplate*`. In
CLIPS, Deftemplates are kind-of like classes in Object Oriented Programming.
You can define named slots, and slot order is not dependent unlike
non-deftemplate facts asserted. For example,
`(foo (bar "Bar!") (baz "Baz!"))` and `(foo (baz "Baz!") (bar "Bar!"))` are
the same, while `(foo a b c)` is different than `(foo b c a)`. In both
cases, the Deftemplate's name would be `foo`.

We pass the C string `"foo"` returned from `DeftemplateName` to Ruby's
`rb_intern` which converts it into a Ruby ID. We then pass this Ruby ID to
`ID2SYM`, a Ruby C function that converts IDs to Ruby symbols.

Let's update our `main.rb` file to look like this:

```ruby
require_relative("./clipsruby")

env = CLIPS::Environment.new
fact = env.assert_string("(foo bar)")
p fact.deftemplate_name
p CLIPS::Environment::Fact.deftemplate_name(fact)
```

Now you can do `make; ruby main.rb` and look at the output:

```
$ make; ruby main.rb
compiling clipsruby.c
linking shared-object clipsruby.so
:foo
:foo
```

### Conclusion

This has been the first part of a small series in writing a Ruby C
Extension, specifically for leveraging CLIPS. I'm excited to continue on
with a few more of these, detailing some awesome things including
translating between Ruby and CLIPS values seamlessly. Stay tuned!

\- ryjo
