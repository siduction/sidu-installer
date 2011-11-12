#! /usr/bin/perl
use strict;
my $fdisk = shift;
$fdisk = "fdisk -l |" unless $fdisk;
my $blkid = shift;
$blkid = "/sbin/blkid -c /dev/null|" unless $blkid;

my $verbose = 0;
my $mountpoint = "/tmp/partinfo-mount";
my %months = ( 
	"Jan" => "01",
	"Feb" => "02",
	"Mar" => "03",
	"Apr" => "04",
	"May" => "05",
	"Jun" => "06",
	"Jul" => "07",
	"Aug" => "08",
	"Sep" => "09",
	"Oct" => "10",
	"Nov" => "11",
	"Dec" => "12"
);
if (! -d $mountpoint){
	mkdir $mountpoint;
	print STDERR $mountpoint, " created\n" if $verbose;
}
# get the info from fdisk:
my %devs;
open(CMD, $fdisk) || die "$fdisk failed: $!";
my ($dev, $size, $ptype, $info);
while(<CMD>){
	s/\*/ /;
	if (/^(\S+)\s+\d+\s+\d+\s+(\d+)[+]?\s+([0-9a-fA-F]{1,2})\s+(.*)/){
		$dev = $1;
		$size = $2;
		$ptype = $3;
		$info = $4;
		# forget extended:
		if ($ptype != 5){
			$devs{$dev} = "size:$size\tptype:$ptype\tpinfo:$info";
		}
	}
}
close CMD;

# get the info from blkid

open(CMD, $blkid) || die "$blkid failed: $!";
my %blkids;
my ($label, $uuid, $fs, $info2);
while(<CMD>){
	if (/^(\S+):/){
		$dev = $1;
		$info = '';
		$label = $uuid = $fs = $size = $info = "";
		if (/LABEL="([^"]+)"/){
			$label = "\tlabel:$1";
		}
		if (/TYPE="([^"]+)"/){
			$fs = "\tfs:$1";
		}
		if (/UUID="([^"]+)"/){
			$uuid = "\tuuid:$1";
		}
		if ($devs{$dev} ne ""){
			$info=$devs{$info}
		}
		$info .= &detective($dev, $fs);
		$blkids{$dev} = "$label$fs$uuid$info";
	}
}
close CMD;

# merge the two fields:
foreach $dev (keys %devs){
	$info = $blkids{$dev};
	my $val = $devs{$dev};
	if ($info eq ""){
		$blkids{$dev} = $val;
	} else {
		$size = $ptype = $info2 = "";
		$size = "\t$1" if $val =~ /(size:\d+)/;
		$ptype = "\t$1" if $val =~ /(id:\w+)/;
		$info2 = "\t$1" if $val =~ /(pinfo:[^\t]+)/;
		$blkids{$dev} = "$info$size$ptype$info2"; 
	}
}

my (%sorted, $key);
foreach $dev (keys %blkids){
	if ($dev =~ /(\D+)(\d+)/){
		$key = $1 . sprintf ("%03d", $2);
	} else {
		$key = $dev;
	} 
	$sorted{$key} = $dev;
}
foreach $key (sort keys %sorted){
	$dev = $sorted{$key};
	print $dev, "\t", $blkids{$dev}, "\n";
}
# searches for extended info of a partition
sub detective{
	my $dev = shift;
	my $fs = shift;
	my $info = "";
	system ("mount -o ro $dev $mountpoint");
	if ($fs eq "ntfs" || $fs =~ /^vfat|fat\d/){
		if (-d "$mountpoint/windows/system32"){
			$info .= "\tos:windows";
		}
	}
	if (-d "$mountpoint/etc"){
		$info .= &firstLineOf("$mountpoint/etc/debian_version", "distro");
		$info .= &firstLineOf("$mountpoint/etc/aptosid-version", "subdistro");
		$info .= &firstLineOf("$mountpoint/etc/sidux-version", "subdistro");
		$info .= &firstLineOf("$mountpoint/etc/siduction-version", "subdistro");
		$info .= "\tos:unix" if $info eq "" && -d "$mountpoint/etc/passwd";		
	}
	system ("umount $mountpoint");
	
	if ($fs =~ /fs:ext\d/){
		open(TUNE, "tune2fs -l $dev|");
		my $date;
		while(<TUNE>){
			#Filesystem created:       Sun May  1 07:53:47 2011
			if (/Filesystem created:\s+\w+\s+(\w+)\s+(\d+)\s+\S+\s+(\d+)/){
				my $month = $months{$1};
				$info .= "\tcreated:$3.$month.$2";
			}
			#Last write time:          Thu May 12 00:33:04 2011
			if (/write time:\s+\w+\s+(\w+)\s+(\d+)\s+\S+\s+(\d+)/){
				my $month = $months{$1};
				$info .= "\tmodified:$3.$month.$2";
			}
		}
		close TUNE;
	}
	return $info;
}

sub firstLineOf{
	my $file = shift;
	my $prefix = shift;
	my $rc = "";
	if (-f $file){
		open(INP, $file);
		$rc = "\t$prefix:" . <INP>;
		chomp $rc;
		close INP;
	}
	return $rc;
}