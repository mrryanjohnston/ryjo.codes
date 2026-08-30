title: Turning Your Application into an Installable Package
description: In this article, I discuss using the built-in package manager of your operating system to distribute your application.
date: 2018-12-13
css: syntax.css
---
### Introduction

There's a ton of cool ways out there to deploy your modern web application
to production.
[dpkg](https://www.debian.org/doc/manuals/debian-faq/ch-pkgtools.en.html#s-dpkg),
the software used to build and install packages for Debian-based GNU/Linux
distributions, is not one I've had the pleasure of directly working with in
a professional capacity. [It's been around since
1994](https://www.debian.org/doc/manuals/project-history/ch-detailed.en.html),
so it's had some time to mature and grow into a very useful tool. A
companion suite of scripts called
[debhelper](http://joeyh.name/blog/entry/ten_years_of_free_software_--_part_5_debhelper/)
that [popped up in
1997](https://lists.debian.org/debian-devel/1997/09/msg00901.html) really
makes the process of creating installable binaries a cinch. Best of all, it
comes right out of the box with Debian-based Operating Systems, Ubuntu
included. This makes my brain happy.

I also really like the idea of installing my application just like any other
part of my machine's software ecosystem. Other approaches tend to make me
feel like my app is something that needs to be quarantined.

In this article, we'll start with the very basics, then work our way up to
building a Rails application as a `.deb` file. I pushed up [a
repository](https://github.com/mrryanjohnston/rails_new) following the steps
outlined for the Rails portion of things if you'd like to skip ahead.

### Operating Systems, Packages and Source Code, Oh My!

`dpkg` installs software packaged in `.deb` files. If you go to a website
and download a `.deb` file, there's nothing stopping you from installing
that piece of software if you have root/sudo access.

These `.deb` files contain the application itself (sort of like a `tar`
file) as well as instructions for installing that application on your
computer. The `.deb` file's responsibilities include (but are not limited
to):

1. copying files stored in the `.deb` file to directories on your machine
2. creating symlinks relevant to your application
3. adding users to your system
4. installing daemons that run in the background and on startup
5. installing cronjobs

This is quite convenient. Not only can you bundle up all of your code in a
single file that can be easily sent to another machine, you can also ship
all of the instructions necessary to get your application running. You get
this for free just by virtue of running your operating system.

### The Minimum Requirements

Let's start with nothing. Create a directory that would hold your
application. If you want to follow along step-by-step, do
`mkdir -p foo/{DEBIAN,usr/bin}`. Inside of the `foo/DEBIAN` directory,
create a file named `control`. At a minimum, it should look something like
this:

```debcontrol
Package: foo
Description: FOO!
Version: 0.0.0
Maintainer: Ryan Johnston
Architecture: all
```

You can read more details about what these things do in the [Debian
Docs](https://www.debian.org/doc/debian-policy/ch-controlfields.html). Now
create a file `foo/DEBIAN/compat` that simply looks like this:

```
10
```

Once you have this file, create your deb by running `dpkg-deb --build foo`
in the parent directory of `foo`. This will create a `foo.deb` file in your
current directory. You can then install this by doing
`sudo dpkg -i foo.deb`. You can remove this package by doing
`sudo dpkg -r foo`. It's that easy.

### Lame. Let's Do Something Cool

Ok, so we can install that package, but it doesn't actually do anything...
yet. Let's create a file that we'll install. Put the following into
`foo/usr/bin/foo.sh`:

```bash
#!/bin/bash
echo "YO"
```

Make this file executable with `chmod +x foo/usr/bin/foo.sh`. When we
install this, `foo.sh` will automatically get dumped into your system's
`/usr/bin` directory.

Now build again with `dpkg-deb --build foo`. You can then just re-install
this package by doing `sudo dpkg -i foo.deb`. You should be able to run
`foo.sh` from anywhere now. That's because by mirroring your system's
directory structure in our app's directory, the `.deb` file knew to put the
executable in `/usr/bin` which is available in your `$PATH`.

### Ew... So I Have To Change My App's Directory Structure?

This isn't bad if your project's file structure directly mimics how it will
be installed on your system. Usually I want to leave my app's directory
structure as is for my development environments and just specify where each
of the files should be installed.

You may notice we named the directory `DEBIAN` with all capital letters.
Generally, [it's recommended not to do
this](https://lists.debian.org/debian-dpkg/2001/08/msg00048.html). Naming
the directory `debian` instead will allow us to specify where each
individual file is supposed to be installed on the production environment
without changing our development environment's directory structure.

Rename the directory `foo/DEBIAN` (all capitals) to `foo/debian`. Now move
`foo/usr/bin/foo.sh` into `foo/foo.sh`. Put the following in a file named
`foo/debian/install`:

```
foo.sh usr/bin
```

Change your `foo/debian/control` file so that it looks something like this:

```debcontrol
Source: foo
Standards-Version: 4.0.0
Maintainer: Ryan Johnston

Package: foo
Architecture: all
Description: FOO!
```

Make a file named `foo/debian/rules` that looks like this:

```make
#!/usr/bin/make -f
# -*- makefile -*-

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

%:
	dh $@
```

Note that it must be an actual `tab` (not spaces!) before `dh`. Make it
executable with `chmod +x foo/debian/rules`.

Finally, we also need to make a file named `foo/debian/changefile`. One can
be generated easily enough by doing `dch --create`. Your
`foo/debian/changefile` should look something like this:

```debchangelog
foo (0.0.0) UNRELEASED; urgency=medium

  * Initial release.

 -- ryjo   Mon, 10 Dec 2018 20:01:33 -0500
```

The build commands are a little different than before. Navigate *inside* of
your `foo` directory and run `debuild
[--no-tgz-check](https://explainshell.com/explain?cmd=debuild+--no-tgz-check)`.
This creates a file in `foo`'s parent directory called `foo_0.0.0_all.deb`,
as well as one or two other files. You can install this package using our
familiar `sudo dpkg -i foo_0.0.0_all.deb`.

You'll see lots of warnings in the console after you run
`debuild --no-tgz-check`, but it shouldn't stop it from building. Feel free
to look them up and tweak your files here and there to make the warnings go
away.

The first time you run `dpkg -i` with a `.deb` file, you'll "install" it.
For all subsequent times, you'll "upgrade" it. It may be wise to first
"remove" the package or even "purge" it with `dpkg -r` or `dpkg -P`
respectively if you ever find yourself in an odd state. This way, you'll be
"installing" the package fresh every time.

### Turn. It. Up.

I've worked quite a bit with Rails, so I'll use this framework to try
building an application that's a bit more complicated. I build a new rails
app by running `rails new rails_new`. I know that running this app can be
accomplished by running `rails server`. Easy.

In my opinion, it makes sense to already have `ruby`, `bundler` and `node`
installed system-wide (executable by all users of the system) on the server
I will deploy my application to. I can make them dependencies of my package
by creating a `rails_new/debian/control` file that looks like this:

```debcontrol
Source: rails-new
Standards-Version: 4.0.0
Maintainer: Ryan Johnston

Package: rails-new
Architecture: all
Depends: ${misc:Depends}, ruby, bundler, nodejs, zlib1g-dev, libsqlite3-dev
Description: New Rails Project
```

`Depends` is optionally used to prevent installation if those packages are
not installed and tracked by `dpkg`. I added the `${misc:Depends}` part to
remove a warning message during build. `zlib1g-dev` and `libsqlite3-dev` are
needed for the `nokogiri` and `sqlite3` gems respectively.

Create a `rails_new/debian/changelog` file either manually or with
`dch --create` that looks something like:

```debchangelog
rails-new (0.0.0) UNRELEASED; urgency=medium

  * Initial release.

 -- ryjo   Mon, 10 Dec 2018 20:01:33 -0500
```

...a filed named `rails_new/debian/compat` that looks like:

```
10
```

...as well as a `rails_new/debian/rules` file that looks like this:

```make
#!/usr/bin/make -f
# -*- makefile -*-

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

%:
	dh $@
```

Make that file executable by running `chmod +x rails_new/debian/rules`.

You should now be able to run `debuild --no-tgz-check` followed by a
`sudo dpkg -i rails-new_0.0.0_all.deb`. Of course, this doesn't actually do
anything yet.

### What's Up With Those Rules?

The `debian/rules` file has some very powerful capabilities. Among other
things, it lets us override what happens during certain steps of the build
process.

One of the steps `debhelper` runs is called `dh_auto_test`. This
automatically attempts to detect and run our testing suite. It doesn't have
the capability to detect a Rails suite automatically, so we'll specify
exactly what needs to happen. Update the `rails_new/debian/rules` file so
that it looks like this:

```make
#!/usr/bin/make -f
# -*- makefile -*-

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

%:
	dh $@
override_dh_auto_test:
	bin/rails test
```

This will run our test suite before we build our package and cancel the
build if it fails. Afterall, we wouldn't want to deploy a binary built upon
source code with failing tests now would we?

We'll create a very trivial and uninteresting test just to showcase this
capability. Create a file `rails_new/test/foo_test.rb` that looks like this:

```ruby
require "test_helper"

class FooTest < ActionDispatch::IntegrationTest
  test "foo!" do
    assert true
  end
end
```

Right now, our test suite will always suceed when we run
`debuild --no-tgz-check` since our one and only test does `assert true`.
This means that it'll exit with code `0`, and the build will continue past
this step. If we change this to `assert false`, the testing suite will fail,
exiting with code `1`. This causes the entire build process to fail. This
effectively prevents us from building a `.deb` file with code that fails our
testing suite. Very nice!

There are lots of steps during the build process that we can `override_*`.
Take a look at the [dh source
code](https://github.com/Debian/debhelper/blob/master/dh) comments for some
really nice examples.

### Understanding the Filesystem

The directories in a unix-like filesystem are meant to store different types
of files. For example, `/usr` is meant to store programs installed by the
user. [The Linux Documentation Project](http://www.tldp.org/) has excellent
write-ups about the Filesystem Hierarchy. [This
one](http://www.tldp.org/LDP/Linux-Filesystem-Hierarchy/html/usr.html) and
[this one](http://www.tldp.org/LDP/sag/html/usr-fs.html) are great starting
points. They basically say that user programs go here. Specifically, this is
where we'll put the files that should not change while our application is
running. A few of these in Rails are `app`, `config` and `lib`.

In order to split up where my files will go, we will use the
`rails_new/debian/install` file:

```
app usr/lib/rails-new
bin/rails-production usr/bin
config usr/lib/rails-new
config.ru usr/lib/rails-new
Gemfile* usr/lib/rails-new
lib usr/lib/rails-new
package.json usr/lib/rails-new
public usr/lib/rails-new
Rakefile usr/lib/rails-new
```

You'll notice that we install a file called `rails-production`. This binary
will live in `/usr/bin` while the rest of the rails app will live in
`/usr/lib`. The normal `rails` executable that comes out of the box with
rails uses relative paths. Luckily this file isn't too large, so it's easy
to change to suit our needs. Create a `rails_new/bin/rails-production` file
that looks like this:

```ruby
#!/usr/bin/env ruby
APP_PATH = File.expand_path('/usr/lib/rails-new/config/application', __dir__)
require_relative '/usr/lib/rails-new/config/boot'
require 'rails/commands'
```

Make it executable with `chmod +x rails_new/bin/rails-production`.

You'll also notice we left out a few directories: `tmp`, `log` and `db`
(which will hold our sqlite database files). All of these directories will
be written to during execution of the application. According to the [Linux
Filesystem
Hierarchy](http://www.tldp.org/LDP/Linux-Filesystem-Hierarchy/html/var.html),
`/var` is where files that are written to during the execution of your
program should go.

This presents a bit of a problem: it's difficult to configure in Rails where
these other directories are located. For example, there is no configuration
option to tell it where the `tmp` directory should go; it just assumes it'll
be located at the root of your app.

We'll just create some symlinks. Luckily, we can easily do this by creating
a `rails_new/debian/links` file that looks like this:

```
var/lib/rails-new/db usr/lib/rails-new/db
var/lib/rails-new/tmp usr/lib/rails-new/tmp
var/log/rails-new usr/lib/rails-new/log
```

This will create symlinks inside of `/usr/lib/rails-new` that link to
directories in `/var/{lib,log}/rails-new`. Of course, we'll need to create
those directories. `dirs` to the rescue! Create a file
`rails_new/debian/dirs` with the following in it:

```
var/lib/rails-new/db
var/lib/rails-new/tmp
var/log/rails-new
```

### Scheduling Tasks

Now that we've set up our log directory, let's make use of it. We'll create
a rake task that logs text to our environment's log file in
`/var/log/rails-new`. We'll schedule it to run every minute with `cron`.

Create a file named `rails_new/lib/tasks/foo.rake` that looks like this:

```ruby
desc "Log 'foo!'"
task :foo do
  Rails.logger = ActiveSupport::Logger.new(Rails.root.join('log', "#{Rails.env}.log"))
  Rails.logger.info 'foo!'
end
```

We can install this as a cron job in a file named `/etc/cron.d/rails-new` by
creating a file `rails_new/debian/rails-new.cron.d` that looks like this:

```crontab
* * * * * rails-new cd /usr/lib/rails-new; /usr/bin/rails-production foo
```

### The Time Has Come To... Daemonize!

We'll want to run our application as a daemon. This gives us a pretty
powerful toolset through `systemd`. We'll be able to run things like
`sudo systemctl restart rails-new.service` to restart the process.
Similarly, `start`, `stop` and `status` will also be available for our use.
This is as easy as creating a `rails_new/debian/rails-new.service` file with
the following contents:

```systemd
[Unit]
Description=A new Rails Service
After=network.target

[Service]
User=rails-new
ExecStart=/usr/bin/rails-production server
ExecStop=/bin/kill -9 $(cat /var/lib/rails-new/tmp/pids/server.pid)

[Install]
WantedBy=multi-user.target
```

By default, our daemon will be enabled and running after we install this
package.

### Huh? rails-new Who?

You may notice we told the cron job and service to run as the user
`rails-new`. It's generally considered good practice to run daemons as a
non-root user. We'll also run all of our cronjobs as the user that runs our
server. Unfortunately, there's not a dedicated file like with `dirs` or
`links` that will let us create a user or set permissions on installed files
or directories.

We'll have to create a "maintainer script." These scripts are used when
tasks fall outside of the normal flow of available `dh_*` scripts. Create a
`rails_new/debian/postinst` file that looks like this:

```bash
#!/bin/bash

set -e

case "$1" in
  configure)
    adduser --disabled-password --quiet --system \
      --home /var/run/rails-new --no-create-home \
      --gecos "Rails New daemon" --group rails-new
    chown rails-new:rails-new \
      /var/lib/rails-new/db \
      /var/lib/rails-new/tmp \
      /var/log/rails-new
    cd /usr/lib/rails-new && bundle install --deployment
  ;;
  abort-upgrade|abort-remove|abort-deconfigure)
  ;;
  *)
    echo "Oops."
    exit 1
  ;;
esac

#DEBHELPER#

exit 0
```

As the name implies, this script will run after installation. It generally
seems like a good idea to avoid putting too much in maintainer scripts since
there are so many `dh_*` utilities to make use of. Plus, the more you use
`dh_*` utilities, the more that `dpkg` is able to track for your package.

Adding that `bundle install` line after the `chown` illustrates this point.
We're not bundling the third party gems specified in the `Gemfile` in the
`.deb` file. Instead, we've chosen to download these gems at install time.
There is no `dh_*` equivalent for installing gems, so, like when we added a
user ([explanation of
command](https://explainshell.com/explain?cmd=adduser+--disabled-password+--quiet+--system+--home+%2Fvar%2Frun%2Frails-new+--no-create-home+--gecos+%22Rails+New+daemon%22+--group+rails-new))
and ran `chown` on the directories Rails would need to write to, we put this
in the maintainer script `rails_new/debian/postinst`.

Running a `dpkg -r` command would normally remove the files that were copied
from `debian/install`, the directories created from `debian/dirs` and so on.
If we were to `sudo dpkg -r rails-new`, however, we would see that the
`/usr/lib/rails-new` directory is not deleted. We ran a `bundle install`,
and that created `/usr/lib/rails-new/{.bundle,vendor}` directories that are
not tracked by `dpkg`.

Even if we didn't use `bundle install` at install time (perhaps we decide to
install vendor gems at the time we build the `.deb` file), we still have
`/var/lib/rails-new/tmp` directory. This directory has contents not tracked
by `dpkg` as they were added during runtime of the Rails application.

### Fight Fire With Fire

To deal with these issues, we'll create a second maintainer script called
`rails_new/debian/prerm` with the following in it to do some extra cleanup:

```bash
#!/bin/bash

set -e


case "$1" in
    upgrade|deconfigure)
    ;;
    remove)
      rm -r /usr/lib/rails-new
      rm -r /var/lib/rails-new
      rm -r /var/log/rails-new
    ;;

    failed-upgrade)
    ;;

    *)
        echo "prerm called with unknown argument $1" >&2
        exit 1
    ;;
esac

#DEBHELPER#

exit 0
```

A keen observer may note that we do not remove the user and group we
created. Generally, [packages shouldn't remove users and
groups](https://unix.stackexchange.com/a/147123/18374). Cleanup of this is
left as an exercise to the system administrator.

Additionally, you may notice the `#DEBHELPER#` at the end of these
maintainer scripts. This is a placeholder. When you build the package,
`debhelper` will put any extra code that it generated for these files in
this location. It won't put the code directly in this file, mind you.
Instead, it'll put it in the `rails_new/debian/rails-new/DEBIAN/postinst`
file that is generated when we run `debuild --no-tgz-check`. In our case, it
puts some extra stuff there because we're installing a `systemd` unit.

### Phew

We made it. It's over. All that's left to do is run a
`debuild --no-tgz-check` and subsequent
`sudo dpkg -i rails-new_0.0.0_all.deb`, and our rails application is
installed and running. You should be able to get to
[http://0.0.0.0:3000](http://0.0.0.0:3000) and be greeted by the default
Rails welcome page. Additionally, if you
`tail -f /var/log/rails-new/development.log`, you'll see "foo!" being logged
from your cron job.

If you want to learn more about this process, do yourself a favor and read
the [many](https://www.debian.org/doc/manuals/maint-guide/index.en.html)
[many](https://askubuntu.com/questions/90764/how-do-i-create-a-deb-package-for-a-single-python-script)
[many](https://wiki.debian.org/Packaging#Introduction_to_Debian_Packaging)
(you get it) resources out there. It may take a bit of piecing together to
get exactly the results you want, but hopefully this article and the many
search results will give you a good starting point.

Also, take a peek at the files in `/var/lib/dpkg/info/*` on an Ubuntu
system. You can see actual files from packages already installed like the
`avahi` and `wpasupplicant` daemons.

Finally, take a look inside of the generated
`rails_new/debian/rails-new/DEBIAN` directory. Lots of learnings to be had!

### Thank You

I really went down a rabbit hole with that one. I appreciate you sticking
through until the end of this article. Hopefully this will provide some
encouragement to you and other readers to use the tools provided out of the
box with your operating system.

Simplify your life, my friend.

\- ryjo
