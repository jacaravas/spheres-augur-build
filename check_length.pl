use strict;
use warnings;

my $file = shift;

open (my $in_fh, "<", $file) or die $!;

my $lengths;

my $seq;
my $id;

while (my $line = <$in_fh>) {
	chomp $line;
	$line =~ s/\R+//g;
	if ($line =~ m/>(.+)/) {
		$id = $1;
# 		print "$id\n";
		if (defined $seq) {
			my $seq_length = length $seq;
# 			print "$seq_length\t$seq\n";
			$lengths -> {$seq_length} ++;
			$seq = '';
		}
	}
	else {
		$seq .= $line;
# 		print $seq;
	}
}

foreach my $length (sort keys %$lengths) {
	print "$length\t", $lengths -> {$length}, "\n";
}