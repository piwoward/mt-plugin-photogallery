package PhotoGallery::App::CMS;

use strict;
use warnings;
use base qw( MT::App );
use MT::Asset;
sub plugin { MT->component('PhotoGallery') }

use MT::Util
  qw( format_ts encode_url dirify archive_file_for iso2ts ts2iso epoch2ts );
use MT::ConfigMgr;

use Data::Dumper;

sub _read_info {
    my $asset = shift;

    eval 'use Image::ExifTool qw(:Public)';
    if ($@) {
        return undef;
    }
    my $cache_prop = $asset->{__exifinfo} || undef;
    unless ($cache_prop) {
        my $tool = new Image::ExifTool;
        ($cache_prop) = $tool->ImageInfo( $asset->file_path );
        return '' unless $cache_prop;
        $asset->{__exifInfo} = $cache_prop;
    }
    return $cache_prop;
}

sub update_timestamps {
    my $app  = shift;
    my $q    = $app->can('query') ? $app->query : $app->param;
    my $blog = $app->blog;
    my $text;
    eval 'require Image::ExifTool';

    if ($@) {
        $text .= "Could not load Image::ExifTool";
    }
    else {
        my $iter = MT->model('entry')->load_iter( { blog_id => $blog->id } );
        while ( my $e = $iter->next ) {
            my $clause = '= asset_id';
            my @assets = MT->model('asset')->load(
                { class => '*' },
                {
                    join => MT->model('objectasset')->join_on(
                        undef,
                        {
                            asset_id  => \$clause,
                            object_ds => 'entry',
                            object_id => $e->id
                        }
                    )
                }
            );
            if (@assets) {
                my $a    = $assets[0];
                my $file = $a->file_path();
                if ( -r $file && -f $file ) {
                    $text .= $file . "\n";
                    if ( my $info = _read_info($a) ) {
                        my $date = $info->{'DateTimeOriginal'} || '';
                        $text .= '  Created: ' . $date . "\n";
                        if ($date) {
                            $date =~ s/[: ]//g;
                            $e->created_on($date);
                            $e->save or die $e->errstr;
                        }
                    }
                }
            }
        }
    }
    my $tmpl = $app->load_tmpl('dialog/upgrade.tmpl');
    $tmpl->param( blog_id => $blog->id );
    $tmpl->param( results => $text );
    return $app->build_page($tmpl);
}

sub upgrade {
    my $app  = shift;
    my $q    = $app->can('query') ? $app->query : $app->param;
    my $blog = $app->blog;
    my $text = '';

    require MT::Asset::ImagePhoto;
    require File::MimeInfo;
    my @entries = MT->model('entry')->load( { blog_id => $blog->id } );
    foreach my $e (@entries) {
        $text .= "Processing " . $e->title . "<br />";
        my ( $alt, $src ) =
          ( $e->text =~ /<img alt="([^\"]*)" src="([^\"]*)"/ );
        ( my $orig = $src ) =~ s/-photo\./\./;
        my ($ext) = ( $alt =~ /\.([a-z]*)$/i );
        my $base  = $blog->site_path;
        my $url   = $blog->site_url;
        ( my $rel_path = $orig ) =~ s/^$url//;
        my $new_path = $base . $rel_path;
        my $exists   = -e $new_path;
        my $mime     = File::MimeInfo::mimetype($new_path);

        $text .= "  original: $orig<br>";
        $text .= "  relative path: $rel_path<br>";
        $text .= "  new path: $new_path<br>";
        $text .= "    file exists? " . ( $exists ? "yes" : "no" ) . "<br>";
        $text .= "    ext: $ext<br>";
        $text .= "    filename: $alt<br>";
        $text .= "    mime: $mime<br>";

        my $a = MT->model('asset.photo')->new;
        $a->blog_id( $e->blog_id );
        $a->label( $e->title );
        $a->created_on( $e->created_on );
        $a->created_by( $e->created_by );
        $a->url($orig);
        $a->file_path($new_path);
        $a->file_name($alt);
        $a->file_ext($ext);
        $a->mime_type($mime);

        #	$a->save();

        $e->text( $e->excerpt );
        $e->excerpt('');
        $e->text_more( $a->as_html );

        $e->title( $a->file_name );
        $e->text( $q->param('text') );
        $e->text_more( $a->as_html );
        $e->allow_comments( $q->param('allow_comments') );

        $e->save or die $e->errstr;

    }

    my $tmpl = $app->load_tmpl('dialog/upgrade.tmpl');
    $tmpl->param( blog_id => $blog->id );
    $tmpl->param( results => $text );
    return $app->build_page($tmpl);
}

# The popup dialog to add a photo to a gallery.
sub start_upload {
    my ($app) = shift;
    my $q     = $app->can('query') ? $app->query : $app->param;
    my $blog  = $app->blog;

    # First, we *only* want to work in blogs that are photo gallery blogs.
    my $set = $blog->template_set;
    return $app->return_to_dashboard( redirect => 1 )
        unless $app->registry('template_sets', $set, 'photo_gallery');

    my $tmpl = $app->component('PhotoGallery')->load_tmpl('dialog/start.tmpl');

    my $iter = MT->model('category')->load_iter( { blog_id => $blog->id } );
    my @category_loop;
    while ( my $cat = $iter->() ) {
        push @category_loop,
          {
            category_id       => $cat->id,
            category_label    => $cat->label,
            category_selected => ( $cat->id == ($q->param('category_id') || 0) ),
          };
    }
    @category_loop =
      sort { $a->{category_label} cmp $b->{category_label} } @category_loop;

    $tmpl->param( blog_id       => $blog->id );
    $tmpl->param( finish        => $q->param('finish') );
    $tmpl->param( category_loop => \@category_loop );
    return $app->build_page($tmpl);
}

sub save_photo {
    my $app = shift;

    my $q = $app->can('query') ? $app->query : $app->param;

    my $asset = MT->model('asset.photo')->load( $q->param('asset_id') );

    my $entry = MT->model('entry')->load( $q->param('entry_id') );
    $entry->title( $q->param('label') );
    $entry->text( $q->param('caption') );
    $entry->allow_comments( $q->param('allow_comments') eq "1" ? 1 : 0 );
    $entry->allow_pings(0);
    $entry->basename( MT::Util::make_unique_basename($entry) );
    $entry->add_tags( $q->param('tags') );

    my $author = $app->user;
    my $blog   = $app->blog;
    my $cb     = $author->text_format || $blog->convert_paras;
    $cb = '__default__' if $cb eq '1';
    $entry->convert_breaks($cb);

    require MT::Tag;
    my $tags      = $app->param('tags');
    my $tag_delim = chr( $app->user->entry_prefs->{tag_delim} );
    my @tags      = MT::Tag->split( $tag_delim, $tags );
    if (@tags) {
        $entry->set_tags(@tags);
    }
    if ( $q->param('publish_date') ) {
        $entry->authored_on( $q->param('publish_date') );
        $entry->created_on( $q->param('publish_date') );
    }
    $entry->save or die $entry->errstr;

    # TODO - trigger rebuild
    $app->rebuild_entry( Entry => $entry, BuildDependencies => 1 );

    start_upload($app);
}

sub upload_photo {
    my $app    = shift;
    my $plugin = $app->instance;
    my $q      = $app->can('query') ? $app->query : $app->param;

    # Indicates to overwrite any duplicate files with the same name
    # Note: these should only be turned on if the file has previously
    #       been determined to exist.
    #$q->param('overwrite_yes', 0);
    #$q->param('overwrite_no', 0);

    # Directs the app to use a custom path
    $q->param( 'site_path', '1' );

    # selected when and if the user is uploading files into their archives
    #$q->param('extra_path_archive', '');

    # the path to append to the local path site
    #$q->param('extra_path_site', 'uploaded_photos');

    # Present if there is a need to point to the location of the temp
    # file created during the upload process
    #$q->param('temp', '');

    my $cat;
    my $cat_id = $q->param('category_id');
    if ( $cat_id eq "__new" ) {
        my $cat_name = $q->param('new_album_name') || 'Untitled';
        $cat = MT->model('category')->new;
        $cat->label($cat_name);
        $cat->blog_id( $app->blog->id );
        $cat->save or die $cat->errstr;
    }
    else {
        $cat = MT->model('category')->load( $cat_id, { cached_ok => 1 } );
    }
    $q->param( 'extra_path_site', dirify( $cat->label ) ) if $cat;

    # I didn't have the patience to do this right. I simply
    # copy-and-pasted the contents of MT::App::CMS::upload_file into
    # this subroutine. Lame. I know.
    my ( $fh, $no_upload );
    if ( $ENV{MOD_PERL} ) {
        my $up = $q->upload('file');
        $no_upload = !$up || !$up->size;
        $fh = $up->fh if $up;
    }
    else {
        ## Older versions of CGI.pm didn't have an 'upload' method.
        eval { $fh = $q->upload('file') };
        if ( $@ && $@ =~ /^Undefined subroutine/ ) {
            $fh = $q->param('file');
        }
        $no_upload = !$fh;
    }

    my $has_overwrite = $q->param('overwrite_yes') || $q->param('overwrite_no');
    return $app->error( $app->translate("You did not choose a file to upload.") )
        if $no_upload && !$has_overwrite;

    my ( $root_path, $relative_path, $relative_url, $base_url, $asset_base_url,
         $asset_file, $mimetype, $local_file, $basename, $relative_path_save );

    my $blog_id = $q->param('blog_id');
    my $blog    = $app->blog;
    my $fmgr    = $blog->file_mgr;

    # Determine filename of uploaded file. Automatically increment basename
    #if previous one exists.
    my $i = 0;
    do {
        $basename = $q->param('file') || $q->param('fname');
        if ($i > 0) {
            $basename .= "_" . $i;
        }
        $i++;
        $basename =~ s!\\!/!g;    ## Change backslashes to forward slashes
        $basename =~ s!^.*/!!;    ## Get rid of full directory paths
        if ( $basename =~ m!\.\.|\0|\|! ) {
            return $app->error(
                $app->translate( "Invalid filename '[_1]'", $basename ) );
        }
     
        ## Set up the full path to the local file; this path could start
        ## at either the Local Site Path or Local Archive Path, and could
        ## include an extra directory or two in the middle.
     
        $root_path = $blog->site_path;
        $relative_path = archive_file_for( undef, $blog, 'Category', $cat );
        $relative_path =~ s/\/[a-z\.]*$//;
     
        $relative_path_save = $relative_path;
        my $path            = $root_path;
        if ($relative_path) {
            if ( $relative_path =~ m!\.\.|\0|\|! ) {
                return $app->error(
                    $app->translate( "Invalid extra path '[_1]'", $relative_path )
                    );
            }
            $path = File::Spec->catdir( $path, $relative_path );
            ## Untaint. We already checked for security holes in $relative_path.
            ($path) = $path =~ /(.+)/s;
            ## Build out the directory structure if it doesn't exist. DirUmask
            ## determines the permissions of the new directories.
            unless ( $fmgr->exists($path) ) {
                $fmgr->mkpath($path)
                    or return $app->error(
                        $app->translate(
                            "Can't make path '[_1]': [_2]",
                            $path, $fmgr->errstr
                        )
                    );
            }
        }
     
        $relative_url =
            File::Spec->catfile( $relative_path, encode_url($basename) );
        $relative_path =
            $relative_path
            ? File::Spec->catfile( $relative_path, $basename )
            : $basename;
        $asset_file = $q->param('site_path') ? '%r' : '%a';
        $asset_file = File::Spec->catfile( $asset_file, $relative_path );
        $local_file = File::Spec->catfile( $path,       $basename );
        $base_url =
            $app->param('site_path')
            ? $blog->site_url
            : $blog->archive_url;
        $asset_base_url = $app->param('site_path') ? '%r' : '%a';
     
        ## Untaint. We have already tested $basename and $relative_path for
        ## security issues above, and we have to assume that we can trust the
        ## user's Local Archive Path setting. So we should be safe.
        ($local_file) = $local_file =~ /(.+)/s;
     
    } while ( $fmgr->exists($local_file) );

    ## If $local_file already exists, we try to write the upload to a
    ## tempfile, then ask for confirmation of the upload.
    if ( $fmgr->exists($local_file) and 0 ) {
        if ($has_overwrite) {
            my $tmp = $q->param('temp');
            if ( $tmp =~ m!([^/]+)$! ) {
                $tmp = $1;
            }
            else {
                return $app->error(
                    $app->translate( "Invalid temp file name '[_1]'", $tmp ) );
            }
            my $tmp_dir = $app->config('TempDir');
            my $tmp_file = File::Spec->catfile( $tmp_dir, $tmp );
            if ( $q->param('overwrite_yes') ) {
                $fh = gensym();
                open $fh, $tmp_file
                  or return $app->error(
                    $app->translate(
                        "Error opening '[_1]': [_2]",
                        $tmp_file, "$!"
                    )
                  );
            }
            else {
                if ( -e $tmp_file ) {
                    unlink($tmp_file)
                      or return $app->error(
                        $app->translate(
                            "Error deleting '[_1]': [_2]",
                            $tmp_file, "$!"
                        )
                      );
                }
                return $app->start_upload;
            }
        }
        else {
            eval { require File::Temp };
            if ($@) {
                return $app->error(
                    $app->translate(
                        "File with name '[_1]' already exists. (Install "
                          . "File::Temp if you'd like to be able to overwrite "
                          . "existing uploaded files.)",
                        $basename
                    )
                );
            }
            my $tmp_dir = $app->config('TempDir');
            my ( $tmp_fh, $tmp_file );
            eval {
                ( $tmp_fh, $tmp_file ) =
                  File::Temp::tempfile( DIR => $tmp_dir );
            };
            if ($@) {    #!$tmp_fh) {
                return $app->errtrans(
                    "Error creating temporary file; please check your TempDir "
                      . "setting in mt.cfg (currently '[_1]') "
                      . "this location should be writable.",
                    (
                          $tmp_dir
                        ? $tmp_dir
                        : '[' . $app->translate('unassigned') . ']'
                    )
                );
            }
            defined( MT::App::CMS::_write_upload( $fh, $tmp_fh ) )
              or return $app->error(
                $app->translate(
                    "File with name '[_1]' already exists; Tried to write "
                      . "to tempfile, but open failed: [_2]",
                    $basename,
                    "$!"
                )
              );
            my ( $vol, $path, $tmp ) = File::Spec->splitpath($tmp_file);
            return $app->build_page(
                $plugin->load_tmpl('dialog/upload_confirm.tmpl'),
                {
                    blog_id    => $blog->id,
                    blog_name  => $blog->name,
                    site_path  => '1',
                    temp       => $tmp,
                    extra_path => $relative_path_save,
                    site_path  => scalar $q->param('site_path'),
                    fname      => $basename
                }
            );
        }
    }

    ## File does not exist, or else we have confirmed that we can overwrite.
    my $umask = oct $app->config('UploadUmask');
    my $old   = umask($umask);
    defined( my $bytes = $fmgr->put( $fh, $local_file, 'upload' ) )
      or return $app->error(
        $app->translate(
            "Error writing upload to '[_1]': [_2]", $local_file,
            $fmgr->errstr
        )
      );
    umask($old);

    ## Use Image::Size to check if the uploaded file is an image, and if so,
    ## record additional image info (width, height). We first rewind the
    ## filehandle $fh, then pass it in to imgsize.
    seek $fh, 0, 0;
    eval { require Image::Size; };
    return $app->error(
        $app->translate(
                "Perl module Image::Size is required to determine "
              . "width and height of uploaded images."
        )
    ) if $@;
    my ( $w, $h, $id ) = Image::Size::imgsize($fh);

    ## Close up the filehandle.
    close $fh;

    ## If we are overwriting the file, that means we still have a temp file
    ## lying around. Delete it.
    if ( $q->param('overwrite_yes') ) {
        my $tmp = $q->param('temp');
        if ( $tmp =~ m!([^/]+)$! ) {
            $tmp = $1;
        }
        else {
            return $app->error(
                $app->translate( "Invalid temp file name '[_1]'", $tmp ) );
        }
        my $tmp_file = File::Spec->catfile( $app->config('TempDir'), $tmp );
        unlink($tmp_file)
          or return $app->error(
            $app->translate( "Error deleting '[_1]': [_2]", $tmp_file, "$!" ) );
    }

    ## We are going to use $relative_path as the filename and as the url passed
    ## in to the templates. So, we want to replace all of the '\' characters
    ## with '/' characters so that it won't look like backslashed characters.
    ## Also, get rid of a slash at the front, if present.
    $relative_path =~ s!\\!/!g;
    $relative_path =~ s!^/!!;
    $relative_url  =~ s!\\!/!g;
    $relative_url  =~ s!^/!!;

    my $url = $base_url;
    $url .= '/' unless $url =~ m!/$!;
    $url .= $relative_url;
    my $asset_url = $asset_base_url . '/' . $relative_url;

    require File::Basename;
    my $local_basename = File::Basename::basename($local_file);
    my $ext =
      ( File::Basename::fileparse( $local_file, qr/[A-Za-z0-9]+$/ ) )[2];

    if ( defined($w) && defined($h) ) {
        eval { require MT::Image; MT::Image->new or die; };
    }

    my $asset = MT->model('asset.photo')->new();
    $asset->label($local_basename);
    $asset->file_path($asset_file);
    $asset->file_name($local_basename);
    $asset->file_ext($ext);
    $asset->blog_id($blog_id);
    $asset->created_by( $app->user->id );
    $asset->save();

    my $original = $asset->clone;
    $asset->url($asset_url);
    $asset->image_width($w);
    $asset->image_height($h);
    $asset->mime_type($mimetype) if $mimetype;
    $asset->save or die $asset->errstr;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    $app->run_callbacks(
        'cms_upload_file.' . $asset->class,
        File  => $local_file,
        file  => $local_file,
        Url   => $url,
        url   => $url,
        Size  => $bytes,
        size  => $bytes,
        Asset => $asset,
        asset => $asset,
        Type  => 'image',
        type  => 'image',
        Blog  => $blog,
        blog  => $blog
    );
    $app->run_callbacks(
        'cms_upload_image',
        File       => $local_file,
        file       => $local_file,
        Url        => $url,
        url        => $url,
        Size       => $bytes,
        size       => $bytes,
        Asset      => $asset,
        asset      => $asset,
        Height     => $h,
        height     => $h,
        Width      => $w,
        width      => $w,
        Type       => 'image',
        type       => 'image',
        ImageType  => $id,
        image_type => $id,
        Blog       => $blog,
        blog       => $blog
    );

    my $entry = MT->model('entry')->new;
    $entry->blog_id( $app->blog->id );
    $entry->author_id( $app->{author}->id );
    $entry->title( $asset->file_name );
    $entry->category_id( $cat->id );
    $entry->text( $q->param('text') );
    $entry->text_more( $asset->as_html );
    $entry->allow_comments( $q->param('allow_comments') );

    # Set the entry status to based on the blog default, which will respect if
    # the admin prefers entries to stay unpublished by default, for example.
    $entry->status( $blog->status_default );

    eval 'require Image::ExifTool';
    my $exif_date;
    if ( !$@ ) {
        my $info = _read_info($asset);
        my $date = $info->{'DateTimeOriginal'} || '';
        if ($date) {
            $date =~ s/[: ]//g;
            $entry->created_on($date);
            $exif_date = $date;
        }
    }

    $entry->save or die $entry->errstr;

    if (MT->version_number >= 4.3) {
        # this must be done because MT 4.3 no longer processes a form tag to associate
        # assets to posts
        my $map = MT->model('objectasset')->new;
        $map->blog_id($entry->blog_id);
        $map->asset_id($asset->id);
        $map->object_ds('entry');
        $map->object_id($entry->id);
        $map->save or die $map->errstr;
    }

    if ( $q->param('is_favorite') ) { $entry->add_tags( ['@favorite'] ); }

    ## Now that the object is saved, we can be certain that it has an
    ## ID. So we can now add/update/remove the primary placement.
    $app->delete_param('category_id');

    my $place =
      MT->model('placement')->load( { entry_id => $entry->id, is_primary => 1 } );
    if ( $cat->id ) {
        unless ($place) {
            $place = MT->model('placement')->new;
            $place->entry_id( $entry->id );
            $place->blog_id( $entry->blog_id );
            $place->is_primary(1);
        }
        $place->category_id( $cat->id );
        $place->save or die $place->errstr;
    }
    else {
        if ($place) {
            $place->remove;
        }
    }

    # save secondary placements...
    my @place = MT->model('placement')->load(
        {
            entry_id   => $entry->id,
            is_primary => 0
        }
    );
    for my $place (@place) {
        $place->remove;
    }

    # Normally an "original object" ($orig_obj or $orig_entry) would be
    # included with the callback, however since we know this is always a new
    # entry this can be undef.
    $app->run_callbacks( 'cms_post_save.entry', $app, $entry, undef );

    my %arg;
    if ( $asset->image_width > $asset->image_height ) {
        $arg{Width} = 200;
    }
    else {
        $arg{Height} = 200;
    }
    ( $url, $w, $h ) = $asset->thumbnail_url(%arg);

    my $tmpl = $app->load_tmpl('dialog/edit_photo.tmpl');
    $tmpl->param( blog_id        => $blog->id );
    $tmpl->param( entry_id       => $entry->id );
    $tmpl->param( allow_comments => $blog->allow_comments_default );
    $tmpl->param( fname          => $asset->label );
    $tmpl->param( thumbnail      => $url );
    $tmpl->param( asset_id       => $asset->id );
    $tmpl->param( is_image       => 1 );
    $tmpl->param( url            => $asset->url );
    $tmpl->param( category_id    => $cat->id );
    $tmpl->param( has_exif       => $exif_date ? 1 : 0 );
    if ( $tmpl->param('has_exif') ) {

        my $info = _read_info($asset);
        $tmpl->param( caption => $info->{'ImageDescription'} || '' );
        $tmpl->param( artist  => $info->{'Artist'}           || '' );

        my $date_format = "%Y.%m.%d";
        my @ts = MT::Util::offset_time_list( time, $blog->id );
        my $ts = sprintf '%04d%02d%02d%02d%02d%02d', $ts[5] + 1900, $ts[4] + 1,
          @ts[ 3, 2, 1, 0 ];
        $tmpl->param( date_taken => $exif_date );
        $tmpl->param( date_today => $ts );
        $tmpl->param(
            date_taken_fmt => format_ts(
                $date_format, $exif_date, $app->blog,
                $app->user ? $app->user->preferred_language : undef
            )
        );
        $tmpl->param(
            date_today_fmt => format_ts(
                $date_format, $ts, $app->blog,
                $app->user ? $app->user->preferred_language : undef
            )
        );
    }

    #    $tmpl->param(middle_path   => $app->param('middle_path') || '');
    #    $tmpl->param(extra_path    => $app->param('extra_path') || '');
    return $app->build_page($tmpl);
}

# The user has chosen to Batch Upload Photos.
sub start_batch {
    my $app   = shift;
    my $blog  = $app->blog;
    my $q     = $app->can('query') ? $app->query : $app->param;
    my $param = {};

    # First, we *only* want to work in blogs that are photo gallery blogs.
    my $set = $blog->template_set;
    return $app->return_to_dashboard( redirect => 1 )
        unless $app->registry('template_sets', $set, 'photo_gallery');

    return $app->show_error('Insufficient permissions to upload files or '
        . 'create entries on this blog.')
        if !$app->user->permissions($blog->id)->can_upload
            || !$app->user->permissions($blog->id)->can_post;

    # Populate the Photo Album (categories) dropdown picker.
    my $iter = MT->model('category')->load_iter({ blog_id => $blog->id });
    my @category_loop;
    while ( my $cat = $iter->() ) {
        push @category_loop,
            {
                category_id       => $cat->id,
                category_label    => $cat->label,
                category_selected => ( $cat->id == ($q->param('category_id') || 0) ),
            };
    }
 
    # Sort the categories alphabetically.
    @category_loop =
        sort { $a->{category_label} cmp $b->{category_label} } @category_loop;

    $param->{category_loop}    = \@category_loop;
    $param->{can_publish_post} = $app->permissions->can_publish_post;
    $param->{status_default}   = $blog->status_default;

    $app->load_tmpl('batch_upload.tmpl', $param);
}

# The Ajax call for the automatic multi-file upload process.
sub multi_upload_photo {
    my ($app)  = shift;
    my $q    = $app->can('query') ? $app->query : $app->param;
    my $blog = $app->blog;

    return MT::Util::to_json({
        status  => -1,
        message => 'Insufficient permissions to upload files to this blog.',
    })
        if !$app->user->permissions($blog->id)->can_upload;

    return MT::Util::to_json({
        status  => -1,
        message => "No blog specified in request? This shouldn't happen.",
    })
        if !$blog;

    $app->validate_magic()
        or return MT::Util::to_json({
            status  => -1,
            message => 'Invalid request.'
        });

    # Use the specified category ID to load that category. Or, if a new album
    # is to be created we need to first check that it's indeed new before
    # creating.
    my $cat;
    my $cat_is_new = 0;
    my $cat_id = $q->param('category_id');

    if ( $cat_id eq '__new' || $cat_id eq '' ) {
        # Check if the category exists before trying to create it.
        my $cat_label = $q->param('new_album_name') || 'Untitled';
        unless (
            $cat = MT->model('category')->load({
                label => $cat_label,
            })
        ) {
            # This album is definitely new, so let's create it.
            $cat = MT->model('category')->new;
            $cat->label( $cat_label );
            $cat->blog_id( $blog->id );
            $cat->save or die MT::Util::to_json({
                status  => -1,
                message => $cat->errstr,
            });
            $cat_is_new = 1; # Note that we just created this so it can be
                             # reported to the user.
        }
    }
    else {
        $cat = MT->model('category')->load( $cat_id, { cached_ok => 1 } )
            or return MT::Util::to_json({
                status  => -1,
                message => 'Album (category) ID ' . $q->param('category_id')
                    . ' could not be found.',
            });
    }

    my @files = $q->param('files');

    # The foreach should be unneeded because the fileupload jQuery plugin
    # should always only submit one file at a time... right?
    my ($file, $asset);
    foreach $file (@files) {
        $asset = _write_file({
            app      => $app,
            blog     => $blog,
            category => $cat,
            filename => $file,
        });

        return MT::Util::to_json({
            status     => 1,
            sort_order => $q->param('sort_order') || '0',
            cat_label  => $cat->label,
            cat_id     => $cat->id,
            cat_is_new => $cat_is_new,
            orig_name  => "$file", # If unquoted, throws an error.
            asset_id   => $asset->id,
            asset_name => $asset->label,
            asset_url  => $asset->url,
            asset_w    => $asset->image_width,
            asset_h    => $asset->image_height,
            blog_id    => $blog->id,
        });
    }

}

# Write the file the user wants to upload.
sub _write_file {
    my ($arg_ref) = @_;
    my $app      = $arg_ref->{app};
    my $blog     = $arg_ref->{blog};
    my $cat      = $arg_ref->{category};
    my $filename = $arg_ref->{filename};

    my ( $fh, $no_upload );
    if ( $ENV{MOD_PERL} ) {
        $fh = $filename->fh;
    }
    else {
        $fh = $filename;
    }

    # Run the uploaded file through the DeniedAssetFileExtensions and
    # AssetFileExtensions config directive options. We want to respect the
    # admins preference here to not upload "bad" things.
    if ( my $deny_exts = $app->config->DeniedAssetFileExtensions ) {
        my @deny_exts = map {
            if   ( $_ =~ m/^\./ ) {qr/$_/i}
            else                  {qr/\.$_/i}
        } split '\s?,\s?', $deny_exts;
        my @ret = File::Basename::fileparse( $filename, @deny_exts );
        if ( $ret[2] ) {
            return $app->error(
                $app->translate(
                    'The file([_1]) you uploaded is not allowed.', $filename
                )
            );
        }
    }
    if ( my $allow_exts = $app->config('AssetFileExtensions') ) {
        my @allow_exts = map {
            if   ( $_ =~ m/^\./ ) {qr/$_/i}
            else                  {qr/\.$_/i}
        } split '\s?,\s?', $allow_exts;
        my @ret = File::Basename::fileparse( $filename, @allow_exts );
        unless ( $ret[2] ) {
            return $app->error(
                $app->translate(
                    'The file([_1]) you uploaded is not allowed.', $filename
                )
            );
        }
    }

    # We need to ensure that the filename is "safe."
    my ($basename, undef, $ext)
        = File::Basename::fileparse($filename, qr/\.[A-Za-z0-9]+$/);
    if ( $basename =~ m!\.\.|\0|\|! ) {
        return $app->error(
            $app->translate( "Invalid filename '[_1]'", $basename ) );
    }

    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new( 'Local' );

    # Set up the full path to the local file; this path could start at
    # either the Local Site Path or Local Archive Path, and could include an
    # extra directory or two in the middle.
    my $root_path = $blog->site_path;
    my $relative_path = archive_file_for( undef, $blog, 'Category', $cat );
    $relative_path =~ s/\/[a-z\.]*$//;

    my $relative_path_save = $relative_path;
    my $path               = $root_path;
    if ($relative_path) {
        if ( $relative_path =~ m!\.\.|\0|\|! ) {
            return $app->error(
                $app->translate( "Invalid extra path '[_1]'", $relative_path )
            );
        }
        $path = File::Spec->catdir( $path, $relative_path );
        ## Untaint. We already checked for security holes in $relative_path.
        ($path) = $path =~ /(.+)/s;
        ## Build out the directory structure if it doesn't exist. DirUmask
        ## determines the permissions of the new directories.
        unless ( $fmgr->exists($path) ) {
            $fmgr->mkpath($path)
                or return $app->error(
                    $app->translate(
                        "Can't make path '[_1]': [_2]",
                        $path, $fmgr->errstr
                    )
                );
        }
    }

    # Ensure that we've got a unique file by incrementing the file's basename.
    my ( $unique_id, $relative_url, $local_file, $asset_file,
        $base_url, $asset_base_url );
    my $i = 0;
    do {
        # Use $i and the $unique_id to ensure that we have a unique file name.
        if ($i > 0) {
            $unique_id = '_' . $i;
        }
        $i++;

        # Reconstruct the filename, which includes the updated file count in
        # the basename to make the filename unique.
        $filename = $basename . $unique_id . $ext;

        $relative_url =
            File::Spec->catfile( $relative_path_save, encode_url($filename) );
        $relative_path =
            $relative_path_save
            ? File::Spec->catfile( $relative_path_save, $filename )
            : $filename;

        $asset_file = ($blog->archive_path eq $blog->site_path)
            ? '%r'
            : '%a';
        $asset_file = File::Spec->catfile( $asset_file, $relative_path );
        $local_file = File::Spec->catfile( $path, $filename );

        $base_url = ($blog->archive_path eq $blog->site_path)
            ? $blog->site_url
            : $blog->archive_url;
        $asset_base_url = ($blog->archive_path eq $blog->site_path)
            ? '%r'
            : '%a';

        # Untaint. We have already tested $basename and $relative_path for
        # security issues above, and we have to assume that we can trust the
        # user's Local Archive Path setting. So we should be safe.
        ($local_file) = $local_file =~ /(.+)/s;
    } while ( $fmgr->exists($local_file) );

    # By incrementing the basename we've guaranteed a unique basename was
    # found, so we can just write it now.
    my $umask = oct $app->config('UploadUmask');
    my $old   = umask($umask);
    defined( my $bytes = $fmgr->put( $fh, $local_file, 'upload' ) )
        or return $app->error(
            $app->translate(
                "Error writing upload to '[_1]': [_2]", $local_file,
                $fmgr->errstr
            )
        );
    umask($old);

    # Use Image::Size to check if the uploaded file is an image, and if so,
    # record additional image info (width, height). We first rewind the
    # filehandle $fh, then pass it in to imgsize.
    seek $fh, 0, 0;
    eval { require Image::Size; };
    return $app->error(
        $app->translate(
                "Perl module Image::Size is required to determine "
              . "width and height of uploaded images."
        )
    ) if $@;
    my ( $w, $h, $id ) = Image::Size::imgsize($fh);

    ## Close up the filehandle.
    close $fh;

    my $url = $base_url;
    $url .= '/' unless $url =~ m!/$!;
    $url .= $relative_url;
    my $asset_url = $asset_base_url . '/' . $relative_url;

    # Create an asset with the uploaded photo.
    my $asset = MT->model('asset.photo')->new();
    $asset->label(      $filename      );
    $asset->file_path(  $asset_file    );
    $asset->file_name(  $filename      );
    $ext =~ s/^\.//;
    $asset->file_ext(   $ext           );
    $asset->blog_id(    $blog->id      );
    $asset->created_by( $app->user->id );
    $asset->url(        $asset_url     );

    if ( defined($w) && defined($h) ) {
        eval { require MT::Image; MT::Image->new or die; };
        $asset->image_width($w);
        $asset->image_height($h);
    }

    my $original = $asset->clone;
    $asset->save or die $asset->errstr;

    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    $app->run_callbacks(
        'cms_upload_file.' . $asset->class,
        File  => $local_file,
        file  => $local_file,
        Url   => $url,
        url   => $url,
        Size  => $bytes,
        size  => $bytes,
        Asset => $asset,
        asset => $asset,
        Type  => 'image',
        type  => 'image',
        Blog  => $blog,
        blog  => $blog
    );
    $app->run_callbacks(
        'cms_upload_image',
        File       => $local_file,
        file       => $local_file,
        Url        => $url,
        url        => $url,
        Size       => $bytes,
        size       => $bytes,
        Asset      => $asset,
        asset      => $asset,
        Height     => $h,
        height     => $h,
        Width      => $w,
        width      => $w,
        Type       => 'image',
        type       => 'image',
        ImageType  => $id,
        image_type => $id,
        Blog       => $blog,
        blog       => $blog
    );

    return $asset;
}

# The Ajax call to delete the uploaded photo. (Perhaps they selected the wrong
# photo or realized it shouldn't be part of the selecte album or soemthing.)
sub ajax_remove_photo {
    my $app  = shift;
    my $blog = $app->blog;
    my $q    = $app->can('query') ? $app->query : $app->param;

    return MT::Util::to_json({
        status  => -1,
        message => 'Insufficient permissions to upload files to this blog.',
    })
        if !$app->user->permissions($blog->id)->can_upload;

    $app->validate_magic()
        or return MT::Util::to_json({
            status  => -1,
            message => 'Invalid request.'
        });

    my $asset_id = $q->param('asset_id')
        or return MT::Util::to_json({
            status  => -1,
            message => 'No asset ID specified!',
        });

    my $asset = MT->model('asset')->load({ id => $asset_id })
        or return MT::Util::to_json({
            status  => -1,
            message => 'Error loading asset: ' . $app->errstr,
        });

    # $asset->remove will remove the asset record in the DB, as well as the
    # uploaded file itself.
    $asset->remove
        or return MT::Util::to_json({
            status  => -1,
            message => 'Error deleting asset: ' . $asset->errstr,
        });

    MT::Util::to_json({
        status  => 1,
        message => 'Asset deleted.',
    });
}

# Save the entries that the user has created with the batch upload tool. The
# assets have already been uploaded/created, so we just need to use the asset
# ID to create an objectasset association.
sub multi_save {
    my $app    = shift;
    my $q      = $app->can('query') ? $app->query : $app->param;
    my $param  = {};
    my $author = $app->user;
    my $blog   = $app->blog;

    return MT::Util::to_json({
        status  => -1,
        message => 'Insufficient permissions to upload files to this blog.',
    })
        if !$app->user->permissions($blog->id)->can_upload
            || !$app->user->permissions($blog->id)->can_post;

    $app->validate_magic()
        or return MT::Util::to_json({
            status  => -1,
            message => 'Invalid request.'
        });

    # Create a new entry for this photo.
    #my $entry = MT->model('entry')->load( $q->param('entry_id') );
    my $entry = MT->model('entry')->new();
    $entry->title(          $q->param('title')            );
    $entry->text(           $q->param('caption')          );
    $entry->allow_comments( $blog->allow_comments_default );
    $entry->allow_pings(    $blog->allow_pings_default    );
    $entry->status(         $q->param('status')           );
    $entry->author_id(      $author->id                   );
    $entry->blog_id(        $blog->id                     );

    my $cb = $author->text_format || $blog->convert_paras;
    $cb = '__default__' if $cb eq '1';
    $entry->convert_breaks($cb);

    require MT::Tag;
    my $tags      = $app->param('tags');
    my $tag_delim = chr( $app->user->entry_prefs->{tag_delim} );
    my @tags      = MT::Tag->split( $tag_delim, $tags );
    if (@tags) {
        $entry->set_tags( @tags );
    }

    $entry->save
        or return MT::Util::to_json({
            status  => -1,
            message => 'Error saving entry: ' . $entry->errstr,
        });

    # Now that the entry is created/saved, set the category placement. Before
    # setting the placement, let's verify that the category is valid, just to
    # be safe.
    my $cat = MT->model('category')->load( $q->param('cat_id') )
        or return MT::Util::to_json({
            status  => -1,
            message => 'Album (category) ID ' . $q->param('cat_id')
                . ' could not be found.',
        });

    # Category exists, associate the entry and category with a placement record.
    my $place = MT->model('placement')->new();
    $place->entry_id(    $entry->id      );
    $place->blog_id(     $entry->blog_id );
    $place->is_primary(  1               );
    $place->category_id( $cat->id        );
    $place->save
        or return MT::Util::to_json({
            status  => -1,
            message => 'Placement record associating ' . $cat->label
                . '(' . $cat->id . ') with entry ' . $entry->title
                . '(' . $entry->id . ') could not be saved.',
        });

    # Normally an "original object" ($orig_obj or $orig_entry) would be
    # included with the callback, however since we know this is always a new
    # entry this can be undef.
    $app->run_callbacks( 'cms_post_save.entry', $app, $entry, undef );

    # And now move on to working with the asset. Verify the asset exists, and
    # create an objectasset record to associate the asset and entry.
    my $asset = MT->model('asset')->load( $q->param('asset_id') )
        or return MT::Util::to_json({
            status  => -1,
            message => 'Asset ID ' . $q->param('asset_id')
                . ' could not be found.',
        });

    # Asset exists; create the objectasset record.
    my $map = MT->model('objectasset')->new();
    $map->blog_id(   $entry->blog_id );
    $map->asset_id(  $asset->id      );
    $map->object_ds( 'entry'         );
    $map->object_id( $entry->id      );
    $map->save
        or return MT::Util::to_json({
            status  => -1,
            message => 'Objectasset record associating ' . $asset->label
                . '(' . $asset->id . ') with entry ' . $entry->title
                . '(' . $entry->id . ') could not be saved.',
        });

    # After an entry is saved we would normally republish. But, because we're
    # saving many entries now we don't want to try to start republishing
    # because we will almost definitely republish things needlessly, such as
    # category archives (albums) and index templates. So, republishing is
    # handled after all entries are saved.

    # Successly saved!
    return MT::Util::to_json({
        status       => 1,
        asset_id     => $asset->id,
        entry_id     => $entry->id,
        entry_status => $entry->status,
        blog_id      => $entry->blog->id,
    });
}

# After the batch entry save process is complete, all of the batched entries
# are republished.
sub multi_republish {
    my $app     = shift;
    my $q       = $app->can('query') ? $app->query : $app->param;
    my $blog_id = $q->param('blog_id');
    my $blog    = MT->model('blog')->load( $blog_id );

    return MT::Util::to_json({
        status  => -1,
        message => 'Insufficient permissions to publish entries in this blog.',
    })
        if !$app->user->permissions($blog_id)->can_post;

    $app->validate_magic()
        or return MT::Util::to_json({
            status  => -1,
            message => 'Invalid request.'
        });

    my @entry_ids = split( /,/, $q->param('entry_ids') || '' )
        or return MT::Util::to_json({
            status  => 0,
            message => 'No entries to publish.'
        });

    my @published_entries;

    foreach my $entry_id (@entry_ids) {
        # Load the entry with the supplied entry ID.
        my $entry = MT->model('entry')->load( $entry_id )
            or die MT::Util::to_json({
                status  => -1,
                message => 'Invalid entry ID '.$entry_id,
            });

        # Republish, but carefully to be sure we do just what's needed.
        # * Need to republish all supplied entries.
        # * Need to republish the previous entry to the first supplied entry.
        # * Need to republish the next entry after the last supplied entry.
        # * All supplied entries are in the same category (album), and
        #   therefore only only need to republish the category archive once.
        # * Dated archives that encompass all entries need to be republished.
        #   We can cover this easily by publishing the dated archives of the
        #   first and last supplied entry.
        # * Need to republish all index templates.
        # The BuildDependencies argument will cover all this before/after
        # stuff: just use BuildDependecies for the first and last entry (but
        # only those two) and we're done.
        my $build_dependencies = 0;

        # First entry in loop?
        $build_dependencies = 1
            if ( $entry_ids[0] == $entry_id );
        # Last entry in loop?
        $build_dependencies = 1
            if ( $entry_ids[-1] == $entry_id );

        $app->rebuild_entry(
            Entry             => $entry,
            BuildDependencies => $build_dependencies,
        )
            or die MT::Util::to_json({
                status  => -1,
                message => $app->handle_error(
                    $app->translate( "Publish failed: [_1]", $app->errstr ) ),
            });

        # Note the entry permalink so that we can send it back to the user.
        push @published_entries, {
            entry_id  => $entry->id,
            entry_url => $entry->permalink,
        };
    }

    # Build the category archive link so that we can provide it to the user
    # in the returned status. Grab the last entry ID to look up the category
    # placement, so that we can load the category and get the category archive
    # link's URL.
    my $cat_archive_url;
    if (@published_entries) {
        my $published_entry = $published_entries[0];
        my $placement = MT->model('placement')->load({
            entry_id   => $published_entry->{entry_id},
            is_primary => 1,
        })
            or return MT::Util::to_json({
                status  => -1,
                message => 'Could not load a category placement record for '
                    . 'Entry ID '.$published_entry->{entry_id},
            });

        my $cat = MT->model('category')->load( $placement->category_id )
            or return MT::Util::to_json({
                status  => -1,
                message => 'Album (category) ID ' . $placement->category_id
                    . ' could not be found.',
            });

        $cat_archive_url  = $blog->archive_url;
        $cat_archive_url .= '/' unless $cat_archive_url =~ m!/$!;
        $cat_archive_url .= archive_file_for( undef, $blog, 'Category', $cat );
        # MT->log("Building the archive URL for category " . $cat->label
        #     . ". URL: " . $cat_archive_url );
    }

    # Send the status update back to the user so they can have the entry
    # permalink and category archive link.
    return MT::Util::to_json({
        status               => 1,
        category_archive_url => $cat_archive_url,
        published_entries    => \@published_entries,
    });
}

# This list action (on the Manage Assets screen) will allow the user to change
# assets to type "photo," which is what the Photo Gallery plugin expects to
# have. This is useful to fix assets created incorrectly or to update an old
# blog, for example.
sub asset_change_to_type_photo {
    my ($app) = @_;
    $app->validate_magic or return;
    my $q     = $app->can('query') ? $app->query : $app->param;
    my @asset_ids = $q->param('id');

    foreach my $asset_id (@asset_ids) {
        my $asset = $app->model('asset')->load($asset_id)
            or next;

        $asset->class('photo');
        $asset->save or die $asset->errstr;
    }

    $app->call_return;
}

1;
__END__
