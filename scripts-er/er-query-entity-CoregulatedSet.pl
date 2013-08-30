use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 NAME

er-query-entity-CoregulatedSet

=head1 SYNOPSIS

er-query-entity-CoregulatedSet [--is field,value] [--like field,value] [--op operator,field,value]

=head1 DESCRIPTION

Query the entity CoregulatedSet. Results are limited using one or more of the query flags:

=over 4

=item the C<--is> flag to match for exact values; 

=item the C<--like> flag for SQL LIKE searches, or 

=item the C<--op> flag for making other comparisons. 

=back

We need to represent sets of genes that are coregulated via
some regulatory mechanism.  In particular, we wish to represent
genes that are coregulated using transcription binding sites and
corresponding transcription regulatory proteins. We represent a
coregulated set (which may, or may not, be considered a regulon)
using CoregulatedSet.

Example:

    er-query-entity-CoregulatedSet -is id,exact-match-value -a > records

=head2 Related entities

The CoregulatedSet entity has the following relationship links:

=over 4
    
=item IsControlledUsing Feature

=item IsRegulatedSetOf Feature

=item WasFormulatedBy Source


=back

=head1 COMMAND-LINE OPTIONS

er-query-entity-CoregulatedSet [arguments] > records

=over 4

=item --is field,value

Limit the results to entities where the given field has the given value.

=item --like field,value

Limit the results to entities where the given field is LIKE (in the sql sense) the given value.

=item --op operator,field,value

Limit the results to entities where the given field is related to the given value based on the given operator.

The operators supported are as follows. We provide text based alternatives to the comparison
operators so that extra quoting is not required to keep the command-line shell from 
confusing them with shell I/O redirection operators.

=over 4

=item < or lt

=item > or gt

=item <=  or le

=item >= or ge

=item =

=item LIKE

=back

=item --a

Return all fields.

=item --show-fields

Display a list of the fields available for use.

=item --fields field-list

Choose a set of fields to return. Field-list is a comma-separated list of 
strings. The following fields are available:

=over 4

=item source_id

=item binding_location

=back    
   
=back

=head1 AUTHORS

L<The SEED Project|http://www.theseed.org>

=cut

use Bio::KBase::CDMI::CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'source_id', 'binding_location' );
my %all_fields = map { $_ => 1 } @all_fields, 'id';

our $usage = <<'END';
er-query-entity-CoregulatedSet [arguments] > records

--is field,value
    Limit the results to entities where the given field has the given value.

--like field,value
    Limit the results to entities where the given field is LIKE (in the sql sense) the given value.

--op operator,field,value
    Limit the results to entities where the given field is related to
    the given value based on the given operator.

    The operators supported are as follows. We provide text based
    alternatives to the comparison operators so that extra quoting is
    not required to keep the command-line shell from confusing them
    with shell I/O redirection operators.

        < or lt
        > or gt
        <=  or le
        >= or ge
        =
        LIKE

-a
    Return all fields.

--show-fields
    Display a list of the fields available for use.

--fields field-list
    Choose a set of fields to return. Field-list is a comma-separated list of 
    strings. The following fields are available:

        source_id
        binding_location
END

my $a;
my $f;
my @fields;
my $help;
my $show_fields;
my @query_is;
my @query_like;
my @query_op;

my %op_map = ('>', '>',
	      'gt', '>',
	      '<', '<',
	      'lt', '<',
	      '>=', '>=',
	      'ge', '>=',
	      '<=', '<=',
	      'le', '<=',
	      'like', 'LIKE',
	      );

my $geO = Bio::KBase::CDMI::CDMIClient->new_get_entity_for_script("all-fields|a" => \$a,
								  "show-fields"	 => \$show_fields,
								  "help|h"	 => \$help,
								  "is=s"	 => \@query_is,
								  "like=s"	 => \@query_like,
								  "op=s"	 => \@query_op,
								  "fields=s"	 => \$f);

if ($help)
{
    print $usage;
    exit 0;
}
elsif ($show_fields)
{
    print STDERR "Available fields:\n";
    print STDERR "\t$_\n" foreach @all_fields;
    exit 0;
}

if (@ARGV != 0 || ($a && $f))
{
    print STDERR $usage, "\n";
    exit 1;
}

if ($a)
{
    @fields = @all_fields;
}
elsif ($f) {
    my @err;
    for my $field (split(",", $f))
    {
	if (!$all_fields{$field})
	{
	    push(@err, $field);
	}
	else
	{
	    push(@fields, $field);
	}
    }
    if (@err)
    {
	print STDERR "er-all-entities-CoregulatedSet: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
}

my @qry;

for my $ent (@query_is)
{
    my($field,$value) = split(/,/, $ent, 2);
    if (!$all_fields{$field})
    {
	die "$field is not a valid field\n";
    }
    
    push(@qry, [$field, '=', $value]);
}

for my $ent (@query_like)
{
    my($field,$value) = split(/,/, $ent, 2);
    if (!$all_fields{$field})
    {
	die "$field is not a valid field\n";
    }
    
    push(@qry, [$field, 'LIKE', $value]);
}

for my $ent (@query_op)
{
    my($op,$field,$value) = split(/,/, $ent, 3);

    if (!$all_fields{$field})
    {
	die "$field is not a valid field\n";
    }
    my $mapped_op = $op_map{lc($op)};
    if (!$mapped_op)
    {
	die "$op is not a valid operator\n";
    }
    
    push(@qry, [$field, $mapped_op, $value]);
}

my $h = $geO->query_entity_CoregulatedSet(\@qry, \@fields );

while (my($k, $v) = each %$h)
{
    print join("\t", $k, map { ref($_) eq 'ARRAY' ? join(",", @$_) : $_ } @$v{@fields}), "\n";
}
