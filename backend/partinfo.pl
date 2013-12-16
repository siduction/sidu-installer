#! /usr/bin/perl
# Gets the partition info.
# @param fnProgress name of the file containing progress info
# @param answer     the partition info 
# @param testRun	"": normal run otherwise: name of the test
#
use strict;
use sidu_basic;
use sidu_recorder;

my $s_answer = shift;
$s_answer = "/var/cache/sidu-base/partinfo.txt" unless $s_answer;

my $s_fnProgress = shift;
$s_fnProgress = "/tmp/partinfo.progress" unless $s_fnProgress;

my $s_testRun = shift;
# /dev/sda -> 123456 (KiByte)
my %s_disks;
my $verbose = 0;
my $gv_mount_base = "/tmp/partinfo-mount";
my $gv_log = "/tmp/partinfo_err.log";
my $gv_mount_no = 0;
my %s_lvm;
my @s_output;
my @s_labels;
my %s_physicalDisks;
my $s_diskInfoEx = "";

# minimal size of a partition in bytes:
my $s_minPartSize = 10*1024*1024;
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
my $s_gptDisks;
my @s_vg;
my @s_vgSize;
my @s_lv;
my @s_fdFree;
my @s_fdEmpty;
my %s_devs;
my %s_lvDevs;
my %blkids;	
my (%sorted, $key, $dev);
my $s_gapPart;
my $s_maxTasks = 10;
my $s_currTask = 0;
my $s_appl = "pi";
# <name> -> <from>-<to>
my %s_extParts;
my %s_damagedDisks;
my $s_hints;

if ($s_testRun){
	# replaying
	recorder::Init($s_appl, 2, $s_testRun);
    basic::Init($s_fnProgress, $s_testRun ne "");
} else {
    # recording:
	recorder::Init($s_appl, 1, "/tmp/$s_appl.recorder.data");
}
# we need no arg saving/restoring
basic::Init($s_fnProgress, $s_testRun ne "");
system ("./automount-control.sh disabled");
&main();
system ("./automount-control.sh enabled");

my ($refExecs, $refLogs) = basic::GetVars();
recorder::Finish("execLines", $refExecs, "logLines", $refLogs);
if ($s_testRun){
	&finishTest;
}
exit 0;

# ===
# main routine.
sub main{
	if (! -d $gv_mount_base){
		mkdir $gv_mount_base;
		print STDERR $gv_mount_base, " created\n" if $verbose;
	}
	&Progress("disk info (partprobe)");
	my @diskDevs = &getDiskDev;
	
	&Progress("volume group info");
	&getVG;
	# get the info from blkid
	
	&Progress("block id info");
	%blkids = &getBlockId;
	&Progress("-merging infos");
	&mergeDevs;
	&Progress("logical volume info");
	&getLvmPartitions;
	
	&Progress("-writing info");
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
		push(@s_output, "$dev\t$blkids{$dev}");
	}
	foreach $dev (sort keys %s_lvDevs){
		push(@s_output, "$dev\t$s_lvDevs{$dev}");
	}
	push(@s_output, "!phDisk=" . JoinPhysicalDiskInfo());
	push(@s_output, "!GPT=$s_gptDisks;");
	push(@s_output, "!labels=;" . join(";", @s_labels));
	my $val = "!VG=";
	foreach my $ix (0..$#s_vg){
	    $val .= ";" . $s_vg[$ix] . ":" . $s_vgSize[$ix];
	}
	push(@s_output, $val);
	push(@s_output, '!LV=' . join(';', @s_lv));
	push(@s_output, "!GapPart=$s_gapPart");
	push(@s_output, "!damaged=" . join(';', sort keys %s_damagedDisks));
    push(@s_output, "!osinfo=" . &GetSiduInfo());
	&basic::Progress("writing info", 1);
	recorder::Put("partition_info", \@s_output);

	my $temp = recorder::WriteFile(join("\n", @s_output), ".out", "", 0, 
	   "/var/cache/sidu-base");
	unlink($s_answer) if -e $s_answer;
	print STDERR "cannot rename: $temp -> $s_answer $!" unless rename($temp, $s_answer);
	&UnmountAll();
}

# ===
# Joins the info about the physical disks.
# @return   e.g "\tsda;12345;msdos;1;2;;WD Green 17383UI\tsdb;45689;gpt;3;0;efiboot damaged;USB"
sub JoinPhysicalDiskInfo{
    my $rc;
    foreach my $dev (sort keys %s_physicalDisks){
        my @vals = split(/\t/, $s_physicalDisks{$dev});
        if ($s_damagedDisks{$dev} ne ""){
            # size pType primaries extendeds attr model
            $vals[4] .= " damaged";
        }
        $rc .= "\t$dev;" . join(";", @vals);
    }
    return $rc;
}

# ===
# Gets info about the current os
# @return:  <flavour>;<arch>,<version> e.g. kde;32;11.1
sub GetSiduInfo{
    my $info = &firstLineOf("/etc/siduction-version");
    # siduction 11.1 One Step Beyond - kde - 
    die $info unless $info =~ /^\S+\s+([.\d]+)\s.*-\s+(\w+) -/;
    my ($version, $flavour) = ($1, $2);
    # Linux version 3.7-8.towo-siduction-amd64 (Debian 3.7-14)...
    $info = &firstLineOf("/proc/version");
    my $arch = $info =~ /amd64/ ? "64" : "32";
    return "$flavour;$arch;$version";
}
# ===
# release all mounts done by the script itself
sub UnmountAll{
	my @files = recorder::ReadStream("UnmountAll", $gv_mount_base);
	my $dir;
	my $run = 0;
	while ($run < 2){
		$run++;
		my $errors = 0;
		foreach $dir (@files){
			next if $dir =~ /\.{1,2}/;
			my $full = "$gv_mount_base/$dir";
			system ("echo $full >>$gv_log 2>&1");
			system ("umount $full >>$gv_log 2>&1");
			rmdir $full;
			if (-d $full){
				system ("lsof +d $full >>$gv_log 2>&1");
				$errors++;
			}
		}
		last if $errors == 0;
		sleep 1;
	}
}
	
# ===
# searches for extended info of a partition
# @param dev	e.g. /dev/sda2
# @param fs		file system, e.g. ext4
sub detective{
	my $dev = shift;
	my $fs = shift;
	my $info = "";
	my $dirMount = &getMountPoint($dev);
	if ($dirMount eq ""){
		$dirMount = sprintf("$gv_mount_base/p%03d", ++$gv_mount_no);
		mkdir $dirMount;
		system ("mount -o ro $dev $dirMount >>$gv_log 2>&1");
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
	if ($dirMount =~ /^$gv_mount_base/){
		system ("umount $dirMount >>$gv_log 2>&1");
		rmdir $dirMount;
	}

	if ($dev !~ /swap/ && ($fs =~ /fs:ext\d/ || $fs eq "auto")){
		my @lines = recorder::ReadStream("detective", "tune2fs -l $dev|");
		my $date;
		foreach(@lines){
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
	}
	return $info;
}

my %s_mounts;
my $s_mounts;
# ===
# Finds the mountpoint of a device
# @param dev	e.g. /dev/sda
# @return 		"": not found
#				otherwise: the mountpoint
sub getMountPoint{
	my $dev = shift;
	if ($s_mounts eq ""){
		my @lines = recorder::ReadStream("getMountPoint", "mount|");
		foreach(@lines){
			if (/^(\S+)\s+on\s+(\S+)/){
				$s_mounts{$1} = $2;
			}
		}
		$s_mounts = 1;
	}
	return $s_mounts{$dev};
}
# ===
# Gets the first line of a file
# @param 	file	the filename, e.g. /etc/siduction-version
# @param 	prefix	this string will be put in front of the result
# @return	"\t$prefix:<first_line> 
sub firstLineOf{
	my $file = shift;
	my $prefix = shift;
	my $rc = "";
	if (-f $file){
		my @lines = recorder::ReadStream("firstOfLine", $file);
		$prefix = "\t$prefix:" if $prefix;
		$rc = $prefix . $lines[0];
		chomp $rc;
	}
	return $rc;
}
# ===
# Returns the factor associated to the unit, e.g. 1024 belongs to Ki
# @param unit   K(i), M(i), G(i), T(i)
# @return       1024**N with N in (0..4)
sub UnitToFactor{
    my $rc = 1;
    my $unit = shift;
    if ($unit =~ /^kb/i){
        $rc = 1000;
    } elsif ($unit =~ /^k/i){
        $rc = 1024;
    } elsif ($unit =~ /^mb/i){
        $rc = 1000*1000;
    } elsif ($unit =~ /^m/i){
        $rc = 1024*1024;
    } elsif ($unit =~ /^gb/i){
        $rc = 1000*1000*1000;
    } elsif ($unit =~ /^g/i){
        $rc = 1024*1024*1024;
    } elsif ($unit =~ /^tb/i){
        $rc = 1000*1000*1000*1000;
    } elsif ($unit =~ /^t/i){
        $rc = 1024*1024*1024*1024;
    }
    return $rc;
}
# ===
# Gets the volume group info
# The info will be stored in @lvs
sub getVG{
	my @lines = recorder::ReadStream("getVG", "vgdisplay|");
	my $vgs = "";
	foreach(@lines){
		if (/VG Name\s+(\S+)/){
			push(@s_vg, $1);
		} elsif (/VG Size\s+(\d+)([.,](\d+))? (\w+)/){
			# VG Size   14,71 GiB
			my ($val, $val2, $unit) = ($1, $2, $3);
			$val2 .= "0" x (3 - length($val2));
			$val = int(1000*$val + $val2 * &UnitToFactor($unit) / 1024); 
            push(@s_vgSize, $val);
		}
	}

	my ($vg, @lvs, $lv);
	foreach $vg (@s_vg){
		@lvs = findFiles("getVG", "/dev/$vg");
		foreach $lv(@lvs){		
			next if $lv =~ /^\.{1,2}$/;
			push(@s_lv, "$vg/$lv");
		}
	}
}

# ===
# Gets the disk device info
# fills: %s_damagedDisks
# @return 	e.g. ("sda", "sdc")
sub getDiskDev{
	&Progress("partprobe");
	my @lines = recorder::ReadStream("getDiskDev", "partprobe -s|");
	my @rc;
	
	# count the interesting disks:
	foreach (@lines){
		if (m!Warning: /dev/(\w+)!){
			$s_damagedDisks{$1} = 1;
		} elsif (m!/dev/(\w+):\s+(msdos|gpt)\s+partitions\s(.+)!){
			$s_maxTasks += 1;
		}
	}

	foreach (@lines){
#/dev/sda: msdos partitions 1 2 3 4 <5 6>                                                                                          
#/dev/sdb: gpt partitions 1 5 6 7 
		if (m!/dev/(\w+):\s+(msdos|gpt)\s+partitions\s(.+)!){
			my ($dev, $class, $parts) = ($1, $2, $3);
			next if $s_damagedDisks{$dev};
			push(@rc, $dev);
			if ($class eq "msdos"){
				&Progress("fdisk");
				&getFdiskInfo($dev);
			} else {
				&Progress("gdisk");
				&getGdiskInfo($dev);
			}
		}
        if (m!/dev/(\w+):\s+(\w+)!){                                                                                                
			GetPhysicalDiskInfo($1, $2);
        }
	}
	my @disks = getEmptyDisks();
	foreach (@disks){
		&Progress("empty disk");
		# fdisk calculates the partition gaps (here the whole disk)
		getFdiskInfo($_);
	}
	return @rc;
}

# ===
# Gets the basic info about a disk.
# @param dev    disk name, e.g. sda
# @param class  "gpt"or "msdos""
sub GetPhysicalDiskInfo {
    my $disk = shift;
    my $class = shift;
    
    my @lines = recorder::ReadStream("GetPhysicalDiskInfo", "parted -s /dev/$disk print|");
    my ($model, $primaries, $extendeds) = (0, 0, "");
    my ($pType, $size, $unit);
    foreach(@lines){
        if (/Model: (.*)/){ 
            $model = $1;
            $model =~ s/;/ /;
        } elsif (/Partition Table: (\S+)/){
            $pType = $1;
        } elsif (/Disk.*:\s+([\d,.]+)(\S+)/){
            ($size, $unit) = ($1, $2);
            $size =~ s/,/./;
            $size = int($size / 1024 / 1024 * UnitToFactor($unit));
        } elsif (/\s*(\d+)/){
            if ($1 <= 4 && $class ne "gpt"){
                $primaries++;
            } else {
                $extendeds++;
            }
        }
    }  
    $s_diskInfoEx .= "\t$disk;$size;$pType;$primaries;$extendeds;$model";
}
# ===
# Finds an unused primary partition number
# Fills: $s_hints
# @param ref_partList	In/Out: e.g. " 1 4 "
# @return				0: no unused number
#						otherwise: an unused number
sub findFreePrimary{
	my $refPartList = shift;
	my $rc = 0;
	if ($$refPartList != /\S/){
		$rc = 1;
	} else {
		my $last = 0;
		for (sort split/ /, $$refPartList){
			if (/(\d+)/){
				if ($1 > $last + 1){
					$rc = $last + 1;
					last;
				}
				$last = $1;
			}
		}
		$rc = 0 if $rc > 4;
		if ($rc == 0){
			$s_hints .= ";missingPrimary";
		} else {
			$$refPartList .= "$rc ";
		}
	}
	return $rc;
}

# ===
# Gets the disks without a partition table.
# @return	e.g ("sdc", "sdx")
sub getEmptyDisks{
	my @files = findFiles("getEmptyDisk", "/sys/block");
	my @rc;
	my $dev;
	foreach $dev (@files){
		# find all names without a digit:
		next if $dev =~ /^\.{1,2}$/;
		next if $dev =~ /\d/ && $dev !~ /mmcblk\d/;
		# already recognised by partprobe?
		next if $s_disks{$dev} ne "";
		push @rc, $dev;
	}
	return @rc;
}


# ===
# Gets the info from fdisk.
# @param disk		partition device, e.g. sda
# Fills: %s_devs, %s_disks, %s_extParts, $s_hints, $s_gapPart
sub getFdiskInfo{
	my $disk = shift;
	my @lines = recorder::ReadStream("getFdiskInfo", "fdisk -l /dev/$disk|");
	my ($dev, $size, $ptype, $info, $min, $max);
	my $sectorSize = 512;
	my $sectorCount = -1;
	my @sectors;
	my @partNos;
	my ($extMin, $extMax) = (-1, -1);
	foreach(@lines){
#/dev/sda6       118061056  1000215215   441077080   8e  Linux LVM
		if (m!^(/dev/[a-z]+(\d+))\s\D*(\d+)\s+(\d+)\s+(\d+)[+]?\s+([0-9a-fA-F]{1,2})\s+(.*)!){
			my ($dev, $partno, $min, $max, $size, $ptype, $info)  = ($1, $2, $3, $4, $5, $6, $7);
			# extended partition?
			if ($ptype == 5){
				$s_extParts{$disk} = "$min-$max";
				($extMin, $extMax) = ($min, $max);
			} elsif ($ptype ne "ee"){
				# ignore extended and protective partitions:
				$s_devs{$dev} = "size:$size\tptype:$ptype\tpinfo:$info";
				push(@sectors, sprintf("%012d-%012d-%d", $min, $max, $partno));
				push(@partNos, $partno);
			}
		} elsif (/total\s+(\d+)\s+sectors/){
			$sectorCount = $1;
		} elsif (m!logical/physical\): (\d+) bytes!){
			$sectorSize = $1;
		} elsif (/^Disk\s+([^:]+):.*\s(\d+)\s+bytes/){
			my ($dev, $bytes) = ($1, $2);
			my $mb = length($bytes) <= 6 ? 1 : substr($bytes, 0, length($bytes) - 6);
			$s_disks{$disk} = $mb;
		}
	}
	@sectors = sort(@sectors);
	@partNos = sort(@partNos);
	my $lastMax;
	my ($no);
	my $maxPartNo = $partNos[$#partNos];
	my $partList = " " . join(" ", @partNos) . " ";
	# 4 primary partitions makes it impossible to expand
	if ($partList eq " 1 2 3 4 " && $extMin > 0){
		$s_hints .= ";4primeries";
	} else {
		my ($noGap, $lbound, $ubound);
		my $lastMax = 2047;
		foreach(@sectors){
			# forget the ext. partition?
			$extMax = -1 if $extMin < 0;
			my ($min, $max, $no) = split(/-/);
			my $count = $min - $lastMax;
			if ($count*$sectorSize > $s_minPartSize){
				# in extended?
				if ($min >= $extMin && $min < $extMax){
					# is there a rest of the primary?
					if ($lastMax < $extMin - $s_minPartSize / $sectorSize){
						$lbound = $lastMax + 1;
						$ubound = $extMin - 1;
						$noGap = findFreePrimary(\$partList);
						$s_gapPart .= ";$disk!$noGap-$lbound-$ubound";
					}
					$noGap = $maxPartNo <= 4 ? 5 : $maxPartNo + 1;
					$maxPartNo = $noGap;
					# the first 48 sectors in the extendet partition are reserved:
					$lastMax = $extMin + 47 if $lastMax < $extMin + 47;
					$max = $extMax if $max > $extMax;
				} else {
					if ($min > $extMax){
						# is there a rest of the extended partition?
						if ($lastMax < $extMax - $s_minPartSize/$sectorSize){
							$lbound = $lastMax + 1;
							# the first 48 sectors in the extendet partition are reserved:
							$lbound = $extMin + 47 if $lbound < $extMin + 47;
							$ubound = $extMax;
							$noGap = $maxPartNo >= 5 ? $maxPartNo + 1 : 5;
							$maxPartNo = $noGap;
							$s_gapPart .= ";$disk!$noGap-$lbound-$ubound";
							$extMin = -1;	
						}
					}
					$lastMax = $extMax if $min > $extMin && $lastMax < $extMax;
					next if ($min - $lastMax) * $sectorSize < $s_minPartSize;
					$noGap = findFreePrimary(\$partList);
					next if $noGap <= 0;
				}
				$s_gapPart .= ";$disk!$noGap-" . ($lastMax + 1) . "-" . ($min - 1);
				$partList .= "$no ";
			}
			$lastMax = $max;		
		}
		if (($sectorCount - $lastMax) * $sectorSize > $s_minPartSize){
			my $ubound = $sectorCount - 1;
			my $lbound = $lastMax + 1;
			# in extended?
			if ($lastMax >= $extMin && $lastMax <= $extMax){
				$noGap = $maxPartNo <= 4 ? 5 : $maxPartNo + 1;
				$maxPartNo = $noGap;
				$lbound = $extMin + 48 if $lbound < $extMin + 48;
				$ubound = $extMax if $ubound > $extMax;
			} else {
				$noGap = findFreePrimary(\$partList);
			}
			if ($noGap > 0){
				$s_gapPart .= ";$disk!$noGap-$lbound-$ubound";
			}
		}
	}
}


# ===
# Gets the info from gdisk
# Fills: %s_devs, $s_disks, $s_gapPart, s_gptDisks
# @param disk	e.g. sda
# @param cmd	the call of gdisk, e.g. sdc
sub getGdiskInfo{
	my $disk = shift;
	my @lines = recorder::ReadStream("getGdiskInfo", "echo 1 | gdisk -l /dev/$disk|");
	my $sectorSize = 512;
	my $lastSector = -1;
	my @sectors;
	my @partNos;
	my $isGpt = 0;
	foreach(@lines){
		s/\*/ /;
#   5        96392048        98799749   1.1 GiB     8200  Linux swap
#   6        98801798       176714999   37.2 GiB    8300  Linux filesystem
		if (/^\s+(\d+)\s+(\d+)\s+(\d+)\s+\S+\s+\S+B\s+([0-9A-Fa-f]+)\s+(.*)/){
			my ($partno, $min, $max, $ptype, $info) = ($1, $2, $3, $4, $5);
			push(@sectors, sprintf("%012d-%012d-%d", $min, $max, $partno));
			push(@partNos, $partno);
			my $dev = "/dev/$disk$partno";
			my $size = int(($max - $min + 1) * 1.0 * $sectorSize / 1024);
			$s_devs{$dev} = "size:$size\tptype:$ptype\tpinfo:$info";
#Disk /dev/sda: 3907029168 sectors, 1.8 TiB
		} elsif (m!Logical sector size: (\d+) bytes!){
			$sectorSize = $1;
		} elsif (/last usable sector is (\d+)/){
			$lastSector = $1;
#   GPT: present
		} elsif (/^\s*GPT: present/){
			$isGpt = 1;
		}
	}
	$s_gptDisks .= ';' . $disk if $isGpt;
	if ($lastSector >= 0){
		$s_disks{$disk} = int(($lastSector - 34) * 1.0 * $sectorSize / 1024);
	}
	@sectors = sort(@sectors);
	@partNos = sort(@partNos);
	my $lastMax = 2047;
	my ($no, $lbound, $ubound);
	my $maxPartNo = $partNos[$#partNos];
	my $partList = " " . join(" ", @partNos) . " ";
	foreach(@sectors){
		my ($min, $max, $no) = split(/-/);
		my $count = $min - $lastMax;
		if ($count*$sectorSize > $s_minPartSize){
			my $noGap = $no - 1;
			$noGap = ++$maxPartNo if $partList =~ / $noGap /;
			$lbound = $lastMax + 1;
			$ubound = $min - 1;
			$s_gapPart .= ";$disk!$noGap-$lbound-$ubound"; 
		}
		$lastMax = $max;		
	}
	if (($lastSector - $lastMax) * $sectorSize > $s_minPartSize){
		$maxPartNo++;
		$lastMax++;
		$s_gapPart .= ";$disk!$maxPartNo-$lastMax-$lastSector";
	}
}
sub getBlockId{
	my ($label, $uuid, $fs, $info2, $dev);
	my %blkids;
	my @lines = recorder::ReadStream("getBlockId", "/sbin/blkid -c /dev/null|");
	foreach(@lines){
		if (/^(\S+):/){
			my $dev = $1;
			my ($info, $label, $uuid, $fs, $size);
			if (/LABEL="([^"]+)"/){
				$label = "\tlabel:$1";
				push(@s_labels, $1);
			}
			if (/TYPE="([^"]+)"/){
				$fs = "\tfs:$1";
			}
			if (/UUID="([^"]+)"/){
				$uuid = "\tuuid:$1";
			}
			if ($s_devs{$dev} ne ""){
				$info=$s_devs{$info}
			}
			if (/mapper/){
				$size = getSizeOfLvmPartition($dev);
				$size = $size == 0 ? "" : "\tsize:$size";
			}
			$info .= &detective($dev, $fs);
			$blkids{$dev} = "$label$fs$uuid$info$size";
		}
	}
	return %blkids;
}
sub getLvmPartitions{
	my ($lv, $size, $info, $fs);
	for $lv(@s_lv){
		$dev = "/dev/$lv";
		$size = getSizeOfLvmPartition($dev);
		$fs = "auto";
		$info = &detective($dev, $fs);
		$s_lvDevs{$lv} = "size:$size\tpinfo:$info";
	}
}
sub mergeDevs{
	# merge the two fields:
	foreach $dev (keys %s_devs){
		my $info = $blkids{$dev};
		my $val = $s_devs{$dev};
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
	open my $INP, "gdisk -l $dev|" || die "gdisk: $!";
	while(<$INP>){
		if (/(\d+)\s+sectors/){
			$sectors = $1;
		} elsif (/sector\s+size:\s+(\d+)/){
			$size = int($1 * 1.0 * $sectors / 1024);
			last;
		}
	}
	close $INP;
	return $size;
}
sub prettySize{
	my $kbyte = shift;
	my $rc;
	if ($kbyte >= 9*1024*1024){
		$rc = int($kbyte / 1024 / 1024) . ' GiB';
	} elsif ($kbyte >= 1024*1024){
		$rc = sprintf("%.2f", $kbyte / 1024.0 / 1024) . ' GiB';
	} elsif ($kbyte >= 1024){
		$rc = int($kbyte / 1024) . ' MiB';
	} else{
		$rc = sprintf("%.2f", $kbyte / 1024.0) . ' MiB';
	}
	return $rc;
}
	
sub physicalView{
	my @lines = recorder::ReadStream("physicalView", "pvdisplay|");
	my ($pvName, $vgName, $size, %devs, %unassigned, %assigned);
	foreach(@lines){
		chomp;
		if (/PV Name\s+(\S+)/){
			$pvName = $1;
		} elsif (/VG Name\s+(\S+)/){
			$vgName = $1;
		} elsif (/VG Name\s*$/){
			$vgName = '?';
		} elsif (m!PV Size\s+(\S.*)!){
			$size = $1;
			$size =~ s!\s*/.*$!!;
		} elsif (/---/){
			if ($pvName ne ""){
				if ($vgName eq '?'){
					$unassigned{$pvName} = "|$pvName|$size";
				} else {
					$s_devs{$vgName} .= "\t|$pvName|$size";
					$assigned{$pvName} = 1;
				}
				$vgName = "";
			}
		}
		if ($vgName eq '?'){
			$unassigned{$pvName} = "|$pvName|$size";
		} elsif ($pvName ne ""){
			$s_devs{$vgName} .= "\t|$pvName|$size";
			$assigned{$pvName} = 1;
		}
		my ($key, $out);
		foreach $key (sort keys %devs){
			$out .= "\f\t$key" . $s_devs{$key};
		}
		foreach $key (%assigned){
			if ($s_lvm{$key}){ 
				delete($s_lvm{$key});
			}
		}
		push(@s_output, "PhLVM:$out");
		$out = '';
		for $key (sort keys %unassigned){
			delete($s_lvm{$key}) if $unassigned{$key};
			$out .= "\t" . $unassigned{$key}; 
		} 
		push(@s_output, "FreeLVM:$out");
		$out = '';
		for $key (sort keys %s_lvm){
			$out .= "\t|$key|" . &prettySize($s_lvm{$key}); 
		} 
		push(@s_output, "MarkedLVM:$out");
		close INP;
	}
}


sub logicalView{
	my @lines = recorder::ReadStream("logicalView", "lvdisplay|");
	my ($lvName, $vgName, $size, $access, %devs, %snaps, $parent);
	foreach(@lines){
		chomp;
		if (/LV Name\s+(\S+)/){
			$lvName = $1;
			$lvName =~ s!/dev/[^/]+/!!;
		} elsif (/VG Name\s+(\S+)/){
			$vgName = $1;
		} elsif (m!LV Size\s+(\S.*)!){
			$size = $1;
		} elsif (m!LV snapshot status.*\sfor\s+(\S+)!){
			$parent = $1;
			$parent =~ s!/dev/[^/]+/!!;
		} elsif (m!LV Write Access\s+(\S.*)!){
			$access = $1;
		} elsif (/--- Logical volume/){
			if ($lvName ne ""){
				if ($parent){
					$snaps{$vgName} .= "\t|$lvName|$size|$access|$parent";
					$parent = '';
				} else {
					$s_devs{$vgName} .= "\t|$lvName|$size|$access";
				}
			}
		}
		if ($lvName ne ""){
			if ($parent){
				$snaps{$vgName} .= "\t|$lvName|$size|$access|$parent";
			} else {
				$s_devs{$vgName} .= "\t|$lvName|$size|$access";
			}
		}
		close INP;
		my ($key, $out);
		foreach $key (sort keys %devs){
			$out .= "\f\t$key" . $s_devs{$key}; 
		}
		if ($out ne ""){
			push(@s_output, "LogLVM:$out");
		}
		$out = '';
		foreach $key (sort keys %snaps){
			$out .= "\f\t$key" . $snaps{$key}; 
		}
		if ($out ne ""){
			push(@s_output, "SnapLVM:$out");
		}
	}
}
sub vgInfo {
	my @lines = recorder::ReadStream("vgInfo", "vgdisplay|");
	my ($vgName, $size, $access, $status, $free, $alloc, %vgs, $peSize);
	foreach(@lines){
		chomp;
		if (/VG Name\s+(\S+)/){
			$vgName = $1;
		} elsif (m!VG Size\s+(\S.*)!){
			$size = $1;
		} elsif (m!VG Access\s+(\S.*)!){
			$access = $1;
		} elsif (m!VG Status\s+(\S.*)!){
			$status = $1;
		} elsif (m!Alloc PE / Size.*/\s+(\S.*)!){
			$alloc = $1;
		} elsif (m!Free  PE / Size.*/\s+(\S.*)!){
			$free = $1;
		} elsif (m!PE Size\s+(\S.*)!){
			$peSize = $1;
		} elsif (/--- Volume group/){
			if ($vgName ne ""){
				$vgs{$vgName} .= "|$size|$alloc|$free|$peSize|$status|$access";
			}
		}
		if ($vgName ne ""){
			$vgs{$vgName} .= "|$size|$alloc|$free|$peSize|$status|$access";
		}
		my ($key, $out);
		foreach $key (sort keys %vgs){
			$out .= "\t|$key" . $vgs{$key}; 
		}
		if ($out ne ""){
			push(@s_output, "VgLVM:$out");
		}
	}
}

# Writes the progress file.
#@param task	name of the current task
sub Progress{
	my $task = shift;
	if ($task =~ /^-/){
		$task = substr($task, 1);
	} else {
		$task = "collecting " . $task;
	}
	$task .= " ...";
	if ($s_currTask == $s_maxTasks){
		$s_maxTasks += 5;
	}
	my $temp = $s_fnProgress . ".tmp";
	open my $PROGRESS, ">", $temp || die "$temp: $!";
	my $percent = int(100 * $s_currTask / $s_maxTasks);
	print $PROGRESS <<EOS;
PERC=$percent
CURRENT=<b>$task</b>
COMPLETE=completed $s_currTask of $s_maxTasks
EOS
	close $PROGRESS;
	unlink $s_fnProgress if -f $s_fnProgress;
	rename $temp, $s_fnProgress;
}

# Gets the files of a given directory.
# In test mode this directoy will be simulated.
# @param id		caller's id
# @param dir	name of the directory, e.g. "/sys/block"
# @return		an array of the names, e.g. ("sda", "sdb")
sub findFiles{
	my $id = shift;
	my $dir = shift;
	my @rc;
	
	if (! $s_testRun){
		opendir my $DIR, $dir || die "$dir: $!";
		@rc = readdir $DIR;
		closedir $DIR;
	} elsif ($id eq "getEmptyDisk") {
		if ($s_testRun =~ /gapPart/){
			@rc = (".", "..", "dm-0", "sdd1", "sda", "sdb", "sdc", "sdx");
		} else {
			die "not implemented";
		}
	}
	return @rc
}

# Builds a pointer to the first different position of 2 strings.
# @param x	1st string
# @param y	2nd string
# @return	the pointer, e.g. "-----^"
sub MkPointer{
	my $x = shift;
	my $y = shift;
	my $len = 1;
	while($len < length($x) && substr($x, $len) == substr($y, $len)){
		$len++;
	}
	my $ptr = ("-" x $len) . "^";
	return $ptr;
}
#== Tests equality of two strings.
# @param prefix	id of the test
# @param x		first string
# @param y		2nd string
# @return		0: different 1: equal
sub Equal{
	my $prefix = shift;
	my $x = shift;
	my $y = shift;
	if ($x ne $y){
		if ($x !~ /\n/){
			print "Difference at $prefix:\n$x\n$y\n", 
				MkPointer($x, $y), "\n";
		} else {
			my @x = split(/\n/, $x);
			my @y = split(/\n/, $y);
			my ($ix, $max) = (0, $#x);
			$max = $#y if $#x < $#y;
			while($ix <= $max){
				if ($x[$ix] ne $y[$ix]){
					print "Difference at $prefix in line ", $ix + 1, "\n", 
						$x[$ix], "\n", $y[$ix], "\n",
						MkPointer($x[$ix], $y[$ix]), "\n";
					last;
				}
				$ix++;
			}
		}
	}
	return $x eq $y;
}

#== Tests equality of two arrays.
# @param prefix	id of the test
# @param x		first array (reference)
# @param y		2nd array (reference)
# @param sep	separator, should not part of the strings. Default: "|"
# @return		0: different 1: equal
sub EqualArray{
	my $prefix = shift;
	my $refX = shift;
	my $refY = shift;
	my $sep = shift;
	$sep = "|" unless $sep;
	my $x = join($sep, @$refX);
	my $y = join($sep, @$refY);
	return Equal($prefix, $x, $y);
}

#== 
# Tests equality of two hashes.
# @param prefix	id of the test
# @param x		first hash (reference)
# @param y		2nd hask (reference)
# @param sep	separator, should not part of the strings. Default: "|"
# @return		0: different 1: equal
sub EqualHash{
	my $prefix = shift;
	my $refX = shift;
	my $refY = shift;
	my $sep = shift;
	my (@x, @y);
	for (sort keys %$refX){
		my $val = $$refX{$_};
		$val =~ s/\s+$//;
		$val =~ s/\t/ /g;
		push(@x, "$_=>$val");
	} 
	for (sort keys %$refY){
		my $val = $$refY{$_};
		$val =~ s/\s+$//;
		$val =~ s/\t/ /g;
		push(@y, "$_=>" . $val);
	} 
	return EqualArray($prefix, \@x, \@y, $sep);
}
#===
# Builds a hash from a string.
# @param x		string to convert. Starts with a separator, e.g. ";a=>1;b=>3"
# @return		the hash
sub toHash{
	my $x = shift;
	my %hash;
	my $sep = substr($x, 0, 1);
	$x = substr($x, 1);
	my @x = split(/$sep/, $x);
	foreach(@x){
		my @y = split(/=>/, $_);
		$hash{$y[0]} = $y[1];
	}
	return \%hash;
}
sub testGetDiskDev{
	&getDiskDev;
	my @a = ("abc", "def");
	my @b = ("abc", "123");
	die "!" unless Equal("s_gapPart",  
		";sdb!4-100000-1023999;sdb!8-2457600-4194303;sdb!9-10897408-31248350;sdc!2-2048-79999;sdc!3-100000-300000;sdc!8-300049-1023999;sdc!9-2457600-4194303;sdc!10-10897408-31248383;sdx!1-2048-31248383",
		$s_gapPart);
	die unless EqualHash("s_devs", toHash("
/dev/sdb1=>size:48976\tptype:8E00\tpinfo:Linux LVM
/dev/sdb5=>size:716800\tptype:8300\tpinfo:Linux filesystem
/dev/sdb6=>size:3145728\tptype:8300\tpinfo:Linux filesystem
/dev/sdb7=>size:204800\tptype:8300\tpinfo:Linux filesystem
/dev/sdc1=>size:48976 ptype:8e pinfo:Linux LVM
/dev/sdc5=>size:716800 ptype:83 pinfo:Linux
/dev/sdc6=>size:3145728\tptype:83\tpinfo:Linux
/dev/sdc7=>size:204800\tptype:83\tpinfo:Linux
"),
		\%s_devs, "\n");
	die unless EqualHash("s_disks", toHash(";sdb=>15624158;sdc=>15999;sdx=>15999"),
		\%s_disks, ";");
	die unless EqualHash("s_extParts", toHash(";sdc=>300001-31248383"),
		\%s_extParts, "\n");
	die unless Equal("s_hints", "",
		$s_hints);
}
