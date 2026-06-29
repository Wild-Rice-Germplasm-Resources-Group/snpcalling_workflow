
package zzToolkit;
use strict;

require Exporter;
use Statistics::TTest;

use vars qw(
  @ISA
  %EXPORT_TAGS
  @EXPORT_OK
  @EXPORT
);

@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [
        qw(
            t_test
            read_list
            read_gcstat_dp
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(t_test read_list read_gcstat_dp);


sub kbytes2str {
    my $kbytes = shift;
    if ($kbytes == 0) {
        return sprintf("%.2f", 0.0);
    }
    my $mul = 1024;
    my $exp = int(log($kbytes) / log($mul));
    my @pre = (qw/ K M G T P E /);
    my $pre = $pre[$exp];
    return sprintf("%.2f %sB", ($kbytes / pow($mul, $exp)), $pre ? $pre : "");
}

sub t_test($$$) {
	#my ($a,$b)=@_;
	my $a = shift or die;
	my $b = shift or die;
	my $t_significance = shift or 0.05;
	my $ttest = new Statistics::TTest; 
	$ttest->set_significance($t_significance);
	$ttest->load_data($a,$b); 
	my $t = $ttest->null_hypothesis();
	return 1 if $t eq 'not rejected'; #same
	return 0 if $t eq 'rejected'; #rejected, not same
	return undef;
}


sub read_list($) {
	my $file_path = $_[0];
	my @ret;
	open (my $t,"< $file_path") or die "can't open $file_path, $!";
	while (<$t>) {
		chomp;
		push (@ret,$_) if $_;
	}
	close $t;
	return @ret;
}

sub read_gcstat_dp{
	my ($in)=shift or die;
	my %r;
	my $D;
	open ($D,"$in") or die"no $in\n";
	while (<$D>) {
		chomp;
		next if /^#/;
		my @a=split(/\s+/,$_);
		$r{$a[0]}=$a[5];
		# $r{$a[0]}=$a[6];
	}
	close $D;
	return %r;
}

sub cal_mean($) {
	my $in=shift or die;
	my $ret;
	if (ref $in eq 'HASH') {
		return &cal_mean([@$in{keys %$in}]);
	} elsif (ref $in eq 'ARRAY') {
		my ($add, $count)=(0,0);
		foreach (@$in) {
			$add+=$_;
			$count+=1;
		}
		return $add/$count;
	} else {
		die $in . ref $in;
	}
}

sub cal_sd($) {
	my ($in, $mean)=@_;
	my $ret;
	if (ref $in eq 'HASH') {
		return &cal_sd( [@$in{keys %$in}], $mean );
	} elsif (ref $in eq 'ARRAY') {
		$mean = &cal_mean($in) unless defined $mean;
		my ($add, $count)=(0,0);
		foreach my $value (@$in) {
			$add += ($value - $mean)**2;
			$count+=1;
		}
		return ($add/$count)**0.5;
	} else {
		die;
	}
} 

1;
