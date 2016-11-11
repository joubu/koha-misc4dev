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
