#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2016 KohaSuomi
# Copyright 2016 Theke Solutions
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Koha::Database;

use Cwd qw(abs_path getcwd);
use Data::Printer colored => 1;
use File::Which;
use Getopt::Long;
use Pod::Usage;
use Template;

my $class;
my $help;

GetOptions(
    "class=s" => \$class,
    "h|help"  => \$help
);

# If we were asked for usage instructions, do it
pod2usage(1) if defined $help or !defined $class;

my $jq = which 'jq';
die "Required jq binary not found on path."
    unless defined $jq;

open (STDOUT,'|jq .');

my @columns
    = Koha::Database->new->schema->resultset($class)->result_source->columns;
my $columns_info = Koha::Database->new->schema->resultset($class)
    ->result_source->columns_info;

my @properties;

foreach my $column (@columns) {
    my $type
        = "[\""
        . column_type_to_swagger_type( $columns_info->{$column}->{data_type} )
        . "\"";
    $type .= ",\"null\""
        if $columns_info->{$column}->{is_nullable};
    $type .= "]";
    push @properties,
        {
        name        => $column,
        type        => $type,
        description => $columns_info->{$column}->{koha_description}
            // "REPLACE WITH A PROPER DESCRIPTION"
        };
}

my $cwd = abs_path($0);
$cwd =~ s/\/koha_object_to_swagger\.pl$//;

my $tt = Template->new(
    {   INCLUDE_PATH => $cwd,
        INTERPOLATE  => 1
    }
) || die "$Template::ERROR\n";

my $vars = { properties => \@properties };

$tt->process( 'tt/swagger-definition.tt', $vars ) || die "$Template::ERROR";

sub column_type_to_swagger_type {
    my ($column_type) = @_;

    my $mapping = {
        ############ BOOLEAN ############
        'bool'    => 'boolean',
        'boolean' => 'boolean',
        'tinyint' => 'boolean',

        ############ INTEGERS ###########
        'bigint'    => 'integer',
        'integer'   => 'integer',
        'int'       => 'integer',
        'mediumint' => 'integer',
        'smallint'  => 'integer',

        ############ NUMBERS ############
        'decimal'          => 'number',
        'double precision' => 'number',
        'float'            => 'number',

        ############ STRINGS ############
        'blob'       => 'string',
        'char'       => 'string',
        'date'       => 'string',
        'datetime'   => 'string',
        'enum'       => 'string',
        'longblob'   => 'string',
        'longtext'   => 'string',
        'mediumblob' => 'string',
        'mediumtext' => 'string',
        'text'       => 'string',
        'tinyblob'   => 'string',
        'tinytext'   => 'string',
        'timestamp'  => 'string',
        'varchar'    => 'string'
    };

    return $mapping->{$column_type} if exists $mapping->{$column_type};
}

1;

=head1 NAME

misc/devel/koha_schema_to_swagger.pl

=head1 SYNOPSIS

    koha_schema_to_swagger.pl --class 'Koha::...'

The command in usually called from the root directory for the Koha source tree.
If you are running from another directory, use the --path switch to specify
a different path.

=head1 OPTIONS

=over 8

=item B<--class>

DBIC schema. (mandatory)

=item B<-h|--help>

prints this help text

=back
