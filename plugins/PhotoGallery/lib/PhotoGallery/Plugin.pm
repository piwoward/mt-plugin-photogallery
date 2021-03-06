package PhotoGallery::Plugin;

use strict;
use MT::Util qw(relative_date);

# A utility function used to determine if the current blog is using a photo
# gallery theme.
sub in_gallery {
    local $@;
    my $app = MT::App->instance;
    return 0 unless $app;
    return 0 unless $app->blog;
    my $ts  = $app->blog->template_set;
    return $app->registry('template_sets')->{$ts}->{'photo_gallery'};
}

# A utility function used to determine if the current blog is using a photo
# gallery theme. This also requires that the suppress_create_entry checkbox
# (in Plugin Settings) be checked to affect things.
sub unless_gallery {
    my $app = MT::App->instance;

    # At System Overview
    return 1 if $app->param('blog_id') == 0;

    # Only proceed if this is a photo gallery blog and if the suppress option
    # has been enabled.
    return 0 if !$app->blog;
    return 1
        if !MT->component('PhotoGallery')->get_config_value(
                'suppress_create_entry',
                'blog:' . $app->blog->id
            )
            || !in_gallery();
}

sub plugin {
    return MT->component('PhotoGallery');
}

sub type_galleries {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;

    my @sets;
    my $all_sets = $app->registry('template_sets');
    foreach my $set ( keys %$all_sets ) {
        push @sets, $set
          if $app->registry('template_sets')->{$set}->{'photo_gallery'};
    }
    my @blogs = MT->model('blog')->search_by_meta( 'template_set', \@sets );
    if ( $#blogs < 0 ) {
        return
'<p>There is no blog in your system that utilizes a photo gallery template set.</p>';
    }
    $out .= "      <select name=\"$field_id\">\n";
    $out .=
        "        <option value=\"0\" "
      . ( 0 == $value ? " selected" : "" )
      . ">None Selected</option>\n";
    foreach (@blogs) {
        $out .=
            "        <option value=\""
          . $_->id . "\" "
          . ( $value == $_->id ? " selected" : "" ) . ">"
          . $_->name
          . "</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
}

# A checkbox in the plugin Settings will remove the "Write Entry" button from
# the Header. Also take this opportunity to add an "Upload Photo" button.
sub xfrm_header {
    my ( $cb, $app, $html_ref ) = @_;

    # Only proceed if this is a photo gallery blog and if the suppress option
    # has been enabled.
    return
      unless in_gallery()
          && plugin()
          ->get_config_value( 'suppress_create_entry',
              'blog:' . $app->blog->id );

    my $replacement = '';

    # If the user has permission to post entries, show them the Upload Photo
    # button in place of the Write Entry button.
    # We shouldn't use the #create-entry ID twice, but it seems to work just
    # fine so let's go with it.
    if ($app->permissions->can_post) {
        $replacement = <<HTML;
<li id="create-entry" class="nav-link">
    <a href="javascript:void(0);"
        onclick="return openDialog(false, 'PhotoGallery.start', 'blog_id=<mt:BlogID>')">
        <span>Upload Photo</span>
    </a>
</li>
<li id="create-entry" class="nav-link">
    <a href="<mt:Var name="script_uri">?__mode=PhotoGallery.start_batch&amp;blog_id=<mt:BlogID>">
        <span>Batch Upload Photos</span>
    </a>
</li>
HTML
    }

    # Finally, remove the Write Entry button and if needed add the replacement
    # Upload Photo button.
    $$html_ref =~ s{<li id="create-entry" class="nav-link">.*</a></li>}{$replacement};
}

# The cms_upload_file.image callback can help us identify if an image should
# actually be a "photo" asset type instead. Determine and reassign, if
# neccessary.
sub callback_upload_file {
    my $cb = shift;
    my (%params) = @_;
    my $app = MT->instance;

    # Give up if this isn't a Photo Gallery blog
    return if !in_gallery();

    # Get the field name the uploaded image is being inserted into.
    my $field_basename = $app->param('edit_field');
    $field_basename =~ s/^customfield_//;

    # Give up if no custom field can be found. "Normal" uploads can be type
    # `image` and we only want to check for Custom Fields that need to be
    # captured.
    return if !$field_basename;

    # Look for all fields in this blog that match the basename. There should
    # only ever be one, though, right? (Basenames can't conflict.)
    my @fields = $app->model('field')->load({
        basename => $field_basename,
        blog_id  => $app->blog->id,
    });
    foreach my $field (@fields) {
        # Give up if this Custom Field is a photo asset field type. There are at
        # least two options: `photo` (created by the Photo Gallery plugin) and
        # `selected_asset.photos` (created by the More Custom Fields plugin).
        # Maybe others?
        next if $field->type !~ /photo/;

        # The field type is a photo of some sort, so set the asset to the photo
        # type so that it is used correctly.
        my $asset = $params{'Asset'};
        $asset->class('photo');
        $asset->save or die $asset->errstr;
    }
}

sub load_list_filters {
    if ( in_gallery() ) {
        my $core  = MT->component('Core');
        my $fltrs = $core->{registry}->{applications}->{cms}->{list_filters};
        delete $fltrs->{'entry'};

        my $mt = MT->instance;
        my @cats = MT::Category->load( { blog_id => $mt->blog->id },
            { sort => 'label' } );
        my $reg;

        my $i = 0;
        $reg->{'entry'}->{'all'} = {
            label   => 'All Photos',
            order   => $i++,
            handler => sub {
                my ( $terms, $args ) = @_;
                $terms->{blog_id} = $mt->blog->id;
            },
        };
        foreach my $c (@cats) {
            $reg->{'entry'}->{ $c->basename } = {
                label   => $c->label,
                order   => $i++,
                handler => sub {
                    my ( $terms, $args ) = @_;
                    $terms->{category_id} = $c->id;
                    $terms->{blog_id}     = $c->blog_id;
                },
            };
        }
        return $reg;
    }
    return {};
}

# Modify the menu items in Photo Gallery blogs.
sub load_menus {
    # Remove StyleCatcher, just to prevent the user from hurting themself.
    my $sc = MT->component('StyleCatcher');
    delete $sc->{registry}->{applications}->{cms}->{menus};

    my $entry_order = in_gallery() ? 2200 : 1000;
    return {
        'create:entry' => {
            condition => sub { unless_gallery },
        },
        'photogallery' => {
            label     => 'Photo Gallery',
            order     => 100,
            view      => 'blog',
            condition => sub { in_gallery },
        },
        'photogallery:batch_upload' => {
            label      => 'Upload Photos',
            order      => 200,
            mode       => 'PhotoGallery.start_batch',
            view       => "blog",
            permission => 'create_post,upload',
            condition  => sub { in_gallery },
        },
        'photogallery:photos' => {
            label => "Uploaded Photos",
            mode  => 'PhotoGallery.photos',
            order => 300,
            condition => sub { in_gallery },
        },
        'photogallery:albums' => {
            label      => "Albums",
            mode       => 'list',
            args       => {
                _type => 'category',
            },
            order      => 400,
            permission => 'edit_categories',
            view       => "blog",
            condition  => sub { in_gallery },
        },
        'entry'         => { condition => sub { unless_gallery } },
        'asset'         => { condition => sub { unless_gallery } },
        'feedback:ping' => { condition => sub { unless_gallery } },
    };
}

sub xfrm_categories {
    return unless in_gallery();
    my ( $cb, $app, $output_ref ) = @_;
    $$output_ref =~ s/Create top level category/Create new photo album/g;
    $$output_ref =~
s/No categories could be found/Please create an album before uploading photos/g;
    $$output_ref =~ s/\bCategories\b/\bPhoto Albums\b/g;
    $$output_ref =~ s/\bYour category\b/\bYour photo album\b/g;
}

sub mode_delete {
    my $app = shift;
    $app->validate_magic or return;

    my @photos = $app->param('id');
    for my $entry_id (@photos) {
        my $e = MT->model('entry')->load($entry_id) or next;
        my $a = load_asset_from_entry($e);
        $e->remove();
        $a->remove();
    }
    $app->redirect(
        $app->uri(
            'mode' => 'PhotoGallery.photos',
            args   => {
                blog_id => $app->blog->id,
                deleted => 1,
            }
        )
    );
}

sub mode_edit {
    my $app   = shift;
    my %param = @_;
    my $q     = $app->can('query') ? $app->query : $app->param;

    my $obj   = MT->model('entry')->load( $q->param('id') );
    my $asset = load_asset_from_entry($obj);

    my %arg;
    if ( $asset->image_width > $asset->image_height ) {
        $arg{Width} = 200;
    }
    else {
        $arg{Height} = 200;
    }
    my ( $url, $w, $h ) = $asset->thumbnail_url(%arg);

    my $tmpl = $app->load_tmpl('dialog/edit_photo.tmpl');
    $tmpl->param( blog_id        => $app->blog->id );
    $tmpl->param( entry_id       => $obj->id );
    $tmpl->param( fname          => $obj->title );
    $tmpl->param( caption        => $obj->text );
    $tmpl->param( allow_comments => $obj->allow_comments );
    $tmpl->param( thumbnail      => $url );
    $tmpl->param( asset_id       => $asset->id );
    $tmpl->param( is_image       => 1 );
    $tmpl->param( url            => $asset->url );
    $tmpl->param( category_id    => $obj->category->id );

    my $tag_delim = chr( $app->user->entry_prefs->{tag_delim} );
    my $tags = MT->model('tag')->join( $tag_delim, $obj->tags );
    $tmpl->param( tags => $tags );

    return $app->build_page($tmpl);
}

sub mode_manage {
    my $app   = shift;
    my $q     = $app->can('query') ? $app->query : $app->param;
    my %param = @_;

    if ( !in_gallery() ) {
        $app->return_to_dashboard( redirect => 1 );
    }
    my $code = sub {
        my ( $obj, $row ) = @_;
        $row->{'title'}   = $obj->title;
        $row->{'caption'} = $obj->text;

        my $asset = load_asset_from_entry($obj);
        if ($asset && ($asset->isa('MT::Asset::Photo') || $asset->isa('MT::Asset::Image')) ) {
            my %arg;
            if ( $asset->image_width > $asset->image_height ) {
                $arg{Width} = 110;
            }
            else {
                $arg{Height} = 110;
            }
            my ( $url, $w, $h ) = $asset->thumbnail_url(%arg);
            $row->{'thumb_url'} = $url;
            $row->{'thumb_w'}   = $w;
            $row->{'thumb_h'}   = $h;
            $row->{'photo_id'}  = $obj->id;
            $row->{'photo'}     = $asset->url;
        }
        else {
            $row->{'thumb_url'} = File::Spec->catfile(
                $app->static_path, "plugins",
                "PhotoGallery",    "text-icon.gif"
            );
            $row->{'thumb_w'}  = 142;
            $row->{'thumb_h'}  = 133;
            $row->{'entry_id'} = $obj->id;
        }
        my $ts = $row->{created_on};
        $row->{date} = relative_date( $ts, time );
    };

    my %terms = ( blog_id => $app->blog->id, );

    my %args = (
        sort      => 'created_on',
        direction => 'descend',
    );

    my %params = ( deleted => ($q->param('deleted') || 0), );

    my $plugin = MT->component('PhotoGallery');

    $app->listing(
        {
            type           => 'entry',    # the ID of the object in the registry
            terms          => \%terms,
            args           => \%args,
            listing_screen => 1,
            code           => $code,
            template => $plugin->load_tmpl('manage.tmpl'),
            params   => \%params,
        }
    );
}

sub load_asset_from_entry {
    my ($obj) = @_;
    my $join = '= asset_id';
    my $asset = MT->model('asset')->load(
        { class => '*' },
        {
            lastn => 1,
            join  => MT->model('objectasset')->join_on(
                undef,
                {
                    asset_id  => \$join,
                    object_ds => 'entry',
                    object_id => $obj->id
                }
            )
        }
    );
    return $asset;
}

1;
