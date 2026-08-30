title: A Shell Script Calling ChatGPT that uses ChatGPT to Describe its Usage
description: This article describes a shell script that can be used to send a question to and receive an answer from OpenAI's ChatGPT. It also sends the contents of itself to ChatGPT to provide usage documentation to the user.
date: 2023-05-14
css: syntax.css
---
### Introduction

I've been casually using OpenAI's ChatGPT to describe confusing pieces of
code, generate ideas for coding solutions, and just for fun. The web UI is
really great; it saves your conversations and gives the impression of a
back-and-forth conversation with the model. However, it doesn't allow very
long text to be sent via the UI.

I wanted to see how ChatGPT could be used to describe the contents of a pdf,
specifically a pdf describing Charles Forgy's Rete Algorithm. The document
is quite long, so I couldn't copy-and-paste it in the UI due to the
previously mentioned length limits. After a bit of searching, I discovered
[an article describing using ChatGPT from python to summarize
pdfs](https://medium.com/geekculture/summarize-papers-with-chatgpt-8737ed520a07).
While trying the sample code and getting something working, I discovered
[OpenAI's HTTP
API](https://platform.openai.com/docs/api-reference/making-requests) which
would let me use two of my favorite tools to talk to ChatGPT:
[curl](https://curl.se/) and [jq](https://stedolan.github.io/jq/). After
writing a simple shell script that could pass a question and receive an
answer from ChatGPT, I decided to have some fun and use ChatGPT to generate
a typical "usage" message for my new `ask.sh` script. Here's some example
output of that script:

```
$ ./ask.sh
Usage: ./ask.sh [OPENAI_API_PROMPT]

Description:
This script uses the OpenAI API to generate responses to a given prompt. The prompt can be provided as an optional argument. If not provided, the default prompt will be used.

Environment Variable:
OPENAI_API_KEY - This variable should be set to your OpenAI API key. It is required for this script to function properly.

Examples of Usage:
1. ./ask.sh "What is the meaning of life?"
2. OPENAI_API_KEY=your_api_key ./ask.sh "What is the capital of France?"
3. export OPENAI_API_KEY=your_api_key; ./ask.sh "How do I bake a cake?"

$ ./ask.sh "What is the meaning of life?"
As an AI language model, I don't have personal beliefs or opinions. The meaning of life is a philosophical and existential question that has been debated for centuries. It is subjective and varies from person to person. Some believe that the meaning of life is to seek happiness, while others believe it is to fulfill a higher purpose or to achieve spiritual enlightenment. Ultimately, the answer to this question is a personal one that each individual must discover for themselves.
```

In this article, I'll describe a shell script that can be used to send a
question to and receive an answer from OpenAI's ChatGPT. I'll cover some
very basic shell scripting, and I'll describe the `curl` and `jq` programs I
use regularly. Finally, I'll talk a little about what some people are
calling "prompt engineering," which refers to tweaking prompts (or
questions) sent to ChatGPT to refine responses received.

### Creating an Executable Shell Script

If you run a distribution of Linux, this part is quite easy: we'll create a
file called `ask.sh`, add a line to it that describes the "interpreter"
that'll be used to "run" the program we write in it, and finally make it
executable.

```
$ touch ./ask.sh
$ echo '#!/usr/bin/env sh' > ./ask.sh
$ echo "echo 'hello, world'" >> ./ask.sh
$ chmod +x ./ask.sh
$ ./ask.sh
hello, world
```

We first use `touch` to create an empty file in the current directory called
`ask.sh`. We then use `echo` to print some text into that file. This text
describes the "interpreter" that'll run our script. In this case: we're
using the interpreter invoked by `sh`. We then write another command onto
the next line of the file by using `&gt;&gt;`. This command will simply
print "hello, world" to our terminal. `chmod +x ./ask.sh` will make our file
executable. Finally, we run our command and see its output.

### Using `curl` to Talk to ChatGPT

Now that we have a file that can be executed, let's change the contents of
the file so that we use ChatGPT's HTTP API. The program `curl` makes this
very easy for us. It can be used to send an HTTP request to a given URL with
a given payload. [According to OpenAI's
website](https://platform.openai.com/docs/api-reference/making-requests),
the curl command that would send a prompt to ChatGPT is as follows:

```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
     "model": "gpt-3.5-turbo",
     "messages": [{"role": "user", "content": "Say this is a test!"}],
     "temperature": 0.7
   }'
```

Note the `$OPENAI_API_KEY` part. This is a variable in shell scripting, and
it will hold an [OpenAI API
Key](https://platform.openai.com/docs/api-reference/authentication)
generated via OpenAI's website. We'll set this in our environment so that we
don't need to remember our API key. On my computer, I can put the following
into either my `~/.bashrc` or my `~/.bash_profile` file to set this key
automatically:

```bash
export OPENAI_API_KEY="Your API key here!"
```

Now whenever you open a new terminal, this environment variable will be set.
To use it in your *current* terminal, do `. ~/.bashrc` (or similar file
name).

Alright, let's run the above curl command in our terminal. Here's what I
get:

```
$ curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
     "model": "gpt-3.5-turbo",
     "messages": [{"role": "user", "content": "Say this is a test!"}],
     "temperature": 0.7
   }'
{"id":"chatcmpl-7FwnymAAoWvId6SJhrRntHV5xL6DP","object":"chat.completion","created":1684035322,"model":"gpt-3.5-turbo-0301","usage":{"prompt_tokens":14,"completion_tokens":5,"total_tokens":19},"choices":[{"message":{"role":"assistant","content":"This is a test!"},"finish_reason":"stop","index":0}]}
```

The `curl` command results in some JSON printing to our terminal. It's a
little difficult to read, so we'll use `jq` to format it nicely:

```
$ curl https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{
     "model": "gpt-3.5-turbo",
     "messages": [{"role": "user", "content": "Say this is a test!"}],
     "temperature": 0.7
   }' | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   432  100   300  100   132     49     21  0:00:06  0:00:06 --:--:--   106
{
  "id": "chatcmpl-7FwpZAyQTfW7wTbDyMxKabhDn9tkm",
  "object": "chat.completion",
  "created": 1684035421,
  "model": "gpt-3.5-turbo-0301",
  "usage": {
    "prompt_tokens": 14,
    "completion_tokens": 5,
    "total_tokens": 19
  },
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "This is a test!"
      },
      "finish_reason": "stop",
      "index": 0
    }
  ]
}
```

`curl` outputs some extra information about the HTTP request when we do
this. We'll use the `-s` flag the next time we try this command to silence
this output. Additionally, we'll use `jq` to specify that we're only really
interested in the `"content"` returned from ChatGPT:

```
$ curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{
     "model": "gpt-3.5-turbo",
     "messages": [{"role": "user", "content": "Say this is a test!"}],
     "temperature": 0.7
   }' | jq '.choices | first | .message.content'
"This is a test!"
```

`jq` makes it very easy to work with JSON. In this last command, we use it
to specify that we only want the first element of the `"choices"` array in
the response from ChatGPT. We also specify that we want the `"content"`
property in the `"message"` object.

Finally, let's replace the `echo` command in our `ask.sh` file with that
command:

```bash
#!/usr/bin/env sh
curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{
       "model": "gpt-3.5-turbo",
       "messages": [{"role": "user", "content": "Say this is a test!"}],
       "temperature": 0.7
     }' | jq '.choices | first | .message.content'
```

Now we'll run it:

```
$ ./ask.sh
"This is a test!"
```

### Specifying Our Prompt

In order to pass arguments to a shell script, we need to change the contents
of the file very slightly. To get the first, second, or even third arguments
passed to a shell script as in `./ask.sh one two three`, you'd use the
variables `$1`, `$2`, and `$3` respectively. We'll only allow one argument,
so we'll replace the hard coded message we send to ChatGPT with `$1`:

```bash
#!/usr/bin/env sh
curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "{
       \"model\": \"gpt-3.5-turbo\",
       \"messages\": [{\"role\": \"user\", \"content\": \"$1\"}],
       \"temperature\": 0.7
     }" | jq '.choices | first | .message.content'
```

We change from using single quotes `'` to `"` double quotes. This lets us
use the variable `$1` in the string of text, but it also means we must
"escape" the other double quotes inside of the string. Let's test this out:

```
$ ./ask.sh "How many ounces are in a pound"
"There are 16 ounces in a pound."
```

This is fine, but escaping all of those double quotes is a little
cumbersome. Fortunately, `jq` has the ability to build JSON for us. Update
your `ask.sh` file like so:

```bash focus={3-9,14:7-28,14:35-36}
#!/usr/bin/env sh

OPENAI_API_PAYLOAD=$(echo '{}' |
                     jq --arg openai_api_prompt "$1" \
                    '{
                      "model": "gpt-3.5-turbo",
                      "messages": [{ "role": "user", "content": $openai_api_prompt }],
                      "temperature": 0.5
                    }')

curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$OPENAI_API_PAYLOAD" | jq -r '.choices | first | .message.content'
```

We use `jq` to build our JSON payload that we send to ChatGPT. We use the
`--arg` flag to tell `jq` to replace the variable `openai_api_prompt` with
`$1` in the JSON it creates. We do `echo '{}' |` to feed an empty JSON
object into `jq`. Then, in our `curl` command, we replace the hard-coded and
manually escaped string with the output of the earlier `jq` command.
Finally, we pass the flag `-r` to our final call to `jq`. This lets us
request "raw" output; this way, `jq` will not return the response from
ChatGPT surrounded with double quotes. Let's give this a try:

```
$ ./ask.sh "what is 5x5"
5x5 is equal to 25.
```

### Default Prompt

Let's say it's the user's first time using our script. We want to provide a
helpful usage message for them if they run the script without a prompt. We
can ask ChatGPT to write this message for us by sending the contents of the
script along with a prompt to explain the script's usage:

```bash focus={3-7,10:50-67}
#!/usr/bin/env sh

OPENAI_API_PROMPT="Output a typical Usage help message for the following shell script called ask.sh:\n$(cat "$0")\nBe sure to describe usage of the environment variable OPENAI_API_KEY.\nExamples of Usage provided will not use questions that would reference the contents or usage of this script."
if [ -n "$1" ]
then
  OPENAI_API_PROMPT="$1"
fi

OPENAI_API_PAYLOAD=$(echo '{}' |
                     jq --arg openai_api_prompt "$OPENAI_API_PROMPT" \
                    '{
                      "model": "gpt-3.5-turbo",
                      "messages": [{ "role": "user", "content": $openai_api_prompt }],
                      "temperature": 0.5
                    }')

curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$OPENAI_API_PAYLOAD" | jq -r '.choices | first | .message.content'
```

We start off by building a prompt that we'll send to ChatGPT if a first
argument is not provided when this script is called. In it, we'll specify
that we want it to output the Usage of this script. We then pass the
contents of our script using `cat "$0"`. Just like `$1`, this references the
first (0 indexed) word used to run our script. We also specify that we do
not want examples to contain references to the script itself; if a user
sends "How do I use this script?", ChatGPT won't know since it doesn't have
the contents of the script itself. The output looks something like this:

```
$ ./ask.sh
Usage: ./ask.sh [OPENAI_API_PROMPT]

Description:
This script uses the OpenAI API to generate responses to a given prompt. The prompt can be provided as an optional argument. If not provided, the default prompt will be used.

Environment Variable:
OPENAI_API_KEY - This variable should be set to your OpenAI API key. It is required for this script to function properly.

Examples of Usage:
1. ./ask.sh "What is the meaning of life?"
2. OPENAI_API_KEY=your_api_key ./ask.sh "What is the capital of France?"
3. export OPENAI_API_KEY=your_api_key; ./ask.sh "How do I bake a cake?"
```

The default prompt took some tweaking before it came out right. I found that
ChatGPT would sometimes return mentions of the script itself in the examples
it provided if it was not explicitly told not to do so. ChatGPT also wanted
to explain how to add the contents of the script to a file, turn it into an
executable, then run it (kind of like how I did with this article). I needed
to specify that I was looking for a "typical Usage help message." I also
needed to specifically ask for an explanation of `OPENAI_API_KEY`.
Sometimes, ChatGPT would leave mention of this variable out of its Usage
message entirely.

This fine tuning and tweaking is what's known as "prompt engineering." Over
time, it'll become a skill to refine prompts sent to AI tools such as
ChatGPT. Just like crafting the perfect phrase in your favorite search
engine to get exactly what you need, your ability to refine queries made to
ChatGPT will be a part of future engineer's toolboxes.

### Conclusion

We've learned how to create a shell script, issue http requests to servers
using `curl`, parse and create JSON using `jq`, and, finally, fine tune
prompts made to ChatGPT. I hope you've found this helpful in some way, or at
least enjoyed the journey. Happy coding!

\- ryjo
