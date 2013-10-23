package basic;

=head1 NAME
base -- basic methods for generally usage

=head1 Summary
Implements generally usable methods

=head1 Author
hamatoma (C) 2013

=cut

#use strict;

my $s_logPrefixImportant = "=== ";
my $s_logPrefix = "";
my $s_stdoutPrefixImportant = "";
my $s_prefixError = "+++";
my $s_testRun = 0;
my $s_logStdout = 1;
my $s_logList = 1;
my $s_execList = 1;
# collects the commands done with Exec:
my @s_execLines;
my @s_logLines;
my $s_errors;
my $s_currTask;
my $s_maxTasks = 10;
my $s_fnProgress;

# ===
# Initializes the module.
sub Init{
    my $fn = shift;
    $s_fnProgress = $fn;
    my $val = shift;
    $s_testRun = $val;
}
# ===
# Returns the important static variables.
# @return (<refExecLines>, <reflogLines>) 
sub GetVars{
    return (\@s_execLines, \@s_logLines); 
}
# ===
# Executes a command.
# @param cmd			the command to execute
# @param important	true: the logging will be prefixed
sub Exec{
	my $cmd = shift;
	my $important = shift;
	push(@s_execLines, $cmd) if $s_execList;
	if (! $s_testRun){
		Log($cmd, $important);
		system($cmd);
	}
}

# ===
# Logs a message.
# @param msg			message
# @param important	true: a prefix will be added
sub Log{
	my $msg = shift;
	if (ref $msg eq "ARRAY"){
	    my $sep;
	    $sep = "\n" if $$msg[0] !~ /\n/;
	    $msg = join($sep, @$msg);
	}
	my $important = shift;
	if ($important){
	    $msg = $s_logPrefixImportant . $msg;
	} 
    print $msg, "\n" if $s_logStdout;
	push(@s_logLines, $msg . "\n") if $s_logList;
}

# ===
# Handles an error message.
# @param msg	error message
sub Error{
	my $msg = shift;
	$s_errors++;
	&Log("===+++ $msg");
}

# ===
# Return the number of errors.
# @return   the count of calls of the subroutine Error()
sub GetErrorCount{
    return $s_errors;
}

# ===
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
	open my $PROGRESS, ">", $temp || die "$temp: $!";
	my $percent = int(100 * ($s_currTask - 1) / $s_maxTasks);
	$percent = 5 if $percent < 5;
	print $PROGRESS <<EOS;
PERC=$percent
CURRENT=<b>$task</b>
COMPLETE=completed $s_currTask of $s_maxTasks
EOS
	close $PROGRESS;
	unlink $s_fnProgress if -f $s_fnProgress;
	rename $temp, $s_fnProgress;
}
my $xx = "";
# ===
# Disquises the passphrase.
# @param text clear text
# @return:    the disguised text
sub Cover{
    my $text = shift;
    my $seed = int(rand 0xffff);
    my $rc = sprintf("%02x%02x", $seed % 256, $seed / 256);
    my $ix = 0;
    my ($cc, $val);
    $xx .= sprintf("seed: %d %04x\n", $seed, $seed);
    while($ix < length($text)){
        $seed = ($seed * 7 + 0x1234321) &  0x8fffffff;
        $cc = substr($text, $ix, 1);
        $val = ((chr($cc) ^ $seed) & 0xff);
        $xx .= sprintf("ix: %d s: %d cc: %s/%02x v: %d %02x\n", $ix, $seed, $cc, ord($cc), $val, $val); 
        $rc .= sprintf("%02x", $val);
        $ix++;
    }
    return $rc;
}
# ===
# Converts a 2 digit hex number into a number.
# @param x      2 digit hex number, e.g. "a9"
# @return       the value of x, 0..255
sub Hex2Bin{
    my $x = shift;
    my ($n1, $n2) = (substr($x, 0, 1), substr($x, 1, 1));
    $n1 = 10 + ord($n1) - ord("a") if $n1 gt "a"; 
    $n2 = 10 + ord($n2) - ord("a") if $n2 gt "a"; 
    my $rc =  16 * $n1 + $n2;
    return $rc;
}
# ===
# Cover the text disguised with cover().
# @param text    encrypted text
# @return        clear text
sub Uncover{
    my $text = shift;
    my $rc = "";
    my ($s1, $s2) = (Hex2Bin(substr($text, 0, 2)), Hex2Bin(substr($text, 2, 2)));
    my $seed = $s1 + 256 * $s2;
    my $ix = 4;
    my ($val, $val2, $hh);
    while($ix < length($text)){
        $seed = ($seed * 7 + 0x1234321) & 0x8fffffff;
        $val = Hex2Bin(substr($text, $ix, 2));
        $val2 = (($val ^ $seed) & 0xff);
        $rc .= chr($val2);
        $ix += 2;
    }
    return $rc;
}    

my $CHARS10 = "9147253806";
my $CHARS16 = "fadceb" . $CHARS10;
my $CHARS26 = "zfsoeiurglhqnmwtbvpxyjakcd";
my $CHARS38 = "_." . $CHARS10 . $CHARS26;
my $CHARS64 = "QASDFGHJKLWERTZUIOPYXCVBNM" . $CHARS38;
my $CHARS76 = "!\@my \$%&#;,/+=?" . $CHARS64;
my $CHARS93 = "^`(>~[{<*)\" |}]-:" . $CHARS76;
my $CHARS95 = "'\\" . $CHARS93;
my $CHARS96 = "" . $CHARS95;
my $TAG_CHARS10 = "9";
my $TAG_CHARS16 = "f";
my $TAG_CHARS26 = "z";
my $TAG_CHARS38 = "_";
my $TAG_CHARS64 = "Q";
my $TAG_CHARS76 = "!";
my $TAG_CHARS93 = "^";
my $TAG_CHARS95 = "<";
my $TAG_CHARS96 = ">";
my @ALL_TAGS = ($TAG_CHARS10, $TAG_CHARS16, $TAG_CHARS26, $TAG_CHARS38,
    $TAG_CHARS64, $TAG_CHARS76, $TAG_CHARS93, $TAG_CHARS95, $TAG_CHARS96);
my %tagToSet = ( $TAG_CHARS10 => $CHARS10, $TAG_CHARS16 => $CHARS16,
    $TAG_CHARS26 => $CHARS26, $TAG_CHARS38 => $CHARS38, 
    $TAG_CHARS64 => $CHARS64, $TAG_CHARS76 => $CHARS76,
    $TAG_CHARS93 => $CHARS93, $TAG_CHARS95 => $CHARS95,
    $TAG_CHARS96 => $CHARS96 ); 
  
# ===
# @return a list of all charset tags
sub AllTags{
    return @ALL_TAGS;
} 
# ===
# Gets the charset given by the charset tag
# @param tag    the tag of the charset    
# @return       a string with all allowed characters
sub GetCharset{
    my $tag = shift;
    my $rc = $tagToSet{$tag};
    if ($rc eq ""){
        die "Unknown charset: $tag"
    }
    return $rc;
}

# ===
# Finds the character set to a given text.
# @param text   text to inspect
# @return       the tag of the charset containing all chars of the text
sub FindCharset{
    my $text = shift;
    my ($rc, $ix, $cc, $outside, $set);
    foreach my $tag (@ALL_TAGS){
        $set = GetCharset($tag);
        $outside = 0;
        for($ix = 0; $ix < length($text); $ix++){
            $cc = substr($text, $ix, 1);
            if (index($set, $cc) < 0){
                $outside = 1;
                last;
            }
        } 
        if (! $outside){
            $rc = $tag;
            last;
        }
    }
    return $rc;
}

# ===
# Scrambles (encrypts) a text.
# @param text   clear text
# @param tag    tag of the charset
# @return       the scrambled text
# 
sub Scramble{
    my $text = shift;
    my $tagCharset = shift;
    $tagCharset = FindCharset($text) unless $tagCharset;
    my $charset = GetCharset($tagCharset);
 
    my $seed2 = int(rand 0x7fff0000);
    $seed2 = 0x1234;
    my $size = length($charset);
    my $head = "";
    my $seed = 0;
    foreach(0..2){
        my $seedX = $seed2 % $size;
        $seed = $seed * $size + $seedX;
        $seed2 = int($seed2 / $size);
        $head .= substr($charset, $seedX, 1);
    }
    $head .= $tagCharset;
    my $rc = ""; 
    my $msg = sprintf("seed: %d", $seed);
    my $count = 0;
    while($count < length($text)){
        $seed = ($seed * 7 + 0x1234321) & 0x8fffffff;
        my $delta = 1 + $seed % ($size - 1);
        my $cc = substr($text, $count, 1);
        my $ix = index($charset, $cc);
        die sprintf("scrambleText: unknown char %s allowed: %s", $cc, $charset)
            if $ix < 0;
        $ix = ($ix + $delta) % $size;
        $rc .= substr($charset, $ix, 1);
        # $msg .= sprintf("\ncc: %s seed: %d ix: %d delta: %d val: %s", $cc, 
        #    $seed, $ix, $delta, substr($charset, $ix, 1));
        $count++;
    }
    return $head . $rc
}

# ===
# Decodes a text encrypted with Scramble.
# @param text       encrypted text
# @return           clear text
sub UnScramble{
    my $text = shift;
    my $tag = substr($text, 3, 1);
    my $charset = GetCharset($tag);
    my $size = length($charset);
    my $seed = 0;
    my $cc;
    foreach(0..2){
        $cc = substr($text, $_, 1); 
        $seed = $seed * $size + index($charset, $cc);
    }
    my $pos = 4;
    my $rc = "";
    my ($delta, $ix);
    while($pos < length($text)){
        $seed = ($seed * 7 + 0x1234321) & 0x8fffffff;
        $cc = substr($text, $pos, 1) . "";
        $delta = 1 + $seed % ($size - 1);
        $ix = index($charset, $cc) - $delta;
        $ix += $size if $ix < 0;
        $rc .= substr($charset, $ix, 1); 
        $pos++;
    }
    return $rc;
}
return 1;