package Text::Parts;

use warnings;
use strict;
use Carp ();
use Carp::Heavy ();
use File::Spec ();

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

sub _size {
  my ($self) = @_;
  return -s $self->{file};
}

sub split {
  my ($self, %opt) = @_;
  Carp::croak("num or size is required.") if not $opt{num} and not $opt{size};

  my $num = $opt{num} ? $opt{num} : int($self->_size / $opt{size});

  Carp::croak('num must be grater than 1.') if $num <= 1;

  my $file = $self->file;
  my $file_size = $self->_size;
  my $chunk_size = int $file_size / $num;
  my @parts;
  open my $fh, '<', $file or Carp::croak "$!: $file";
  local $/ = $self->{eol};
  my $delimiter_size = length($/);
  my $start = 0;
  seek $fh, 0, 0;
  my $total;
  my $getline_method = $self->{parser} ? '_getline_parser' : '_getline';
  $getline_method .= '_restrict' if $self->{check_line_start};
  while ($num-- > 0) {
    $chunk_size = $file_size - $start if $start + $chunk_size > $file_size;
    last unless $chunk_size;

    seek $fh, $chunk_size - $delimiter_size, 1;
    $self->$getline_method($fh);
    my $end = tell($fh);
    my %args = (%$self, (exists $opt{no_open} ? (no_open => $opt{no_open}) : ()));
    push @parts, Text::Parts::Part->new(%args, start => $start, end => $end - 1);
    $start = $end;
    if (($num > 1) and $chunk_size > $delimiter_size + 1) {
      $chunk_size = int(($file_size - $end) / $num);
      $chunk_size = $delimiter_size + 1 if $chunk_size < $delimiter_size + 1;
    }
  }
  close $fh;
  return @parts;
}

sub write_files {
  my ($self, $filename, %opt) = @_;
  $filename or Carp::croak("file is needed as first argument.");
  my $code = ref $opt{code} eq 'CODE' ? delete $opt{code} : undef;
  my @filename;
  my @parts = $self->split(%opt, no_open => 1);

  my $n = defined $opt{start_number} ? delete $opt{start_number} : 1;
  open my $fh, '<', $self->file or Carp::croak "cannot open file($!): " . $self->file;
  seek $fh, 0, 0;
  foreach my $part (@parts) {
    my $buf;
    read $fh, $buf, $part->{end} - $part->{start};
    push @filename, sprintf $filename, $n++;
    open my $fh_w, '>', $filename[-1] or Carp::croak("cannot open file($!): " . $filename[-1]);
    print $fh_w $buf;
    close $fh_w;
    $code and $code->($filename[-1]);
  }
  return @filename;
}

sub _getline {
  my ($self, $fh) = @_;
  <$fh>;
}

sub _getline_parser {
  my ($self, $fh) = @_;
  my $method = $self->{parser_method};
  $self->{parser}->$method($fh);
}

sub _getline_restrict {
  my ($self, $fh) = @_;
  $self->_move_line_start($fh);
  $self->_getline($fh);
}

sub _getline_parser_restrict {
  my ($self, $fh) = @_;
  $self->_move_line_start($fh);
  $self->_getline_parser($fh);
}

sub _move_line_start {
  my ($self, $fh) = @_;
  my $current = tell $fh;
  <$fh>;
  my $end     = tell $fh;
  my $size = $current - 1024 < 0 ? int($current / 2) : 1024;
  my $eol = $self->eol;
  my $check = 0;
  while ($end - $current + $size > 0 and $current - $size > 0) {
    seek $fh, $current - $size, 0;
    read $fh, my $buffer, $end - $current + $size;
    my @buffer = split /$eol/, $buffer;
    if (@buffer > 1) {
      $check = 1;
      $current = $end - (length($buffer[-1]) + length($eol));
      last;
    } else {
      $size += $size;
    }
  }
  seek $fh, ($check ? $current : 0), 0;
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
  my $fh;
  my $self = bless {%args}, $class;
  if (not $args{no_open}) {
    $self->open_and_seek;
  }
  $self;
}

sub open_and_seek {
  my ($self) = @_;
  open my $fh, '<', $self->{file} or Carp::croak("cannot read" . $self->{file} . ": $!");
  seek $fh, $self->{start}, 0;
  $self->{fh} = $fh;
}

sub is_opened {
  my ($self) = @_;
  return $self->{fh} ? 1 : 0;
}

sub close {
  my ($self) = @_;
  close $self->{fh};
  undef $self->{fh};
  $self->{_opend} = 0;
}

sub all {
  my ($self, $buf) = @_;
  my $buffer = '';
  my $_buf = $buf || \$buffer;
  if ($self->{no_open} and not $self->is_opened) {
    $self->open_and_seek;
    seek $self->fh, $self->{start}, 0 if $self->eof;
    read $self->fh, $$_buf, $self->{end} - $self->{start};
    $self->close;
  } else {
    seek $self->fh, $self->{start}, 0 if $self->eof;
    read $self->fh, $$_buf, $self->{end} - $self->{start};
  }
  return $buf ? () : $buffer;
}

sub write_file {
  my ($self, $name) = @_;
  $name or Carp::croak("file is needed.");
  if ($self->{no_open} and not $self->is_opened) {
    $self->open_and_seek;
    open my $fh, '>', $name or Carp::croak("cannot write $name: $!");
    print $fh $self->all;
    $self->close;
  } else {
    open my $fh, '>', $name or Carp::croak("cannot write $name: $!");
    print $fh $self->all;
  }
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

our $VERSION = '0.11';

=head1 NAME

Text::Parts - split text file to some parts(from one line start to another/same line end)

=head1 SYNOPSIS

If you want to split Text file to some number of parts:

    use Text::Parts;
    
    my $splitter = Text::Parts->new(file => $file);
    my (@parts) = $splitter->split(num => 4);

    foreach my $part (@parts) {
       while(my $l = $part->getline) { # or <$part>
          # ...
       }
    }

If you want to split Text file by about specified size:

    use Text::Parts;
    
    my $splitter = Text::Parts->new(file => $file);
    my (@parts) = $splitter->split(size => 10); # size of part will be more than 10.
    # same as the previous example

If you want to split CSV file:

    use Text::Parts;
    use Text::CSV_XS; # don't work with Text::CSV_PP if you want to use {binary => 1} option
    
    my $csv = Text::CSV_XS->new();
    my $splitter = Text::Parts->new(file => $file, parser => $csv);
    my (@parts) = $splitter->split(num => 4);
    
    foreach my $part (@parts) {
       while(my $col = $part->getline_parser) { # getline_parser returns parsed result
          print join "\t", @$col;
          # ...
       }
    }

Write parts to file:

   $splitter->write_files('file%d.csv', num => 4);
   
   my $i = 0;
   foreach my $part ($splitter->slit(num => 4)) {
     $part->write_file("file" . $i++ . '.csv');
   }

with Parallel::ForkManager:

  my $splitter = Text::Parts->new(file => $file);
  my (@parts) = $splitter->split(num => 4);
  my $pm = new Parallel::ForkManager(4);
  
  foreach my $part (@parts) {
    $pm->start and next; # do the fork
    
    while (my $l = $part->getline) {
      # ...
    }
  }
  
  $pm->wait_all_children;

NOTE THAT: If the file is on the same disk, fork is no use.
Maybe, using fork makes sense when the file is on RAID (I haven't try it).

=head1 DESCRIPTION

This moudle splits file by specified number of part.
The range of each part is from one line start to another/same line end.
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

Constructor. It can take following optins:

=head3 num

number how many you want to split.

=head3 size

file size how much you want to split.
This value is used for calucurating C<num>.
If file size is 100 and this value is 25, C<num> is 4.

=head3 file

target file which you want to split.

=head3 parser

Pass parser object(like Text::CSV_XS->new()).
The object must have method which takes filehandle and whose name is C<getline> as default.
If the object's method is different name, pass the name to C<parser_method> option.

=head3 parser_method

name of parser's method. default is C<getline>.

=head3 check_line_start

If this options is true, check line start and move to this position before C<< <$fh> >> or parser's C<getline>/C<parser_method>.
It may be useful when parser's C<getline>/C<parser_method> method doesn't work correctly when parsing wrong format.

default value is 0.

=head3 no_open

If this option is true, don't open file on creating Text::Parts::Part object.
You need to call C<open_and_seek> method from the object when you read the file
(But, C<all> and C<write_file> checks this option, so you don't need to call C<open_and_seek>).

This option is required when you pass too much number, wihch is more than OS's open file limit, to split method.

=head2 file

 my $file = $s->file;
 $s->file($filename);

get/set target file.

=head2 parser

 my $parser_object = $s->parser;
 $s->parser($parser_object);

get/set paresr object.

=head2 parser_method

 my $method = $s->parser_method;
 $s->parser_method($method);

get/set paresr method.


=head2 split

 my @parts = $s->split(num => $num);
 my @parts = $s->split(size => $size);

Try to split target file to C<$num> of parts. The returned value is array of Text::Parts::Part object.
If you pass C<< size => bytes >>, calcurate C<$num> from file size / C<$size>.

This returns array of Text::Parts::Part object.
See L</"Text::Parts::Part METHODS">.

This method doesn't actually split file, only calcurate the start and end poition of parts.

=head2 eol

 my $eol = $s->eol;
 $s->eol($eol);

get/set end of line string. default value is $/.

=head2 write_files

 @filenames = $s->write_files('path/to/name%d.txt', num => 4);

C<name_format> is the format of filename. %d is replaced by number.
For example:

 path/to/name1.txt
 path/to/name2.txt
 path/to/name3.txt
 path/to/name4.txt

The rest of arguments are as same as C<split> except the following 2 options.

=over 4

=item code

C<code> option takes code reference which would be done immediately after file had been written.
If you pass C<code> option as the following:

 @filenames = $s->write_files('path/to/name%d.txt', num => 4, code => \&do_after_split)

splited file name is given to &do_after_split:

 sub do_after_split {
    my $filename = shift; # 'path/to/name1.txt'
    # ...
    unlink $filename;
 }

=item start_number

This is use for filename.

if start_nubmer is 0.

 path/to/name0.txt
 path/to/name1.txt
 ...

if start_nubmer is 1 (default).

 path/to/name1.txt
 path/to/name2.txt
 ...

if start_nubmer is 2

 path/to/name2.txt
 path/to/name3.txt
 ...

=back

=head1 Text::Parts::Part METHODS

Text::Parts::Part objects are returned by C<split> method.

=head2 getline

 my $line = $part->getline;

return 1 line.
You can use C<< <$part> >>, also.

 my $line = <$part>

=head2 getline_parser

 my $parsed = $part->getline_parser;

returns parsed result.

=head2 all

 my $all = $part->all;
 $part->all(\$all);

return all of the part.
just C<read> from start to end position.

If scalar reference is passed as argument, the content of the part is into the passed scalar.

This method checks no_open option.
If no_open is ture, open file before writing file and close file after writing.

=head2 eof

 $part->eof;

If current position is the end of parts, return true.

=head2 write_file

 $part->write_file($filename);

Write the contents of the part to $filename.

This method checks no_open option.
If no_open is ture, open file before writing file and close file after writing.

=head2 open_and_seek

 $part->open_and_seek;

If the object is created with no_open true, you need to call this method before reading file.

=head2 close

 $part->close;

close file handle.

=head2 is_opened

 $part->is_opened;

If file handle is opend, return true.

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
