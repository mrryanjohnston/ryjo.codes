title: A JSON Validator in C
description: This article describes an implementation of a json parser in C.
date: 2023-09-05
css: syntax.css
---
### Introduction

In this article, I'll walk you through [a JSON validator in C that I
wrote](https://github.com/mrryanjohnston/validatejson). A lot of popular
programming languages have some way to parse a string of
[JSON](https://www.json.org/json-en.html). I wanted to come up with a way to
bring JSON (as defined by [RFC
8259](https://datatracker.ietf.org/doc/html/rfc8259) ) into
[CLIPS](https://www.clipsrules.net/), but I wasn't quite pleased with
existing JSON parsing libraries. This will be a "base" from which I write a
JSON-to-CLIPS library next.

### Wait... But Why?

There are some really cool [JSON parsers in C on
GitHub](https://github.com/search?q=json+parser+language%3AC&type=repositories&l=C),
and I had fun writing a few proof-of-concepts with
`[cJSON](https://github.com/DaveGamble/cJSON)`,
`[yajl](https://github.com/lloyd/yajl)`, and
`[jsmn](https://github.com/zserge/jsmn)`. `cJSON` was super
simple to use, but it provided so many options that I didn't want (including
one to [allow junk after a valid portion of the
string](https://github.com/DaveGamble/cJSON/issues/767)) that I decided to
look elsewhere. `yajl` is a tried-and-true library developed by [Loid
Hilaiel](https://github.com/lloyd). It provides a nice bring-your-own data
structure approach, but I didn't want the sort-of "framework" functionality
that it provides. `jsmn` really struct me as an awesome implementation.
However, like the other two, it initializes `structs` that I don't need. On
top of all of this, every one of those libraries uses `goto`, which I'm
personally not a fan of.

I decided to take `jsmn`'s implementation and make it my own. What I ended
up with was a JSON validator that does not initialize structs and only uses
1 `int` variable. I also wrote a test suite to make sure changes I made over
time did not introduce regressions. While there is still room for
improvement, I'm happy with the effort, and I'll use this for a
JSON-to-CLIPS implementation in the coming weeks/months/whatevers. Now: on
with the article!

### First Steps: Tests!

First, the test suite setup.
`[test.c](https://github.com/mrryanjohnston/validatejson/blob/e677fbf753e57a044a90c8812f6e182ecb070ad0/tests/test.c)`
loads in files from `test/valid` and `test/invalid` in order to test both
valid and invalid JSON strings respectively. If it hits an error, it exits
immediately. To add a new valid or invalid case, add a file to those
directories containing the string in question. Here's what that looks like:

```
$ make test
gcc -c validatejson.c
gcc -o tests/test tests/test.c validatejson.o
./tests/test
Test results:
================
PASS
rm ./tests/test validatejson.o
```

Here's what it looks like when I add a valid `json` file to the
`test/invalid` directory:

```
$ echo "{}" > tests/invalid/foo.json
$ make test
gcc -c validatejson.c
gcc -o tests/test tests/test.c validatejson.o
./tests/test
Test results:
================
ERROR: {}
 should be invalid!
rm ./tests/test validatejson.o
```

Here's what it looks like when I add an invalid `json` file to the
`test/valid` directory:

```
$ echo "}" > tests/valid/foo.json
$ make test
gcc -c validatejson.c
gcc -o tests/test tests/test.c validatejson.o
./tests/test                                                                                                                                                                                 
Test results:                                                                                                                                                                                
================
ERROR: }
 should be valid!
rm ./tests/test validatejson.o
```

### The Library and the Binary

I separated this out into two files: one file is meant to be included in
projects as a library, the other: a project that uses the aforementioned
library. This let me "dog food" my library. Take a look at
`[main.c](https://github.com/mrryanjohnston/validatejson/blob/e677fbf753e57a044a90c8812f6e182ecb070ad0/main.c)`.
This is a slightly more complex version of the example given in the
`[README.md](https://github.com/mrryanjohnston/validatejson/blob/e677fbf753e57a044a90c8812f6e182ecb070ad0/README.md)` file. Here's its
output:

```
$ make
gcc -c validatejson.c
gcc -o validatejson main.c validatejson.o
$ ./validatejson 
USAGE
validatejson checks whether the argument passed is a valid string of JSON

Example:
        validatejson '{ "foo": [ 1, 2, "Bar!" ] }'
$ ./validatejson '{ "foo": [ 1, 2, "Bar!" ] }'
PASS
$ ./validatejson '{ "foo": [ 1, 2, "Bar! ] }'
ERROR: { "foo": [ 1, 2, "Bar! ] } is invalid!
```

The main purpose of this binary is to demonstrate [usage of the underlying
function
`validateJSON`](https://github.com/mrryanjohnston/validatejson/blob/e677fbf753e57a044a90c8812f6e182ecb070ad0/main.c#L10)
which is provided by the library:

```c focus={2,13,14:1-4}
#include <stdio.h>
#include "validatejson.h"

int main(int argc, char *argv[])
{
  if (argc == 1)
  {
    printf("USAGE\nvalidatejson checks whether the argument passed is a valid string of JSON\n\nExample:\n\tvalidatejson '{ \"foo\": [ 1, 2, \"Bar!\" ] }'\n");
    return 0;
  }
  else if (argc == 2)
  {
    if (!validateJSON(argv[1]))
    {
      printf("ERROR: %s is invalid!\n", argv[1]);
      return -1;
    }
    printf("PASS\n");
    return 0;
  }
  return -1;
}
```

### The Library: Part 1

Let's have a look at the "entry" function: `validateJSON`:

```c
bool validateJSON(const char *jsonString) {
  int cursor = 0;

  return validateJSONString(jsonString, &cursor, strlen(jsonString));
}
```

Super straightforward. Its main purpose is to store the context of our
`cursor`. This `cursor` will iterate over every character in the passed
string and determine if it's a valid character at that point in the string
according to [RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259). We
also pass in the calculated `length` of the passed string. This provides
defaults for our validator. If the programmer wanted to start at a later
character in a string, or if the programmer wanted to limit the validation
check to a certain number of characters, they could pass their own into
`validateJSONString`:

```c
bool validateJSONString(const char *jsonString, int *cursor, int length)
{
  return validateJSONElement(jsonString, cursor, length) &&
         (
           (*cursor) == length ||
           ++(*cursor) &&
           skipWhitespace(jsonString, cursor, length) &&
           (*cursor) == length
         );
}
```

This function is a convenient way of saying "the string must only contain
one valid JSON element at the top level." We validate the first JSON element
(as defined in the RFC), and then we make sure there is only whitespace
trailing it.

Let's look at the next "layer:" `validateJSONElement`:

```c
bool validateJSONElement(const char *jsonString, int *cursor, int length)
{
  skipWhitespace(jsonString, cursor, length);
  switch (jsonString[*cursor])
  {
    case '"':
      return validateString(jsonString, cursor, length);
    case '[':
      return validateArray(jsonString, cursor, length);
    case '{':
      return validateObject(jsonString, cursor, length);
    case 't':
    case 'f':
    case 'n':
      return validateBoolean(jsonString, cursor, length);
    case '-':
      (*cursor)++;
    default:
      return validateNumber(jsonString, cursor, length);
  }
}
```

First thing first: since we're at the beginning of the string, we can safely
skip over whitespace. The next character we encounter must be a string, an
array, an object, a boolean, a null, or a number. strings must start with a
`&quot;`, arrays must start with a `[`, and objects start with a `{`. We
check for `true`, `false` and `null` in `validateBoolean`, so we look for
their starting characters `t`, `f`, or `n`. Finally, numbers can either
begin with a `-` in the case of negatives or `0` through `9`. By default,
we'll go int to `validateNumber` which will return `false` if the `cursor`
is not on a valid number:

```c
bool validateNumber(const char *jsonString, int *cursor, int length)
{
  return validateAtLeastOneInteger(jsonString, cursor, length) &&
         validateFraction(jsonString, cursor, length) &&
         validateExponent(jsonString, cursor, length) &&
         (
           jsonString[*cursor] == '}' ||
           jsonString[*cursor] == ']' ||
           jsonString[*cursor] == ',' ||
           jsonString[*cursor] == ' ' ||
           jsonString[*cursor] == '\t' ||
           jsonString[*cursor] == '\r' ||
           jsonString[*cursor] == '\n' ||
           jsonString[*cursor] == '\0'
         ) &&
         (*cursor)--;
}
```

The first thing we're going to do is verify there is at least one integer:

```c
bool validateAtLeastOneInteger(const char *jsonString, int *cursor, int length)
{
  if (
    jsonString[*cursor] < 48 ||
    jsonString[*cursor] > 57
  ) return false;
  do (*cursor)++;
  while (
    *cursor < length &&
    jsonString[*cursor] >= 48 &&
    jsonString[*cursor] <= 57
  );
  return true;
}
```

In C, we can check the `int` representation of a `char` value. Conveniently,
digits `0` through `9` are represented as `int`s `48` to `57`, so we make
sure the `int` the `cursor` is on is between those two.

Once we've confirmed we're on an integer, we skip characters in the string
until we get to a non-integer. Using a `do-while` loop lets us move the
cursor forward once. This is nice since we've already checked the character
the current cursor is on.

The next non-integer character we should run into is a period `.` to signify
a fraction or an `e`/`E` to signify an exponent. `validateFraction` and
`validateExponent`, which are called after we've hit a non-integer
character, will return with `true` if the character we're on is not `.` or
`e`/`E`. This lets us "fall through" to the end of our potential JSON number
to make sure it "ends" properly:

```c
bool validateFraction(const char *jsonString, int *cursor, int length)
{
  return jsonString[*cursor] != '.' ||
         (*cursor)++ &&
         validateAtLeastOneInteger(jsonString, cursor, length);
}

bool validateExponent(const char *jsonString, int *cursor, int length)
{
  return (
           jsonString[*cursor] != 'e' &&
           jsonString[*cursor] != 'E'
         ) ||
         (*cursor)++ &&
         (
           (
             jsonString[*cursor] == '-' ||
             jsonString[*cursor] == '+'
           ) &&
           (*cursor)++ ||
           true
         ) &&
         validateAtLeastOneInteger(jsonString, cursor, length);
}
```

If we do find a `.` or `e`/`E`, we move the cursor forward and begin
validating that we have the proper characters after this character in each
function. For the fraction, we make sure that we have at least one integer.
For the exponent, we allow an optional `+` or `-` sign. Then, we make sure
we have at least one integer.

`validateNumber` then checks for a character that signifies the "end" of the
number, then we move the `cursor` back one. This is a potential place of
improvement for our algorithm; we must ask ourselves "how can we re-write
this logic such that we only ever move the cursor forward?" For now, I'm not
sure. But that's ok: our current approach works, and "perfect is the enemy
of done."

### Our Other Validation Functions

Now that our `cursor` is on the end of a valid JSON number, we can make sure
that any "surrounding" JSON element is "closed" or "continued" correctly.
Control of our program will return to the "outer" function calls, and
validation will continue. If this string only contains a number, we'll
verify that there are no characters after the JSON number.

The next "easy" validation to wrap our minds around is `validateBoolean`
since this checks for three specific series of characters: `true`, `false`,
or `null`.

```c
bool validateBoolean(const char *jsonString, int *cursor, int length)
{
  return (
      strncmp(jsonString + (*cursor), "true", 4) == 0 ||
      strncmp(jsonString + (*cursor), "null", 4) == 0
    ) &&
    (*cursor = (*cursor) + 3) ||
    strncmp(jsonString + (*cursor), "false", 5) == 0 &&
    (*cursor = (*cursor) + 4);
}
```

Given that the `cursor` is at the beginning of one of these three specific
words, we use `strncmp` (built into C's `string.h` library) to check it and
the following characters for a match. `strncmp` returns `0` if we have a
match, so we just return the boolean value of a comparison check for that
integer. We also return `(*cursor)++` which itself will be an `int`. This is
convenient because our `cursor` will be an `int` greater than `0`. This
equates to `true` in C, while `0` itself equates to `false`. One gotcha: C
will return `*cursor` *before* it increments `*cursor`, so if we ever need
to return the value of `*cursor` *after* it's been incremented, we'd need to
use `++(*cursor)`. That's why we do `++(*cursor)` in `validateJSONString`.
This allows us to consider the case of a single-digit number like `1`. Since
`1` would be valid JSON, and our `*cursor` would be on index `0`, our return
statement would be `false`.

One last thing before we move on: `(*cursor = (*cursor) + 4)` can be
returned. It'll return the `int` which is the result of `(*cursor) + 4`.
It'll also set the value of `cursor`. Convenient!

`validateArray` is next. By default, we'll allow for an empty array `[]`.
Else, we'll make sure the following content is a valid JSON element, then
we'll make sure the array ends properly:

```c
bool validateArray(const char *jsonString, int *cursor, int length)
{
  (*cursor)++;
  skipWhitespace(jsonString, cursor, length);
  return jsonString[*cursor] == ']' ||
         validateJSONElement(jsonString, cursor, length) &&
         validateEndOfArray(jsonString, cursor, length);
}
```

Note that we need to first advance the `*cursor` since the only reason we're
in this function is that we've determined we've hit the start of an array
with `[` in `validateJSONElement`.

Before we take a look at `validateEndOfArray`, let's have a look at
`skipWhitespace`:

```c
bool skipWhitespace(const char *jsonString, int *cursor, int length)
{
  while (
    *cursor < length && (
      validateCharAndAdvanceCursor(jsonString, cursor, ' ')  ||
      validateCharAndAdvanceCursor(jsonString, cursor, '\t') ||
      validateCharAndAdvanceCursor(jsonString, cursor, '\r') ||
      validateCharAndAdvanceCursor(jsonString, cursor, '\n')
    )
  );
  return true;
}
```

This one has a funky-looking `while` loop. The `while` will loop until the
check returns `false`, and this will only happen until your cursor is at the
end of the string or when the cursor is on a whitespace. Each
`validateCharAndAdvanceCursor` does exactly what you think it should do:

```c
bool validateCharAndAdvanceCursor(const char *jsonString, int *cursor, char c)
{
  return jsonString[*cursor] == c &&
         ++(*cursor);
}
```

The `while` loop in `skipWhitespace` doesn't need a body because all of the
work is done by advancing the cursor in `validateCharAndAdvanceCursor`.

Ok, as promised: here's `validateEndOfArray`:

```c
bool validateEndOfArray(const char *jsonString, int *cursor, int length)
{
  (*cursor)++;
  skipWhitespace(jsonString, cursor, length);
  return jsonString[*cursor] == ']' ||
         validateCharAndAdvanceCursor(jsonString, cursor, ',') &&
         validateJSONElement(jsonString, cursor, length) &&
         validateEndOfArray(jsonString, cursor, length);
}
```

Short and sweet. Either we end the array here with a `]` character, or we
continue it with a `,`. There's some duplication here between
`validateArray` and this function. However, I believe it would require some
re-organization of the control flow of our program since the order of
validations is context-dependent. Simply: the only difference here is that
`,` is a valid character as it is at least the second JSON element in the
array. I'm sure there's some way to pass pointers to functions here, though
it's not immediately clear to me how that might work. Thus, we leave this
duplication for now.

`validateObject` and `validateEndOfObject` work similarly:

```c
bool validateEndOfObject(const char *jsonString, int *cursor, int length)
{
  (*cursor)++;
  skipWhitespace(jsonString, cursor, length);
  return jsonString[*cursor] == '}' ||
         validateCharAndAdvanceCursor(jsonString, cursor, ',') &&
         skipWhitespace(jsonString, cursor, length) &&
         jsonString[*cursor] == '"' &&
         validateString(jsonString, cursor, length) &&
         (*cursor)++ &&
         skipWhitespace(jsonString, cursor, length) &&
         validateCharAndAdvanceCursor(jsonString, cursor, ':') &&
         validateJSONElement(jsonString, cursor, length) &&
         validateEndOfObject(jsonString, cursor, length);
}

bool validateObject(const char *jsonString, int *cursor, int length)
{
  (*cursor)++;
  skipWhitespace(jsonString, cursor, length);
  return jsonString[*cursor] == '}' ||
         jsonString[*cursor] == '"' &&
         validateString(jsonString, cursor, length) &&
         (*cursor)++ &&
         skipWhitespace(jsonString, cursor, length) &&
         validateCharAndAdvanceCursor(jsonString, cursor, ':') &&
         validateJSONElement(jsonString, cursor, length) &&
         validateEndOfObject(jsonString, cursor, length);
}
```

Just like in our array validation functions, the only difference between
these two is that we allow the possibility of a `,` and following whitespace
before validating a key/value pair in this object in `validateEndOfObject`.
In `validateObject`, we skip these two checks because we assume it's the
first key/value pair in the object.

The last function we'll look at is `validateString`. Just a fair warning:
this one deviates from the other validation functions.

```c
bool validateString(const char *jsonString, int *cursor, int length)
{
  (*cursor)++;
  while (
    *cursor < length &&
    jsonString[*cursor] != '"'
  )
  {
    if (jsonString[*cursor] == '\\')
    {
      (*cursor)++;
      if (jsonString[*cursor] == 'u')
      {
        if ((*cursor) + 4 > length) return false;
        // From https://github.com/zserge/jsmn/blob/25647e692c7906b96ffd2b05ca54c097948e879c/jsmn.h#L241-L251
        for (int x = 0; x < 4; (*cursor)++ && x++)
        {
          int c = jsonString[(*cursor) + 1];
          if (!(
               (c >= 48 && c <= 57) || /* 0-9 */
               (c >= 65 && c <= 70) || /* A-F */
               (c >= 97 && c <= 102)   /* a-f */
          )) return false;
        }
      }
    }
    (*cursor)++;
  }
  return jsonString[*cursor] == '"';
}
```

We immediately end once we find a `&quot;` character. We allow for
characters to be escaped with `\`. There's a special case accounted for when
there is `\u` present. This signifies a character represented by 4 hex
digits.

### Conclusion

In this article, I stepped you through a C implementation of a JSON
validator. We talked about potential uses, tradeoffs in its design, and ways
we could improve it. I'm going to use this as a reference for writing a JSON
parser next. Thanks for reading!

\- ryjo
