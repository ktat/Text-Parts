#!perl

use Test::More;
use strict;
use warnings;
BEGIN {
    use_ok( 'Text::Parts' ) || print "Bail out!";
}

open my $fh, '>', 't/data/2048.txt' or die $!;
foreach my $i (1 .. 2048) {
  print $fh $i . "\n";
}
close $fh;
mkdir "t/tmp";
foreach my $check (0, 1) {
  my $s = Text::Parts->new(file => "t/data/2048.txt", no_open => 1);
  my $i = 0;
  foreach my $p ($s->split(num => 2048)) {
    $p->write_file("t/tmp/x" . ++$i . ".txt");
    my $file = "t/tmp/x" . $i . '.txt';
    ok -f $file, 'file exists';
    is $p->all, _read_file($file), "file contents is ok";
  }
  my @filenames = $s->write_files('t/tmp/xx%d.txt', num => 2048);
  foreach my $file (@filenames) {
    my $_file = $file;
    $_file =~s{/xx}{/x};
    ok -s $_file, 'file exsists';
    is -s $_file, -s $file, 'file size is same';
    unlink $file;
    unlink $_file;
  }
}

unlink 't/data/2048.txt';

sub _read_file {
  my ($f) = @_;
  local $/;
  open my $fh, '<', $f;
  my $str = <$fh>;
  close $fh;
  return $str;
}

done_testing;
