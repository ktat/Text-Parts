package Text::Parts;

use warnings;
use strict;
use Carp;
use File::Spec;

sub new {
  my ($class, %args) = @_;
  $args{eol} ||= $/;
  $args{file} = File::Spec->rel2abs($args{file})  if $args{file};
  $args{parser_method} ||= 'getline';
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

sub parser {
  my $self = shift;
  $self->{parser} = shift if @_;
  $self->{parser};
}

sub parser_method {
  my $self = shift;
  $self->{parser_method} = shift if @_;
  $self->{parser_method};
}

sub split {
  my ($self, %opt) = @_;
  Carp::croak("num or size is required.") if not $opt{num} and not $opt{size};

  my $num = $opt{num} ? $opt{num} : int((-s $self->file) / $opt{size});

  Carp::croak('num must be grater than 1.') if $num <= 1;

  my $file = $self->file;
  my $file_size = -s $file;
  my $chunk_size = int $file_size / $num;
  my @parts;
  open my $fh, '<', $file or Carp::croak "$!: $file";
  local $/ = $self->{eol};
  my $delimiter_size = length($/);
  my $start = 0;
  seek $fh, 0, 0;
  my $total;
  my $getline_method = $self->{parser} ? '_getline_parser' : '_getline';
  while ($num-- > 0) {
    $chunk_size = $file_size - $start if $start + $chunk_size > $file_size;
    last unless $chunk_size;

    seek $fh, $chunk_size - $delimiter_size, 1;
    $self->$getline_method($fh);
    my $end = tell($fh);
    push @parts, Text::Parts::Part->new(%$self, start => $start, end => $end - 1);
    $start = $end;
    if (($num > 1) and $chunk_size > $delimiter_size + 1) {
      $chunk_size = int(($file_size - $end) / $num);
      $chunk_size = $delimiter_size + 1 if $chunk_size < $delimiter_size + 1;
    }
  }
  close $fh;
  return @parts;
}

sub _getline {
  my ($self, $fh) = @_;
  <$fh>;
}

sub _getline_parser {
  my ($self, $fh) = @_;
  $self->{parser}->getline($fh);
}

package
  Text::Parts::Part;

use overload '<>' => \&getline;
# sub {
#   my $self = shift;
#   if (wantarray) {
#     my @lines;
#     until ($self->eof) {
#       push @lines, $self->getline;
#     }
#     return @lines;
#   } else {
#     return $self->getline;
#   }
# };

sub new {
  my ($class, %args) = @_;
  open my $fh, '<', $args{file} or Carp::croak "$!: $args{file}";
  seek $fh, $args{start}, 0;
  bless {
         %args,
         fh    => $fh,
        }, $class;
}

sub getline {
  my ($self) = @_;
  return () if $self->eof;

  local $/ = $self->{eol};
  my $fh = $self->{fh};
  return <$fh>;
}

sub getline_parser {
  my ($self) = @_;
  return () if $self->eof;

  if ($self->{parser}) {
    my $method = $self->{parser_method};
    $self->{parser}->$method($self->{fh});
  } else {
    Carp::croak("no parser object is given.");
  }
}

sub fh { $_[0]->{fh} }

sub eof {
  my ($self) = @_;
  $self->{end} <= tell($self->{fh}) ? 1 : 0;
}

=head1 NAME

Text::Parts - split text file to some parts

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

If you want to split Text file to specified parts:

    use Text::Parts;
    
    my $splitter = Text::Parts->new(file => $file);
    my (@parts) = $splitter->split(num => 4);

    foreach my $part (@parts) {
       while(my $l = $part->getline) { # or <$part>
          # ...
       }
    }

If you want to split Text file by specified size:

    use Text::Parts;
    
    my $splitter = Text::Parts->new(file => $file);
    my (@parts) = $splitter->split(size => 10);
    # same as the previous example

If you want to split CSV file:

    use Text::Parts;
    use Text::CSV_XS; # don't work with Text::CSV_PP
    
    my $csv = Text::CSV_XS->new();
    my $splitter = Text::Parts->new(file => $file, parser => $csv);
    my (@parts) = $splitter->split(num => 4);
    
    foreach my $part (@parts) {
       while(my $col = $part->getline_parser) { # getline_parser returns parsed result
          print join "\t", @$col;
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
 $s = Text::Parts->new(file => $filename, parser => Text::CSV_XS->new({binary => 1}));

Constructoer. can take following optins:

=head2 num

number how many you want to split.

=head2 size

file size how much you want to split.

=head3 file

target file which you want to split.

=head3 parser

Pass parser object(like Text::CSV_XS).
The object must have method which take filehandle.
method name is C<getline> as default.
If the object has different name of method, pass the name to parser_method.

=head3 parser_method

name of parser's method. default is C<getline>.

=head2 file

 my $file = $s->file;
 $s->file($filename);

get/set target file.

=head2 parser

 my $parser = $s->parser;
 $s->parser($parser);

get/set paresr.

=head2 parser_method

 my $method = $s->parser_method;
 $s->parser_method($method);

get/set paresr method.

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

return 1 line.

=head2 <$part>

 my $line = <$part>;

return 1 line.

=head2 getline_parser

 my $parsed = $part->getline_parser;

returns parsed result.

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
