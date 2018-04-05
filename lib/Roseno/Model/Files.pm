package Roseno::Model::Files;
use Moose;
use File::Path qw/make_path/;
use File::Copy;
use Imager;

extends 'Catalyst::Model';

has 'base_path' => ( is => 'rw' );

=head1 METHODS

=head2 add_file

Receives $tempname, $original_filename and $should_resize. Copies
files to "file" directory. Returns the filename(s).

=cut

sub add_file {
    my ($self, $tempname, $original_filename, $should_resize) = @_;

    $original_filename =~ s/\(|\)//g;
    $original_filename =~ s/\s+/-/g;

    my $rand     = join '', map { int rand 9 } 1..7;
    my $base_dir = join '/', $self->base_path, (split '', substr($rand, 0, 3));

    if (! -d $base_dir) { make_path $base_dir or warn $! }

    my $normal_filename = $rand . '-' . $original_filename;

    if (!$should_resize) {
        copy( $tempname, $base_dir . '/' . $normal_filename );
        return $normal_filename;
    }

    my ($ext)                  = $normal_filename =~ /(\.[\w\d]+)$/;
    my ($base_normal_filename) = $normal_filename =~ /(.*)\.[\w\d]+$/;

    my $medium_filename = $base_normal_filename . "_medium" . $ext;
    my $thumb_filename  = $base_normal_filename . "_thumb"  . $ext;

    my @resize_params = ([1200, $normal_filename],
                         [730,  $medium_filename],
                         [300,  $thumb_filename]);

    for my $values (@resize_params) {
        my $img = Imager->new(file => $tempname);
        my $other_img = $img->scale
          (xpixels => $values->[0], ypixels => $values->[0], type => 'min');
        $other_img->write(file => $base_dir . '/' . $values->[1]);
    }

    return $normal_filename;
}

=head2 del_file

Receives filename ("1234567-file.png"). Deletes it and its resized
versions, if they exist.

=cut

sub delete_file {
    my ($self, $normal_filename) = @_;
    my $base_dir = join '/',
      $self->base_path, (split '', substr($normal_filename, 0, 3));

    my ($ext)                  = $normal_filename =~ /(\.[\w\d]+)$/;
    my ($base_normal_filename) = $normal_filename =~ /(.*)\.[\w\d]+$/;

    unlink  $base_dir . '/' . $normal_filename
      if -e $base_dir . '/' . $normal_filename;

    unlink  $base_dir . '/' . $base_normal_filename . '_medium' . $ext
      if -e $base_dir . '/' . $base_normal_filename . '_medium' . $ext;

    unlink  $base_dir . '/' . $base_normal_filename . '_thumb' . $ext
      if -e $base_dir . '/' . $base_normal_filename . '_thumb' . $ext;
}

sub filename_with_dirs {
    my ($self, $filename, $type) = @_;
    my $dirs = join '/', split('', substr($filename, 0, 3));

    if (!$type or $type eq 'normal') {
        return '/files/' . $dirs . '/' . $filename;
    }

    my ($base, $ext) = $filename =~ /^(.+)(\.[\d\w]+)$/;
    return '/files/' . $dirs . '/' . $base . '_' . $type . $ext;
}

sub ACCEPT_CONTEXT {
    my ($self, $c) = @_;
    $self->base_path( $c->path_to(qw/root files/) );
    return $self;
}

1;
