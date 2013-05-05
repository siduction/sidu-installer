#! /usr/bin/perl

use strict;

my $input;
$input = shift if $#ARGV >= 0;
$input = "fw-detect -v|" unless $input;

my ($module, $ok, @missing);

&checkFirmware($input);
&checkMicrocode;

print "+$ok\n" if $ok;
print join("\n", @missing), "\n" if $#missing >= 0;
exit 0;

# Tests the state of the microcode packets: 
sub checkMicrocode{
	# Test for the microcode packets:
	if (open(INFO, "/proc/cpuinfo")){
		while(<INFO>){
			if (/vendor_id\s*:\s+(AuthenticAMD|GenuineIntel)/){
				my $id = $1;
				my $packet = $id eq 'AuthenticAMD' ? 'amd64-microcode' : 'intel-microcode';
				my $installed = checkInstalled($packet);
				if ($installed){
					$ok .= "|$packet";
				} else {
					push(@missing, "$packet|apt-get install $packet");
				}			
				last;
			}
		}
	}
	close INFO;
}

# Tests the state of the firmware packets 
sub checkFirmware{
	my $input = shift;
	my $missing;
	if (open(FW, $input)){
		while(<FW>){
			chomp;
			if (/^Driver:\s(\S+)/){
				$module = $1;
				push(@missing, $missing) if $missing;
				$missing = "";
			} elsif (/^Firmware\sis\sokay/){
				$ok .= "|$module";
				$missing = "";
				$module = "";
			} elsif (/^(apt-get install|modprobe)/){
				$missing = $module unless $missing;
				$missing .= "|$_";
			}
		}
	}
	close FW;
	push(@missing, $missing) if $missing;
}

sub checkInstalled{
	my $packet = shift;
	open(APT, "apt-cache policy $packet|");
	# 1st line: name of the packet
	my $rc = 0;
	my $line = <APT>;
	if ($line ne ""){
		# 2nd line: installed:
		$line = <APT>;
		$rc = $line =~ /\d/;
	}
	close APT;
	return $rc;
}

