title: Creating CI/CD Pipelines
description: In this article, I explore the creative process that is writing scripts for the setup/teardown of CI/CD environments.
date: 2019-06-07
css: syntax.css
---
### Introduction

This article is long. If you want to get to the meat and potatoes of it,
give the [scripts in the rails_new
repo](https://github.com/mrryanjohnston/rails_new/tree/master/lib/scripts) a
looksee.

We're going to take a quick pit stop before continuing on with our
discussion of [hosting your own git
server](/articles/hosting-your-own-git-server-part-1.html). I realized after
I'd completed the article that the concepts I discuss were based on
hypotheticals. This might be alright and get my point across, but I think
it's beneficial to be rooted somewhat in reality when discussing programming
concepts. Afterall, I believe we should write code for the features we have,
not the features we may have someday.

If you're following along with the madness that is my blog, you've already
got [a git server](/articles/hosting-your-own-git-server-part-1.html)
hosting our [installable rails
package](/articles/turning-your-application-into-an-installable-package.html).
This is great for development on your local dev's machines, and has set us
up for really easy deployments.

Before this, though, we'll need an environment into which we can deploy our
code. I've found that it's very tempting to manually set up
production/staging/development environments by creating ec2 instances,
`ssh`ing in to them to update the OS and install your application's
dependencies (nginx, php, ruby, node, what-have-you). Then you need to get
your application's code onto that ec2 instance. Perhaps you install `git`
and `git pull` the latest, maybe you use `sftp`/`scp` to manually copy your
application's files.

And then you add a new feature to your application. What do you do? Do you
`ssh` onto that same ec2 instance and pull the latest code? `sftp` the
latest file up there? When do you run your database migrations? Do you put
your application into "maintenance mode," causing downtime for your users?
Gross.

What if we automated these steps? Instead of doing everything manually, we
write some scripts that build our architecture and deploy our application.
Not only does this avoid application downtime, but we pave the road for more
advanced features of a CI/CD (continuous integration/continuous deployment)
pipeline, such as spinning up temporary environments to test our
experimental feature branches.

Just a heads up: I will use AWS as my deployment platform of choice. If you
want to do something else, that's totally fine. The concepts I use here are
universal, it's just that the aws cli is so darned convenient. Wherever you
host your code, just make sure they give you a way to build your
infrastructure via the command line.

Enough talk. Let's code.

### Plan First, Code Later

Er, I mean, let's plan.

Alright, it sounds far less fun, but planning what you're going to do ahead
of time can actually save you from writing too much code.

Our rails application is very easy. It doesn't have any requirements outside
of a running machine that has ruby and node installed on it. For this
reason, we'll create a snapshot of a virtual machine that we can use in any
environment as a base for our application.

### The Time Has Come To Templatize!

Let's first start on the script that will create our base machine image
which we'll use to spin up other ec2 instances. In AWS language, this image
is called an
"[AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)."

This image will have dependencies that we'll need in every environment.
First, we'll want to update the Ubuntu system with the latest packages. Then
we'll need ruby and node. I've covered a lot of this ground in [my previous
article](/articles/hosting-your-own-git-server-part-1.html), so I may gloss
over some of the details:

```bash
aws ec2 create-key-pair \
  --key-name rails-new-template-key \
  --query 'KeyMaterial' \
  --output text \
  > ~/.aws/rails-new-template-key.pem
chmod 400 ~/.aws/rails-new-template-key.pem
```

This first command creates an ssh key pair that we'll use to ssh into our
ec2 instance. Pretty straight forward! Let's move on:

```bash
security_group=$(aws ec2 create-security-group \
  --group-name rails-new-template \
  --description "Rails New Template" |
  jq ".GroupId" -r)
```

Here we create a security group. We save the `GroupId` of this security
group by wrapping the command in `security_group=$()`. This is a universal
way to save the output of a command in a variable. You'll also notice we're
using our old pal `[jq](https://stedolan.github.io/jq/)` to parse
the json response from AWS and only get the `GroupId`.

Now we'll attach an "ingress rule" to `$security_group` that'll open up port
22 for our IP address:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$security_group" \
  --cidr 127.0.0.1/24 \
  --port 22 \
  --protocol tcp
```

You'll notice I use `127.0.0.1` in place of my actual IP address. You can
use your favorite search engine to find out what your public-facing IP
address is. You can also take a look at the [little script I
wrote](https://gist.github.com/mrryanjohnston/f5ee07928ab0735a32cbfdb680b4ece3)
that gets your public IP from DuckDuckGo.

Now we'll look for the latest version of Ubuntu Cosmic 18.10 available as an
AMI:

```bash
ami=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters 'Name=name,
    Values=ubuntu/images/hvm-ssd/ubuntu-cosmic-18.10-amd64-server*' |
  jq '.Images | sort_by(.CreationDate) | last(.[]) | .ImageId' -r)
```

Just like with the security group, we save the `ImageId` we find in the
variable `$ami`. We also use a slightly more complex `jq` command to sort
the found `Images` by `CreationDate` and get the last result. In other
words: we get the most recent ami.

Alright, now let's run an instance using this found ami image id, assigning
the key pair and security group we created previously to it:

```bash
instance_id=$(aws ec2 run-instances \
  --image-id "$ami" \
  --count 1 \
  --instance-type t2.micro \
  --key-name rails-new-key \
  --security-group-ids "$security_group" \
  jq '.Instances | first(.[]).InstanceId' -r)
```

Pretty straight forward, eh? Now we need to wait for this machine to finish
starting so that we can get its public IP address. We'll use bash's `while`
loop for this purpose:

```bash
while [ "$instance_ip_address" == "" ]
do
  sleep 1
  instance_ip_address=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=$instance_id,Name=instance-state-name,Values=running" |
    jq ".Reservations[].Instances | first(.[]) | .PublicIpAddress" -r)
done
```

Basically, we break out of the loop if `$instance_ip_address` is ever set to
anything other than `""`. This loop first `sleep`s for 1 second. It then
attempts to find an instance with the id `$instance_id` that is also
`running`. This will mean it has a public IP address. You can toy around
with the amount of time that you `sleep` here or even choose to not `sleep`,
but this works!

I've also found it beneficial to artificially wait for a minute longer since
sometimes the server will refuse the ssh connection if you try it too soon
after the ec2 instance comes up:

```
sleep 1m
```

Once we get the public IP address, we can update the machine and install our
dependencies onto it with ssh using the key pair we created earlier:

```bash
ssh -i ~/.aws/rails-new-template-key.pem ubuntu@"$instance_ip_address" "sudo apt-get update;
  sudo apt-get upgrade;
  sudo apt-get install nodejs ruby bundler zlib1g-dev libsqlite3-dev nginx"
```

I choose not to use `rvm` or `nvm` to install non-default versions of `ruby`
or `node` respectively. I think these are great tools for environments that
will need multiple version of `ruby` or `node` available. For example,
developers may have many different code bases that require different
versions of these binaries. Our ec2 instance, however, will only ever use
one version to run our application. For this reason, consider either
installing the version you need specifically using
[snap](https://www.ruby-lang.org/en/documentation/installation/#snap) or
[NodeSource](https://github.com/nodesource/distributions/blob/master/README.md)
respectively.

Alright, we've crafted the perfect machine that can run our application. Any
other customizations we'd do to it would be environment-specific, so let's
take a snapshot here:

```bash
aws ec2 create-image \
  --instance-id "$instance_id" \
  --name rails-new-template |
  jq -r '.ImageId'
```

Nice. This will start creating a snapshot of your running instance. You can
check when the AMI is done doing this by checking its state:

```bash
aws ec2 describe-images \
  --filters "Name=name,Values=rails-new-template" "Name=is-public,Values=false" |
  jq 'first(.Images[]).State'
```

Once it's listed as "available," it's safe to tear down that ec2 instance:

```bash
aws ec2 terminate-instances \
  --instance-ids "$instance_id"
```

We also have a security group floating around out there. It'll take a little
before we can delete it since we just terminated the instance it was
attached to, so we'll loop until it returns a `0` exit status:

```bash
while ! aws ec2 delete-security-group \
  --group-id "$security_group"
  do
    sleep 1
  done
```

### Back To Planning

Alright, so now we have the ability to spin up instances that we can install
the built `deb` file for rails_new. We don't even need to worry about RDS
because our database...

Wait... our database. Right now, we're using
[SQLite](https://sqlite.org/index.html) which is storing our database in a
file (`db/development.sqlite3` by default for our development environments).
This file will disappear when we re-deploy our code since it's just a file
sitting on the ec2 instance. How embarrassing; if we want to deploy new
code, we'll lose all of our app's data.

Luckily for us, AWS provides a bunch of different detachable storage
solutions. The one I was most familiar with was
[EBS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AmazonEBS.html).
Consider this a detachable harddrive that can be re-attached to any ec2
instance in the future.

Hold up. Unfortunately, EBS volumes can only be mounted on one ec2 instance
at a time. Why is this a problem? Ideally, we'd like "zero downtime
deployments," meaning the user's experience will never be interrupted. If we
use EBS volumes, our steps for deploying a new version of our application
would have to look like:

1. Spin up a new ec2 instance
2. Unmount the EBS volume from the old ec2 instance
3. Remount the EBS volume from the old ec2 instance
4. Point the DNS entry at the new ec2 instance
5. Terminate the old ec2 instance

This leaves some downtime around the "Unmount" and "Point the DNS entry"
steps. Wouldn't it be nice if the above steps could look like this instead?:

1. Spin up a new ec2 instance
2. Mount the detachable volume on the new ec2 instance
3. Point the DNS entry at the new ec2 instance
4. Terminate the old ec2 instance

Ahhh... that sweet sweet uptime. Now our users will never notice a moment
lost. One thing to keep in mind: the above process assumes you're making
"backwards compatible" database changes. Basically, this means the old code
and new code can run on the current database structure simultaneously. This
will require developers to be mindful when creating new features, but will
be worth it; if we do things this way, our users won't experience any odd
behavior in the time that it takes the DNS entry to switch over to the new
ec2 instance.

### What Do?

Now that we've established that EBS volumes are probably not the right
solution for this, let's explore other options. Luckily for us, AWS has
[many different storage
solutions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Storage.html).
One of these is [Elastic File System
(EFS)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AmazonEFS.html).
From their website, Amazon says "You can use an EFS file system as a common
data source for workloads and applications running on multiple instances."
Perfect.

We'll follow [the steps listed in Amazon's
docs](https://docs.aws.amazon.com/efs/latest/ug/wt1-create-ec2-resources.html)
for setting up EFS on an ec2 instance. I'll sum up what they have written
there.

### Creating Environment-Specific AMIs

First, we need to create two security groups; the first one we'll create is
for the ec2 instance that will run our
[rails_new](https://github.com/mrryanjohnston/rails_new) project:

```bash
security_group_ec2=$(aws ec2 create-security-group \
  --group-name rails-new-production \
  --description "Rails New Production" |
  jq ".GroupId" -r)
```

You'll note here that we are once again saving the output of this command to
`security_group_ec2`. We'll later use this variable in our script to easily
apply it to our ec2 instance.

Also note that we're calling this "production." I think it's wise to first
aim to set up your production environment since it'll be the "gold standard"
for all other environments after it. All of your other environments should
be mimicking production as much as possible. That way, you'll have higher
confidence that you code is "production ready" because you'll be testing in
"production-like" environments.

That's a lot of use of the word "production."

Ok, one more: "Production."

### Production

Now, we'll create one for the EFS "mount target." A "mount target" is simply
something that gives a public IP to our File System so that it's accessible
over the network:

```bash
security_group_efs=$(aws ec2 create-security-group \
  --group-name rails-new-efs \
  --description "Rails New Production EFS Mount Target" |
  jq ".GroupId" -r)
```

Hi, variable `security_group_efs`! Nice to meet you. I'm ryjo. Please hold
the security group id that we'll use to apply to our efs "mount target."
Thanks!

Now we'll add an ingress rule for the ec2 security group that'll let us ssh
into the machine as well as one that will let us see our running rails app
over http:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$security_group_ec2" \
  --cidr 127.0.0.1/24 \
  --port 22 \
  --protocol tcp

aws ec2 authorize-security-group-ingress \
  --group-id "$security_group_ec2" \
  --cidr 127.0.0.1/24 \
  --port 3000 \
  --protocol tcp
```

The idea here is that, after we do this initial environment setup, we'll
have a working environment. All subsequent deploys to this environment will
not have to run through the initial steps; we'll just re-use
`$security_group_ec2` for all the new ec2 instances.

Also note that we use port 3000 for our http server. This is the port our
app is currently running on. You could make this use port 80 by specifying
From and To ports, or you could use something like nginx to port forward for
you. For the sake of this article's length, we'll keep this short and just
use port 3000. Check out [AWS's
documentation](https://docs.aws.amazon.com/cli/latest/reference/ec2/authorize-security-group-ingress.html)
to read up on how to do the former. In [the rails_new create_environment
script](https://github.com/mrryanjohnston/rails_new/blob/master/lib/scripts/create_environment.sh#L377-L391),
I've chosen to do the latter.

EFS is basically [Network File
System](https://en.wikipedia.org/wiki/Network_File_System_(protocol)) (NFS)
behind the scenes. NFS uses port 2049 by default, so we'll make a rule in
the "mount target's" security group to allow inbound traffic on this port:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$security_group_efs" \
  --source-group "$security_group_ec2" \
  --port 2049 \
  --protocol tcp
```

Woah, ok, we did something kind of cool in this last comment. We authorized
ec2 instances that have the `$security_group_ec2` security group applied to
them to use this ingress rule instead of specifying an ip range using the
`--cidr` flag. This is really awesome. This means we won't have to get the
ip address of every ec2 instance we start and create an ingress rule for it.

Alright, it's time to spin up our ec2 instance that'll run our rails_new
app. Let's first create a key pair:

```bash
aws ec2 create-key-pair \
  --key-name rails-new-production-key \
  --query 'KeyMaterial' \
  --output text \
  > ~/.aws/rails-new-production-key.pem
chmod 400 ~/.aws/rails-new-production-key.pem
```

Remember way back in our first script? It should have output an AMI image id
that we can use to spin up our first rails_new production ec2 instance.
Since this is a different script, I'm going to hardcode this as
`ami-00000000000000000`:

```bash
instance_id=$(aws ec2 run-instances \
  --image-id ami-00000000000000000 \
  --count 1 \
  --instance-type t2.micro \
  --key-name rails-new-key \
  --security-group-ids "$security_group_ec2" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=rails-new-production}]' |
  jq '.Instances | first(.[]).InstanceId' -r)
```

We store the output of this command into the `instance_id` variable.
Additionally, we name this instance "rails-new-production" using the
`--tag-specifications` flag.

Alright, now we'll create a file system and save its id into yet another
variable:

```bash
file_system_id=$(aws efs create-file-system \
  --creation-token RailsNewProductionFileSystem \
  --tags Key=Name,Value=rails-new-production-file-system |
  jq '.FileSystemId' -r)
```

We've now created a file system, but we have no way of mounting it. We'll
create a mount target for this file system so that we can go into our ec2
instance and "mount" it. This will give our filesystem a public IP address
and DNS name by which we'll mount it.

First, we'll need to get a subnet in which to place it. I'll choose the
default subnet to keep it simple:

```bash
subnet=$(aws ec2 describe-subnets \
  --filters='Name=default-for-az,Values=true' |
  jq -r '.Subnets | first(.[]).SubnetId')
```

Then we'll create the mount target:

```bash
aws efs create-mount-target \
  --file-system-id "$file_system_id" \
  --security-group "$security_group_efs" \
  --subnet-id "$subnet"
```

'Tis a thing of beauty. The command line is so powerful. By doing this,
we've allowed our ec2 instance to mount our filesystem via port 2049.

### Now the Really Fun Part: Mounting an NFS Volume

Now, we must mount this file system in the ec2 instance using the mount
target. First, if you're unaware, "mounting" means making a storage device
available in the directory structure. Simple as that. Once we "mount" this
device, we'll be able to access it somewhere by `cd`ing into it, `ls` to get
its contents, and even `touch` or `rm` to modify stuff.

First, we should ssh into our ec2 instance. Let's get its IP address first:

```bash
while [ "$instance_ip_address" == "" ]
do
  sleep 1
  instance_ip_address=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=$instance_id,Name=instance-state-name,Values=running" |
    jq ".Reservations[].Instances | first(.[]) | .PublicIpAddress" -r)
done
```

Ah, our old friend `while`. We used this in our first script to get the ip
address of our base ec2 instance, so it should be familiar. We'll use the
`$instance_ip_address` to first install the package `nfs-common`. We'll then
use this package to `mount` our nfs file system:

```bash
ssh -i ~/.aws/rails-new-production-key.pem ubuntu@"$instance_ip_address" \
  "sudo apt-get install nfs-common;
   sudo mkdir -p /var/lib/rails-new/db
   sudo mount \
     -t nfs \
     -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
     $file_system_id.efs.us-east-1.amazonaws.com:/ /var/lib/rails-new/db"
```

Alright, that's a lot of stuff we just did. The trickiest part is probably
the `mount` command. I won't lie: I straight-up copied the command from the
[AWS
documentation](https://docs.aws.amazon.com/efs/latest/ug/wt1-test.html). The
`-t` flag specifies that this is indeed an `nfs` file system. We then use
the `-o` command to pass a bunch of extra options. There's a lot of them, so
I recommend reading through `man mount` to figure out what they do.
Honestly, this article is already long enough. Consider it homework.

`$file_system_id.efs.us-east-1.amazonaws.com` is the URL our filesystem is
available at. This is always the case with EFS. You may find that, in a
script, this URL may not be available right away. That's because DNS takes a
little bit to propagate, and it may be the case that it's not available for
that mount target yet. In that case, you can use the IP address of the mount
target instead. You can find that by doing:

```bash
aws efs describe-mount-targets \
  --file-system-id "$file_system_id" |
  jq 'first(.MountTargets[]) | select(.IpAddress!=null) | .IpAddress' -r
```

That... that's it. Yep. We should now have access to this file system on
this ec2 instance. We'll create an AMI based on this image so we can use it
for future deployments:

```bash
aws ec2 create-image \
  --instance-id "$instance_id" \
  --name rails-new-production-template |
  jq -r '.ImageId'
```

Ok, [let's review how we install the database for rails_new on ubuntu-based
machines](https://github.com/mrryanjohnston/rails_new/blob/master/debian/dirs#L1).
We create a directory at `/var/lib/rails-new/db`, and then the app knows to
use this directory based on the
[links](https://github.com/mrryanjohnston/rails_new/blob/master/debian/links#L1)
we create. Now, instead of creating this directory using the `dirs` file, we
create it when we mount the NFS volume.

We can now use this AMI when we start up instances for rails_new! Woo! In
this particular case, we already have an instance running, so we'll use it
for the rest of the setup process.

We'll build the `deb` file for rails_new and install it on this machine.
Back on our local machine:

```bash
debuild --no-tgz-check
scp -i ~/.aws/rails-new-production-key.pem ../rails-new_0.0.0_all.deb ubuntu@"$instance_ip_address":~
ssh -i ~/.aws/rails-new-production-key.pem ubuntu@"$instance_ip_address" "sudo dpkg -i rails-new_0.0.0_all.deb"
```

Since this is our first install of rails_new, we'll need to initialize the
database to create it. We won't need to do this for subsequent deploys since
the old db file should be available in the EFS volume:

```bash
ssh -i ~/.aws/rails-new-key.pem "cd /usr/lib/rails-new && rails db:create"
```

Boom! You should now be able to access the running rails app in your web
browser by going to http://`$instance_ip_address`. But... ugh, yuck, who
remembers IP addresses these days?

### What's In a Name?

One more thing we need to do is create a DNS entry for our server. I'm using
[Route
53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html),
yet another aws hosted service. We'll use this to create a subdomain on a
domain that we already own and point it at our new environment. We'll want
to use `aws route53 change-resource-record-sets`. This command is a little
more advanced than previous commands, but we can do it. We'll want to create
an A name record which maps an IP address to an easily remembered URL.

The way that `aws route53 change-resource-record-sets` works is you pass it
a json string that describes an acton you want to take on a resource (a name
record). It might be a little daunting at first, but what's cool about this
command is we can generate sample json strings and take a look at them by
doing the following:

```bash
aws route53 change-resource-record-sets --generate-cli-skeleton
```

Let's check out one possible output from this command:

```json
{
  "HostedZoneId": "",
  "ChangeBatch": {
    "Comment": "",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "",
          "Type": "A",
          "SetIdentifier": "",
          "Weight": 0,
          "Region": "ap-northeast-2",
          "GeoLocation": {
            "ContinentCode": "",
            "CountryCode": "",
            "SubdivisionCode": ""
          },
          "Failover": "PRIMARY",
          "MultiValueAnswer": true,
          "TTL": 0,
          "ResourceRecords": [
            {
              "Value": ""
            }
          ],
          "AliasTarget": {
            "HostedZoneId": "",
            "DNSName": "",
            "EvaluateTargetHealth": true
          },
          "HealthCheckId": "",
          "TrafficPolicyInstanceId": ""
        }
      }
    ]
  }
}
```

Conveniently, this is part of the way towards what we'd like to do: we want
to create an "A" record, and we can see from this that
`ResourceRecordSet.Type` is `A`. Before this, we see that the `Action` is
`UPSERT`. This means if the record already exists, it'll update it. If not,
it'll create it. We'll change ours to a `CREATE` so that we'll be explicit
about what we're trying to do (which is initialize an environment).

To get the value of `HostedZoneId`, you can use
`aws route53 list-hosted-zones`. For example, if you only have one hosted
zone:

```bash
aws route53 list-hosted-zones |
  jq '.HostedZones[0].Id'
```

I'll use `/hostedzone/0000000000000` to represent the output of this
command.

Reviewing this, we probably don't need to specify a bunch of these fields.
By process of elimination (aka trying everything until something worked), I
whittled down what we need to the following:

```json
{
  "HostedZoneId": "/hostedzone/0000000000000",
  "ChangeBatch": {
    "Comment": "",
    "Changes": [
      {
        "Action": "CREATE",
        "ResourceRecordSet": {
          "Name": "rails-new.ryjo.codes.",
          "Type": "A",
          "SetIdentifier": "Rails New",
          "Region": "us-east-1",
          "TTL": 0,
          "ResourceRecords": [
            {
              "Value": "0.0.0.0"
            }
          ]
        }
      }
    ]
  }
}
```

An interesting thing about `change-resource-record-sets` is we can specify
our json structure in two ways: one using `--cli-input-json`, the other
`--hosted-zone-id` in conjunction with `--change-batch`. Note the
`HostedZoneId` and `ChangeBatch` properties in the above JSON. Because we
specify these in the JSON object, we can use this as an argument to
`--cli-input-json`. We could also opt to store our JSON object in a separate
file and pass the path of that file to `--change-batch`. We would also pass
`/hostedzone/0000000000000` to `--hosted-zone-id` in this case. Our command
would look something like this:

```bash
aws ec2 change-resource-record-sets \
  --hosted-zone-id "/hostedzone/0000000000000" \
  --change-batch "file://dns.json"
```

...and then we'd have a `dns.json` file stored in the same directory that
looks like this:

```json
{
  "Comment": "",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "rails-new.ryjo.codes.",
        "Type": "A",
        "SetIdentifier": "Rails New",
        "Region": "us-east-1",
        "TTL": 0,
        "ResourceRecords": [
          {
            "Value": "0.0.0.0"
          }
        ]
      }
    }
  ]
}
```

It'd be nice to use this method because it would keep our json in a separate
file. Organization! However, then we wouldn't be able to replace some of the
properties in this json programmatically, such as `Value` and `Name` which
we'll pass the ec2 instance's IP address and environment-specific dns record
respectively. Here is what our implementation will look like:

```bash
hz=$(aws route53 list-hosted-zones | jq -r '.HostedZones[0].Id')
environment="$1"
function jsontemplate() {
  cat << JSON 
{
  "HostedZoneId": "$hz",
  "ChangeBatch": {
    "Comment": "",
    "Changes": [
      {
        "Action": "CREATE",
        "ResourceRecordSet": {
          "Name": "rails-new-$environment.ryjo.codes.",
          "Type": "A",
          "SetIdentifier": "Rails New",
          "Region": "us-east-1",
          "TTL": 0,
          "ResourceRecords": [
            {
              "Value": "0.0.0.0"
            }
          ]
        }
      }
    ]
  }
}
JSON
}

aws route53 change-resource-record-sets \
  --cli-input-json "$(jsontemplate)"
```

Ahhh... our old friend `cat &lt;&lt; FOO`. If you recall from [a previous
article](/articles/hosting-your-own-git-server-part-1.html), this basically
signifies we're returning a multi-line string to STDOUT. We use this in
order to make use of the `$hz` and `$environment` variables in our script.
We then use `"$(jsontemplate)"` to call the `jsontemplate` function and use
what it returns as the value of argument `--cli-input-json`. Assuming we
save the above in a file `foo.sh`, this means we can create a new
environment-specific DNS record `rails-new-staging.ryjo.codes` that points
at `0.0.0.0` by doing `./foo.sh staging`.

Hmm... but what about `production`? Do we really want
`rails-new-production.ryjo.codes`? Probably not. Let's fix that:

```bash
hz=$(aws route53 list-hosted-zones | jq -r '.HostedZones[0].Id')
if [ -z "$1" ]
then
  environment="production"
  dns_entry="rails-new.ryjo.codes."
else
  environment="$1"
  dns_entry="rails-new-$environment.ryjo.codes."
fi
function jsontemplate() {
  cat << JSON 
{
  "HostedZoneId": "$hz",
  "ChangeBatch": {
    "Comment": "",
    "Changes": [
      {
        "Action": "CREATE",
        "ResourceRecordSet": {
          "Name": "$dns_entry",
          "Type": "A",
          "SetIdentifier": "Rails New $environment",
          "Region": "us-east-1",
          "TTL": 0,
          "ResourceRecords": [
            {
              "Value": "0.0.0.0"
            }
          ]
        }
      }
    ]
  }
}
JSON
}

aws route53 change-resource-record-sets \
  --cli-input-json "$(jsontemplate)"
```

We'll only pass an argument to `./foo.sh` if we want to create an
environment other than `production`. Obviously you may want to investigate
`tr` to fix up `$1` before setting it as part of the DNS record, perhaps
replacing some characters that would make an invalid URL. Again, I leave
this as a bit of homework for you.

We should now be able to get to `rails-new.ryjo.codes:3000` in our browsers!
Woo! Well, I should, anyway. You'd obviously use your own domain.

### Feature Requests, Bug Fixes and More

Eventually, you'll write new code for your application. Let's examine a
script that'll deploy a new version of our code with zero downtime. I'm
going to fly through these first few steps since they are pretty much the
same as the environment initialization step. First, make a change to the
codebase that you can easily tell something happened. For example, you could
[create a homepage that displays something other than the default Rails
page](https://guides.rubyonrails.org/getting_started.html#say-hello-rails).
Next, we'll build the new version of our application:

```
debuild --no-tgz-check 
```

This way, if there's anything wrong with our tests, we can stop before we do
something in AWS that we'd have to revert.

Now we'll look for our environment-specific AMI:

```bash
ami=$(aws ec2 describe-images \
  --filters "Name=name,Values=rails-new-production-template" "Name=is-public,Values=false" |
  jq ".Images | first(.[]).ImageId" -r)
```

...and the security group used to ssh into the machine and http our deployed
application:

```bash
security_group_ec2=$(aws ec2 describe-security-groups \
  --group-names "rails-new-production-ec2" | 
  jq -r '.SecurityGroups | first(.[]).GroupId' -r)
```

Believe it or not, we can just create a new ec2 instance now:

```bash
instance_id=$(aws ec2 run-instances \
  --image-id "$ami" \
  --count 1 \
  --instance-type t2.micro \
  --key-name "rails-new-production-key" \
  --security-group-ids "$security_group_ec2" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" |
  jq '.Instances | first(.[]).InstanceId' -r)
```

...and wait for that machine to have an IP address:

```bash
while [ "$instance_ip_address" == "" ]
do
  sleep 1
  instance_ip_address=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=$instance_id" "Name=instance-state-name,Values=running" |
    jq ".Reservations[].Instances | first(.[]) | .PublicIpAddress" -r)
done
sleep 1m
```

Oky doke. Now let's copy our build `deb` to the ec2 instance and install it:

```bash
scp -i ~/.aws/rails-new-production-key.pem rails-new_0.0.0_all.deb ubuntu@"$instance_ip_address":~
ssh -i ~/.aws/rails-new-production-key.pem ubuntu@"$instance_ip_address" "sudo dpkg -i rails-new_0.0.0_all.deb"
```

This next step will be slightly different than our environment
initialization script. We've already created our database. For our new
deploys, we'll migrate instead:

```bash
ssh -i ~/.aws/rails-new-key.pem "cd /usr/lib/rails-new && rails db:migrate && sudo service rails-new restart"
```

Notice that we also restart our rails service. We need to do this for Rails'
ActiveRecord magic. Finally, we'll change the DNS entry:

```bash
hz=$(aws route53 list-hosted-zones | jq -r '.HostedZones[0].Id')
if [ -z "$1" ]
then
  environment="production"
  dns_entry="rails-new.ryjo.codes."
else
  environment="$1"
  dns_entry="rails-new-$environment.ryjo.codes."
fi
function jsontemplate() {
  cat << JSON 
{
  "HostedZoneId": "$hz",
  "ChangeBatch": {
    "Comment": "",
    "Changes": [
      {
        "Action": "CREATE",
        "ResourceRecordSet": {
          "Name": "$dns_entry",
          "Type": "A",
          "SetIdentifier": "Rails New $environment",
          "Region": "us-east-1",
          "TTL": 0,
          "ResourceRecords": [
            {
              "Value": "$instance_ip_address"
            }
          ]
        }
      }
    ]
  }
}
JSON
}

aws route53 change-resource-record-sets \
  --cli-input-json "$(jsontemplate)"
```

It may take a few minutes for the DNS changes to propagate, but that should
be it! Check out your sweet changes at your
`rails-new.whateveryourdomainis.com:3000`.

### Reasons For Madness

Why in the world are we doing this? We're only going to be creating the
production environment once, so why script it?

First, never assume you're only ever going to do something once. When we're
first setting up our environment, we might find that our original
architecture design is lacking or over-engineered. We should keep this
script along with a script that will undo our changes so that we can quickly
iterate on this design. Additionally, it'll help for the inevitable time
that we want to spin up a different application with a similar architecture.

"But Ryan," I hear you say, "microservices are years away for my company,
and we may never get there." Sure, but that isn't the only reason you'd ever
want to codify and version the way you spin up environments that run your
application. For example, imagine you're creating an experimental feature,
and you want to run it in its own quarantined environment. How long would it
take you to manually follow the above steps all over again? Then it would
take more time to tear down that environment. You may as well write those
two processes down in code. Save "future you" some time!

### Conclusion

That was a lot. Maybe consider taking a nap after reading that one.

We may have exhausted ourselves mentally, but now we have done something
very valuable: we've automated creating environments for our application. It
should now, theoretically, be trivial to set up and tear down our
application environments. This means we can very easily do things like spin
up an entire environment to test a new feature that lives in a specific
branch.

We've also made it very easy to deploy new versions of our code without
introducing downtime for our service via blue/green deployment methods.

There's so much more we could do here, but I think this is a really good
starting point. I hope this article illustrates just how much potential
there is for automating your common AWS actions using simple bash scripts.

If you want more, give the [README for
rails_new](https://github.com/mrryanjohnston/rails_new/blob/master/README.md#deploying-to-aws)
a review. I've added a lot of
[scripts](https://github.com/mrryanjohnston/rails_new/tree/master/lib/scripts)
that do more things like tear down, prune and check the status of your
various bits of infrastructure. For the sake of the length of this article,
I've omitted explaining them here. Do check out those scripts, as I've made
some nice improvements to my code samples from this article.

In future articles, I'll show you how to use these script in conjunction
with our [git server that we set
up](/articles/hosting-your-own-git-server-part-1.html), making it part of
our CI/CD pipeline.

For now, let's walk away slowly and rejoin society.

\- ryjo
