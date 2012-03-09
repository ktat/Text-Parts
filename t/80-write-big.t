#!perl

use Test::More;
use strict;
use warnings;
use Test::Requires qw/Digest::MD5/;

BEGIN {
    use_ok( 'Text::Parts' ) || print "Bail out!";
}

my $eol = "\r\n";
my $eol_len = length($eol);
open my $fh, '>', 't/data/2048.txt' or die $!;
foreach my $i (1 .. 2048) {
  print $fh random(100) . $eol;
}
close $fh;
mkdir "t/tmp";

my $s = Text::Parts->new(file => "t/data/2048.txt", no_open => 1);

$s->eol($eol);
my $i = 0;
foreach my $p ($s->split(num => 2048)) {
  $p->write_file("t/tmp/x" . ++$i . ".txt");
  my $file = "t/tmp/x" . $i . '.txt';
  is -s $file, 100;
}

my @filenames = $s->write_files('t/tmp/xx%d.txt', num => 2048);
foreach my $file (@filenames) {
  my $_file = $file;
  $_file =~s{/xx}{/x};
  ok -s $_file, 'file exsists';
  is Digest::MD5::md5_hex(_read_file($_file)), Digest::MD5::md5_hex(_read_file($file)), 'file checksum is same' or sleep 2;
  unlink $file;
  unlink $_file;
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

sub random {
  my $n = shift;
  my $str;
  $str .= ("a" .. "z", "A" .."Z", 0 .. 9)[rand 62] while $n--;
  $str;
}

done_testing;
