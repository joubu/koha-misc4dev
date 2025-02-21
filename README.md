# Koha misc4dev

Create a handy kit for Koha developpers (https://koha-community.org).

## Why this is not in the Koha codebase?

The Koha community does not have enough people to test patches.
Developpers need handy tools to make their everyday works and do not want to wait for people to be interested in what they need.

## Who should not use these scripts?

If you do not know what they are, do not use them.

They are mostly used internally by koha-testing-docker and so our CI (jenkins), see
http://wiki.koha-community.org/wiki/Developer_handbook first, then https://gitlab.com/koha-community/koha-testing-docker/

## How to use it

### You want to fill your existing database

  # As the root user

  % perl do_all_you_can_do.pl

### You want to reset your database

Note that this is very useful if you want to git bisect

  # As the root user

  % alias reset_my_db='mysql -u koha_kohadev -ppassword -e"DROP DATABASE koha_kohadev";mysql -u koha_kohadev -ppassword -e"CREATE DATABASE koha_kohadev";perl /kohadevbox/misc4dev/do_all_you_can_do.pl'

  % reset_my_db

If you are inside a koha-testing-docker container you should use the `reset_all` alias instead.

### You want to benchmark Koha

You can compare Koha versions 3.14, 3.16, 3.18, 3.20, 3.22, 16.05 and 16.11.

A new branch perf_${version}.x has been pushed to [[https://github.com/joubu/Koha.git my Koha github repository]]. On top of the stable versions, a new commit "wip perfs ${version}.x" adds and or adapts the selenium script for the branches it is missing, and a new "search" step has been added to the selenium script.

To benchmark Koha using the `t/db_dependent/selenium/basic_workflow.pl` script, you need to do the following steps:

#### Add the Joubu's Koha git repository
  # As the root user

  % cd kohaclone
  % git remote add Joubu https://github.com/joubu/Koha.git

#### Configure Selenium and install firefox

  % sudo wget https://selenium-release.storage.googleapis.com/2.53/selenium-server-standalone-2.53.0.jar  -O /opt/selenium-server-standalone-2.53.0.jar

  % SELENIUM_PATH=/opt/selenium-server-standalone-2.53.0.jar

  % echo "deb http://packages.linuxmint.com debian import" | sudo tee /etc/apt/sources.list.d/firefox.list

  % apt update && apt install firefox xvfb

#### Benchmark!
##### Start the selenium server

  % Xvfb :1 -screen 0 1024x768x24 2>&1 >/dev/null &

  % DISPLAY=:1 java -jar $SELENIUM_PATH

##### Launch the benchmark script
  % perl koha-misc4dev/benchmark_them_all.pl # That will take a while, almost 1h on my laptop

Note that you can set a verbose flag (edit the script and set $verbose = 1)

The performance data have been created into /tmp/${version}[_plack].txt

The _plack files are only generated if the `debian/templates/koha.psgi` file exists (from 3.22)

##### Collect the data

  % perl koha-misc4dev/collect_benchmark_data.pl /tmp/3.14.txt /tmp/3.16.txt /tmp/3.18.txt /tmp/3.20.txt /tmp/3.22.txt /tmp/3.22_plack.txt /tmp/16.05.txt /tmp/16.05_plack.txt /tmp/16.11.txt /tmp/16.11_plack.txt # Yes this could be improved

That will produce 2 sections, the "Raw data" (not really useful) and the "Average".

You can have a look at my own generated file in the `benchmark_data` directory.

#### Generate a graph

To generate a graph, copy and paste the "Average" section into a spreadsheet program (Calc for instance).

You can take a look at my generated graph in `benchmark_data/Joubu/results.ods`

## How are sql files generated?

This scripts load the default sample data from the Koha codebase. Bibliographic and authority records
are loaded from `data/sql`. This directory will be traversed from higer Koha version to lower.

This files need to be regenerated every time the relevant tables get their structure changed. This doesn't
happen too often. The tables are:

* `auth_header`
* `biblio_metadata`
* `biblio`
* `biblioitems`
* `items`

NOTE: for all steps, they need to be repeated for both *marc21* and *unimarc* flavours. In the examples
we only use *marc21*.

If bug `XXX` introduces a change in one of those tables you need to follow this steps:

1. Does the current major version have a specific dir? (for example, if Koha.pm says *24.12.00.013*, then
   the major version is *2412*) If there isn't a directory it needs to be created: `mkdir -p sql/data/marc21/2412`.
2. Once we identified the directory, we need to create a new directory named `after_XXX`.
3. Copy all the `.sql` files from the closest prior version.
4. Regenerate `auth_header.sql` (the only modified one in our example)
5. Repeat for *unimarc*
6. Adapt `insert_data.pl` to handle this new use case.

### Generating the updated SQL

Following with our example, the first thing to do is to load `KTD` in the commit prior to the change:

```shell
git checkout <commit id>
ktd up -d
```

Now update the DB (with the sample data in it):

```shell
git reset --hard origin/main
ktd --shell
updatedatabase
```

Now we need to export the table:

```shell
mysqldump -ppassword -uroot -hdb -c --skip-lock-tables koha_kohadev auth_header > auth_header.sql
```

This file will contain some SQL comments. Clean it all. Then move this file into your `koha-misc4dev`
working directory. And repeat for the next `KOHA_MARC_FLAVOUR`.
