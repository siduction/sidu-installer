package recorder;

=head1 NAME
recorder -- implements a recorder for regression tests
			and the infrastructure to replay this recording

=head1 Summary
Allows the recording of a real session. This recording can be
replayed in a regression test.

=head1 Author
hamatoma (C) 2013

=cut

use strict;
use sidu_basic;

my $MODE_NONE = 0;
my $MODE_RECORDING = 1;
my $MODE_REPLAYING = 2;

# 0: no recording/replaying 
# 1: recording 
# 2: replaying
my $s_mode;
my $s_recorderFile = "/tmp/autopart.recorder.txt";
# "ReadMsdosDisk-1:/sbin/fdisk -l /dev/sdb|" => <ref_of_line_array>
my %s_recorderStorage;
# collects the content of writeStream():
my @s_outputStreamLines;
my $s_currentFileNo;
# e.g. "getFdiskInfo" => 2
my %s_currNoIds;
my $s_application = "recorder";

# ===
# Initializes the session.
# @param application  a prefix for temporary files
# @param mode	      0: no recording/replaying 1: recording 2: replaying
# @param file         recorder storage file
sub Init{
    $s_application = shift;
	$s_mode = shift;
	$s_recorderFile = shift;
	$s_recorderFile = "/tmp/autopart.recorder.txt" unless $s_recorderFile;
	if ($s_mode == $MODE_REPLAYING){
		&ReadRecordedInfo($s_recorderFile)
	}
}

# ===
# Stores the program arguments into the recorder file.
# @param @args		all names and values of the variables
sub StoreArgs{
	if ($s_mode == $MODE_RECORDING){
		# find the values:
		my $val;
		my @defs;
		push(@defs, "###recorder progArgs:");
		my ($name, $value);
		foreach(@_){
			if ($name){
				push (@defs, "\$$name=\"$_\";");
				$name = "";
			} else {
				$name = $_;
			}
		}
		&recorder::WriteFile(join("\n", @defs) . "\n", "", $s_recorderFile);
	}
}

# ===
# Writes a given content to a temporary file.
# @param content	content to write
# @param suffix		suffix of the generated filename
# @param name		"" or name of the file
# @param append		if true the content will be appended
# @param dir        "" or the target directory
# @return 	        filename
sub WriteFile{
	my $content = shift;
	my $suffix = shift;
	my $name = shift;
	my $append = shift;
	my $dir = shift;
	my $fn = $name;
	if ($fn eq ""){
	    $dir = "/tmp" unless $dir;
		$fn = "$dir/tmp.$s_application." . ++$s_currentFileNo . "$suffix";
	}
	my $mode = $append ? ">>" : ">";
	open my $OUT, $mode, $fn || die "$fn: $!";
	print $OUT $content if $content;
	close $OUT;
	return $fn;
}

# ===
# Do the last things for the recorder.
#
# @param varargs	<name1> <content1> <name2> <content2>...
#                   <contentX> is a string or a reference of an array of lines
sub Finish{
	my $name;
	foreach(@_){
		if ($name eq ""){
			$name = $_;
		} else {
			Put($name, $_);
			$name = "";
		}
	} 
}

# ===
# Stores the content of one stream
# @param header		identifies the block
# @param refBlock	reference of the line array
sub StoreBlock{
	my $header = shift;
	my $refBlock = shift;
	my $content;
	my @lines = @$refBlock;
	if($header =~ /readStream id: (\w+): no: (\d+) device: (.+)/){
		my ($id, $no, $dev) = ($1, $2, $3);
		$s_recorderStorage{"$id-$no:$dev"} = \@lines;
	} elsif ($header =~ /recorder (\w+):/){
		$s_recorderStorage{$1} = \@lines;
	} elsif ($header =~ /FileExists id: (\w+): mode: (\S+) no: (\d+) file: (\S+) rc: (.)/){
		# FileExists id: $id: mode: $mode no: $callNo file: $file rc: 
		my ($id, $mode, $callNo, $file, $val) = ($1, $2, $3, $4, $5);
		$s_recorderStorage{"$id-$callNo$mode:$file"} = $val;
	} else {
		die "unknown header: $header";
	}
}

# ===
# Reads the file created by the recorder.
# @param file	the file's name
sub ReadRecordedInfo{
	my $file = shift;
	
	my @lines;
	my $lastHeader;
	open my $INP, "<", $file || die "$file: $!";
	while(<$INP>){
		if (/^###(readStream|FileExists|recorder \w+:)/){
			StoreBlock($lastHeader, \@lines) if $lastHeader; 
			$lastHeader = $_;
			@lines = ();
		} else{
			push(@lines, $_);
		}
	}
	StoreBlock($lastHeader, \@lines);
	close $INP;
}

# ===
# Puts an entry of the recorder storage.
# @param name		name of the entry
# @param content	a string or a reference of an array of lines
sub Put{
	my $name = shift;
	my $content = shift;
	if (ref($content) eq "ARRAY"){
		my $last = substr($$content[0], -1);
		my $sep = $last eq "\n" ? "" : "\n";  
		$content = join($sep, @$content) . $sep;
	}
	&WriteFile("###recorder $name:\n$content", "", $s_recorderFile, 1);
}


# ===
# Writes to a stream.
# A stream can be a file or the input of an external command.
# For tests this can be a file.
# @param id			identifies the caller
# @param device		a filename or a external command, e.g. "|fdisk /dev/sdb"
# @param content	this content will be written
sub WriteStream{
	my $id = shift;
	my $device = shift;
	my $content = shift;

	if ($s_mode == $MODE_RECORDING){
		my $header = "### writeStream id: $id device: $device\n";
		&WriteFile($header . $content, "", $s_recorderFile, 1);
	}
	if ($s_mode != $MODE_REPLAYING){	
		open my $OUT, "<", $device;
		print $OUT $content;
		close $OUT;
	} else {
		push(@s_outputStreamLines, "== id: $id device: $device");
		push(@s_outputStreamLines, $content);
	}
}
# ===
# Execute a command.
# @param id         identifies the caller
# @param cmd        command to execute
# @param important	true: the logging will be prefixed
# @return           the output of the command
sub Exec{
    my $id = shift;
    my $cmd = shift;
    my $important = shift;
    my @rc = ReadStream($id, "$cmd |");
    basic::Log(\@rc, $important);
    return @rc;
}


# ===
# Tests the existence of a file.
# @param id		id of the caller
# @param file	file to test
# @param mode 	"-e", "-d", "-f" ...
# @return 		0: does not exist. 1: exists
sub FileExists{
	my $id = shift;
	my $mode = shift;
	my $file =  shift;
	my $callNo = ++$s_currNoIds{$id};	
	my $rc;
	if ($s_mode == $MODE_REPLAYING){
		my $key = "$id-$callNo$mode:$file";
		$rc = $s_recorderStorage{$key};
		if ($rc eq ""){
			die "missing entry: $key";
		} else {
			$rc = $rc ne "F";
		}
	} else {
		if ($mode eq "-e"){
			$rc = -e $file;
		} elsif ($mode eq "-d"){
			$rc = -d $file;
		} elsif ($mode eq "-l"){
			$rc = -l $file;
		} elsif ($mode eq "-f"){
			$rc = -f $file;
		} else {
			die "$id: unknown mode: $mode: (file: $file)"; 
		}
		if ($s_mode == $MODE_RECORDING){
			my $content = "###FileExists id: $id: mode: $mode no: $callNo file: $file rc: "
				. ($rc ? "T" : "F") . "\n";
			&WriteFile($content, "", $s_recorderFile, 1);
		}
	}
	return $rc;
}

# ===
# Gets an entry of the recorder storage.
# @param name	name of the entry
# @return: an array of lines
sub Get{
	my $name = shift;
	my $refArray = $s_recorderStorage{$name};
	my @rc;
	if ($refArray){
		@rc = @$refArray;
	}
	return @rc;
}

# ===
# Reads a stream into an array of lines.
# A stream can be a file or the output of an extern command.
# For tests this can be a file.
# @param id		defines the stream to open
# @param device	a filename or a external command, e.g. "partprobe -s |"
sub ReadStream{
	my $id = shift;
	my $device = shift;
	my $content = "<!None>";
	my @rc;
	my $callNo = ++$s_currNoIds{$id};
	if ($s_mode != $MODE_REPLAYING){
	    # 
		# call of an external program with input and output:
		if (-d $device){
		    opendir(my $DIR, $device);
		    @rc = readdir($DIR);
		    close $DIR;
		} elsif ($device =~ /^</){
		    my $file = WriteFile("", ".exc");
		    my $cmd = substr($device, 1) . " >$file";
		    system($cmd);
			open my $INP, "<", $file;
			@rc = <$INP>;
			close $INP;
			unlink $file;
		} elsif ($device =~ /[<]/){
			system($device);
			if ($device =~ /[>]\s*(\S+)/){
				my $file = $1;
				open my $INP, "<", $file;
				@rc = <$INP>;
				close $INP;
			} else {
				die "no output file found: $device";
			}	
		} elsif (open my $INP, $device){
			@rc = <$INP>;
			close $INP;
		} else {
			print "+++ $device: $!";
		}
	} elsif (scalar keys %s_recorderStorage > 0){
		my $key = "$id-$callNo:$device";
		my $refArray = $s_recorderStorage{$key};
		if ($refArray){
			@rc = @$refArray;
		} else {
			my $msg = "+++ stream content not found: $key\nStored blocks:\n";
			foreach(keys %s_recorderStorage){
				$msg .= "$_\n" if /^$id/;
			}
			die $msg;
		}
	} else {
		die "not implemented: $id ($device)";
	}
	@rc = split(/\n/, $content) unless $content eq "<!None>";
	if ($s_mode == $MODE_RECORDING){
		my $sep = $rc[0] =~ /\n/ ? "" : "\n";
		$content = "###readStream id: $id: no: $callNo device: $device\n";
		$content .= join($sep, @rc);
		$content .= "\n" unless substr($content, -1) eq "\n"; 
		&WriteFile($content, "", $s_recorderFile, 1);
	}
	return @rc;
}	


return 1;