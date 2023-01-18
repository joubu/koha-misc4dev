#!/usr/bin/perl

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

BEGIN {
    $ENV{KOHA_DB_DO_NOT_RAISE_OR_PRINT_ERROR} = 1;
};

use Getopt::Long;
use Pod::Usage;

use C4::Installer;
use C4::Context;

use Koha;

use Koha::SearchEngine::Elasticsearch;

=head1 NAME

populate_db.pl - Load included sample data into the DB

=head1 SYNOPSIS

populate_db.pl [--marcflavour MARCFLAVOUR]

 Options:
   --help                Brief help message
   --marcflavour m       Specify the MARC flavour to use (MARC21|UNIMARC). Defaults
                                to MARC21.
   --opac-base-url o     Specify the OPAC's base URL.
   --intranet-base-url o Specify the intranet's base URL.
   -v                    Be verbose.

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--marcflavour>

Lets you choose the desired MARC flavour for the sample data. Valid options are MARC21 and UNIMARC.
It defaults to MARC21.

=item B<--verbose>

Make the output more verbose.

=back

=cut

my $help;
my $verbose;
my $marcflavour = 'MARC21';
my $opac_base_url = 'catalogue.kohadev.vm';
my $intranet_base_url = 'pro.kohadev.vm';

GetOptions(
    'help|?'              => \$help,
    'verbose'             => \$verbose,
    'marcflavour=s'       => \$marcflavour,
    'opac-base-url=s'     => \$opac_base_url,
    'intranet-base-url=s' => \$intranet_base_url
) or pod2usage;

if ( $help ) {
    pod2usage;
}

$marcflavour = uc($marcflavour);

if (     $marcflavour ne 'MARC21'
     and $marcflavour ne 'UNIMARC' ) {
    say "Invalid MARC flavour '$marcflavour' passed.";
    pod2usage;
}

our $root      = C4::Context->config('intranetdir');
our $data_dir  = "$root/installer/data/mysql";
our $installer = C4::Installer->new;
my $koha_structure_file = "$data_dir/kohastructure.sql";

my @installer_files = qw(
    sysprefs.sql
    subtag_registry.sql
    auth_val_cat.sql
    message_transport_types.sql
    sample_notices_message_attributes.sql
    sample_notices_message_transports.sql
    keyboard_shortcuts.sql
    userflags.sql
    userpermissions.sql
    audio_alerts.sql
    account_offset_types.sql
    account_credit_types.sql
    account_debit_types.sql
);

my (
    @sample_files_mandatory,     @sample_lang_files_mandatory,
    @sample_lang_files_optional, @marc_sample_files_mandatory
);
my $version = get_version();
$version =~ s|\.||g;
if ( $version < 211200036 ) {
    my $lang = $marcflavour eq 'UNIMARC' ? 'fr-FR' : 'en';
    # Looking in installer/data/mysql for backward compatibility
    @sample_files_mandatory = map { -f $root . "/installer/data/mysql/mandatory/$_" ? $root . "/installer/data/mysql/mandatory/$_" : $root . "/installer/data/mysql/$_"} @installer_files;

    my @marc21_sample_lang_files_mandatory    = ( glob( $root . "/installer/data/mysql/$lang/mandatory/*.sql"), glob( $root . "/installer/data/mysql/$lang/mandatory/*.yml" ) );
    my @marc21_sample_lang_files_optional     = ( glob( $root . "/installer/data/mysql/$lang/optional/*.sql"), glob( $root . "/installer/data/mysql/$lang/optional/*.yml" ) );

    my @unimarc_sample_lang_files_mandatory    = ( glob( $root . "/installer/data/mysql/fr-FR/1-Obligatoire/*.sql"), glob( $root . "/installer/data/mysql/fr-FR/1-Obligatoire/*.yml" ) );
    my @unimarc_sample_lang_files_optional     = ( glob( $root . "/installer/data/mysql/fr-FR/2-Optionel/*.sql"), glob( $root . "/installer/data/mysql/fr-FR/2-Optionel/*.yml" ),
                                                   glob( $root . "/installer/data/mysql/fr-FR/3-LecturePub/*.sql"), glob( $root . "/installer/data/mysql/fr-FR/3-LecturePub/*.ymL" ),
                                                 );

    @sample_lang_files_mandatory = $marcflavour eq 'UNIMARC' ? @unimarc_sample_lang_files_mandatory : @marc21_sample_lang_files_mandatory;
    @sample_lang_files_optional = $marcflavour eq 'UNIMARC' ? @unimarc_sample_lang_files_optional : @marc21_sample_lang_files_optional;

    my @marc21_marc_sample_files_mandatory  = ( glob( $root . "/installer/data/mysql/$lang/marcflavour/marc21/*/*.sql"), glob( $root . "/installer/data/mysql/$lang/marcflavour/marc21/*/*.yml" ) );
    my @unimarc_marc_sample_files_mandatory = ( glob( $root . "/installer/data/mysql/$lang/marcflavour/unimarc_complet/*/*.sql"), glob( $root . "/installer/data/mysql/$lang/marcflavour/unimarc_complet/*/*.yml" ) );

    @marc_sample_files_mandatory = $marcflavour eq 'UNIMARC' ? @unimarc_marc_sample_files_mandatory : @marc21_marc_sample_files_mandatory;
} else {
    my $lang = 'en';
    @sample_files_mandatory = map { $root . "/installer/data/mysql/mandatory/$_" } @installer_files;

    # Only yml files should exist here, but it's certainly better to continue supporting sql files
    @sample_lang_files_mandatory    = ( glob( $root . "/installer/data/mysql/$lang/mandatory/*.sql"), glob( $root . "/installer/data/mysql/$lang/mandatory/*.yml" ) );
    @sample_lang_files_optional     = ( glob( $root . "/installer/data/mysql/$lang/optional/*.sql"), glob( $root . "/installer/data/mysql/$lang/optional/*.yml" ) );

    my @marc21_marc_sample_files_mandatory  = ( glob( $root . "/installer/data/mysql/$lang/marcflavour/marc21/*/*.sql"), glob( $root . "/installer/data/mysql/$lang/marcflavour/marc21/*/*.yml" ) );
    my @unimarc_marc_sample_files_mandatory = ( glob( $root . "/installer/data/mysql/$lang/marcflavour/unimarc/*/*.sql"), glob( $root . "/installer/data/mysql/$lang/marcflavour/unimarc/*/*.yml" ) );

    @marc_sample_files_mandatory = $marcflavour eq 'UNIMARC' ? @unimarc_marc_sample_files_mandatory : @marc21_marc_sample_files_mandatory;
}

initialize_data();
#update_database();
# Set staffClientBaseURL and OPACBaseURL
C4::Context->set_preference( 'staffClientBaseURL', $intranet_base_url );
C4::Context->set_preference( 'OPACBaseURL',        $opac_base_url );

sub initialize_data {
    say "Inserting koha db structure..."
        if $verbose;
    my $error = $installer->load_db_schema;
    die $error if $error;

    for my $f (@sample_files_mandatory) {
        execute_sqlfile($f);
    }

    for my $f (@sample_lang_files_mandatory) {
        execute_sqlfile($f);
    }

    for my $f (@sample_lang_files_optional) {
        execute_sqlfile($f);
    }

    for my $f (@marc_sample_files_mandatory) {
        execute_sqlfile($f);
    }

    # set marcflavour
    my $dbh = C4::Context->dbh;

    say "Setting the MARC flavour on the sysprefs..."
        if $verbose;
    $dbh->do(qq{
        INSERT INTO `systempreferences` (variable,value,explanation,options,type)
        VALUES ('marcflavour',?,'Define global MARC flavor (MARC21 or UNIMARC) used for character encoding','MARC21|UNIMARC','Choice')
    },undef,$marcflavour);

    # set version
    my $version = get_version();
    say "Setting Koha version to $version..."
        if $verbose;
    $dbh->do(qq{
        INSERT INTO systempreferences(variable, value, options, explanation, type)
        VALUES ('Version', '$version', NULL, 'The Koha database version. WARNING: Do not change this value manually, it is maintained by the webinstaller', NULL)
    });

    # Initialize ES mappings
    Koha::SearchEngine::Elasticsearch->reset_elasticsearch_mappings;
}

sub execute_sqlfile {
    my ($filepath) = @_;
    unless ( -f $filepath ) {
        ( my $yml_filepath = $filepath ) =~ s|\.sql$|.yml|;
        unless ( -f $yml_filepath ) {
            say "Skipping $filepath" if $verbose;
            return;
        }
        $filepath = $yml_filepath;
    }
    say "Inserting $filepath..."
        if $verbose;
    my $error = $installer->load_sql($filepath);
    die $error if $error;
}

sub get_version {
    my $version = $Koha::VERSION;
    $version =~ s/(\d)\.(\d{2})\.(\d{2})\.(\d{3})/$1.$2$3$4/;
    return $version;
}

sub update_database {
    my $update_db_path = $root . '/installer/data/mysql/updatedatabase.pl';
    say "Updating database..."
        if $verbose;
    my $file = `cat $update_db_path`;
    $file =~ s/exit;//;
    eval $file;
    if ($@) {
        die "updatedatabase.pl process failed: $@";
    } else {
        say "updatedatabase.pl process succeeded.";
    }
}
