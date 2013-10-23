#! /usr/bin/perl
#
# Usage: autopart.pl CMD PROGRESS ANSWER DISKS ALLOW_INIT \
#                    PARTS VG_INFO LV_INFO MAX_SIZE [PASSPHRASE]

use strict;
use sidu_basic;
use sidu_recorder;
use sidu_test;

my $s_cmd = shift;
my $s_answer = shift;
# progress file, e.g. /tmp/xy.progress
my $s_fnProgress = shift;
$s_fnProgress = "/tmp/autopart.progress" unless $s_fnProgress;
# sdb:mbr+sdc:gpt
my $s_diskinfo = shift;
# YES or NO
my $s_allowInit = shift;
# sdb1-2048-9999+sdb2-10000
my $s_partitions = shift;
# siduction:32M
my $s_vgInfo = shift;
# root:rider32:4G:ext4;home:home:2G:ext4;swap:swap:400M:swap
my $s_lvInfo = shift;
my $s_maxSize = shift;
my $s_passPhrase = shift;

# progress: max. number of steps (progress)
my $s_maxTasks = 5;
# number of done steps
my $s_currTask = 0;

# === Test equipment ===
# "" or name of the regressiontest
my $s_testRun = "";

# Constants:
my $MBR = "mbr";
my $GPT = "gpt";

my $s_fdisk = "/sbin/fdisk";
my $s_gdisk = "/sbin/gdisk";

my %s_wantedDiskType;
my %s_realDiskType;
# name => "ptype:mbr ext:2 last:999999 part:1-1024-8000:2-8001-16000"
my %s_diskInfo;
my $s_appl = "ap";

my $text = "GeHeim123456";
my $covered = basic::Cover($text);
my $clear = basic::Uncover($covered);
die unless $text ne $clear;

if ($s_cmd !~ /^test(.*)/){
    # recording:
	recorder::Init($s_appl, 1, "/tmp/$s_appl.recorder.data");
} else {
	$s_testRun = $1;
	if ($s_testRun =~ /^:(.*)/){
		my $file = $1;
		die "test input not found: $file" unless -f $file;
		# replaying
		recorder::Init($s_appl, 2, $file);
	} else {
		$s_cmd = "-"; 
		recorder::Init($s_appl, 0);
	}
}
basic::Init($s_fnProgress, $s_testRun ne "");

basic::Progress("initialization");
if ($s_testRun){
    my @lines = recorder::Get("progArgs");
    $_ = join("", @lines);
    
    $s_cmd = $1 if /s_cmd="([^"]*)"/;
    $s_diskinfo = $1 if /s_diskinfo="([^"]*)"/;
    $s_allowInit = $1 if /s_allowInit="([^"]*)"/;
    $s_partitions = $1 if /s_partitions="([^"]*)"/;
    $s_vgInfo = $1 if /s_vgInfo="([^"]*)"/;
    $s_lvInfo = $1 if /s_lvInfo="([^"]*)"/;
    $s_passPhrase = $1 if /s_passPhrase="([^"]*)"/;
 } else {   
    &recorder::StoreArgs(
    	"s_cmd", $s_cmd,
    	"s_diskinfo", $s_diskinfo,
    	"s_allowInit", $s_allowInit,
    	"s_partitions", $s_partitions,
    	"s_vgInfo", $s_vgInfo,
    	"s_lvInfo", $s_lvInfo,
    	"s_passPhrase", $s_passPhrase);
}

&StorePartTypeInfo($s_diskinfo);

system ("./automount-control.sh disabled");
if ($s_cmd eq "-"){
	&TestSuite;
} elsif ($s_cmd eq "raw"){
	&basic::Progress("creating partitions");
	my ($boot, $lvm) = &CreateThreePartitions($s_partitions, $s_lvInfo);
} elsif ($s_cmd eq "lvm"){
	if (! VGExists($s_vgInfo)){
		&basic::Progress("creating partitions");
		&CreatePartitions($s_partitions);
		if ($basic::s_errors > 0){
			&basic::Error ("task was aborted due to errors");
		} else {
			BuildVG($s_partitions, $s_vgInfo);
			BuildLVs($s_lvInfo, $s_vgInfo);
		}
	}
} elsif ($s_cmd eq "cryptlvm"){
	if (! VGExists($s_vgInfo)){
		&basic::Progress("creating partitions");
		my ($boot, $lvm) = &CreateTwoPartitions($s_partitions, $s_lvInfo);
        if ($boot ne ""){
            BuildEncrypted($boot, $lvm, $s_lvInfo, $s_passPhrase);
        }
	}
} else {
	&basic::Error("unknown command: $s_cmd");
}
system ("./automount-control.sh enabled");
my ($refExecs, $refLogs) = basic::GetVars();
recorder::Finish("execLines", $refExecs, "logLines", $refLogs);
if ($s_testRun){
	&FinishTest;
} else {
	&basic::Progress("writing info", 1);
	my $temp = recorder::WriteFile(join("", @$refLogs), ".log");
	&basic::Exec("mv $temp $s_answer");
	if (! -f $s_answer){
		die "+++ $temp -> $s_answer failed: $!";
	}
}
exit(0);

# ===
# Builds a file containing the password.
#
# This file contains random characters, the password and random characters.
# @param password   the file content
# @return           (<filename>, <offset>, <lengthPw>)
#                   <offset> is the beginning of the real password
#                   <length> is the length of the password
sub CreatePasswordFile{
    my $password = shift;
    my $fn = "/tmp/p";
    $password = basic::UnScramble($password);
    open(my $OUT, ">", $fn) || die "$fn: $!";
    my $len = length($password);
    my $offset = 128 + int(rand(512 - $len - 128));
    my $rest = 512 - $offset - $len;
    Fill($password, $offset, $OUT);
    print $OUT $password;
    Fill($password, $rest, $OUT);
    close $OUT;
    return ($fn, $offset, $len);
}

my @s_passwords = qw(password 123456 12345678 qwerty  abc123
 monkey  1234567 letmein trustno1 dragon baseball 111111
 iloveyou master sunshine ashley bailey passw0rd shadow
 123123 654321 superman qazwsx michael football
 admin hallo internet pass password passwort schatz);
 
# ===
# Fills random chars into a file
# @param charset
# @param count
# @param handle
sub Fill{
    my $charset = shift;
    my $count = shift;
    my $handle = shift;
    my $charset2 = "aaaaaabcdeeeeefghiiiiijklmnoooopqrstuuuuvwxyz";
    my $charset3 = "AAAAABCDEEEEEFGHIIIIIJKLMNOOOOOPQRSTUUUUVWXYZeE";
    my $content = "";
    while($count-- > 0){
        my $rand = int(rand(100));
        if ($rand < 60){
            $content .= substr($charset2, rand length($charset2) - 1, 1); 
        } elsif ($rand < 75) {
            $content .= chr(32 + int(rand(127-32)));
        } elsif ($rand < 85){
            $content .= substr($charset2, rand length($charset2) - 1, 1); 
        } elsif ($count > 5 && $rand < 95){
            my $w = $s_passwords[rand $#s_passwords];
            if (length($w) >= $count) {
                $w = substr(0, $count);
                $count -= lenght($w) - 1;
            }
            $content .= $w;
        } else {
            $content .= substr($charset, rand(length($charset) - 1), 1);
        }
    }
    if ($handle){
        print $handle $content;
        
    } else {
        print $content, "\n";
    }
} 

# ===
# Builds the system with encrypted partitions.
# @param boot       partition for boot, e.g. sda5
# @param lvm        partition for LVM, e.g. sda6
# @param lvmInfo    e.g. boot:boot:100M:ext4;root:siduction:4G:ext4
# @param password   password, encrypted with Scramble()
sub BuildEncrypted{
    my $boot = shift;
    my $lvm = shift;
    my $lvInfo = shift;
    my $password = shift;
    
    &basic::Progress("creating encrypted partition");
    $password = basic::UnScramble($password);
    my $content = "spawn cryptsetup -c aes-cbc-essiv:sha256 -q -s 512 luksFormat /dev/$lvm\n";
    $content .= "sleep 2\n";
    $content .= "send \"$password\"\n";
    my $fn = recorder::WriteFile($content);
    recorder::Exec("BuildEncrypted", "expect $fn");
    unlink $fn;
    $content = "spawn cryptsetup -q luksOpen /dev/$lvm crypt$lvm\n";
    $content .= "sleep 2\n";
    $content .= "send \"$password\"\n";
    $fn = recorder::WriteFile($content);
    recorder::Exec("BuildEncrypted-2", "expect $fn");
    unlink $fn;
    my $parts = "mapper/crypt$lvm-2048-4096";
    BuildVG($parts, $s_vgInfo);
    BuildLVs($s_lvInfo, $s_vgInfo, "boot");
}

# ===
# Tests whether a volume group exists.
# @param vgInfo	e.g. siduction:4M
# @return 0: vg does not exist 1: vg exists
sub VGExists{
	my $vgInfo = shift;
	my ($name, $extSize) = split(/:/, $vgInfo);
	my $rc = recorder::FileExists("VGExists", "-d", "/dev/$name");
	$rc = 0 if $s_testRun;
	if ($rc){
		&basic::Error("VG $name already exists. (/dev/$name exists)");
	}
	return $rc;
}

# ===
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
	&recorder::Exec("BuildLV", "lvcreate $size --name $name $vg", 1);
	my $lvPath = "/dev/mapper/$vg-$name";
	if (! recorder::FileExists("BuildLV", "-e", $lvPath)){
		&basic::Error("LV $name not created");
	} elsif ($fs eq "swap"){
		&recorder::Exec("BuildLV-2", "mkswap -L $label /dev/mapper/$vg-$name", 1);
		&basic::Log("$vg/$name activated as swap", 1);
	} else {
	    # execute and return as string (list):
		my $fsFull = join("", recorder::ReadStream("BuildLV", "<which mkfs.$fs"));
		if ($fsFull eq ""){
			&basic::Error("unknown filesystem: $fs");
		} else {
			&recorder::Exec("BuildLV-3", "mkfs.$fs -L $label $lvPath");
			&basic::Log("mapper/$vg-$name created as $name ($fs)", 1);
		}
	}
}


# ===
# Converts a amount of KiBytes into a number and a unit.
# @param kiByte		amount in KiBytes
# @return			e.g. 4M or 243K or 22G
sub KiByteToSize{
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
# ===
# Converts a size (number + unit) into an amount of KiBytes.
# @param size		e.g. 4M or 243K or 22G
# @return			amount in KiBytes
sub SizeToKiByte{
	my $size = shift;
	die "not a size (number+unit): $size" unless $size =~ /^(\d+)([TGMK])?$/i;
	my ($rc, $unit) = ($1, $2);
	$unit =~ tr/a-z/A-Z/;
	if ($unit eq "M"){
	    $rc *= 1024;
	} elsif ($unit eq "G"){
	    $rc *= 1024 * 1024;
	} elsif ($unit eq "T"){
	    $rc *= 1024 * 1024 * 1024;
	}
	return $rc;
}
	
# ===
# Builds all logical volumes:
# @param lvInfo	    e.g. root:rider32:4G:ext4;swap:swap:400M:swap	
# @param vgInfo	    e.g. siduction:4M
# @param ignored    partition to ignore, e.g. "boot"
sub BuildLVs{
	my $lvInfo = shift;
	my $vgInfo = shift;
	my $ignored = shift;
	my ($vg, $extSize) = split(/:/, $vgInfo);
    &basic::Progress("creating logical volumes");
	$extSize = SizeToKiByte($extSize);
	my @lvs = split(/;/, $lvInfo);
	foreach(@lvs){
		my ($lv, $name, $size, $fs) = split(/:/);
		next if $lv eq $ignored;
		if ($size ne "*"){
			$size = SizeToKiByte($size);
			$size = KiByteToSize(int($size / $extSize) * $extSize);
		}
		&basic::Progress("creating $name");
		BuildLV($lv, $name, $size, $fs, $vg);
	}
}

# ===
# Builds a volume group.
# @param parts	the partion info of the disk, lvmInfo 
#               e.g. sdb1-2048-9999+sdb2-10000
# @param vgInfo	e.g. "siduction:32M"
sub BuildVG{
	my $parts = shift;
	my $vgInfo = shift;
	my ($vg, $extSize) = split(/:/, $vgInfo);
    &basic::Progress("creating volume group");
	# Initialize the PV:
	my $cmd = "";
	my @parts = split(/\+/, $parts);
	my $pvList = "";
	foreach(@parts){
		my @cols = split(/-/);
		$pvList .= " /dev/" . $cols[0];
	}
	&recorder::Exec("BuildVG", "pvcreate --yes $pvList", 1);
	&recorder::Exec("BuildVG", "vgcreate --physicalextentsize $extSize $vg $pvList", 1);
	&basic::Log("VG $vg has been created", 1)
}

# ===
# Reads the disk info with a MSDOS disk label.
# The info will be stored in %s_diskInfo
# @param disk 	e.g. sdb
sub ReadMsdosDisk{
	my $disk = shift;
	my $info = "ptype:$MBR";
	my @lines = recorder::ReadStream("ReadMsdosDisk", "parted -s /dev/$disk 'unit s' print|");
	my ($parts, $total);
	foreach(@lines){
		if (/^\s+(\d+)\s+(\d+)\s+(\d+)/){
			if ($parts eq ""){
				$parts = " part";
			}
			$parts .= ":$1-$2-$3";		
		} elsif (/total\s+(\d+)\s+sectors/){
		    $total = $1;
		}
		if (m!extended!){
			$info .= " ext:$1";
		}
	}
	# parted reserves 34 sectors at the end (independent of label is msdos or gpt)
	$info .= " last:" . ($total - 34 - 1) if $total; 
	$info .= $parts;
	$s_diskInfo{$disk} = $info;
	return $info;
}

# ===
# Reads the disk info with a GUID Partition Table.
# The info will be stored in %s_diskInfo
# @param disk 	e.g. sdb
sub ReadGPTDisk{
	my $disk = shift;
	my $info = "ptype:gpt";
	my @lines = recorder::ReadStream("ReadGPTDisk", "parted -s /dev/$disk 'unit s' print|");
	my $parts;
	foreach(@lines){
		if (/^\s+(\d+)\s+(\d+)\s+(\d+)/){
			if ($parts eq ""){
				$parts = " part";
			}
			$parts .= ":$1-$2-$3";		
		} elsif (/^Disk.*:\s+(\d+)s/){
		    # 34 sectors reserved for GPT shadow:
		    $parts .= " last:" . ($1 - 34 - 1);
		}
	}
	$info .= $parts;
	$s_diskInfo{$disk} = $info;
	return $info;
}

# ===
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
			$rc = ReadMsdosDisk($disk);
		} elsif ($type eq $GPT){
			$rc = ReadGPTDisk($disk);
		} elsif ($type eq "!"){
			# error already is displayed
		} else{
			&basic::Error("unknown partition table: $disk");
		}
	}
	return $rc;
}

# ===
# Stores the partition types of the disks.
# @param info	e.g. "sdb:mda+sdb:gdb"	
sub StorePartTypeInfo{
	my $info = shift;
	if ($info){
    	for my $disk(split(/\+/, $info)){
    		my ($name, $type) = split(/:/, $disk);
    		$s_wantedDiskType{$name} = $type;
    	}
	}
}

# ===
# Builds the partitions on the disk(s)
# @param pvlist		a list of all partitions (which do not already exist)
#                   e.g. "sda1-9-2048-1000000+sdb1-9-2048-1000000"
sub CreatePartitions{
	my $pvlist = shift;
	for my $pv (split(/\+/, $pvlist)){
		my ($name, $from, $to) = split(/-/, $pv);
		CreateOnePartition($name, $from, $to, "-", "lvm", "LVM");
		last if ($basic::s_errors > 0);
	}
	&recorder::Exec("CreatePartitions", "partprobe");
}

# ===
# Creates the two partitions boot + LVM (encrypted partitions)
# @param parts      the partition, e.g. sdb1-2048-9999+sdb2-10000-2000 
# @param lvInfo     e.g. boot:boot02:256M;root:rider32:4G:ext4;home:home:2G
# @return           (<devBoot>, <devLvm>), e.g. ("sda6", "sda7")
#                   ("", "") error occurred
sub CreateTwoPartitions{
    my $parts = shift;
    my $lvInfo = shift;
    my ($boot, $lvm) = split(/\+/, $parts);
    my ($bootName, $bootFrom, $bootTo) = split(/-/, $boot);
    my ($lvmName, $lvmFrom, $lvmTo) = split(/-/, $lvm);
    my ($rcBoot, $rcLvm);
    
    if ($lvmName ne $bootName){
        # 2 different free spaces:
        $rcBoot = CreateOnePartition($bootName, $bootFrom, $bootTo, "ext4", "LinuxBoot");  
        $rcLvm = CreateOnePartition($lvmName, $lvmFrom, $lvmTo, "-", "lvm", "LVMCrypt");  
    } else {
        # 2 partitions in a single free space:
        die "unexpected device name: $lvmName" unless $bootName =~ /(\D+)(\d+)/;
        my ($disk, $bootPartNo) = ($1, $2);
        my $diskInfo = $s_diskInfo{$disk};
        die "missing boot info: $lvInfo" 
                unless $lvInfo =~ /boot:[^:]+:(\d+\w?):(\w+)/;
        my ($records, $fsBoot) = (2 * SizeToKiByte($1), $2);
        # round up to the next MiByte:
        $records = int(($records + 2047) / 2048) * 2048;
        # split the free space into 2 parts:
        # a logical partition needs 1 record for partition info
        # to be aligned we reduce the previous partition by one record:
        $bootTo = $bootFrom + $records - 1 - 1;
        $lvmFrom = $bootTo + 2;
        my $createIt = 1;
        if ($diskInfo =~ /ptype:$GPT/){
            # make 2 partitions
        } elsif ($diskInfo !~ / ext:/){
            # there is no extended partition. We make it:  
            CreateOnePartition("${disk}0", $bootFrom, $lvmTo, "-");
            # the logical partition needs one record, but we will be aligned:
            $bootFrom += 2048;
            ($bootName, $lvmName) = ($disk . "5", $disk . "6");
        } elsif ($bootPartNo <= 4) {
            # the free space is not in the extended partition.
            # we need 2 primaries:
            my @nos = &GetPartNosOfDisk($disk);
            my $count = 0;
            foreach(@nos){
                $count++ if $_ < 5;
            }
            if ($count > 2){
                &basic::Error("too many primary partitions");
                $createIt = 0;
            }
        } else {
            # the free space is in the extended partition.
            # we need 2 logicals:
            my @nos = &GetPartNosOfDisk($disk);
            my $count = 0;
            foreach(@nos){
                $count++ if $_ < 5;
            }
            if ($count > 15 - 4 - 2){
                &basic::Error("too many logical partitions");
                $createIt = 0;
            }
        }
        if ($createIt && &basic::GetErrorCount() == 0){
            $rcBoot = CreateOnePartition($bootName, $bootFrom, $bootTo, 
                $fsBoot, "ext4", "", "LinuxBoot");  
            $rcLvm = CreateOnePartition($lvmName, $lvmFrom, $lvmTo, "-",
                "lvm", "LVM");  
        }     
    }
	&recorder::Exec("CreateTwoPartitions", "partprobe");
    return ($rcBoot, $rcLvm);
}

# ===
# Makes a GPT disk bootable with (U)EFI:
# If there is no bios partition (EB02)
# this partition will be created
# @param disk       disk to inspect
# @return           0: no partition created
#                   otherwise: the number of used records 
sub MakeEFIPartition{
    my $disk = shift;
    my $info = GetDiskInfo($disk);
    my $first = 2048;
    my $size = 0;
    if (CountOfPartitions($disk) == 0 && $info =~ /$GPT/){
        # 100 MiByte in records:
        $size = 100*1024*2;
        my $dev = CreateOnePartition("${disk}1", $first, $first + $size - 1, 
            "fat32", "bios_grub", "EFI");
        &basic::Log("$dev created as (U)EFI boot (fat32)", 1);
        recorder::Exec("mkfs.vfat -F 32 -n EFI-BOOT /dev/$disk");
    }
    return $size;
}
# ===
# Creates the two partitions boot + LVM (encrypted partitions)
# @param part       the partition, e.g. sdb1-2048-9999 
# @param lvInfo     e.g. root:rider32:4G:ext4;home:home:2G
# @return           (<devBoot>, <devLvm>), e.g. ("sda6", "sda7")
#                   ("", "") error occurred
sub CreateThreePartitions{
    my $part = shift;
    my $lvInfo = shift;
    my ($dev, $from, $maxTo) = split(/-/, $part);
    
    # until to 3 partitions in a single free space:
    my $countParts = 1 + ($lvInfo =~ tr/;/;/);
    die "unexpected device name: $dev" unless $dev =~ /(\D+)(\d+)/;
    my ($disk, $no) = ($1, $2);
    my $diskInfo = GetDiskInfo($disk);
    if ($diskInfo =~ /last:(\d+)/){
        $maxTo = $1 if $1 < $maxTo;     
    }              

    my $isExtended = 0;
    my $createIt = 1;
    if ($diskInfo =~ /ptype:\s*$GPT/){
        # we have enough partitions
    } elsif ($diskInfo !~ / ext:/){
        # there is no extended partition. We make it:  
        CreateOnePartition("${disk}0", $from, $maxTo);
        $isExtended = 1;
    } elsif ($no <= 4) {
        # the free space is not in the extended partition.
        # we need N primaries:
        my @nos = &GetPartNosOfDisk($disk);
        my $count = 0;
        foreach(@nos){
            $count++ if $_ < 5;
        }
        if ($count + $countParts > 4){
            &basic::Error("too many primary partitions");
            $createIt = 0;
        }
    }
    if ($createIt){
        my ($to, $records, $lastRecord);
        my @lv = split(/;/, $lvInfo);
        my $efiSize = MakeEFIPartition($disk);
        foreach my $lv (@lv){
            $from += $efiSize;

            # root:rider32:4G:ext4
            if ($isExtended){
                # the logical partition needs one record, but we will be aligned:
                $from += 2048;
            }
            my ($class, $label, $size, $fs) = split(/:/, $lv);
            basic::Progress("creating $class...");
            if ($size eq "*"){
                $to = $maxTo; 
                $efiSize = 0;
            } else {
                # If > 500MiByte: the partition size is reduced by the size of EFI part: 
                my $records = 2 * SizeToKiByte($size);
                if ($records >= 500*1024*2){
                   $records -= $efiSize;
                   $efiSize = 0;
                }
                # round up to the next MiByte:
                $records = int(($records + 2047) / 2048) * 2048;
                $to = $from + $records - 1;
            }
            $no = $isExtended ? 5 : 1;
            $dev = CreateOnePartition("${disk}$no", $from, $to, $fs, "", "Linux");
            if ($fs eq "swap"){
    			&recorder::Exec("CreateThreePartitions", "mkswap -L $label /dev/$dev");
    			&basic::Log("swap activated on $dev", 1);
            } else {
    			&recorder::Exec("CreateThreePartitions-2", "mkfs.$fs -L $label /dev/$dev");
    			&basic::Log("$dev created as $class ($fs)", 1);
                
            }
            $from = $to + 1;
        }    
    }
}

# ===
# Builds one PV of a LVM
# @param dev		device of the partition, e.g. sda1
# @param from		first record (of the disk)
# @param to			last record
# @param fileSys	"lvm", "ext4" or "fat32"
# @param flag       "bios_grub", "lvm"
# @param name       partition name (GPT only)
# @return			the name of the created partition, e.g. sda3
sub CreateOnePartition{
	my $dev = shift;
	my $from = shift;
	my $to = shift;
	my $fileSys = shift;
	my $flag = shift;
	my $name = shift;
	my $partType = FindDiskType($dev);
	my $disk = FindDiskName($dev);
	my $newNo = -1;
	
	$dev =~ /^(\D+)(\d+)/;
	my $no;
	($disk, $no) = ($1, $2);
	my $info = GetDiskInfo($disk);
	my $last;
	$last = $1 if $info =~ /last:(\d+)/;
	$to = $last if $last < $to;
	
	if (! SectorsOverlap($disk, $no, $from, $to)){
		if ($partType eq $MBR || $partType eq $GPT){
			my $class;
			if ($no == 0){
			     $class = "extended";  
			} else {
			    $class = $partType eq $MBR && $no > 4 ? "logical" : "primary";
			} 
			my $fs = "";
			$fs = $fileSys if $fileSys =~ /ext|fat/;
			$fs = "linux-swap" if $fileSys eq "swap";

			my @lines = recorder::ReadStream("CreateOnePartition", 
				"parted -s /dev/$disk unit s mkpart $class $fs ${from}s ${to}s print|");
			foreach (@lines){
				if (/^\s*(\d+)\s+(\d+)s\s+(\d+)s/ && $2 == $from && $3 == $to){
					$newNo = $1;
					last;
				}
			}
			if ($newNo < 0){
				my $msg = "creating $dev failed!";
				foreach(@lines){
					$msg .= " $_" if /error/i;
				}
				&basic::Error($msg);
			} elsif ($partType eq $GPT && $name ne ""){
			    &recorder::Exec("CreateOnePartition-2", 
			         "parted -s /dev/$disk name $newNo $name"); 
			}
			if ($flag ne "") {
			    &recorder::Exec("CreateOnePartition-3", 
			         "parted -s /dev/$disk set $newNo $flag on");
			}
		} elsif ($partType eq "!"){
			# error already is displayed
		} else {
			&basic::Error("Unknown partType: $partType");
		}
	}
	return "$disk$newNo";
}

# ===
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

# ===
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
		&basic::Error("partition $partNo already exists");
		$rc = 1;
	} else {
		if ($info =~ /part:(\S+)/){
			my $parts = $1; 
			my @parts = split(/:/, $parts);
			foreach(@parts){
				my ($no, $f, $t) = split(/-/);
	
				if ($info !~ /ext:$no/
					&& ($f >= $from && $f <= $to || $t >= $from && $t <= $to)){
					&basic::Error("partition $no overlaps with $partNo: $f-$t / $from-$to");
					$rc = 1;
				}
			}
		}
	}
	return $rc;
}

# ===
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

# ===
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
		# gdisk waits for an answer if the GPT/MBR is damaged
		my $input = recorder::WriteFile("1\n");
		my $answer = recorder::WriteFile("<none>");
		my @lines = recorder::ReadStream("FindDiskType", 
			"$s_gdisk -l /dev/$disk  < $input >$answer");
		unlink $input;
		unlink $answer;
		my $mbrOnly;
		foreach(@lines){
			# "MBR: protective" will be ignored! 
			if (/MBR: (present|MBR only)/){
				$rc = $MBR;
				$mbrOnly = $1 eq "MBR only";
			} elsif (/GPT: damaged/){
				&basic::Error("GPT is damaged. Must be repaired manually.");
				$rc = "!";
				last;
			} elsif (/GPT: present/){
				if ($mbrOnly){
					&basic::Error("GPT mixed with MBR. Fix it manually with gdisk, e.g: x (expert only) z (destroy GPT)");
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
				&basic::Error("No partition table type given for $disk: mbr will be taken");
				$rc = $MBR;
			}
			CreatePartitionTable($disk, $rc);
		}
		$s_realDiskType{$disk} = $rc;
	}
	return $rc;
}

# ===
# Gets the partition numbers of a disk
# @param disk   e.g. sda
# @return       a sorted array of partition numbers, e.g. (1, 3, 5, 7)
sub GetPartNosOfDisk{
    my $disk = shift;
    
    my $parts = getDiskInfo($disk);
    my @cols = split(/:/, $parts);
    my @rc;
    foreach(@cols){
        push(@rc, $1) if /(\d+)-\d+-\d+/;       
    }
    return sort @rc;
}
# ===
# Creates a partition table for a disk.
# @param disk	disk name, e.g. sdc
# @param type	partition table type: "mbr" or "gpt"
sub CreatePartitionTable{
	my $disk = shift;
	my $type = shift;
	
	if ($s_allowInit ne "YES"){ 
		&basic::Error("not allowed to create a partition table");
	} else {
	    my $label = $type eq $MBR ? "msdos" : "gpt";
		recorder::Exec("CreatePartitionTable", 
		  "parted -s /dev/$disk mklabel $label");
		&basic::Log("$disk initialized ($type)", 1);
	}
}

# ===
# do simple tests 
sub TestSuite{
	my $test = shift;
}

# ===
# Initializes a full size test.
sub InitializeTest{
	if ($s_testRun eq "stdlvm"){
		
	} elsif ($s_testRun eq "crypt"){
		
	} else {
		die "not implemented: $s_testRun";
	}
}

# ===
# Evaluation of the test result for full size tests.
sub FinishTest{
	my @expectedExec = recorder::Get("execLines");
	my @expectedLog = recorder::Get("logLines");
    my ($refExecs, $refLogs) = basic::GetVars();
	die unless test::EqualArray("LogList", $refLogs, \@expectedLog);
	die unless test::EqualArray("ExecList", $refExecs, \@expectedExec);
}
