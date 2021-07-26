use strict;
use warnings;
use Text::CSV;
use Cwd;
use LWP::Simple;

my $meta_in  = shift;
my $fasta_in = shift;

#  Specify minimum fraction of population a lineage must be to be included (>=)
my $min_frac = 0.01;

# Create two include files.
# 	"include.txt" is used for augur analysis.  Contains strain names
#
#	"include_gisaid.txt" is used in the NS3 filtering step to ensure that
#	these isolates appear in the input file.  Not strictly necessary, but utilizing
#	EPI_ISL numbers simplifies the filtering slightly
my $include_augur = "./spheres-augur-build/spheres_profile/NS3/include.txt";
my $include_gisaid = "./spheres-augur-build/spheres_profile/NS3/include_gisaid.txt";
# my $include_augur = "include.txt";
# my $include_gisaid = "include_gisaid.txt";

my @required_pangolin_clades = qw (B.1.525 B.1.526 B.1.526.1 B.1.617 B.1.617.1 B.1.617.3 P.2 B.1.1.7 B.1.351 B.1.427 B.1.429 B.1.617.2 P.1);

#  Download and parse current CDC variants

# my $cdc_url = "https://www.cdc.gov/coronavirus/2019-ncov/cases-updates/variant-surveillance/variant-info.html";
# my $html;
# unless ($html = get($cdc_url)) {
# 	print "Failed to download web site\n";
# 	exit 1;
# }
# 
# #  All nextstrain and GISAID clades are considered required.
# #  All VoI and VoC pangolin lineages are considered required
# my @required_pangolin_clades = $html =~ m/^<th class=\"trow-\d+\" scope=\"row\">(.+)<\/th>$/mg;
# 
# unless (@required_pangolin_clades > 0) {
# 	print "No VoI/VoC parsed from web site\n";
# 	exit 1;
# }

my $count = 0;

my $seq_stats = ParseFastaInfo ($fasta_in);

my $clade_stats = GetCladeInfo($meta_in);

my $exemplars = PickExemplars($clade_stats, $count, \@required_pangolin_clades);

# binmode(STDOUT, "encoding(UTF-8)");
open (my $aug_fh, ">", $include_augur) or die $!;
open (my $gis_fh, ">", $include_gisaid) or die $!;

#  Add Wuhan strains to include files
print $aug_fh "Wuhan/Hu-1/2019\nWuhan/WH01/2019\n";
print $gis_fh "EPI_ISL_402125\nEPI_ISL_406798\n";
foreach my $clade (sort keys %$exemplars) {
	#print "$clade\t", join ("\t", @{$exemplars -> {$clade}}), "\n";
	print $aug_fh $exemplars -> {$clade} -> [0], "\n";
	print $gis_fh $exemplars -> {$clade} -> [2], "\n";	
}

sub ParseFastaInfo {
	my $file = shift;

	my $stats;	
	open (my $in_fh, "<", $file) or die $!;
	
	my $name;
	
	while (my $line = <$in_fh>) {
		chomp $line;
		$line =~ s/\R+//g;
		if ($line =~ m/^>(.+)/) {
# 			print "$count $name " . $stats -> {$name} . "\n";
			$name = $1;
			$count++;			
# 			if ($count == 10000) {
# 				return $stats;
# 			}
		}
		else {
			$line = uc($line);
			$line =~ s/[^ATCG]//g;
			$stats -> {$name} += length $line;
		}
	}
	close $in_fh;
	return $stats;
}

sub GetCladeInfo {
	my $file = shift;
	
	my $clades;
	my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1, sep_char => "\t" });
	open (my $in_fh, "<:encoding(utf8)", $file) or die $!;
	my $header = $csv->getline ($in_fh);
	while (my $row = $csv->getline ($in_fh)) {
		if ((defined $row -> [17]) && ($row -> [17] =~ m/\S+/)) {
	    	my $nextstrain_clade = "ns_" . $row -> [17];
	    	my $name = $row -> [0];
	    	if (exists $seq_stats -> {$name}) {
	    		push (@$row, $seq_stats ->{$name});
	    		push(@{$clades -> {$nextstrain_clade}}, $row)
    		}	    	
    	}
		if ((defined $row -> [18]) && ($row -> [18] =~ m/\S+/)) {                         		    	
	    	my $pangolin_clade = "pg_" . $row -> [18];	    		    	
	    	my $name = $row -> [0];                     	    
	    	if (exists $seq_stats -> {$name}) {           
	    		push (@$row, $seq_stats ->{$name});          
	    		push(@{$clades -> {$pangolin_clade}}, $row)
    		}
		}
		if ((defined $row -> [19]) && ($row -> [19] =~ m/\S+/)) {                         		
	    	my $gisaid_clade = "ga_" . $row -> [19];	    	 	
	    	my $name = $row -> [0];                     	                                         
	    	if (exists $seq_stats -> {$name}) {              	    
	    		push (@$row, $seq_stats ->{$name});             	
	    		push(@{$clades -> {$gisaid_clade}}, $row)   	    
    		}                                                	    
		}
	} 
	close $in_fh;
	return $clades;
}

sub PickExemplars {
	my $clades = shift;
	my $count = shift;
	my $required_clades = shift;
	
	my $exemplars;
	
	my $required_clades_lookup;
	foreach my $required_clade (@$required_clades) {
		$required_clade = "pg_" . $required_clade;
		$required_clades_lookup	-> {$required_clade} = 0;
	} 	
	foreach my $clade (keys %$clades) {
		my $observed = @{$clades -> {$clade}};
		my $frac = $observed/$count;
		unless ($clade =~ m/^pg_/) {
			$required_clades_lookup -> {$clade} = $frac;
			next;
		}

		if ($frac >= $min_frac) {
			$required_clades_lookup -> {$clade} = $frac;
		}
	}

	foreach my $clade (keys %$required_clades_lookup) {
		if (exists $clades -> {$clade}) {
			my @isolates = sort SortSizeDate (@{$clades -> {$clade}});
			$exemplars -> {$clade} = $isolates[0];
		}
	}
			
	
	return $exemplars; 			 
		
}
sub SortSizeDate {
	my $a_val = $a ->[-1];
	my $b_val = $b ->[-1];

	# Return biggest	
	if ($a_val < $b_val) {
		return 1;
	}
	elsif ($b_val < $a_val) {
		return -1;
	}
	# If tied, return oldest
	else {
		#Check if date defined
		unless ((defined $a -> [4]) && (defined $b -> [4])) {
			return 0;
		}
		unless (defined $a -> [4]) {
			return 1;
		}
		unless (defined $b -> [4]) {
			return -1;
		}		
		my $a_date_string = $a -> [4];
		$a_date_string =~ s/\//-/g;
		$a_date_string =~ s/XX/99999999/g;
		my $b_date_string = $b -> [4];
		$b_date_string =~ s/\//-/g;
		$b_date_string =~ s/XX/99999999/g;				
		my @a_date = split ("-", $a_date_string);	
		my @b_date = split ("-", $b_date_string);
		
		if (@a_date< 3) {
			$a_date[1] = 99;
			$a_date[2] = 99;
		}
		if (@b_date< 3) {
			$b_date[1] = 99;
			$b_date[2] = 99;
		}			
		
		if ($a_date[2] < $b_date[2]){
			return -1;
		}
		elsif ($b_date[2] < $a_date[2]){
			return 1;
		}
		elsif ($a_date[0] < $b_date[0]){
			return -1;
		}
		elsif ($b_date[0] < $a_date[0]){
			return 1;
		}
		elsif ($a_date[1] < $b_date[1]){
			return -1;
		}
		elsif ($b_date[1] < $a_date[1]){
			return 1;
		}
		else {
			return 0;
		}
	}
}			 
				
		