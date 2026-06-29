#!/usr/bin/env perl
#===============================================================================
#
#         FILE: 04-05.MISS_SNP_ALL.pl
#
#        USAGE: ./04-05.MISS_SNP_ALL.pl
#
#  DESCRIPTION:  !!! By group !!! Muti-CPU !!!
#			删除丢失10%以上的; 删除深度异常位点比例超过10%的位点信息; 
#			req; INDEL; 'PASS'; QUAL<20; 过滤len(REF|ALT)>1
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Zeyu Zheng (Lanzhou University), zhengzy2014@lzu.edu.cn
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 10/24/2017 07:23:37 PM
#     REVISION: ---
#===============================================================================

# java -jar /home/share/software/gatk/GenomeAnalysisTK-3.8-0.jar -T SelectVariants -nt 8 -R xx.fa -V xx.join.raw.vcf.gz -selectType SNP -o xx.join.raw.SNP.vcf.gz

# java -jar /home/share/software/gatk/GenomeAnalysisTK-3.8-0.jar -T SelectVariants -nt 8 -R xx.fa -V xx.join.raw.vcf.gz -selectType INDEL -o xx.join.raw.INDEL.vcf.gz


#use v5.18;
use strict;
use warnings;
use utf8;
#use FileHandle;
use Getopt::Long;
use v5.10;
use zzIO;
use MCE::Flow;
use MCE::Candy;
use List::Util qw/max/;

my $GCstats_file;

my $GCstat_depth_i_col = 7;
my $miss_threshold=1; ##### 删除丢失或深度异常, 10% 以上的
my $args_input = join ' ', $0, @ARGV;

my($in_vcf, $in_indel, $opt_help);
my $type='snp';
my $thread='auto';
my $out_file = '-';
GetOptions (
	'help|h!' => \$opt_help,
	'vcf=s' => \$in_vcf,
	'p=i' => \$thread,
	't=s' => \$type,
	'G=s' => \$GCstats_file,
	'miss_threshold=s' => \$miss_threshold,
	'o=s' => \$out_file,
    'GCstat_depth_i_col=i'=> \$GCstat_depth_i_col,
);

$type = lc($type);
$type = 'snp' if $type eq 'snps';
$type = 'indel' if $type eq 'indels';
die "error type: $type, only snp, indel and samtools are available\n" unless ( $type ~~ [qw/snp indel samtools other/] );

die "usage: perl xxx.pl -vcf raw_snp.vcf.gz [-miss_threshold 1] -t [snp/indel/other] [-p INT] [-G GCstat_file] (| bgzip -c ) > out.vcf\n" if ($opt_help || ! $in_vcf );

my $O = open_out_fh($out_file, 4);


print STDERR "\n** Now in node: ";
print STDERR`hostname`;


foreach ($GCstats_file, $in_vcf){
	next if $in_vcf eq '-';
	die "file not exist: $_\n" unless -e $_;
}


my %dp=&readdp($GCstats_file);
print STDERR "GC: ".join(' ',sort keys %dp)."\n";


my $INVCF = open_in_fh($in_vcf);
my @idline;
print STDERR "Processing snp_vcf: $in_vcf\n";
while ( <$INVCF> ){
	if ( /^##/ ){
		print $O $_;
		next;
	}
	if (/^#/){
		chomp;
		print STDERR $_."\n";
		if (/^#CHROM\s+POS\s+ID\s+REF\s+ALT\s+QUAL\s+FILTER\s+INFO\s+FORMAT\s+\w+/){
			@idline=split(/\s+/,$_);
			print $O join("\t",@idline)."\n";
			last;
		}else{
			print STDERR $_;
			last;
		}
	}
}
die "NO idline: \n" if ! @idline;
my $miss_threshold_now=($#idline-8) * $miss_threshold; ## 删除丢失 ?% 以上的
$miss_threshold_now=int($miss_threshold_now)+1 if $miss_threshold_now>int($miss_threshold_now) + 0.5;


# MCE::Loop::init {
# 		max_workers => $thread, chunk_size => 1
# };
# while(<$INVCF>) {
# 	chomp;
# 	my $result=&flt($_);
# 	say( $result ) if $result;
# } 


if ($thread eq 1) {
	while(<$INVCF>) {
		my $result = &flt($_);
		say $O $result if defined $result;
	}
	exit();
}

sub flt_mce {
	my ( $mce, $chunk_ref, $chunk_id ) = @_;
	my $result = &flt($$chunk_ref[0]);
	if (defined $result) {
		$mce->gather($chunk_id, $result, "\n") 
	} else {
		$mce->gather($chunk_id);
	}
}

mce_flow_f {
    chunk_size => 1,
    max_workers => $thread,  
    #max_workers => 1,
	#use_slurpio => 0,
    gather => MCE::Candy::out_iter_fh($O)
    },
    \&flt_mce,
    $INVCF;

close $INVCF;

print STDERR "tabix $out_file\n";

THEEND:

print STDERR "\n** ALL Done\n";
print STDERR `date`;

exit 0;



sub readdp{
	my ($in)=@_;
	my %r;
	my $D;
	open ($D,"$in")||die"no $in\n";
	while (<$D>) {
		chomp;
		next if /^#/;
		my @a=split(/\s+/,$_);
		$r{$a[0]}=$a[$GCstat_depth_i_col];
		# $r{$a[0]}=$a[6];
	}
	close $D;
	return %r;
}




sub flt{
	my $line=$_;
	chomp $line;
	return undef unless $line;
	my @a=split(/\s+/,$line);
	return undef if /^#/;
	##  VCF:
	##   0    1   2  3    4   5      6     7    8      9...
	## CHROM POS ID REF  ALT QUAL FILTER INFO FORMAT   ...
	#my %info=split(/[=;]/,$a[7]);
	my $info = &get_info($a[7]);
	## 舍去 QD < 2.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0

# For SNPs:
# QD < 2.0
# MQ < 40.0
# FS > 60.0
# SOR > 3.0
# MQRankSum < -12.5
# ReadPosRankSum < -8.0
# If your callset was generated with UnifiedGenotyper for legacy reasons, you can add HaplotypeScore > 13.0.

# For indels:
# QD < 2.0
# ReadPosRankSum < -20.0
# InbreedingCoeff < -0.8
# FS > 200.0
# SOR > 10.5
	#return undef if ( length($a[3])>1 || length($a[4])>1 );
	my @alts = ($a[3], split(',',$a[4]));
	if ($type eq 'snp') {
		foreach my $alt (@alts) {
			return undef if length($alt)!=1;
		}
		return undef if ( exists($$info{'QD'}) && $$info{'QD'} < 2 );
		return undef if ( exists($$info{'FS'}) && $$info{'FS'} > 60 );
		return undef if ( exists($$info{'MQ'}) && $$info{'MQ'} < 40 );
		return undef if ( exists($$info{'MQRankSum'}) && $$info{'MQRankSum'} < -12.5 );
		return undef if ( exists($$info{'ReadPosRankSum'}) && $$info{'ReadPosRankSum'} < -8 );
		return undef if ( exists($$info{'SOR'}) && $$info{'SOR'} > 3 );
		return undef if ( exists($$info{'HaplotypeScore'}) && $$info{'HaplotypeScore'} < 13 );
		return undef if ( $a[5]< 50 );  # QUAL 默认50
	} elsif ($type eq 'indel') {
        #my $reflen = length($a[3]);
        #my $max_alts_len = &get_max_alt_len($a[4]);
		return undef if ( exists($$info{'QD'}) && $$info{'QD'} < 2 );
		return undef if ( exists($$info{'ReadPosRankSum'}) && $$info{'ReadPosRankSum'} < -20 );
		return undef if ( exists($$info{'InbreedingCoeff'}) && $$info{'InbreedingCoeff'} < -0.8 );
		return undef if ( exists($$info{'FS'}) && $$info{'FS'} > 200 );
		return undef if ( exists($$info{'SOR'}) && $$info{'SOR'} > 10.5 );
		return undef if ( $a[5]< 50 );  # QUAL 默认50
	} elsif ($type eq 'other') {
		#
	} elsif ($type eq 'samtools') {
		return undef if ( $a[5]< 20 );  # QUAL 默认20
	} else {
		die;
	}

	


	my $all=0;
	my $alt=0;
	my $DP_num;
	my $GQ_num;
	my $SB_num;
	my @info=split(/:/,$a[8]);
	for (my $ii=0;$ii<@info;$ii++){
		if ($info[$ii] eq 'DP'){
			$DP_num = $ii ;
			next;
		}  elsif($info[$ii] eq 'GQ'){
			$GQ_num = $ii;
			next;
		}
		# }elsif($info[$ii] eq 'SB'){
		# 	$SB_num = $ii;
		# 	next;
		# }
	}
	#say STDERR "no DP_num" unless defined $DP_num;
	my $miss=0;
	for (my $i=9;$i<@a;$i++){
		my $id=$idline[$i];
		my $dp_now=$dp{$id} or die "dp not in list: $id";
		my ($mindp, $maxdp)=(int($dp_now*0.33),$dp_now*3);  ### 默认 DP ÷3 *3
		$mindp = 80 if $mindp>80;
		#$mindp = 4;
		# ($mindp, $maxdp)=(3, 60);  ### 默认 DP ÷3 *3
		$maxdp=int($maxdp)+1 if $maxdp>int($maxdp);
		$mindp=int($mindp);

		if ($a[$i]=~/^\.\/\./){
			#return undef; ###########!!!!!!!!!!!!!!!!!!!!!!!###########!!!!!!!!!
			$miss++;
			next;
		}elsif ( $a[$i] =~ /^(\d+)\/(\d+):/ ) {
			$alt = $alt + $1 + $2;
			$all = $all + 2;
			next unless defined $DP_num;
			my @idinfo=split(/:/,$a[$i]);
			my $iddp=$idinfo[$DP_num] // die "no iddp found: $line";
			$iddp=0 if $iddp eq '.';
			if ( $iddp<$mindp || $iddp>$maxdp || 
				(defined $GQ_num and exists $idinfo[$GQ_num] and $idinfo[$GQ_num]<10) 
				) {  
				$miss++;
				#$a[$i] = './.'.substr($a[$i],3);
				$a[$i] = './.';
				next;
			}
		} elsif ( $a[$i] =~ s#\|#/# ) {
			redo;
		} else{
			die $a[$i];
		}
	}
	#say "$miss $miss_threshold_now";
	return undef if ( $miss > $miss_threshold_now ) ;  ## 删除丢失或深度异常位点比例 ?% 以上的
	return undef if $all==0;
	my $ratio_now = $alt/$all;
	#return undef if ($ratio_now < $ratio_threshold || $ratio_now > (1-$ratio_threshold) ); ### 删除基因频率过低的 10%
	$a[6]='PASS';
	return join("\t",@a);
}


sub get_info() {
	my $in = $_[0];
	my %ret;
	my @a = split ';',$in;
	foreach my $a (@a) {
		my @b = split '=',$a;
		$ret{$b[0]} = defined $b[1] ? $b[1] : 0;
	}
	return \%ret;
}

sub get_max_alt_len() {
    my ($alts) = @_;
    my $maxlen = max map {length $_} split(/,/, $alts);
    return $maxlen;
}

