#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw( dirname );
use Cwd 'abs_path';

use C4::Installer;
use C4::Context;
use Koha::AuthUtils qw( hash_password );
use Koha::IssuingRule; # Should not be needed but Koha::IssuingRules does not use it
use Koha::IssuingRules;
use Koha::Patrons;
use Koha::Patron::Categories;
use t::lib::TestBuilder;

my $marcflavour = 'MARC21';
my ( $help, $verbose );

GetOptions(
    'help|?'        => \$help,
    'verbose'       => \$verbose,
    'marcflavour=s' => \$marcflavour
);

pod2usage(1) if $help;

$marcflavour = uc($marcflavour);
my $lc_marcflavour = lc $marcflavour;

if (     $marcflavour ne 'MARC21'
     and $marcflavour ne 'UNIMARC' ) {
    say "Invalid MARC flavour '$marcflavour' passed.";
    pod2usage;
}

if ( $marcflavour eq 'UNIMARC' ) {
    warn "There is no records data for UNIMARC yet"
}

our $root      = C4::Context->config('intranetdir');
our $installer = C4::Installer->new;
my $sql_dir = dirname( abs_path($0) ) . '/data/sql';
my @records_files = ( "$sql_dir/$lc_marcflavour/biblio.sql", "$sql_dir/$lc_marcflavour/biblioitems.sql", "$sql_dir/$lc_marcflavour/items.sql", "$sql_dir/$lc_marcflavour/auth_header.sql" );

C4::Context->preference('VOID'); # FIXME master is broken because of 174769e382df - 16520
insert_records();
insert_default_circ_rule();
configure_selfreg();
configure_selfcheckout();
insert_acquisition_data();

sub execute_sqlfile {
    my ($filepath) = @_;
    say "Inserting $filepath..."
        if $verbose;
    # FIXME There is something wrong here
    # load_sql does not return the error as expected
    my $error = $installer->load_sql($filepath);
    die $error if $error;
}

sub insert_records {
    say "Inserting records..."
        if $verbose;
    for my $file ( @records_files ) {
        execute_sqlfile( $file );
    }
}

sub insert_default_circ_rule {
    say "Inserting default circ rule..."
        if $verbose;
    Koha::IssuingRule->new(
        {
                 categorycode => '*',
                     itemtype => '*',
                   branchcode => '*',
                  maxissueqty => 5,
            maxonsiteissueqty => 5,
                  issuelength => 5,
                   lengthunit => 'days',
                renewalperiod => 5,
              reservesallowed => 5,
             holds_per_record => 2,
                 onshelfholds => 1,
                opacitemholds => 'Y',
             article_requests => 'yes',
        }
    )->store;
}

sub configure_selfreg {
    C4::Context->set_preference('PatronSelfRegistration', 1);
    C4::Context->set_preference('PatronSelfRegistrationDefaultCategory', 'SELFREG');
    Koha::Patron::Category->new(
        {
                 categorycode => 'SELFREG',
                  description => 'Self registration',
              enrolmentperiod => 99,
                 enrolmentfee => 0,
                   reservefee => 0,
                hidelostitems => 0,
                category_type => 'A',
              default_privacy => 'default',
        }
    )->store;
}

sub configure_selfcheckout {
    C4::Context->set_preference('WebBasedSelfCheck', 1);
    C4::Context->set_preference('AllowSelfCheckReturns', 1);
    C4::Context->set_preference('AutoSelfCheckAllowed', 1);
    C4::Context->set_preference('AutoSelfCheckID', 'self_checkout');
    C4::Context->set_preference('AutoSelfCheckPass', 'self_checkout');

    my $password = hash_password('self_checkout');

    my $patron = Koha::Patron->new(
        {
                 cardnumber => 'self_checkout',
                     userid => 'self_checkout',
                   password => $password,
                    surname => 'Self-checkout patron',
               categorycode => 'S',
                 branchcode => 'CPL',
                 dateexpiry => 2099-12-31,
                      flags => 0,
        }
    )->store;
    my $dbh = C4::Context->dbh;
    $dbh->do(q|
        INSERT INTO user_permissions (borrowernumber, module_bit, code) VALUES (?, ?, ?)
    |, undef, $patron->borrowernumber, 1, 'self_checkout' );
}

sub insert_acquisition_data {
    my $builder = t::lib::TestBuilder->new;
    my $budget = $builder->build({ source => 'Aqbudgetperiod', value => {
    budget_period_startdate => '2016-01-01',
      budget_period_enddate => '2026-12-31',
       budget_period_active => 1,
  budget_period_description => 'Main budget',
        budget_period_total => 1000000,
    }});

    my $fund_1 = $builder->build({ source => 'Aqbudget', value => {
           budget_parent_id => undef,
                budget_code => 'Main fund',
                budget_name => 'Main fund',
              budget_amount => 1000,
              budget_encumb => 10,
           budget_period_id => $budget->{budget_period_id},
    }});
    my $fund_1_2 = $builder->build({ source => 'Aqbudget', value => {
           budget_parent_id => $fund_1->{budget_id},
                budget_code => 'Fund 1_2',
                budget_name => 'Fund 1_2',
              budget_amount => 100,
           budget_period_id => $budget->{budget_period_id},
    }});
    my $fund_2 = $builder->build({ source => 'Aqbudget', value => {
           budget_parent_id => undef,
                budget_code => 'Secondary fund',
                budget_name => 'Secondary fund',
              budget_amount => 1000,
              budget_encumb => 10,
           budget_period_id => $budget->{budget_period_id},
    }});

    C4::Context->set_preference('gist', '0|0.12|0.1965');
    my $vendor = $builder->build({ source => 'Aqbookseller', value => {
                       name => 'My Vendor',
                     active => 1,
                  listprice => 'USD',
               invoiceprice => 'USD',
                     gstreg => 0,
                 listincgst => 0,
              invoiceincgst => 0,
                   tax_rate => 0.1965,
                   discount => 10,
               deliverytime => 3,
    }});

    my $basket = $builder->build({ source => 'Aqbasket', value => {
                 basketname => 'My Basket',
                       note => 'An internal note',
             booksellernote => 'A vendor note',
               booksellerid => $vendor->{id},
               authorisedby => 51,
              deliveryplace => 'CPL',
               billingplace => 'CPL',
                  closedate => undef, # Need the undefs otherwise TestBuilder will create the FK with random data
                     branch => undef,
             contractnumber => undef,
              basketgroupid => undef,
    }});
}

=head1 SYNOPSIS

insert_data.pl [ --marcflavour <marcflavour> ]

 Options:
   -?|--help         Brief help message
   --marcflavour m   Specify the MARC flavour to use (MARC21|UNIMARC). Defaults to MARC21.
   -v|--verbose      Be verbose

=head1 OPTIONS

=over 8

=item B<--help|-?>

Print a brief help message and exits

=item B<--marcflavour>

Lets you choose the desired MARC flavour for the sample data. Valid options are MARC21 and UNIMARC.
It defaults to MARC21.

=item B<--verbose>

Make the output more verbose.

=back

=head1 DESCRIPTION

A simple script to create a user in the Koha database with superlibrarian permissions

=cut

=head1 AUTHOR

Jonathan Druart <jonathan.druart at bugs.koha-community.org>

=head1 COPYRIGHT

Copyright 2013 BibLibre

=head1 LICENSE

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

Koha is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with Koha; if not, see <http://www.gnu.org/licenses>.
