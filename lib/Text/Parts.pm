package Text::Parts;

use warnings;
use strict;
use Carp;
use File::Spec;

sub new {
  my ($class, %args) = @_;
  $args{eol} ||= $/;
  $args{file} = File::Spec->rel2abs($args{file})  if $args{file};
  bless \%args, $class;
}

sub eol {
  my $self = shift;
  $self->{eol} = File::Spec->rel2abs(shift) if @_;
  $self->{eol};
}

sub file {
  my $self = shift;
  $self->{file} = File::Spec->rel2abs(shift) if @_;
  $self->{file};
}

sub split {
  my ($self, %opt) = @_;
  my $num = $opt{num};
  Carp::croak('num must be grater than 1.') if $num <= 1;

  my $file = $self->file;
  my $file_size = -s $file;
  my $chunk_size = int $file_size / 4;
  my @parts;
  open my $fh, '<', $file or Carp::croak "$!: $file";
  local $/ = $self->{eol};
  my $start = 0;
  seek $fh, $start, 0;
  my $total;
  foreach my $i (0 .. $num -1) {
    $chunk_size = $file_size - $start if $start + $chunk_size > $file_size;
    last unless $chunk_size;

    seek $fh, $chunk_size - 1, 1;
    my $line = <$fh>;
    my $end = tell($fh) - 1;
    push @parts, Text::Parts::Part->new(file => $file, start => $start, end => $end, eol => $self->{eol});
    if (($num - $i > 1) and $chunk_size > 2 and (my $over = ($end - $start - $chunk_size)) > 0) {
      $chunk_size = int(($file_size - $end) / ($num - $i - 1));
      $chunk_size = 2 if $chunk_size < 3;
    }
    $start = $end + 1;
  }
  close $fh;
  return @parts;
}

package
  Text::Parts::Part;

use overload '<>' => \&getline;

sub new {
  my ($class, %args) = @_;
  open my $fh, '<', $args{file} or Carp::croak "$!: $args{file}";
  seek $fh, $args{start}, 0;
  bless {
         %args,
         fh    => $fh,
         next  => $args{start},
        }, $class;
}

sub getline {
  my ($self) = @_;
  return () if $self->{next} > $self->{end};

  local $/ = $self->{eol};
  my $fh = $self->{fh};
  my $line = <$fh>;
  $self->{next} = tell $fh;
  return $line;
}

sub eof {
  my ($self) = @_;
  $self->{end} <= $self->{next} ? 1 : 0;
}

=head1 NAME

Text::Parts - split text file to some parts

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Text::Parts;

    my $splitter = Text::Parts->new(file => $file);
    my (@parts) = $splitter->split(num => 4);

    foreach my $part (@parts) {
       while(my $l = $part->getline) { # or <$part>
          # ...
       }
    }

=head1 DESCRIPTION

This moudle splits file by specified number of part.
Each part is started from line start to line end.
For example, file content is the following:

 1111
 22222222222222222222
 3333
 4444

If C<< $splitter->split(num => 3) >>, split like the following:

1st part:
 1111
 22222222222222222222

2nd part:
 3333

3rd part:
 4444

At first, C<split> method trys to split by bytes of file size / 3,
Secondly, trys to split by bytes of rest file size / the number of rest part.
So that:

 1st part : 36 bytes / 3 = 12 byte + bytes to line end(if needed)
 2nd part : (36 - 26 bytes) / 2 = 5 byte + bytes to line end(if needed)
 last part: rest part of file

=head1 METHODS

=head2 new

 $s = Text::Parts->new(file => $filename);

Constructoer.

=head2 file

 my $file = $s->file;
 $s->file($filename);

get/set target file.

=head2 split

 my @parts = $s->split(num => $num);

Try to split target file to $num of parts. The returned value is array of Text::Parts::Part object.

=head2 eol

 my $eol = $s->eol;
 $s->eol($eol);

get/set end of line string. default value is $/.

=head1 Text::Parts::Part METHODS

=head2 getline

 my $line = $part->getline;

=head2 <$part>

 my $line = <$part>;

=head2 eof

 $part->eof;

If end of parts, return true.

=head1 AUTHOR

Ktat, C<< <ktat at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-text-parts at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-Parts>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::Parts


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-Parts>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Text-Parts>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Text-Parts>

=item * Search CPAN

L<http://search.cpan.org/dist/Text-Parts/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Ktat.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Text::Parts
