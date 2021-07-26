use strict;
use warnings;
use Text::CSV;
use File::DirList;
use File::Path;
use Cwd;

my $meta_in  = shift;
my $fasta_in = shift;

my $include_gisaid = "./spheres-augur-build/spheres_profile/NS3/include_gisaid.txt";
# my $include_gisaid = "include_gisaid.txt";
# my $ns3_list = "ns3_isolates.tsv";
my $ns3_list = "./spheres-augur-build/spheres_profile/NS3/ns3_isolates.tsv";


my $fasta_out = "ns3_sequences.fasta";
my $meta_out = "ns3_metadata.tsv";

# Force inclusion of "include" isolates
my %ns3_isolates;
open (my $include_fh, "<", $include_gisaid) or die $!;
while (my $line = <$include_fh>) {
	$line =~ s/\R+//g;
	chomp $line;
	$ns3_isolates{$line} = 0;
} 

open (my $in_fh, "<", $ns3_list) or die $!;
my $header = <$in_fh>;
while (my $row = <$in_fh>) {
	$row =~ s/\R+//g;
	chomp $row;
	my @vals = split ("\t", $row);
	if ( (exists $vals[1]) && ($vals[1] =~ m/\S+/) ) {
		$ns3_isolates{$vals[1]} = 0;
	}
}
chdir "./spheres-augur-build/data";
open (my $meta_fh, "<", $meta_in) or die $!;
open (my $meta_out_fh, ">", $meta_out) or die $!;

my $title = <$meta_fh>;
chomp $title;
$title =~ s/\R+//g;
print $meta_out_fh "$title\n";

my %seq_names;

while (my $line = <$meta_fh>) {
	chomp $line;
	$line =~ s/\R+//g;
	my @fields = split ("\t", $line);
	my $id = $fields[2];
	my $name = $fields[0];
	
	if (exists $ns3_isolates{$id}) {
		print $meta_out_fh "$line\n";
		$ns3_isolates{$id}++;
		$seq_names{$name} = 0;
	}
}

close $meta_fh;
close $meta_out_fh;


open (my $seq_fh, "<", $fasta_in) or die $!;
open (my $fasta_out_fh, ">", $fasta_out) or die $!;

my $name;
my $seq;

while (my $line = <$seq_fh>) {
	chomp $line;
	$line =~ s/\R+//g;
	if ($line =~ m/>(.+)/) {
		if (defined $name) {
			if (exists $seq_names{$name}) {
				print $fasta_out_fh ">$name\n$seq\n";
				$seq = '';
			}
			else {
				$seq = '';
			}
		}
		$name = $1;
	}
	else {
		$seq .= $line;
	}
}
if (defined $seq) {
	if (exists $seq_names{$name}) {
		print $fasta_out_fh ">$name\n$seq\n";
		$seq = '';
	}
}
close $seq_fh;
close $fasta_out_fh;
