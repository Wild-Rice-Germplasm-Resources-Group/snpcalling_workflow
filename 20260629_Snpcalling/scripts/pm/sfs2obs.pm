package sfs2obs;

require Exporter;
use Carp;
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
            conver_sfs2obs_old
			conver_sfs2obs
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(conver_sfs2obs conver_sfs2obs_old);


use v5.24;
use zzIO;



sub conver_sfs2obs {
	my ($file, $pop1_num, $out, $need_rev, $pop0_i, $pop1_i)=@_;
	$pop0_i //= 0;
	$pop1_i //= 1;
	$need_rev //= 0;
    #model_jointDAFpop1_0.obs
	unless( -e $file && $pop1_num ) {
		die "Usage: <angsd file> <ind number of pop1> [rev?] [pop0_i] [pop0_i]";
	}

    my $I = open_in_fh($file);
	my @data_raw;
	while(<$I>){
	    chomp;
        next unless defined $_;
	    my @a=split(/\s+/);
	    for(my $i=0;$i<@a;$i++){
	        $data_raw[$i]+=$a[$i];
	    }
	}
	close $I;

	my @data;
	my $d0=0;
	my $d1=0;
	for(my $i=0;$i<scalar @data_raw ;$i++) {
		if( $d1==($pop1_num) ) {
			$d1=0;
			$d0++;
			redo;
		}
		$data[$d0][$d1] = $data_raw[$i];
		$d1++;
	}
	my $data_final = $need_rev==1 ? &revert_matris(\@data) : \@data;
	&print_obs_($out, $data_final, $pop1_num, $pop0_i, $pop1_i);
}



sub revert_matris {
	my $in = shift or die;
	my $xm= scalar @$in;
	my $ym=-1;
	my @ret;
	for (my $x; $x<$xm; $x++) {
		my $ym_now = scalar $$in[$x]->@*;
		if ($ym== -1) {
			$ym = $ym_now;
		} else {
			die "??  $ym != $ym_now" if $ym != $ym_now;
		}
		for (my $y; $y<$ym; $y++) {
			die "??? " if exists $ret[$y][$x];
			$ret[$y][$x] = $$in[$x][$y];
		}
	}
	return \@ret;
}

sub print_obs_ {
	my ($out, $dat, $pop1_num, $pop0_i, $pop1_i) = @_;
	my $O = open_out_fh($out);
	say $O "1 observation";
	my $d1m = scalar @$dat-1;
	my $d0m = -1;
	foreach my $d1 (0..$d1m) {
		my $d0m_now = scalar $$dat[$d1]->@*;
		if ($d0m== -1) {
			$d0m = $d0m_now;
		} else {
			die "??  $d0m != $d0m_now ; d1=$d1 ; $$dat[$d1]->@*" if $d0m != $d0m_now;
		}
	}
	my @first_line=("");
	for(my $i=0; $i<$d0m; $i++){
	    my $x="d${pop0_i}_$i";
	    push @first_line, $x;
	}

	say $O join "\t",@first_line;

	for (my $i=0; $i<=$d1m; $i++) {
		say $O join "\t", "d${pop1_i}_$i", $$dat[$i]->@*;
	}
	close $O;
}


1;


=old

############### pop1_num is 2*count+1
sub conver_sfs2obs_old {
	my ($file, $pop1_num, $out)=@_;
    #model_jointDAFpop1_0.obs
	die "Usage: $0 <angsd file> <ind number of pop1>" if(!-e $file || !$pop1_num);

	#open(I,"< $file");
    my $I = open_in_fh($file);
    my $O = open_out_fh($out);
	#open(O,"> $out");
	my @data;
	while(<$I>){
	    chomp;
        next unless $_;
	    my @a=split(/\s+/);
	    for(my $i=0;$i<@a;$i++){
	        $data[$i]+=$a[$i];
	    }
	}
	close $I;

	my $control=0;
	my @line=();
	print $O "1 observation\n";
	my @first_line=("");
	for(my $i=0;$i<$pop1_num;$i++){
	    my $x="d0_".$i;
	    push @first_line,$x;
	}
	print $O join "\t",@first_line,"\n";
	my $j=0;
	for(my $i=0;$i<@data;$i++){
	    push @line,$data[$i];
	    $control++;
	    if($control==($pop1_num)){
	        my $y="d1_".$j;
	        print $O "$y\t";
	        print $O join "\t",@line,"\n";
	        @line=();
	        $control=0;
	        $j++;
	    }
	}
	close $O;
}
