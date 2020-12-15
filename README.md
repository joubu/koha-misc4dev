# Koha misc4dev

Create an handy kit for Koha developpers (http://koha-community.org).
In a first time it will provide scripts to fill the DB with useful data.

This project does not have the aim to grow much.

## Why this is not in the Koha codebase?
The Koha community does not have enough people to test patches.
Developpers need handy tools to make their everyday works and do not want to wait for people to be interested in what they need.

## Who should not use these scripts?
You should not use these script if you are not running into a devbox.
If you do not know what is kohadevbox, you should not start from here, see
http://wiki.koha-community.org/wiki/Developer_handbook first, then https://github.com/digibib/kohadevbox

## How to use it

### You want to fill your existing database

  # As the vagrant user

  % perl do_all_you_can_do.pl

### You want to reset your database

Note that this is very useful if you want to git bisect

  # As the vagrant user

  % alias reset_my_db='mysql -u koha_kohadev -ppassword -e"DROP DATABASE koha_kohadev";mysql -u koha_kohadev -ppassword -e"CREATE DATABASE koha_kohadev";perl /home/vagrant/koha-dev-misc/do_all_you_can_do.pl'

  % reset_my_db

### You want to benchmark Koha

You can compare Koha versions 3.14, 3.16, 3.18, 3.20, 3.22, 16.05 and 16.11.

A new branch perf_${version}.x has been pushed to [[https://github.com/joubu/Koha.git my Koha github repository]]. On top of the stable versions, a new commit "wip perfs ${version}.x" adds and or adapts the selenium script for the branches it is missing, and a new "search" step has been added to the selenium script.

To benchmark Koha using the `t/db_dependent/selenium/basic_workflow.pl` script, you need to do the following steps:

#### Add the Joubu's Koha git repository
  # As the vagrant user

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


On debian 9 and Zebra
16.11 to 20.11
sudo apt install libcatmandu-store-elasticsearch-perl libtext-unaccent-perl libswagger2-perl libdata-util-perl libmodule-build-xsutil-perl
sudo cpanm Catmandu
sudo cpanm Catmandu::Importer::MARC

