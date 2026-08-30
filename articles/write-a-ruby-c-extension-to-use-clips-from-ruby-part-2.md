title: Write a Ruby C Extension to Use CLIPS from Ruby: Part 2
description: This article describes converting Ruby VALUEs into CLIPSValues in a Ruby C extension.
date: 2023-06-24
css: syntax.css
---
### Introduction

This is the second part in a series of articles describing creating a Ruby C
extension. In this series, we explore writing a C extension in order to work
with an existing C library in Ruby. In this article, we'll explore
converting data in Ruby land to CLIPS data so that we can assert Ruby values
in our CLIPS environment.

I'd recommend reading [the first
article](./write-a-ruby-c-extension-to-use-clips-from-ruby.html) if you're
new to writing extensions. If you want to skip ahead, I'll provide the
source code that we have up until this point so you can dive right in.

### The Source So Far

The below code block should be everything including the steps from [the
first article](./write-a-ruby-c-extension-to-use-clips-from-ruby.html) for
the `clipsruby.c` file:

```c
#include "clips.h"
#include "ruby.h"

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

static VALUE clips_environment_fact_deftemplate_name(VALUE self)
{
  Fact *fact;

  TypedData_Get_Struct(self, Fact, &Fact_type, fact);

  return ID2SYM(rb_intern(DeftemplateName(FactDeftemplate(fact))));
}

static VALUE clips_environment_fact_static_deftemplate_name(VALUE self, VALUE rbFact)
{
  return clips_environment_fact_deftemplate_name(rbFact);
}

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

VALUE environment_alloc(VALUE self)
{
  return TypedData_Wrap_Struct(self, &Environment_type, CreateEnvironment());
}

static VALUE create_environment(VALUE self)
{
  return environment_alloc(rb_const_get(self, rb_intern("Environment")));
}

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

### From `VALUE` to `CLIPSValue`

The main role of our C extension is to expose CLIPS to Ruby programs.
Ideally, we try to be as lightweight as possible, doing only what is
necessary. Perhaps the "heaviest" lift that we must do is translating data
between the two languages, so we will take extra care to do it right.

In Ruby, data objects are wrapped in `VALUE`s in our C program. CLIPS, on
the other hand, wraps data in `CLIPSValue`s. Thus, we'll start by making
functions that can convert every possible type of `VALUE` that comes with
the standard Ruby library into a `CLIPSValue`. This will let us reference
values in our CLIPS program that were calculated by Ruby.

What we must do is provide behavior for converting [every kind of data types
supported by the Ruby
interpreter](https://docs.ruby-lang.org/en/2.4.0/extension_rdoc.html#label-Data+Types)
into a CLIPSValue. Fair warning: this is going to be a long function. Edit
your `clipsruby.c` file so that it has a function called
`VALUE_to_CLIPSValue`:

```c
static CLIPSValue VALUE_to_CLIPSValue(VALUE from, Environment *env)
{
  CLIPSValue to;
  switch (TYPE(from))
  {
    case T_NIL:
      to.lexemeValue = CreateSymbol(env, "nil");
      break;
    case T_OBJECT:
      rb_warn("Ruby Object not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_CLASS:
      rb_warn("Ruby Class not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_MODULE:
      rb_warn("Ruby Module not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_FLOAT:
      to.floatValue = CreateFloat(env, NUM2DBL(from));
      break;
    case T_STRING:
      to.lexemeValue = CreateString(env, StringValueCStr(from));
      break;
    case T_REGEXP:
      rb_warn("Ruby Regexp not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_ARRAY:
      long length = RARRAY_LEN(from);

      MultifieldBuilder *mb = CreateMultifieldBuilder(env, length);
      CLIPSValue inner;
      for (int i = 0; i < length; i++)
      {
        inner = VALUE_to_CLIPSValue(rb_ary_entry(from, i), env);
        MBAppend(mb, &inner);
      }
      to.multifieldValue = MBCreate(mb);

      MBDispose(mb);
      break;
    case T_HASH:
      rb_warn("Ruby Hash not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_STRUCT:
      rb_warn("Ruby Struct not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_BIGNUM:
      to.floatValue = CreateFloat(env, NUM2LONG(from));
      break;
    case T_FIXNUM:
      to.integerValue = CreateInteger(env, FIX2INT(from));
      break;
    case T_COMPLEX:
      rb_warn("Ruby Complex not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_RATIONAL:
      rb_warn("Ruby Rational not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_FILE:
      rb_warn("Ruby File not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_TRUE:
      to.lexemeValue = CreateBoolean(env, "TRUE");
      break;
    case T_FALSE:
      to.lexemeValue = CreateBoolean(env, "FALSE");
      break;
    case T_DATA:
      rb_warn("Ruby Data not supported as value in CLIPS!");
      to.voidValue = VoidConstant(env);
      break;
    case T_SYMBOL:
      to.lexemeValue = CreateSymbol(env, rb_id2name(SYM2ID(from)));
      break;
    default:
      rb_warn("Trying to convert unknown Ruby data type to CLIPSValue");
      to.voidValue = VoidConstant(env);
      break;
  }
  return to;
}
```

Told you so. The nice thing is that this function has only one focus:
convert a `VALUE` that comes from our Ruby environment into a `CLIPSValue`
in our CLIPS environment. We use `TYPE` to return the type of Ruby `VALUE`
passed in. Our `switch` statement has as many possible `case` statements as
there are [data types in
Ruby](https://docs.ruby-lang.org/en/2.4.0/extension_rdoc.html#label-Data+Types).
Note: I do ignore the types under the section "In addition, there are
several other types used internally."

Where there is no like-datatype in CLIPS, we set `voidValue` on the `to`
struct. We also surface a little warning to the developer letting them know
why the Ruby value converted to `nil`.

Some things to note here. We set `lexemeValue` on the `to` struct for
boolean values. Also, we use a `MultifieldBuilder` to build, well, a
`Multifield`. We use a `for` loop over the length of the array as returned
from Ruby's `RARRAY_LEN`. Inside of that `for` loop, we do a bit of
recursion: we use the `VALUE_to_CLIPSValue` function to convert the elements
of the Ruby array into their matching `CLIPSValue`s. After we create a
Multifield from the MultifieldBuilder from `MBCreate`, we must use
`MBDispose` to free up the memory taken by the MultifieldBuilder.

### Actually Using our Conversion Function

So far, we haven't done anything with our Ruby-to-CLIPS data function. Let's
do something neat: we'll implement a Ruby method on the `CLIPS::Environment`
that lets us assert a Deftemplate fact from a Ruby hash. Update your
`Init_clipsruby` like so:

```c focus={12-13,15:1-2}
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
  rb_define_singleton_method(rbEnvironment, "assert_hash", clips_environment_static_assert_hash, 3);
  rb_define_method(rbEnvironment, "assert_hash", clips_environment_assert_hash, 2);

  VALUE rbFact = rb_define_class_under(rbEnvironment, "Fact", rb_cObject);
  rb_define_singleton_method(rbFact, "deftemplate_name", clips_environment_fact_static_deftemplate_name, 1);
  rb_define_method(rbFact, "deftemplate_name", clips_environment_fact_deftemplate_name, 0);
}
```

Now we'll write our two new functions `clips_environment_assert_hash` and
`clips_environment_static_assert_hash`:

```c
static VALUE clips_environment_assert_hash(VALUE self, VALUE deftemplate_name, VALUE hash)
{
  const char *cdeftemplate_name;
  switch(TYPE(deftemplate_name))
  {
    case T_SYMBOL:
      cdeftemplate_name = rb_id2name(SYM2ID(deftemplate_name));
      break;
    case T_STRING:
      cdeftemplate_name = StringValueCStr(deftemplate_name);
      break;
    default:
      rb_raise(rb_eTypeError, "First argument must be a String or a Symbol");
      break;
  }

  Environment *env;
  TypedData_Get_Struct(self, Environment, &Environment_type, env);

  FactBuilder *fb = CreateFactBuilder(env, cdeftemplate_name);
  void *args[2] = { (void *)fb, (void *)env };
  rb_hash_foreach(hash, _clips_environment_assert_hash, (VALUE)args);
  Fact *fact = FBAssert(fb);
  FBDispose(fb);

  switch (FBError(env))
  {
    case FBE_NO_ERROR:
      break;
    case FBE_NULL_POINTER_ERROR:
      rb_warn("Could not assert fact. This might be a bug in clipsruby!");
      return Qnil;
    case FBE_COULD_NOT_ASSERT_ERROR:
      rb_warn("Could not assert fact. Pattern matching of a fact or instance is already occurring.");
      return Qnil;
    case FBE_RULE_NETWORK_ERROR:
      rb_warn("Could not assert fact. An error occurs while the assertion was being processed in the rule network.");
      return Qnil;
  }

  VALUE rb_fact =
    TypedData_Wrap_Struct(rb_const_get(CLASS_OF(self), rb_intern("Fact")), &Fact_type, fact);

  rb_iv_set(rb_fact, "@environment", self);

  return rb_fact;
}

static VALUE clips_environment_static_assert_hash(VALUE self, VALUE environment, VALUE deftemplate_name, VALUE hash)
{
  return clips_environment_assert_hash(environment, deftemplate_name, hash);
}
```

The first argument we take for this method is the name of a Deftemplate. In
order to assert a hash (a collection of named key/value pairs), we use a
Deftemplate fact. Deftemplate facts have named slots, so the abstraction
fits nicely. If the user passed a string or symbol for the Deftemplate name,
we can continue. If not, we use `rb_raise` to raise an exception in our Ruby
application.

Similar to how we used a `MultifieldBuilder` in our previous function to
build a `Multifield`, we use a `FactBuilder` to build a `Fact`. The line
`void *args[2] = { (void *)fb, (void *)env };` is interesting: we create an
array of `void` pointers, and cast our `FactBuilder` and `Environment` to
`void *` types. `VALUE` is quite a strange thing. We can cast our array of
`void` pointers to a `VALUE` when we pass it to `rb_hash_foreach`, and
things "just work." This is something similar to what the [Ruby source
code](https://github.com/ruby/ruby/blob/33833aaf03bf6ec2bab66b68a6b1bfa6f57ae0ed/hash.c#L2053)
does in a few places.

Speaking of `rb_hash_foreach`: the first two arguments to this function are
a Ruby hash we want to iterate over, as well as the function that will be
called for each key/value pair in that hash. We pass
`_clips_environment_assert_hash` as this second argument. We'll need to
implement this next.

Next, we assert the Fact using `FBAssert`. We capture the pointer to this
Fact in `fact`, and then we free the memory allocated for the `FactBuilder`
using `FBDispose`.

The following `switch` statement checks to see if there was an issue
asserting our Fact into the CLIPS Environment. I choose to use `rb_warn`
here to display a ruby warning, though it may make sense to raise an
exception in the future. Since we don't raise an exception in case of an
error, we `return` `nil` to our Ruby program. Otherwise, we `break` from the
`switch`.

Then, we wrap our C struct in a Ruby object. Since `self` is the Ruby
`CLIPS::Environment` class,
`rb_const_get(CLASS_OF(self), rb_intern("Fact"))` is the Ruby constant
`CLIPS::Environment::Fact`. We then set an instance variable on the Ruby
object that points to the `CLIPS::Environment` the Fact was asserted into.
Finally, we return the newly wrapped Ruby object.

### Implementing the Iterator Function for `rb_hash_foreach`

Now we'll need to implement `_clips_environment_assert_hash`. We'll do this
above `clips_environment_assert_hash`:

```c focus={1-15,17-21,23-24}
static int _clips_environment_assert_hash(VALUE key, VALUE value, VALUE args)
{
  const char *cslot_name;
  switch(TYPE(key))
  {
    case T_SYMBOL:
      cslot_name = rb_id2name(SYM2ID(key));
      break;
    case T_STRING:
      cslot_name = StringValueCStr(key);
      break;
    default:
      rb_raise(rb_eTypeError, "Slot name must be a String or a Symbol");
      return ST_CONTINUE;
  }

  VALUE *fb_and_env = (VALUE*)args;
  FactBuilder *fb = (FactBuilder*) fb_and_env[0];
  Environment *env = (Environment*) fb_and_env[1];
  CLIPSValue cv = VALUE_to_CLIPSValue(value, env);
  handle_pse_error(FBPutSlot(fb, cslot_name, &cv), cslot_name);

  return ST_CONTINUE;
}

static VALUE clips_environment_assert_hash(VALUE self, VALUE deftemplate_name, VALUE hash)
{
  const char *cdeftemplate_name;
```

We first make sure that the key of this key/value pair is a Ruby string or
symbol. Converting other things is possible, but would lose fidelity. Thus,
I choose to showcase the `rb_raise` function. This raises an exception in
Ruby of the class of the first argument. In this case, we raise a
`TypeError` that's build into Ruby. This seems like a fairly reasonable
error to raise. We also `return ST_CONTINUE;` in this `case` so that we
continue going through the hash key/value pairs.

Next, we convert the `args` `VALUE` to a pointer. This means we can use it
as an array to get the `FactBuilder` and `Environment` pointers we passed in
earlier.

The next line uses our `VALUE_to_CLIPSValue` function to magically convert
the value of the hash's key/value pair to a `CLIPSValue`. When we use
`FBPutSlot`, there is a chance there will be a `PSError` (put slot error) in
our CLIPS Enviornment. For this reason, we will create a `handle_pse_error`
function that will handle the error appropriately. Finally, we make sure
that we `return ST_CONTINUE`.

Here's that `handle_pse_error` function. We'll put it just above the
_clips_environment_assert_hash function for now:

```c focus={1-32}
void handle_pse_error(int error, const char *cslot)
{
  switch (error)
  {
    case PSE_NO_ERROR:
      break;
    case PSE_CARDINALITY_ERROR:
      rb_warn("Could not set slot %s: %s", cslot, "slot/multislot mismatch");
      break;
    case PSE_SLOT_NOT_FOUND_ERROR:
      rb_warn("Could not set slot %s: %s", cslot, "slot not found");
      break;
    case PSE_TYPE_ERROR:
      rb_warn("Could not set slot %s: %s", cslot, "value violates type constraint");
      break;
    case PSE_RANGE_ERROR:
      rb_warn("Could not set slot %s: %s", cslot, "value violates range constraint");
      break;
    case PSE_ALLOWED_VALUES_ERROR:
      rb_warn("Could not set slot %s: %s", cslot, "value violates allowed values constraint");
      break;
    case PSE_ALLOWED_CLASSES_ERROR:
      rb_warn("Could not set slot %s: %s", cslot, "value violates allowed classes constraint");
      break;
    case PSE_NULL_POINTER_ERROR:
    case PSE_INVALID_TARGET_ERROR:
    case PSE_EVALUATION_ERROR:
    case PSE_RULE_NETWORK_ERROR:
      rb_warn("Could not set slot %s: %s", cslot, "possible bug in clipsruby!");
      break;
  };
}

static int _clips_environment_assert_hash(VALUE key, VALUE value, VALUE args)
{
  const char *cslot_name;
```

We once again use `rb_warn`. Given our usage of `rb_raise` earlier, it might
make more sense to use that here. I'll leave that choice up to you.

One thing to note here is that `rb_warn` acts as a `printf` function; the
first argument you pass is a format string, while the following arguments
will replace the tokens from the first string. Pretty neat.

One other thing: the bottom 4 `case` statements "fall through" for a
"catch-all." I'm not entirely sure when they would arise, so I just have
them do some basic behavior for now.

### We Need a Deftemplate

In order to use our `assert_hash` function, we'll need to create a
`Deftemplate`. The quickest way to do this will be to implement CLIPS's
`Build` function. This lets us "build" contructs like Deftemplates, Rules,
etc. in the CLIPS Environment. Add the following to the `Init_clipsruby`
function:

```c focus={14-15,17:1-2,23}
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
  rb_define_singleton_method(rbEnvironment, "assert_hash", clips_environment_static_assert_hash, 3);
  rb_define_method(rbEnvironment, "assert_hash", clips_environment_assert_hash, 2);
  rb_define_singleton_method(rbEnvironment, "build", clips_environment_static_build, 2);
  rb_define_method(rbEnvironment, "build", clips_environment_build, 1);

  VALUE rbFact = rb_define_class_under(rbEnvironment, "Fact", rb_cObject);
  rb_define_singleton_method(rbFact, "deftemplate_name", clips_environment_fact_static_deftemplate_name, 1);
  rb_define_method(rbFact, "deftemplate_name", clips_environment_fact_deftemplate_name, 0);

  VALUE rbInstance = rb_define_class_under(rbEnvironment, "Instance", rb_cObject);
}
    
```

You know the drill by now. Let's add our new functions above the
`Init_clipsruby` function:

```c
static VALUE clips_environment_build(VALUE self, VALUE string)
{
  Environment *env;

  TypedData_Get_Struct(self, Environment, &Environment_type, env);

  switch(Build(env, StringValueCStr(string)))
  {
    case BE_NO_ERROR:
      break;
    case BE_COULD_NOT_BUILD_ERROR:
      rb_warn("`build` failed!");
      break;
    case BE_CONSTRUCT_NOT_FOUND_ERROR:
      rb_warn("`build` failed! Construct not found.");
      break;
    case BE_PARSING_ERROR:
      rb_warn("`build` failed! Could not parse string correctly.");
      break;
  }

  return Qnil;
}

static VALUE clips_environment_static_build(VALUE self, VALUE rbEnvironment, VALUE string)
{
  return clips_environment_build(rbEnvironment, string);
}
    
```

Run `make`, then update your `main.rb` file to look like this:

```ruby
require_relative("./clipsruby")

env = CLIPS::Environment.new
env.build("(deftemplate foo (slot bar) (slot baz) (slot bat) (slot buz))")
env.assert_string("(foo (bar 123) (baz something) (bat 4.56) (buz fizz))")
fact = env.assert_hash(:foo, bar: 789, baz: :thing, bat: 3.8, buz: "another thing")
p fact.deftemplate_name
env.facts
```
    Then you should see something like this when you run it:

```
$ ruby main.rb
:foo
f-1     (foo (bar 123) (baz something) (bat 4.56) (buz fizz))
f-2     (foo (bar 789) (baz thing) (bat 3.8) (buz "another thing"))
For a total of 2 facts.
```

### Conclusion

Alright, nice. We now have functionality that will convert Ruby values into
CLIPS values. We demonstrate this by asserting a Ruby hash as a CLIPS Fact.
Next article, we'll look at how to convert CLIPS values into Ruby values.

\- ryjo
