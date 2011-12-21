#! /usr/bin/perl
use strict;
my $gdisk = shift;
# If there is a GPT and a MBR gdisk asks which partition table should be used.
# 1: GPT 2: MBR 3: clean GPT
$gdisk = "echo 1 | gdisk -l DISK|" unless $gdisk;
my $blkid = shift;
$blkid = "/sbin/blkid -c /dev/null|" unless $blkid;
my %disks;
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
my @diskDevs = &getDiskDev;
#&getFdiskInfo;
foreach(@diskDevs){
	&getGdiskInfo($_, $gdisk);
}
# get the info from gdisk:
my %devs;

# get the info from blkid

my %blkids = &getBlockId;
&mergeDevs;

my (%sorted, $key, $dev);
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
foreach $key (sort keys %disks){
	print $key, "\t", $disks{$key}, "\n";
}
exit 0;

# searches for extended info of a partition
sub detective{
	my $dev = shift;
	my $fs = shift;
	my $info = "";
	my $dirMount = &getMountPoint($dev);
	if ($dirMount eq ""){
		system ("mount -o ro $dev $mountpoint");
		$dirMount = $mountpoint;
	}
	if ($fs eq "ntfs" || $fs =~ /^vfat|fat\d/){
		if (-d "$dirMount/windows/system32"){
			$info .= "\tos:windows";
		}
	}
	if (-d "$dirMount/etc"){
		$info .= &firstLineOf("$dirMount/etc/debian_version", "distro");
		$info .= &firstLineOf("$dirMount/etc/aptosid-version", "subdistro");
		$info .= &firstLineOf("$dirMount/etc/sidux-version", "subdistro");
		$info .= &firstLineOf("$dirMount/etc/siduction-version", "subdistro");
		$info .= "\tos:unix" if $info eq "" && -d "$dirMount/etc/passwd";		
	}
	if ($dirMount eq $mountpoint){
		system ("umount $mountpoint");
	}
	
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
my %s_mounts;
my $s_mounts;
sub getMountPoint{
	my $dev = shift;
	if ($s_mounts eq ""){
		open(INP, "mount|");
		while(<INP>){
			if (/^(\S+)\s+on\s+(\S+)/){
				$s_mounts{$1} = $2;
			}
		}
		close INP;
		$s_mounts = 1;
	}
	return $s_mounts{$dev};
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
sub getDiskDev{
	opendir(DIR, "/sys/block");
	my @files = readdir(DIR);
	my @rc;
	closedir DIR;
	foreach (@files){
		# find all names without a digit:
		push @rc, $_ unless /\d/ || /^\.{1,2}$/;
	}
	return @rc;
}

sub getFdiskInfo{
	my $fdisk = "fdisk -l |";
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
		} elsif (/^Disk\s+([^:]+):.*\s(\d+)\s+bytes/){
			my ($dev, $bytes) = ($1, $2);
			my $mb = length($bytes) <= 6 ? 1 : substr($bytes, 0, length($bytes) - 6);
			$disks{$1} = $mb;
		}
	}
	close CMD;
}

sub getGdiskInfo{
	my $disk = shift;
	my $cmd = shift;
	$cmd =~ s!DISK!/dev/$disk! if $cmd =~ /\|/; 
	open(CMD, $cmd) || die "$gdisk failed: $!";
	my $sector = 512;
	my $sectors = 0;
	while(<CMD>){
		s/\*/ /;
#   5        96392048        98799749   1.1 GiB     8200  Linux swap
#   6        98801798       176714999   37.2 GiB    8300  Linux filesystem
		if (/^\s+(\d+)\s+(\d+)\s+(\d+)\s+\S+\s+\S+B\s+([0-9A-Fa-f]+)\s+(.*)/){
			my ($partno, $min, $max, $ptype, $info) = ($1, $2, $3, $4, $5);
			my $dev = "/dev/$disk$partno";
			my $size = int(($max - $min + 1) * 1.0 * $sector / 1024);
			$devs{$dev} = "size:$size\tptype:$ptype\tpinfo:$info";
		} elsif (/sector size:\s+(\d+)/){
			$sector = $1;
#Disk /dev/sda: 3907029168 sectors, 1.8 TiB
		} elsif (/^Disk\s+\S+:\s+(\d+)/){
			$sectors = $1;
		}
	}
	$disks{$disk} = int($sectors * 1.0 * $sector / 1024); 
	close CMD;
}
sub getBlockId{
	my ($label, $uuid, $fs, $info2);
	my ($dev, $info);
	my %blkids;
	open(CMD, $blkid) || die "$blkid failed: $!";
	while(<CMD>){
		if (/^(\S+):/){
			my $dev = $1;
			my ($info, $label, $uuid, $fs, $size, $info);
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
			if (/mapper/){
				$size = getSizeOfLvmPartition($dev);
				$size = $size == 0 ? "" : "\tsize:$size";
			}
			$info .= &detective($dev, $fs);
			$blkids{$dev} = "$label$fs$uuid$info$size";
		}
	}
	close CMD;
	return %blkids;
}

sub mergeDevs{
	# merge the two fields:
	foreach $dev (keys %devs){
		my $info = $blkids{$dev};
		my $val = $devs{$dev};
		if ($info eq ""){
			$blkids{$dev} = $val;
		} else {
			my $size = "\t$1" if $val =~ /(size:\d+)/;
			my $ptype = "\t$1" if $val =~ /(id:\w+)/;
			my $info2 = "\t$1" if $val =~ /(pinfo:[^\t]+)/;
			$blkids{$dev} = "$info$size$ptype$info2"; 
		}
	}
}

sub getSizeOfLvmPartition{
	my $dev = shift;
	my ($sectors, $size);
	open (INP, "gdisk -l $dev|") || die "gdisk: $!";
	while(<INP>){
		if (/(\d+)\s+sectors/){
			$sectors = $1;
		} elsif (/sector\s+size:\s+(\d+)/){
			$size = int($1 * 1.0 * $sectors / 1024);
			last;
		}
	}
	close INP;
	return $size;
}