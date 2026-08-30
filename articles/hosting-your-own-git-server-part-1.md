title: Hosting Your Own Git Server: Part 1
description: In this article, I describe how to host your own git server on an AWS ec2 instance as well as some cool customizations you can make to fit your organization's needs.
date: 2019-01-27
css: syntax.css
---
### Introduction

This sounds crazy. GitHub, GitLab and a myriad of other hosting services
exist just so you don't have to do this. In fact, they provide a really nice
interface over top of your repos. They render your `README`s with some
stylish CSS. The give you pull request, issue tracker and wiki features
built in. Repository forking is a pretty amazing feature, too. Oh, and don't
forget about the social aspect.

All of these things are really attractive, and they lend a lot of
convenience to the software development process.

You and I? We're explorers. We do things that are difficult just to say we
did. In doing these difficult things, we learn. While we may find that this
is not the best way to go about doing things, we may learn some things that
help us in our day-to-day that we may not have known otherwise.

Before we get started, I published [a repository on
GitHub](https://github.com/mrryanjohnston/ryjo-git) containing scripts based
on this article. Give that a look if you'd like to skip to the end.

Alright. Let's do this.

### Prerequisite

Actually, one more thing: in this article, I chose to leverage [Amazon
AWS](https://aws.amazon.com/) ec2 infrastructure to host a virtual machine
that will run my git server. I think this accurately reflects many modern
day tech companies' infrastructures, so it's a valuable tool to learn.

However, there are many options available to us, and I would be remiss to
limit the reader to one non-free route. In this article, I provide several
options, including:

1. [A git "server" running on your local computer](#local)
2. [A separate machine running Ubuntu on your local network](#server)
3. [A virtual machine running on your local computer](#virtual)
4. [Amazon AWS](#aws)

Once you've completed one of the above four sections, feel free to skip
ahead to the [non-implementation-specific section of this
article](#readygo).

### From Scratch, As Usual {#local}

Let's start with nothing. This section details how you can use your local
machine to host your repositories. You'll need to use your imagination in
some places, but pretend that `127.0.0.1` is a different machine and you'll
be good to go.

I'll assume your local machine is running Ubuntu. If you're not, just keep
in mind that you may have to change something slightly if it doesn't work
for you. I anticipate most unix-like environments should function similarly.

The rest of the guide assumes the git server is only accessible via an ssh
connection. In order to get this working locally, you'll just need to
install [Openssh
Server](https://help.ubuntu.com/lts/serverguide/openssh-server.html)
locally. You should follow that guide as it is the official Ubuntu
documentation, but here's what I did to get a local ssh server running:

```bash
sudo apt install openssh-server
printf "PasswordAuthentication no\nPubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd.service
```

The first line installs `openssh-server` which is what will run in the
background and accept ssh connections from clients. In the second line, we
edit the `/etc/ssh/sshd_config` by adding configuration options to the end
of the file. These configuration options tell the ssh server to not accept
the regular user's password as a means of authentication
(`PasswordAuthentication no`) in preference to using a generated ssh public
key instead (`PubkeyAuthentication yes`). `printf` simply prints these lines
to `STDOUT` so that we can pipe (`|`) the text to the `tee` command. We use
`printf` instead of `echo` so that we can specify a newline with `\n`.
`tee -a` appends these two configuration options to the
`/etc/ssh/sshd_config` file. We'll discuss the `tee` command more later in
this article.

Now that we've set up our "server," we'll set up our "client." Assuming our
local user's username is `ryjo`, we'll do the following:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ryjo
cat ~/.ssh/ryjo.pub | tee -a ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat >> ~/.ssh/config << CONFIG 
Host gitservadmin
    Hostname 127.0.0.1
    IdentityFile ~/.ssh/ryjo
    IdentitiesOnly yes
CONFIG
ssh gitservadmin
```

First, we generate an ssh key pair and save it to `~/.ssh/ryjo`. This means
we now have both a `~/.ssh/ryjo` and a `~/.ssh/ryjo.pub` file. We then use
`cat` to pipe the contents of the `pub` file to `~/.ssh/authorized_keys`.
This is a special file that our openssh-server process uses to authenticate
users attempting to log in with their key pair. We need to `chmod` this file
so that only the user who owns the file can read or write it. This is
required by the openssh-server process.

The next line is a convenience; instead of writing `ssh 127.0.0.1` every
time, it might be easier to remember the string `gitservadmin` so that we
can log in as `ssh gitservadmin`. We'll see this
`cat &gt;&gt; ~/.ssh/config &lt;&lt; CONFIG` syntax again later, but
basically it means "output the text surrounded by the two `CONFIG`s into the
`~/.ssh/config` file."

That last `ssh gitservadmin` should give you a login prompt. I assume your
current user has `sudo` privileges on your machine. Once that's done, feel
free to continue on to the [non-implementation-specific section of this
article](#readygo).

### A Separate, Dedicated Machine {#server}

If you've got a dedicated machine sitting in the corner of the room
somewhere that's on your local network, you can follow the [steps
above](#local) replacing `127.0.0.1` with that machine's IP address. You can
find that machine's IP address by doing the following:

```bash
ip -4 address
```

This will display all of the network interfaces connected to that machine.
Find the line that starts with `inet`. This is the ip address on that
interface. The one that's connected to your local network will probably look
something like `192.168.xxx.xxx` since this is how a lot of home routers set
up their networks.

Once that's done, feel free to continue on to the
[non-implementation-specific section of this article](#readygo).

### A Locally Running Virtual Machine {#virtual}

If you don't want to install an ssh server on your local machine and you
don't have a separate dedicated machine, you can use software like
[VirtualBox](https://www.virtualbox.org/) to [run a virtual server on your
local machine](https://askubuntu.com/a/153098/23727).

If you do decide to do this, the important step will be to get the hosted
virtual server on the same network as your local machine. To do this, go to
the settings for your installed virtual machine, then go to the "Network"
section on the left hand side. Set the network adapter "Attached to:" to
"Bridged Adapter." From here, you should be able to start your server as you
normally would and follow the [steps above](#server). Once that's done, feel
free to continue on to the [non-implementation-specific](#readygo) section
of this article.

### AWS-specific Setup {#aws}

All of the above steps so far have been free of cost. Using AWS costs money
unless it's your first time [registering an AWS
account](https://aws.amazon.com/). If this is the case, [there is a free
tier you can use](https://aws.amazon.com/free/). I'll create a virtual
machine (called ec2 instances) that is a `t2.micro` instance. The Free Tier,
as of the date of this article, "includes 750 hours of Linux and Windows
t2.micro instances each month for one year."

You'll also need to
[install](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
and
[configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
the AWS CLI. This will let us manage our AWS resources via the command line.
Sweet!

We'll follow the steps described in Amazon's [official
documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-services-ec2-instances.html).
First, we'll create a key pair. This will be used to ssh into the instance
as the user "ubuntu":

```bash
aws ec2 create-key-pair \
  --key-name ssh-ubuntu-user \
  --query 'KeyMaterial' \
  --output text \
  > ~/.aws/ssh-ubuntu-user.pem
chmod 400 ~/.aws/ssh-ubuntu-user.pem
```

Note that this process does not allow you to create a password to help
protect this key file. [Give this a
read](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws)
to learn how you can generate a key locally (with a password if you wish)
and push it up to AWS instead.

Now we'll create a security group that will let us open port 22 on the
server. This will be how we push to and pull from the server. When we run
this command, we'll get back a JSON response. We can use the program
`[jq](https://stedolan.github.io/jq/)` to parse the response and
only save the security group's ID:

```bash
aws ec2 create-security-group \
  --group-name ssh-server \
  --description "SSH Server" |
  jq ".GroupId" -r
```

I'll use `sg-0000000000` to denote the output of this command.

Now that we've created a security group, we must add an "ingress rule." This
basically means machines with this security group will allow access on a
given ip address and port pair. In our case, we want users in our
organization to ssh into this machine in order to push/pull from the
repository, so we'll need to open port 22 as a tcp port:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-000000000 \
  --cidr 127.0.0.1/24 \
  --port 22 \
  --protocol tcp
```

As an example, I used `127.0.0.1`. In practice you would use your IP
address. You can find this in many ways, one of which is simply asking
another site what they see our IP address as. Use your favorite search
engine to search for "What is my IP address," and you should be rewarded.

One final thing we need to find out is the image ID of the AMI that we want
to use. Using the command described in [Amazon's AWS
Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html),
let's look for the latest release of Ubuntu:

```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters 'Name=name,
    Values=ubuntu/images/hvm-ssd/ubuntu-cosmic-18.10-amd64-server*' |
  jq '.Images | sort_by(.CreationDate) | last(.[]) | .ImageId' -r
```

In my case, the output of this was `ami-05b0fe5b9e7b8b5d7`.

Alright, we've got our image id, security group id as well as our key pair.
The next step that we'll do is "run" an instance:

```bash
aws ec2 run-instances \
  --image-id ami-05b0fe5b9e7b8b5d7 \
  --count 1 \
  --instance-type t2.micro \
  --key-name ssh-ubuntu-user \
  --security-group-ids sg-000000000 |
  jq '.Instances | first(.[]).InstanceId' -r
```

This command will output an instance id (which we'll denote as
`i-00000000000000000`). With this, we'll be able to find the public ip
address of our machine once it's running:

```bash
aws ec2 describe-instances --filter 'Name=instance-id,Values=i-00000000000000000,Name=instance-state-name,Values=running' |
  jq '.Reservations[].Instances | first(.[]).PublicIpAddress' -r
```

I'll use `0.0.0.0` to denote the output of this command.

It may take a few minutes for your ec2 instance to come up, so have
patience!

Now that we know the IP address we'll use to access our git server, we have
everything we need to access it:

```bash
ssh -i ~/.aws/ssh-ubuntu-user.pem ubuntu@0.0.0.0 "whoami"
```

I'll use `0.0.0.0` to stand in place of my server's IP address.
Additionally, we use the `-i` (`--identity-file`) to specify which key pair
we'll use to ssh into the server. The `"whoami"` at the end of that line
will send a single command to be run on that machine, return the results to
your terminal and then kill the connection. This is super helpful for
scripts; no need to write complicated login/logout functionality.

For example, you may wish to get the latest version of all packages before
you do anything else on that ec2 instance:

```bash
ssh -i ~/.aws/ssh-ubuntu-user.pem ubuntu@0.0.0.0 "sudo apt update; sudo apt upgrade"
```

The last thing we'll do is configure our local system so that we don't have
to re-type the username, key and IP address every time we want to send a
command to the git server. On your local machine, make your `~/.ssh/config`
file look like:

```sshconfig
Host gitservadmin
    Hostname 0.0.0.0
    IdentityFile ~/.aws/ssh-ubuntu-user.pem
    IdentitiesOnly yes
    User ubuntu
```

Now we should be able to send commands to the server like so:

```bash
ssh gitservadmin "whoami"
```

### Uh... So... You Said Something About git? {#readygo}

Check to see if `git` is already available:

```bash
ssh gitservadmin "git --version"
```

If not, you'll need to install it:

```bash
ssh gitservadmin "sudo apt install git-core"
```

I've read a few articles that recommend creating a single `git` user on the
server hosting the repos. We would then simply add each user's public key to
the
`[/home/git/.ssh/authorized_keys](https://www.ssh.com/ssh/authorized_keys/)`
file. Then, all users would pull/push code as the `git` user.

This is fine, but it prevents us from making use of the underlying
user/group-based permissions in unix-like operating systems. If we instead
create a new user account using `useradd` for every single user, we could
restrict repository permissions on a per-user or per-group basis. Nice.

By default, we'll want all git users of our system to be able to access all
repositories. Over time, we'll discover how we need to limit certain groups
of users to only a select group of repos. With this in mind, let's create a
group for our git users:

```bash
ssh gitservadmin "sudo groupadd git"
```

Well... that was easy. Now let's create our first user:

```bash
ssh gitservadmin \
  "sudo useradd -m -s /usr/bin/git-shell -G git ryjo"
```

By default, `useradd` creates the user with their password disabled. This is
great news for us; this user will only ever login via `ssh`, so we don't
need to create a temporary/throw-away password. `-m` (`--create-home`) is
specified in order to create a directory in `/home` for the new user.
Additionally, we use the `-G` (`--groups`) flag to specify that this user
should also be in the `git` group.

We also use the `-s` (`--shell`) option to specify the user's default shell
as something other than `bash`. `git` provides `git-shell`, a shell that
only allows git commands to be executed by the user. It also disables the
interactive shell by default; we won't be able to login to this server and
get an interactive shell as this user until we add some custom commands.
More on this later.

We'll need to enable this shell system-wide by adding it to the end of the
`/etc/shells` file [like
so](https://explainshell.com/explain?cmd=echo+%2Fusr%2Fbin%2Fgit-shell+%7C+sudo+tee+-a+%2Fetc%2Fshells):

```bash
ssh gitservadmin \
  "echo /usr/bin/git-shell | sudo tee -a /etc/shells"
```

`tee` is a pretty nifty command; it let's us use `echo` with non-sudo
privileges, only using heightened privileges to append the text we `echo`
into a file. If we left off the `-a` (`--append`) option, we'd just
wholesale overwrite `/etc/shells`.

Finally, we'll need to add the user's public key to the
`/home/ryjo/.ssh/authorized_keys` file on the git server so that we can
login using `ssh`. First, we'll create `/home/ryjo/.ssh` on the git server
with the proper permissions. We could use `mkdir`, `chown` and `chmod`, but
`install` let's us do all of these in [a single
command](https://explainshell.com/explain?cmd=sudo+install+-d+-m+0700+-o+ryjo+-g+ryjo+%2Fhome%2Fryjo%2F.ssh):

```bash
ssh gitservadmin \
  "sudo install -d -m 0700 -o ryjo -g ryjo /home/ryjo/.ssh"
```

Next, we'll create an SSH key pair locally:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ryjo_rsa
```

I decided to use `-f` to specify the filename for the key pair. I followed
the recommended `-t` and `-b` flags as specified in [GitHub's
tutorial](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/).
Now, we'll put the public key in the `/home/ryjo/.ssh/authorized_keys` file
on the git server:

```bash
ssh gitservadmin \
  "echo $(cat ~/.ssh/ryjo_rsa.pub) |
    sudo -u ryjo tee /home/ryjo/.ssh/authorized_keys"
```

[That
command](https://explainshell.com/explain?cmd=echo+%24%28cat+%2Fhome%2Fryjo%2F.ssh%2Ffoo.pub%29+%7C+++++sudo+tee+%2Fhome%2Fryjo%2F.ssh%2Fauthorized_keys)
might look a little funky. The stuff surrounded in `$()` is executed on our
local machine. This way, we get the contents of the public key on the local
machine with `cat`, then `echo` it on the server. We also see our old friend
`tee` being used to put the contents of our ssh public key into the user on
the server's `authorized_keys` file.

Finally, we'll change the permissions for `/home/ryjo/.ssh/authorized_keys`
on the git server:

```bash
ssh gitservadmin \
  "sudo -u ryjo chmod 600 /home/ryjo/.ssh/authorized_keys"
```

We use `-u` (`--user`) to specify which user to run chmod as.

If we try to do `ssh -i ~/.ssh/ryjo_rsa ryjo@gitservadmin`, we'll see a ton
of text that ends with: `fatal: Interactive git shell is not enabled`. Since
we made this user's shell `/usr/bin/git-shell`, this is exactly what we
expect. So far so good.

It'll be nice if we no longer have to reference our git server via
`gitservadmin` or specify our `ryjo` user's key. We can add a second entry
to our local `~/.ssh/config` file:

```sshconfig
Host gitserv
    Hostname 0.0.0.0
    IdentityFile ~/.ssh/ryjo_rsa
    IdentitiesOnly yes
    User ryjo
```

Now in addition to `ssh gitservadmin` we can do `ssh gitserv`. Bonus: if
your local user's name is `ryjo` as well, you can remove the `User ryjo`
line. Sweet.

### Can It Be git Time Now, Please?

We're almost at a point where we can create an empty git repository and
push/pull code to/from it. First, we need to create a directory where we
will store all of the repositories. The question: "where, though?"

The [Pro Git book recommends
`/srv`](https://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server).
`/srv`, according to the [Linux Filesystem
Hierarchy](https://www.tldp.org/LDP/Linux-Filesystem-Hierarchy/html/srv.html),
is meant to hold "data served by the system." I think this is intentionally
vague, but sounds good enough to me! Let's create a directory that will hold
all of our repos:

```bash
ssh gitservadmin \
  "sudo install -d -o ubuntu -g git -m 0770 /srv/git"
```

We set this to `0770` because we want users in the `git` group to be able to
create repositories eventually. For now, we'll rely upon the `ubuntu` user
to create a repo that we can push code to as our new user:

```bash
ssh gitservadmin \
  "sudo install -d -o ryjo -g git -m 0770 /srv/git/foo.git;
   git init --bare --shared /srv/git/foo.git;
   sudo chgrp -R git /srv/git/foo.git"
```

Using `--bare` initializes a new git repository without any checked out
source code files. Basically, it only contains the things that would
normally be in then `.git` directory. Using `--shared` specifies that the
repo will be shared amongst several users. Since we want all of our users in
the `git` group to push/pull to this directory, this sounds like what we
want. Finally, we need to change the group with `chgrp` for all files and
directories within this new directory to `git`.

We should now be able to push a local repository to this remote host. On our
local machine, we'll do:

```bash
mkdir ~/foo
cd ~/foo
git init
echo "# Foo" > README.md
git add .
git commit -m "Initial commit"
git remote add origin gitserv:/srv/git/foo.git
git push -u origin --all
```

Woosh! Just like that, our new git repository is up and running!

### Power to the Developers

Asking the user with access to the `ubuntu` user to create a repo for us
every time would get really annoying. Let's make something that'll let our
developers create repositories on their own. Using `git-shell`, we can
create a directory in a user's home directory that can host other commands
outside of the restricted capabilities of `git-shell`. We'll add a command
`addrepo` that our user `ryjo` and anyone else in the `git` group can use to
create a repository.

This can easily be done by creating a directory `git-shell-commands` in a
user's home directory. Every user can have a list of their own unique
commands if that makes sense for your organization.

Right now, I can't think of a great reason to do this. It's more of an
inconvenience to me that we can't just specify a single group of commands
for every user of this system.

Well, technically, we can. Using
[`/etc/skel`](http://www.tldp.org/LDP/Linux-Filesystem-Hierarchy/html/etc.html),
we can create a directory holding all of our commands that gets copied to
every new user's home directory. This is great if we never update our
existing commands or add new ones. Likely, though, these things will
eventually happen. For this reason, we can create a symlink to a directory
in our system that will hold all of our commands. This way, when one command
updates or we add a new one, every user will have these new capabilities
with no manual work on our part. Woo!

In [my last
article](turning-your-application-into-an-installable-package.html), we
discussed storing files like these commands in `/usr/lib`. This is where we
installed our rails application library files when we were installing our
app as a package. In this case, we're creating these commands locally; we're
not installing these commands via a pre-packaged `deb` file, so we'll store
them in `/usr/local/lib`:

```bash
ssh gitservadmin \
  "sudo install -d -m 0750 -o ubuntu -g git /usr/local/lib/git"
```

Perhaps this isn't the best location. I considered `/usr/local/bin`, but our
users won't be able to run these commands if we store them here since
they're using `git-shell`. Besides, we want to group all of our commands
together so we can symlink to them. For now, they remain in
`/usr/local/lib/git`.

The permissions are `0750` so that the users in the `git` group can read and
execute them. This is required by `git-shell`.

Let's add a symlink to this directory in `/etc/skel`:

```bash
ssh gitservadmin \
  "sudo ln -s /usr/local/lib/git /etc/skel/git-shell-commands"
```

Now, every *new* user we add will have this symlink in their home directory.
We need to manually add this for our existing `ryjo` user. We'll use
`sudo -u ryjo` to create the symlink as the user `ryjo` in order to get the
correct permissions on the file:

```bash
ssh gitservadmin \
  "sudo -u ryjo ln -s /usr/local/lib/git /home/ryjo/git-shell-commands"
```

Finally, we'll make the command itself. This involves a little bit of funky
bash syntax:

```bash
ssh gitservadmin \
  'cat > /usr/local/lib/git/addrepo << "BASH"
#!/bin/bash
reponame=$(echo "$1" | tr -cd a-zA-Z0-9\-\_)
install -d -m 0770 -g git "/srv/git/$reponame.git";
git init --bare --shared "/srv/git/$reponame.git";
chgrp -R git "/srv/git/$reponame.git"
BASH'
```

`cat &gt; /usr/local/lib/git/addrepo &lt;&lt; &quot;BASH&quot;` basically
says "Redirect the output of running `cat` on the
[heredoc](https://en.wikipedia.org/wiki/Here_document#Unix_shells) delimited
by the word `BASH` into `/usr/local/lib/git/addrepo`." A heredoc is
basically a big block of text. We choose to delimit the beginning and end of
our heredoc with the word `BASH`, but it could be any text that we want.

We also wrap the first `BASH` in double quotes. This allows us to write
those `$1`s without the script attempting to insert the value for that
variable from our local machine. We could also skip the double quotes and
instead do `\$1`, but I like that this way displays exactly what will be put
into the file.

One more mention for the `tr` command. That thing lets us say "delete all
characters that aren't `a` to `z`, `A` to `Z`, `0` to `9`, `-` or `_`." This
may not be necessary, but it makes me feel better to limit these names to
characters that I'd normally use for directory names. Besides, I like the
idea of keeping our repo names looking (subjectively) tidy. `tr` is a nifty
little tool. I highly recommend giving `man tr` a read.

We'll now set the proper permissions on this new file:

```bash
ssh gitservadmin \
  "sudo chgrp git /usr/local/lib/git/addrepo;
   sudo chmod 0750 /usr/local/lib/git/addrepo"
```

Remember when we couldn't login to the git server as our user `ryjo`? Well
now that we've added the `git-shell-commands` directory to our user's home
directory, that's no longer true. We'll get an interactive shell after
running `ssh gitserv` that will look like `git&gt;`, and the only command
available to us is `addrepo`.

Let's take [the repository](https://github.com/mrryanjohnston/rails_new) we
worked with from [my last
article](turning-your-application-into-an-installable-package.html) and put
it on the new `gitserv` we have now. First, we'll make the empty git repo on
gitserv just like we did for the `foo` repository, but this time, we'll use
`addrepo`:

```bash
ssh gitserv
# Very long MOTD shows,
# followed by a git> prompt
addrepo rails_new
```

We then logout by either typing `exit` or pressing the `ctrl` and `d` keys.
We could also run single commands like we've been doing with the `ubuntu`
user:

```bash
ssh gitserv "addrepo rails_new"
```

Now we have a new git directory initialized at `/srv/git/rails_new.git`:

```bash
ssh gitservadmin "sudo ls -la /srv/git/rails_new.git"
```

We needed to use `sudo` here; this directory is owned by `ryjo` and has a
group of `git`. Since our `ubuntu` user falls under "others" and our
`rails_new.git` permissions are `770`, we have no rights to run `ls` on this
directory as this user.

Finally, we'll clone the repo from GitHub, add our git server as a new
remote and push:

```bash
git clone git@github.com:mrryanjohnston/rails_new.git
git remote add gitserv gitserv:/srv/git/rails_new.git
git push -u gitserv --all
```

Now we can push to our git server by doing `git push gitserv`, and we can
still `git push origin` to push code updates to GitHub. Side note: this
gives us a little more info about how GitHub saves repositories; there's a
very good chance that repos are stored in the `git` user's home directory.
For example, the above repository could be at
`/home/git/mrryanjohnston/rails_new.git`. Of course this could be way wrong,
but it's fun to think about.

### Stay Tuned!

We covered a lot of ground in this article, and we're only scratching the
surface. I think it's safe to say that it'll be a little cumbersome to
manually do all of this work from scratch, so I put together some scripts
based on this article and published [a repository on
GitHub](https://github.com/mrryanjohnston/ryjo-git) (gasp! GitHub?!) as well
as [a release with pre-built `deb`
binaries](https://github.com/mrryanjohnston/ryjo-git/releases/tag/0.0.1) to
make it much easier to create an ec2 instance and install the scripts we
discussed.

I'm already planning on publishing parts 2 and 3 of this article as I have a
few more ideas surrounding this topic. For now, this should be plenty to
help get your own ideas forming for what you'd want to see in your own git
server.

\- ryjo
