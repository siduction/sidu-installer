#! /usr/bin/perl
#
# Usage: autopart.pl "$CMD" "$ANSWER" "$DISKS" "$ALLOW_INIT" "$PARTS" "$VG_INFO" "$LV_INFO"

use strict;

my $cmd = shift;
my $answer = shift;
# sdb:mbr+sdc:gpt
my $diskInfo = shift;
# YES or NO
my $s_allowInit = shift;
# sdb1-2048-9999+sdb2-10000
my $partitions = shift;
# siduction:32M
my $vgInfo = shift;
# root:rider32:4G:ext4;home:home:2G:ext4;swap:swap:400M:swap
my $lvInfo = shift;
# progress file, e.g. /tmp/xy.progress
my $s_fnProgress = shift;
$s_fnProgress = "/tmp/autopart.progress" unless $s_fnProgress;

# progress: max. number of steps (progress)
my $s_maxTasks = 5;
# done number of steps
my $s_currTask = 0;

my $s_errors = 0;

# Constants:
my $MBR = "mbr";
my $GPT = "gpt";

my $s_fdisk = "/sbin/fdisk";
my $s_gdisk = "/sbin/gdisk";
my @s_logLines;

my %s_wantedDiskType;
my %s_realDiskType;
# name => "ptype:mdb part:1-1024-8000:2-8001-16000 ext:2"
my %s_diskInfo;

&Progress("initialization");
&StorePartTypeInfo($diskInfo);

if ($cmd eq "stdlvm"){
	if (! VGExists($vgInfo)){
		&Progress("creating partitions");
		&BuildLVMs($partitions);
		if ($s_errors > 0){
			Error ("task was aborted due to errors");
		} else {
			&Progress("creating volume group");
			BuildVG($partitions, $vgInfo);
			&Progress("creating logical volumes");
			BuildLVs($lvInfo, $vgInfo);
		}
	}
} else {
	&Error("unknown command: $cmd");
	exit 1;
}
&Progress("writing info", 1);
my $temp = WriteFile(join("", @s_logLines), ".log");
Exec("mv $temp $answer");
if (! -f $answer){
	die "+++ $temp -> $answer failed: $!";
}
exit(0);

# Tests whether a volume group exists.
# @param vgInfo	e.g. siduction:4M
# @return 0: vg does not exist 1: vg exists
sub VGExists{
	my $vgInfo = shift;
	my ($name, $extSize) = split(/:/, $vgInfo);
	my $rc = -d "/dev/$name";
	if ($rc){
		Error("VG $name already exists. (/dev/$name exists)");
	}
	return $rc;
}
# Builds a logical volume
# @param name		boot, root, home or swap
# @param label		file system label
# @param size		e.g. 4G or *
# @param filesys	e.g. ext4
# @param vg			name of the volume group
sub BuildLV{
	my $name = shift;
	my $label = shift;
	my $size = shift;
	my $fs = shift;
	my $vg = shift;
	$size = $size eq "*" ? "--extents 100%FREE" : "--size $size"; 
	Exec("lvcreate $size --name $name $vg", 1);
	my $lvPath = "/dev/mapper/$vg-$name";
	if (! -e $lvPath){
		Error("LV $name not created");
	} elsif ($fs eq "swap"){
		Exec("mkswap -L $label /dev/mapper/$vg-$name", 1);
		Log("=== LV $name created as swap device");
	} else {
		my $fsFull = qx(which mkfs.$fs);
		if ($fsFull eq ""){
			Error("unknown filesystem: $fs");
		} else {
			Exec("mkfs.$fs -L $label $lvPath");
			Log("=== LV $name formatted with $fs");
		}
	}
}

# Converts a value to KiByte
# @param value		examples: 102G 3T 8k 2M
# @return amount of KiByte
sub toKiByte{
	my $value = shift;
	my $number = 0;
	my $unit;
	if ($value =~ /(\d+)(.)/){
		($number, $unit) = ($1, $2);
		$unit =~ tr/a-z/A-Z/;
		if ($unit eq "G"){
			$number *= 1024*1024;
		} elsif ($unit eq "T"){
			$number *= 1024*1024*1024;
		} elsif ($unit eq "K"){
			$number *= 1;
		} else {
			$number *= 1024;
		}
	}
	return $number
}

# Converts a amount of KiBytes into a number and a unit.
# @param kiByte		amount in KiBytes
# @return			e.g. 4M or 243K or 22G
sub kiByteToSize{
	my $kiByte = shift;
	my $size;
	if ($kiByte % (1024 * 1024) == 0){
		$size = int($kiByte / 1024 / 1024) . "G";
	} elsif ($kiByte % (1024) == 0){
		$size = int($kiByte / 1024) . "M";
	} else {
		$size = (0 + $kiByte) . "K";
	}
	return $size;
}
	
# Builds all logical volumes:
# @param lvInfo	e.g. root:rider32:4G:ext4;swap:swap:400M:swap	
# @param vgInfo	e.g. siduction:4M
sub BuildLVs{
	my $lvInfo = shift;
	my $vgInfo = shift;
	my ($vg, $extSize) = split(/:/, $vgInfo);
	$extSize = toKiByte($extSize);
	my @lvs = split(/;/, $lvInfo);
	foreach(@lvs){
		my ($lv, $name, $size, $fs) = split(/:/);
		if ($size ne "*"){
			$size = toKiByte($size);
			$size = kiByteToSize(int($size / $extSize) * $extSize);
		}
		&Progress("creating $name");
		BuildLV($lv, $name, $size, $fs, $vg);
	}
}

# Builds a volume group.
# @param parts	the partion info of the disk
# @param vgInfo	e.g. "siduction:32M"
sub BuildVG{
	my $parts = shift;
	my $vgInfo = shift;
	my ($vg, $extSize) = split(/:/, $vgInfo);
	# Initialize the PV:
	my $cmd = "";
	my @parts = split(/\+/, $parts);
	my $pvList = "";
	foreach(@parts){
		my @cols = split(/-/);
		$pvList .= " /dev/" . $cols[0];
	}
	Exec("pvcreate --yes $pvList", 1);
	Exec("vgcreate --physicalextentsize $extSize $vg $pvList", 1);
}

# Reads the disk info with fdisk.
# The info will be stored in %s_diskInfo
# @param disk 	e.g. sdb
sub ReadFdiskInfo{
	my $disk = shift;
	my $info = "ptype:$MBR";
	open(DISK, "$s_fdisk -l /dev/$disk|") || die "$s_fdisk -l /dev/$disk";
	my @lines = <DISK>;
	close DISK;
	my $parts;
	foreach(@lines){
		#/dev/sdb1     2048       10000        3976+  83  Linux	
	#   if (m!^/dev/\D+(\d+)\D+(\d+)\s+(\d+)!){
		if (m!^/dev/\D+(\d+)\D+(\d+)\s+(\d+)!){
			if ($parts eq ""){
				$parts = " part";
			}
			$parts .= ":$1-$2-$3";		
		}
		if (m!^/dev/\D+(\d+).*Extended!){
			$info .= " ext:$1";
		}
	}
	$info .= $parts;
	$s_diskInfo{$disk} = $info;
	return $info;
}

# Reads the disk info with gdisk.
# The info will be stored in %s_diskInfo
# @param disk 	e.g. sdb
sub ReadGdiskInfo{
	my $disk = shift;
	my $info = "ptype: gpt";
	open(DISK, "$s_gdisk -l /dev/$disk|") || die "$s_gdisk -l /dev/$disk";
	my @lines = <DISK>;
	close DISK;
	my $parts;
	foreach(@lines){
		if (/^\s+(\d+)\s+(\d+)\s+(\d+)/){
			if ($parts eq ""){
				$parts = " part";
			}
			$parts .= ":$1-$2-$3";		
		}
	}
	$info .= $parts;
	$s_diskInfo{$disk} = $info;
	return $info;
}

# Returns the disk info.
# If not known it will be read.
# @param disk	e.g. sdb
# @return 		the disk info
sub GetDiskInfo{
	my $disk = shift;
	my $rc = $s_diskInfo{$disk};
	if ($rc eq ""){
		my $type = FindDiskType($disk);
		$s_diskInfo{$disk} = $type;
		if ($type eq $MBR){
			$rc = ReadFdiskInfo($disk);
		} elsif ($type eq $GPT){
			$rc = ReadGdiskInfo($disk);
		} elsif ($type eq "!"){
			# error already is displayed
		} else{
			Error("unknown partition table: $disk");
		}
	}
	return $rc;
}

# Returns the class of the next new partition.
# @param disk	disk to test
# @result		"p": primary "l": logical "b": primary or logical
sub GetNewPartClass{
	my $disk = shift;
	my $info = $s_diskInfo{$disk};
	my $rc;
	if ($info =~ /ptype:$MBR/){
		if ($info !~ /ext:/){
			$rc = "p";
		} else {
			$rc = ($info =~ /:1-.*:2-.*:3-.*:4-/) ? "l" : "b";
		}
	} else {
		Error("not implemented: GetNewPartClass gpt");
	}
	return $rc;
}
# Stores the partition types of the disks.
# @param info	e.g. "sdb:mda+sdb:gdb"	
sub StorePartTypeInfo{
	my $info = shift;
	my $disk;
	for $disk(split(/\+/, $info)){
		my ($name, $type) = split(/:/, $disk);
		$s_wantedDiskType{$name} = $type;
	}
}

# Builds all PV of a LVM
# @param pvlist		a list of all PV partitions (which do not already exist)
#                   e.g. "sda1-9-2048-1000000+sdb1-9-2048-1000000"
sub BuildLVMs{
	my $pvlist = shift;
	my $pv;
	for $pv (split(/\+/, $pvlist)){
		my ($name, $from, $to) = split(/-/, $pv);
		BuildPV($name, $from, $to, $MBR);
		last if ($s_errors > 0);
	}
}

# Builds one PV of a LVM
# @param name	name of the partition, e.g. sda1
# @param from	first record (of the disk)
# @param to		last record
sub BuildPV{
	my $name = shift;
	my $from = shift;
	my $to = shift;
	my $partType = FindDiskType($name);
	my $disk = FindDiskName($name);
	
	my $no;
	$name =~ /^\D+(\d+)/;
	$no = $1;
	
	if (! SectorsOverlap($disk, $no, $from, $to)){
		if ($partType eq $MBR){
			my $content = "n\n";
			my $class = GetNewPartClass($disk);
			if ($class eq "b"){
				$content .= $no < 5 ? "p\n" : "l\n";
			} else {
				$content .= $class . "\n";
			}
			$content .= "$no\n$from\n$to\nt\n";
			if (CountOfPartitions($disk) > 0){
				$content .= "$no\n";
			}
			$content .= "8e\nw\n"; 
			my $fn = WriteFile($content);
			Exec("$s_fdisk /dev/$disk < $fn");
			my $info = $s_diskInfo{$disk} = ReadFdiskInfo($disk);
			if (index($info, ":$no-$from-$to") < 0){
				Error("creating $name failed!");
			} else {
				Log("=== $name created");
			}
		} elsif ($partType eq $GPT){
			my $content = "n\n$no\n$from\n$to\n8e00\nw\nY\n";
			my $fn = WriteFile($content);
			Exec("$s_gdisk /dev/$disk < $fn");
			my $info = $s_diskInfo{$disk} = ReadGdiskInfo($disk);
			if (index($info, ":$no-$from-$to") < 0){
				Error("creating $name failed!");
			} else {
				Log("=== $name created");
			}
		} elsif ($partType eq "!"){
			# error already is displayed
		} else {
			Error("Unknown partType: $partType");
		}
	}
	Exec("partprobe");
}

# Counts the number of partitions of the disk.
# @param disk	e.g. sdb
# @return		the number of partitions of the disk
sub CountOfPartitions{
	my $disk = shift;
	my $info = $s_diskInfo{$disk};
	my $rc = 0;
	if ($info =~ /part(:\S+)/){
		my $info = $1;
		# Count the ':' in $info:
		$rc = $info =~ tr/:/:/;
	}
	return $rc;
}

# Checks whether a partition already exists or whether the
# sectors of the new partition overlap of an existing partition
# @param disk	e.g. sdb
# @param partNo	the number of the new partition
# @param from	the first sector of the new partition
# @param to		the last sector of the new partition
# @return 1: error 0: OK
sub SectorsOverlap{
	my $disk = shift;
	my $partNo = shift;
	my $from = shift;
	my $to = shift;
	my $info = GetDiskInfo($disk);
	my $rc = 0;
	if ($info =~ /:$partNo-/){
		Error("partition $partNo already exists");
		$rc = 1;
	} else {
		if ($info =~ /part:(\S+)/){
			my $parts = $1; 
			my @parts = split(/:/, $parts);
			foreach(@parts){
				my ($no, $f, $t) = split(/-/);
	
				if ($info !~ /ext:$no/
					&& ($f >= $from && $f <= $to || $t >= $from && $t <= $to)){
					&Error("partition $no overlaps with $partNo: $f-$t / $from-$to");
					$rc = 1;
				}
			}
		}
	}
	return $rc;
}
# Finds the disk name for a given partition
# @param part	partition name, e.g. "sda1"
# @return       the disk name, e.g. "sda"
sub FindDiskName{
	my $part = shift;
	my $rc;
	if ($part =~ /^([a-z]+)/){
		$rc = $1;
	}
	return $rc;
}

# Finds the partition table type.
# If the disk has no type (uninitialized) it will create a partition table
# @param part	e.g. "sda1"
# @return	"" (undef), "mbr" or "gpt"
sub FindDiskType{
	my $part = shift;
	my $disk = FindDiskName($part);
	
	my $rc;
	if ($s_realDiskType{$disk} ne ""){
		$rc = $s_realDiskType{$disk}; 
	} else {
		# gdisk waits for an answer if the GDP/MBR is damaged
		my $input = WriteFile("1\n");
		my $answer = WriteFile("<none>");
		Exec("$s_gdisk -l /dev/$disk  < $input >$answer");
		open(EXEC, $answer) || Error ("$answer: $!");
		my @lines = <EXEC>;
		close EXEC;
		unlink $input;
		unlink $answer;
		my $mbrOnly;
		foreach(@lines){
			# "MBR: protective" will be ignored! 
			if (/MBR: (present|MBR only)/){
				$rc = $MBR;
				$mbrOnly = $1 eq "MBR only";
			} elsif (/GPT: damaged/){
				Error("GPT is damaged. Must be repaired manually.");
				$rc = "!";
				last;
			} elsif (/GPT: present/){
				if ($mbrOnly){
					Error("GPT mixed with MBR. Fix it manually with gdisk, e.g: x (expert only) z (destroy GPT)");
					$rc = "!";
				} else {
					$rc = $GPT;
				}
				last;
			}
		}
		if ($rc eq ""){
			$rc = $s_wantedDiskType{$disk};
			if ($rc eq ""){
				Error("No partition table type given for $disk: mbr will be taken");
				$rc = $MBR;
			}
			CreatePartitionTable($disk, $rc);
		}
		$s_realDiskType{$disk} = $rc;
	}
	return $rc;
}

# Creates a partition table for a disk.
# @param disk	disk name, e.g. sdc
# @param type	partition table type: "mbr" or "gpt"
sub CreatePartitionTable{
	my $disk = shift;
	my $type = shift;
	
	if ($s_allowInit ne "YES"){ 
		Error("not allowed to create a partition table");
	} elsif ($type eq $MBR){
		my $fn = WriteFile("o\nw\n");
		Exec("$s_fdisk /dev/$disk < $fn");
		&Log("=== $disk initialized ($MBR)");
		unlink $fn;
	} else {
		open(EXEC, "|$s_gdisk /dev/$disk");
		print EXEC "o\n", "w\n", "Y\n";
		close EXEC;
		&Log("=== $disk initialized ($GPT)");
	}
}

# Executes a command.
# @param cmd	the command to execute
sub Exec{
	my $cmd = shift;
	my $extendedLog = shift;
	if ($extendedLog){
		Log("=== $cmd");
	} else {
		Log($cmd);
	}
	system($cmd);
}

# Writes a given content to a temporary file.
# @param content	content to write
# @return 	filename
sub WriteFile{
	my $content = shift;
	my $suffix = shift;
	my $fn = "/tmp/$$." . time() . ".tmp$suffix";
	if ($content ne "<none>"){
		open(OUT, ">$fn") || die "$fn: $!";
		print OUT $content;
		close OUT;
	}
	return $fn;
}
# Logs a message.
# @param msg	message
sub Log{
	my $msg = shift;
	print $msg, "\n";
	push(@s_logLines, $msg . "\n");
}

# Handles an error message.
# @param msg	error message
sub Error{
	my $msg = shift;
	$s_errors++;
	&Log("===+++ $msg");
}

# Writes the progress file.
#@param task	name of the current task
sub Progress{
	my $task = shift;
	my $isLast = shift;
	$task .= " ...";
	$s_currTask++;
	$s_maxTasks = $s_currTask if $isLast;
	if ($s_currTask == $s_maxTasks){
		$s_maxTasks += 5;
	}
	my $temp = $s_fnProgress . ".tmp";
	open(PROGRESS, ">$temp") || die "$temp: $!";
	my $percent = int(100 * ($s_currTask - 1) / $s_maxTasks);
	$percent = 5 if $percent < 5;
	print PROGRESS <<EOS;
PERC=$percent
CURRENT=<b>$task</b>
COMPLETE=completed $s_currTask of $s_maxTasks
EOS
	close PROGRESS;
	unlink $s_fnProgress if -f $s_fnProgress;
	rename $temp, $s_fnProgress;
}
