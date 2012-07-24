use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#

=head1 ous_with_trait

Example:

    ous_with_trait [arguments] < input > output

The standard input should be a tab-separated table (i.e., each line
is a tab-separated set of fields).  Normally, the last field in each
line would contain the identifer. If another column contains the identifier
use

    -c N

where N is the column (from 1) that contains the identifier.

This is a pipe command. The input is taken from the standard input, and the
output is to the standard output.

=head2 Documentation for underlying call

This script is a wrapper for the CDMI-API call ous_with_trait. It is documented as follows:



=over 4

=item Parameter and return types

=begin html

<pre>
$genome is a genome
$trait is a trait
$measurement_type is a measurement_type
$min_value is a float
$max_value is a float
$return is a reference to a list where each element is a reference to a list containing 2 items:
	0: an ou
	1: a measurement_value
genome is a string
trait is a string
measurement_type is a string
ou is a string
measurement_value is a float

</pre>

=end html

=begin text

$genome is a genome
$trait is a trait
$measurement_type is a measurement_type
$min_value is a float
$max_value is a float
$return is a reference to a list where each element is a reference to a list containing 2 items:
	0: an ou
	1: a measurement_value
genome is a string
trait is a string
measurement_type is a string
ou is a string
measurement_value is a float


=end text

=back

=head2 Command-Line Options

=over 4

=item -c Column

This is used only if the column containing the identifier is not the last column.

=item -i InputFile    [ use InputFile, rather than stdin ]

=back

=head2 Output Format

The standard output is a tab-delimited file. It consists of the input
file with extra columns added.

Input lines that cannot be extended are written to stderr.

=cut

use SeedUtils;

my $usage = "usage: ous_with_trait [-c column] < input > output";

use Bio::KBase::CDMI::CDMIClient;
use Bio::KBase::Utilities::ScriptThing;

my $column;

my $input_file;

my $kbO = Bio::KBase::CDMI::CDMIClient->new_for_script('c=i' => \$column,
				      'i=s' => \$input_file);
if (! $kbO) { print STDERR $usage; exit }

my $ih;
if ($input_file)
{
    open $ih, "<", $input_file or die "Cannot open input file $input_file: $!";
}
else
{
    $ih = \*STDIN;
}

while (my @tuples = Bio::KBase::Utilities::ScriptThing::GetBatch($ih, undef, $column)) {
    my @h = map { $_->[0] } @tuples;
    my $h = $kbO->ous_with_trait(\@h);
    for my $tuple (@tuples) {
        #
        # Process output here and print.
        #
        my ($id, $line) = @$tuple;
        my $v = $h->{$id};

        if (! defined($v))
        {
            print STDERR $line,"\n";
        }
        elsif (ref($v) eq 'ARRAY')
        {
            foreach $_ (@$v)
            {
                print "$line\t$_\n";
            }
        }
        else
        {
            print "$line\t$v\n";
        }
    }
}