# Photo Gallery Plugin for Movable Type Overview

The Photo Gallery Plugin for Movable Type contains two components:

* A streamlined interface to make managing, editing, and uploading to a photo
  gallery-style blog efficient. This updated interface can be used by any
  theme.

* A photo gallery theme based upon the amazing design work of [Jim
  Ramsey](http://www.jimramsey.net/). It is designed to be a seamless
  extension of his popular Movable Type theme called
  [Mid-Century](http://www.movabletype.org/2008/08/another_hallmark_design_for_movable_type.html).


# Prerequisites

* Movable Type 5 or 6
* [Config Assistant](https://github.com/openmelody/mt-plugin-configassistant/releases)

Additionally, if you want to use the included Mid-Century Photo Gallery theme,
the following are required:

* This plugin makes use of the Image::ExifTool perl module. The module is 
  optional. When installed it will give you the option of setting the 
  date of the photo to the current date or the date the photo was actually 
  taken.

* This plugin requires the Order plugin by Mark Paschal.
  http://markpasc.org/code/mt/order/


# Installation

To install this plugin follow the instructions found here:

http://tinyurl.com/easy-plugin-install


# Setting Up a Photo Gallery Blog

The Mid-Century Photo Gallery theme is specially designed to make creating
photo galleries an easy process. To use this theme you will need to create a
new blog.

* Go to System Overview > Blogs. Click "Create Blog" and on the resulting
  screen select "Mid-Century Photo Gallery Template Set".

* Go to System Overview > Templates. Click "Refresh Templates" from the
  sidebar of the Design > Templates screen.

# Designers: Creating a Photo Gallery Theme

To make use of the Photo Gallery plugin's streamlined interface, a theme must
be properly recognized. This is very easy because it's just an extra key:value
for your theme's `config.yaml`

    template_sets:
        my_awesome_photo_gallery:
            photo_gallery: 1

Refer to the Mid-Century Photo Gallery theme for examples for how a photo
gallery can be built using this plugin's capabilities.

# Use

The Mid-Century Photo Gallery theme is very focused on posting photos, but it
can also be used to create more traditional blog entries, too. Further clarify
the blog's focus by visiting Tools > Plugins at the blog level, where Photo
Gallery > Settings > Blog Content Focus is found.

## Uploading Photos

Once you have successfully applied the template set to your blog, the options
presented in Movable Type's main menu-based navigation will change. You should
now notice two new menu options under the Create menu: Upload Photo, and Batch
Upload Photos.

Basically, Upload Photo is most useful for making single additions to an
existing album, and Batch Upload Photos is most useful for creating new photo
albums.

### Upload Photo

Click Create > Upload Photo to spawn a dialog in which you are prompted to
select a file from your local file system, and choose an album.

If you need to create a new album, select "New Album" from the pull down menu.
When you are ready click Upload Photo.

You will then be given the chance to add a title for the photo and add a
caption. Edit the metadata of the photo and click Finish or Upload Another.

### Batch Upload Photos

Click Create > Batch Upload Photos to go to the Batch Upload Photos tool.
Start the two-step process by selecting an album to add photos to, or choose
"Create a New Album" then give name the new album.

Select photos to be uploaded. Use multiple selections with the shift or
alt/option key, or drag and drop files to the Select Photos to Upload area.
Photos will automatically start uploading, and you're notified of their
progress in the status area. Note that photos will be automatically renamed,
if necessary, and that they can be removed by clicking the "x" icon that
appears next to the file name.

Once all photos have been uploaded, click the Next Step button.

In step two, edit photo tiles, captions, and tags for all of the photos you have
uploaded. In this vertically-tabbed interface, click each tab to work with the
photo thumbnail you see, and drag-n-drop each tab to order photos in the photo
album.

After all photo's have been updated, click Save Photos. The status area will
note saving and publishing progress, and finally present you with links to edit
and view the album contents.


## Configuring the Mid-Century Photo Gallery Theme

### Changing the Layout of your Front Door

One can easily switch between the following layouts for their front door by
navigating to Design > Theme Options:

  * Grid - display a block of thumbnails
  * Blog - display a list of reverse chronologically sorted blog entries with
  medium sized thumbnails.

### Featuring a Photo on the Front Door

Screenshot of what a featured image on the front door looks like.

![Featured Image](http://www.majordojo.com/2009/06/02/Picture%202.png)

To feature a photo on the front door simply add the tag `@featured` to the
photo in question. This can be done one of two ways:

1. From the Manage Photos screen, select the photo you want to feature and
   from the pull down menu labeled "More actions" select "Add Tags..." and
   enter `@featured` into the pop-up that appears.

2. From the Manage Photos screen, click on the title of the image you want to
   feature and enter in the `@featured` tag into the tags text box.

You can disable featured photos altogether by navigating to Tools > Plugins
> Photo Gallery > Settings and clicking the "Use Featured Photo" checkbox.

### Changing the number of photos that appear on the front door

![Change number of Photos](http://www.majordojo.com/2009/06/02/Picture%201.png)

To change the number of photos that appear on the front door, regardless of
whether you are using the Blog or Grid layout, go to Preferences > Entry. Then
in the box labeled "Entry Listing Default" enter in the number you prefer.

_For best results, enter in a number evenly divisible by four, e.g. 4,8,12,
16, 20, etc._


# License

This plugin is licensed under the same terms as Perl itself.
