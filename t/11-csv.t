#!perl

use Test::More;
use strict;
use Test::Requires qw/Text::CSV/;
use warnings;
use Data::Dumper;
BEGIN {
    use_ok( 'Text::Parts' ) || print "Bail out!";
}

foreach my $check (0 , 1) {
  my $csv = Text::CSV->new({'binary'=> 1, eol => "\r\n"});
  my $s = Text::Parts->new(file => "t/data/test.csv", parser => $csv, eol => "\r\n", check_line_start => $check);
  my @split = $s->split(num => 3);
  my @data;
  my $n = 0;
  for (my $i = 0; $i < @split; $i++) {
    my $f = $split[$i];
    ok ! $f->eof, 'not eof';
    $data[$i] ||= [];
    while (my $cols = $f->getline_parser) {
      push @{$data[$i]}, $cols;
    }
    ok $f->eof, 'eof';
  }

  is_deeply(\@data,
            [
             [
              [1,2,3],
              ["aaaaaaaaaaaaa","bbbbbbbbb", "c\r\nccccccccccccccccccccc"],
              ["eeeeeeeee","fffffffffff", "ggggggggg"],
             ],
             [
              ["hhhhhh", "iiiiiiiiiiiiiiiiiiiii","\r\njjjjjjjjjjjjjj"],
             ],
             [
              ["llllllllllllllllllllllllllll","mmmmm","n"],
             ]
            ]);
}
done_testing;
