#! /bin/sh

# Script for testing regular expressions with perl to check that PCRE2 handles
# them the same. For testing with different versions of Perl, if the first
# argument is -perl then the second is taken as the Perl command to use, and
# both are then removed. If the next argument is "-w", Perl is called with
# "-w", which turns on its warning mode.
#
# The Perl code has to have "use utf8" and "require Encode" at the start when
# running UTF-8 tests, but *not* for non-utf8 tests. (The "require" would
# actually be OK for non-utf8-tests, but is not always installed, so this way
# the script will always run for these tests.)
#
# The desired effect is achieved by making this a shell script that passes the
# Perl script to Perl through a pipe. If the next argument is "-utf8", a
# suitable prefix is set up.
#
# The remaining arguments, if any, are passed to Perl. They are an input file
# and an output file. If there is one argument, the output is written to
# STDOUT. If Perl receives no arguments, it opens /dev/tty as input, and writes
# output to STDOUT. (I haven't found a way of getting it to use STDIN, because
# of the contorted piping input.)

perl=perl
perlarg=''
prefix=''

if [ $# -gt 1 -a "$1" = "-perl" ] ; then
  shift
  perl=$1
  shift
fi

if [ $# -gt 0 -a "$1" = "-w" ] ; then
  perlarg="-w"
  shift
fi

if [ $# -gt 0 -a "$1" = "-utf8" ] ; then
  prefix="use utf8; require Encode;"
  shift
fi


# The Perl script that follows has a similar specification to pcre2test, and so
# can be given identical input, except that input patterns can be followed only
# by Perl's lower case modifiers and certain other pcre2test modifiers that are
# either handled or ignored:
#
#   aftertext          interpreted as "print $' afterwards"
#   afteralltext       ignored
#   dupnames           ignored (Perl always allows)
#   jitstack           ignored
#   mark               show mark information
#   no_auto_possess    ignored
#   no_start_optimize  insert (??{""}) at pattern start (disables optimizing)
#  -no_start_optimize  ignored
#   subject_literal    does not process subjects for escapes
#   ucp                sets Perl's /u modifier
#   utf                invoke UTF-8 functionality
#
# Comment lines are ignored. The #pattern command can be used to set modifiers
# that will be added to each subsequent pattern, after any modifiers it may
# already have. NOTE: this is different to pcre2test where #pattern sets
# defaults which can be overridden on individual patterns. The #subject command
# may be used to set or unset a default "mark" modifier for data lines. This is
# the only use of #subject that is supported. The #perltest, #forbid_utf, and
# #newline_default commands, which are needed in the relevant pcre2test files,
# are ignored. Any other #-command is ignored, with a warning message.
#
# The pattern lines should use only / as the delimiter. The other characters
# that pcre2test supports cause problems with this script.
#
# The data lines must not have any pcre2test modifiers. Unless
# "subject_literal" is on the pattern, data lines are processed as
# Perl double-quoted strings, so if they contain " $ or @ characters, these
# have to be escaped. For this reason, all such characters in the
# Perl-compatible testinput1 and testinput4 files are escaped so that they can
# be used for perltest as well as for pcre2test. The output from this script
# should be same as from pcre2test, apart from the initial identifying banner.
#
# The other testinput files are not suitable for feeding to perltest.sh,
# because they make use of the special modifiers that pcre2test uses for
# testing features of PCRE2. Some of these files also contain malformed regular
# expressions, in order to check that PCRE2 diagnoses them correctly.

(echo "$prefix" ; cat <<'PERLEND'

# The alpha assertions currently give warnings even when -w is not specified.

no warnings "experimental::alpha_assertions";
no warnings "experimental::script_run";

# Function for turning a string into a string of printing chars.

sub pchars {
my($t) = "";
if ($utf8)
  {
  @p = unpack('U*', $_[0]);
  foreach $c (@p)
    {
    if ($c >= 32 && $c < 127) { $t .= chr $c; }
      else { $t .= sprintf("\\x{%02x}", $c);
      }
    }
  }
else
  {
  foreach $c (split(//, $_[0]))
    {
    if (ord $c >= 32 && ord $c < 127) { $t .= $c; }
      else { $t .= sprintf("\\x%02x", ord $c); }
    }
  }
$t;
}


# Read lines from a named file or stdin and write to a named file or stdout;
# lines consist of a regular expression, in delimiters and optionally followed
# by options, followed by a set of test data, terminated by an empty line.

# Sort out the input and output files

if (@ARGV > 0)
  {
  open(INFILE, "<$ARGV[0]") || die "Failed to open $ARGV[0]\n";
  $infile = "INFILE";
  $interact = 0;
  }
else
  {
  open(INFILE, "</dev/tty") || die "Failed to open /dev/tty\n";
  $infile = "INFILE";
  $interact = 1;
  }

if (@ARGV > 1)
  {
  open(OUTFILE, ">$ARGV[1]") || die "Failed to open $ARGV[1]\n";
  $outfile = "OUTFILE";
  }
else { $outfile = "STDOUT"; }

printf($outfile "Perl $^V\n\n");

$extra_modifiers = "";
$default_show_mark = 0;

# Main loop

NEXT_RE:
for (;;)
  {
  printf "  re> " if $interact;
  last if ! ($_ = <$infile>);
  printf $outfile "$_" if ! $interact;
  next if ($_ =~ /^\s*$/ || $_ =~ /^#[\s!]/);

  # A few of pcre2test's #-commands are supported, or just ignored. Any others
  # cause an error.

  if ($_ =~ /^#pattern(.*)/)
    {
    $extra_modifiers = $1;
    chomp($extra_modifiers);
    $extra_modifiers =~ s/\s+$//;
    next;
    }
  elsif ($_ =~ /^#subject(.*)/)
    {
    $mod = $1;
    chomp($mod);
    $mod =~ s/\s+$//;
    if ($mod =~ s/(-?)mark,?//)
      {
      $minus = $1;
      $default_show_mark = ($minus =~ /^$/);
      }
    if ($mod !~ /^\s*$/)
      {
      printf $outfile "** Warning: \"$mod\" in #subject ignored\n";
      }
    next;
    }
  elsif ($_ =~ /^#/)
    {
    if ($_ !~ /^#newline_default|^#perltest|^#forbid_utf/)
      {
      printf $outfile "** Warning: #-command ignored: %s", $_;
      }
    next;
    }

  $pattern = $_;

  while ($pattern !~ /^\s*(.).*\1/s)
    {
    printf "    > " if $interact;
