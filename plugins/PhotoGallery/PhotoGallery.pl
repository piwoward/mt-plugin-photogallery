# Photo Gallery
# Copyright (c) 2005-2008, Byrne Reese
#
# $Id $

package MT::Plugin::PhotoGallery;

use strict;
use MT;
use base qw(MT::Plugin);
our $VERSION = '2.2f';
my $plugin = MT::Plugin::PhotoGallery->new({
    id      => 'PhotoGallery',
    name    => 'Photo Gallery',
    version => $VERSION,
    description =>
	'<MT_TRANS phrase="The Photo Gallery plugin allows users to easily create photo galleries and to upload photos to them.">',
    doc_link    => '',
    author_name => 'Byrne Reese',
    author_link => 'http://www.majordojo.com/',
});
MT->add_plugin($plugin);

sub instance { $plugin }

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
	object_types => {
            'asset.photo' => 'MT::Asset::ImagePhoto',
	},
	callbacks => {
	    'MT::App::CMS::template_output.list_category' => sub {
		return unless $plugin->in_gallery;
		my ( $cb, $app, $output_ref ) = @_;
		$$output_ref =~ s/Create top level category/Create new photo album/g;
		$$output_ref =~ s/No categories could be found/Please create an album before uploading photos/g;
		$$output_ref =~ s/\bCategories\b/\bPhoto Albums\b/g;
		$$output_ref =~ s/\bYour category\b/\bYour photo album\b/g;
	    },
	    'MT::App::CMS::template_source.header' => sub {
		my ($cb, $app, $html_ref) = @_;
		return unless $plugin->in_gallery && 
		    $plugin->get_config_value('suppress_create_entry','blog:'.$app->blog->id);
		$$html_ref =~ s{<li id="create-entry" class="nav-link">.*</a></li>}{};;
	    },
	},
	applications => {
	    cms => {
		methods => {
                    'PhotoGallery.start' => '$PhotoGallery::PhotoGallery::App::CMS::start_upload',
                    'PhotoGallery.upload_photo'  => '$PhotoGallery::PhotoGallery::App::CMS::upload_photo',
                    'PhotoGallery.save_photo'  => '$PhotoGallery::PhotoGallery::App::CMS::save_photo',
		    'PhotoGallery.upgrade' => '$PhotoGallery::PhotoGallery::App::CMS::upgrade',
		    'PhotoGallery.timestamps' => '$PhotoGallery::PhotoGallery::App::CMS::update_timestamps',
		    'PhotoGallery.photos' => '$PhotoGallery::PhotoGallery::Plugin::mode_manage',
		    'PhotoGallery.edit' => '$PhotoGallery::PhotoGallery::Plugin::mode_edit',
		    'PhotoGallery.delete' => '$PhotoGallery::PhotoGallery::Plugin::mode_delete',
		},
		menus => '$PhotoGallery::PhotoGallery::Plugin::load_menus',
		list_filters => '$PhotoGallery::PhotoGallery::Plugin::load_list_filters',
	    },
	}, 
	blog_config_template => '<mt:PluginConfigForm id="PhotoGallery">',
	settings => {
	    'suppress_create_entry' => {
		scope => 'blog',
	    },
	},
	plugin_config => {
	    'PhotoGallery' => {
		'fieldset1' => {
		    'suppress_create_entry' => {
			type => 'checkbox',
			label => 'Suppress Create Entry button and menu items for this blog?',
			tag => 'IfSuppressCreateEntry?',
		    },
		},
	    },
	},
	template_sets => {
            'mid-century-photo-gallery' => {
		photo_gallery => 1,
                label => "Mid-Century Photo Gallery Template Set",
                base_path => 'templates/mid-century',
                order => 650,
                templates => {
                    index => {
                        'main_index' => {
                            label => 'Main Index',
                            outfile => 'index.html',
                            rebuild_me => '1',
                        },
                        'archive_index' => {
                            label => 'Archive Index',
                            outfile => 'archives.html',
                            rebuild_me => '1',
                        },
                        'styles' => {
                            label => 'Stylesheet',
                            outfile => 'styles.css',
                            rebuild_me => '1',
                        },
                        'javascript' => {
                            label => 'JavaScript',
                            outfile => 'javascript.js',
                            rebuild_me => '1',
                        },
                        'feed_recent' => {
                            label => 'Feed - Recent Entries',
                            outfile => 'atom.xml',
                            rebuild_me => '1',
                        },
                        'rsd' => {
                            label => 'RSD',
                            outfile => 'rsd.xml',
                            rebuild_me => '1',
                        },
                    },
                    archive => {
                        'monthly_entry_listing' => {
                            label => 'Monthly Entry Listing',
                            mappings => {
                                monthly => {
                                    archive_type => 'Monthly',
                                },
                            },
                        },
                        'category_entry_listing' => {
                            label => 'Category Entry Listing',
                            mappings => {
                                category => {
                                    archive_type => 'Category',
                                },
                            },
                        },
                    },
                    individual => {
                        'entry' => {
                            label => 'Entry',
                            mappings => {
                                entry_archive => {
                                    archive_type => 'Individual',
                                },
                            },
                        },
                        'page' => {
                            label => 'Page',
                            mappings => {
                                page_archive => {
                                    archive_type => 'Page',
                                },
                            },
                        },
                    },
                    module => {
                        'photo_macro' => {
                            label => 'Photo Macro',
                        },
                        'about_me' => {
                            label => 'About Me',
                        },
                        'banner_footer' => {
                            label => 'Banner Footer',
                        },
                        'banner_header' => {
                            label => 'Banner Header',
                        },
                        'albums' => {
                            label => 'Albums',
                        },
                        'entry_summary' => {
                            label => 'Entry Summary',
                        },
                        'html_head' => {
                            label => 'HTML Head',
                        },
                        'individual_comment' => {
                            label => 'Individual Comment',
                        },
                        'sidebar' => {
                            label => 'Sidebar',
                        },
                        'comments' => {
                            label => 'Comments',
                        },
                        'gallery' => {
                            label => 'Gallery',
                        },
                        'monthly' => {
                            label => 'Monthly',
                        },
                        'recent_comments' => {
                            label => 'Recent Comments',
                        },
                        'recent_entries' => {
                            label => 'Recent Entries',
                        },
                        'trackbacks' => {
                            label => 'Trackbacks',
                        },
                        'userpic' => {
                            label => 'Userpic',
                        },
                    },
                    system => {
                        'comment_preview' => {
                            label => 'Comment Preview',
                        },
                        'comment_response' => {
                            label => 'Comment Response',
                        },
                        'dynamic_error' => {
                            label => 'Dynamic Error',
                        },
                        'popup_image' => {
                            label => 'Popup Image',
                        },
                        'search_results' => {
                            label => 'Search Results',
                        },
                    },
                },
	    },
	},
    });
}

sub in_gallery {
    local $@;
    return 0 if !MT->instance->blog;
    my $ts = MT->instance->blog->template_set;
    my $app = MT::App->instance;
    return $app->registry('template_sets')->{$ts}->{'photo_gallery'};
}

1;
