// Use an array to save all of the uploaded files' result data, which is
// used to build the tabbed editing interface.
var saved_assets = new Array();
var to_republish = new Array();
var jqXHR;

jQuery(document).ready(function($) {
    // Hide and show the appropriate buttons
    $('#paginate').bind( 'finished.evtpaginate', function(e, num, isFirst, isLast ){
        if (isFirst) {
            // This is the first page. Hide the "Previous" pagination button.
            $('#previous-step-button').addClass('hidden');
            $('#next-step-button').removeClass('hidden');
            $('#save').addClass('hidden');
        }
        else {
            // This is the last page. Hide the "Next" button and show the submit button.
            $('#previous-step-button').removeClass('hidden');
            $('#next-step-button').addClass('hidden');
            $('#save').removeClass('hidden');
        }
    });

    $('#paginate').evtpaginate({ perPage:1 });

    $('#previous-step-button').click(function(){
        $('#paginate').trigger('prev.evtpaginate');
        return false;
    });

    $('#next-step-button').click( paginateNextStepButton );

    // '#save' is the Save Photos button, the last step in the pagination.
    $('#save').click( paginateSavePhotosButton );

    // Show/hide the New Album Name field.
    $('select#category_id').change(function(){
        if ( $(this).val() == '__new' ) {
            $('#new-album-field').show();
        }
        else {
            $('#new-album-field').hide();
        }
    });

    jqXHR = $('#upload-form').fileupload({
        url: CMSScriptURI,
        dataType: 'json',
        dropZone: $('#file-field'),
        fileInput: $('#fileupload'),
        acceptFileTypes: /(\.|\/)(gif|jpe?g|png)$/i, // Only upload "photos"
        add: fileuploadAdd,
        done: fileuploadDone,
        fail: fileuploadFail
    });

    // Batch editing options
    $('#batch-edit-container div.batch-edit-options p.toggle').click(function(){
        $('#batch-edit-container div.batch-edit-options').slideToggle('fast');
    });

    $('select#batch-edit-publish-status').click(function(){
        $('select[name="status"]').val( $(this).val() );
    });
});


// Part of the file upload process -- the Add callback. This is responsible
// for adding the file to the status line and submitting the file for upload.
function fileuploadAdd (e, data) {
    // Before starting the upload be sure that an album has been selected.
    if ( jQuery('select#category_id').val() == '' ) {
        alert('An album must be selected (or created) before starting an upload.');
        return false;
    }

    // "Lock" the album picker fields so that a different album can't be
    // selected mid-upload.
    jQuery('select#category_id, input#new_album_name').focus(function(e) {
        $(this).blur();
    });

    // Add the uploaded file to the Photo Upload Progress area.
    jQuery('#uploaded-files-status-field').show();
    jQuery.each(data.files, function (index, file) {
        jQuery('<p/>')
            .fadeIn('slow')
            .addClass('file upload')
            .html( '<span class="filename">' + file.name
                + '</span><span class="status"></span>'
                + '<span class="remove"></span>' )
            .appendTo('#uploaded-files-status');
    });

    // Submit the file to be uploaded.
    data.submit();
}

// Part of the file upload process -- the Done callback. This is responsible
// for taking the successful upload's JSON response and updating the status
// area to note the success.
function fileuploadDone (e, data) {
    // A valid response has been received from the server, but we need to
    // check that response (in data.result.status) to know if the file was
    // successfully written to the server.
    if ( data.result.status == -1 ) {
        // Fatal error! Misconfiguration?
        if ( jQuery('#uploaded-files-status p.error').length ) {
            jQuery('#uploaded-files-status p.error')
                .text( data.result.message );
        }
        else {
            jQuery('<p/>')
                .addClass('error')
                .text( data.result.message )
                .prepend('#uploaded-files-status');
        }
    }
    if ( data.result.status == 0 ) {
        // Not successfully uploaded.
        if ( jQuery('#uploaded-files-status p.error').length ) {
            jQuery('#uploaded-files-status p.error')
                .text( data.result.message + data.result.orig_filename);
        }
        else {
            jQuery('<p/>')
                .addClass('error')
                .text( data.result.message + data.result.orig_filename)
                .prepend('#uploaded-files-status');
        }
    }
    else if ( data.result.status == 1 ) {
        // Success!

        // Inform the user if a new category has been created.
        if ( data.result.cat_is_new == 1 ) {
            jQuery('<p/>')
                .addClass('new-category-created')
                .addClass('selected-album')
                .text('The album ' + data.result.cat_label
                    + ' has been created, and photos are being uploaded to it.')
                .prependTo('#uploaded-files-status');
        }

        // Update the row to reflect that upload is complete. Update the
        // filename too, to show if a file was renamed during upload.
        jQuery('#uploaded-files-status p span.filename:contains("' 
            + data.result.orig_name + '")')
            .text( data.result.asset_name ) // Update with new filename
            .parent()                       // Find the parent '<p>'
            .removeClass('upload')
            .addClass('upload-complete')
            .attr('id', data.result.asset_id);

        // Update the three preview divs, changing their title from the
        // original file name to the saved asset id. That gives us an easy way
        // to grab them to build the tabbed panels.
        jQuery('div#previews canvas[title="'+data.result.orig_name+'"]')
            .attr('title', data.result.asset_id);

        // Save the object with the important variables to be used to create
        // the tabbed interface.
        saved_assets.push( data.result );
        //console.log(saved_assets);

        // Now that we have the asset ID we can offer the option to remove
        // this file from the batch and the server.
        jQuery('#uploaded-files-status p#' + data.result.asset_id + ' span.remove')
            .on('click', function(){
            jQuery.ajax({
                url: CMSScriptURI,
                data: {
                    '__mode': 'PhotoGallery.remove_photo',
                    'asset_id': data.result.asset_id,
                    'blog_id': data.result.blog_id,
                    'magic_token': jQuery('input[name="magic_token"]').val()
                },
                dataType: 'json',
                success: function(response){
                    // Remove the asset from the uploaded list.
                    jQuery('p#'+data.result.asset_id).fadeOut('slow').remove();

                    // Remove the asset from the array of saved assets.
                    for(var i=0; i<saved_assets.length; i++) {
                        var obj = saved_assets[i];
                        if ( obj.asset_id == data.result.asset_id ) {
                            saved_assets.splice( i, 1 );
                            break; // Exit the loop since we're done.
                        }
                    }
                }
            });
        });
    }
    else {
        alert("No status from response? Shouldn't happen.");
    }
}

// Part of the file upload process -- the fail callback.
function fileuploadFail (e, data) {
    // console.log(data);
    alert(data.errorThrown);
}

// Pagination -- clicking the Next Step button. Since there are only two pages
// this button takes you from the upload page (step 1) to the editing page
// (step 2), and is responsible for taking the uploaded data and building the
// editing interface.
function paginateNextStepButton () {
    // Make sure something has been selected to upload, and make sure that the
    // selected files have finished uploading before moving on.
    if ( jQuery('#uploaded-files-status p.upload-complete').length == 0 ) {
        alert('Select photos to be uploaded before continuing.');
        return false;
    }

    if ( jQuery('#uploaded-files-status p.upload').length ) {
        alert('Your photos are in the process of uploading. Once complete '
            + 'you can continue to the next step.');
        return false;
    }


    // Before moving on we need to parse the uploaded file data and build the
    // sortable entry listing.
    jQuery('#next-step-button').attr('disabled','disabled');
    jQuery('#processing').show(); // Show the processing indicator

    // We can't be sure that saved_assets is sorted as we want it. Objects
    // were added to the saved_assets array as their file upload completed,
    // which isn't necessarily in the order we uploaded them. The user likely
    // selected files to be uploaded in a clear order and we should respect
    // that order, so resort saved_assets based on the order files were
    // selected in.
    var new_sort = Array();
    jQuery('#uploaded-files-status p.upload-complete').each(function() {
        var sorted_asset_id = jQuery(this).attr('id');
        for(var i=0; i<saved_assets.length; i++) {
            var obj = saved_assets[i];
            if ( obj.asset_id == sorted_asset_id ) {
                new_sort.push( obj );
            }
        }
    });
    // Now that we have the correct order, copy it back to the saved_assets
    // array.
    saved_assets = new_sort.slice();

    // Use the saved_assets array to populate the tabbed view of entries on
    // the next page.
    for(var i=0; i<saved_assets.length; i++) {
        var obj = saved_assets[i];

        // If an Entry panel with the specified asset ID has already been
        // created we don't want to duplicate it. Just move on.
        if ( jQuery('form[name="'+obj.asset_id+'"]').length >= 1 ) {
            //alert('Already created a panel for asset '+obj.asset_id);
            continue; // "next" in Perl
        };

        // Update the category name notification
        jQuery('#photo-album-title span').text(obj.cat_label);

        // Add the navigation tab
        jQuery('<li/>')
            .attr('id', obj.asset_id) // For the sortable serialization
            .html('<a href="#asset_id-' + obj.asset_id + '">'
                + '<span class="filename">' + obj.asset_name + '</span>'
                + '<span class="preview"></span>'
                + '</a>')
            .appendTo('#tabs ul');

        // Add the tab panel where the entry fields are displayed.
        jQuery('form#entry')
            .clone() // Copy the "template" to build the real panel
            .removeClass('hidden')
            .addClass('ui-tabs-panel ui-tabs-hide')
            .attr('name', obj.asset_id)           // Unique identifier
            .attr('id', 'asset_id-'+obj.asset_id) // Tabs identifier
            .appendTo('#tabs')                    // Add it to the tabs location
            .find('h3').text(obj.asset_name)      // Populate fields
            .parent()
            .find('input[name="title"]').val(obj.asset_name)
            // .parent().parent().parent().parent().parent() // Up 5 levels to the form
            .parent().parent().parent().parent()
            .find('input[name="asset_id"]').val(obj.asset_id)
            .parent()
            .find('input[name="cat_id"]').val(obj.cat_id);

        // Create a div for the popup dialog which lives outside of the tabbed
        // panels. (For some reason, the popup doesn't work reliably when the
        // dialog is in a panel, it seems.)
        jQuery('<div/>')
            .attr('title', 'Preview of '+obj.asset_name)
            .addClass('dialog '+obj.asset_id)
            .hide()
            .appendTo('body');

        // Build the preview images, to be used in the tabbed interface.
        // (Actually, we need three different sizes of images: tiny for the
        // vertical tab, small for the tab panel, and large for the dialog.)
        // Calculate the maximum width and height of the tab and panel preview
        // images before creating them.
        if (obj.asset_w < obj.asset_h) {
            tab_max_width  = 20;
            tab_max_height = (tab_max_width * obj.asset_h) / obj.asset_w;
            panel_max_width  = 50;
            panel_max_height = (panel_max_width * obj.asset_h) / obj.asset_w;
        }
        else {
            tab_max_height = 20;
            tab_max_width  = (tab_max_height * obj.asset_w) / obj.asset_h;
            panel_max_height = 50;
            panel_max_width  = (panel_max_height * obj.asset_w) / obj.asset_h;
        }
        // Now, create and insert the preview images in the correct locations.
        jQuery('a[href="#asset_id-'+obj.asset_id+'"] span.preview')
            .html(
                loadImage(
                    obj.asset_url,
                    function (img) {
                        img; // Just print out the returned image.
                    },
                    { maxHeight: tab_max_height, maxWidth: tab_max_width }
                )
            );
        jQuery('form[name="'+obj.asset_id+'"] div.preview')
            .html(
                loadImage(
                    obj.asset_url,
                    function (img) {
                        img; // Just print out the returned image.
                    },
                    { maxHeight: panel_max_height, maxWidth: panel_max_width }
                )
            );
        jQuery('div.dialog.'+obj.asset_id)
            .html(
                loadImage(
                    obj.asset_url,
                    function (img) {
                        img; // Just print out the returned image.
                    },
                    { maxWidth: 900, maxHeight: 600 }
                )
            );
    }

    // When the user clicks on the small preview image they should be shown a
    // larger image in the dialog window.
    jQuery('form .preview').on('click', function(){
        // I think this shold be able to live in the jQuery(document).ready
        // function, but it doesn't work there...
        jQuery('.dialog').dialog({
            autoOpen: false,
            width: 900, // auto width isn't an option
            minHeight: 150,
            maxHeight: 600,
            modal: true,
            draggable: false // I think a draggable dialog is just confusing.
        });
        // Find the dialog for the panel the user is working in.
        var asset_id = $(this).parent().attr('name');
        jQuery('div.dialog.'+asset_id).dialog('open');
    });

    jQuery('#tabs .ui-tabs-panel:first').removeClass('ui-tabs-hide');

    // Create the vertical tabs for the ordering/editing interface
    jQuery('#tabs').tabs().addClass('ui-tabs-vertical ui-helper-clearfix');
    jQuery('#tabs li').removeClass('ui-corner-top').addClass('ui-corner-left');

    // Make the vertical tabs sortable.
    jQuery('#tabs ul').sortable();

    // Now advance to the next page.
    jQuery('#paginate').trigger('next.evtpaginate');
    jQuery('#processing').hide(); // Hide the processing indicator

    jQuery('#next-step-button').removeAttr('disabled');
    return false;
}

// Pagination -- from Step 2, clicking the Save Photos button. This is
// responsible for taking the content that has been edited together and saving
// it into entries with the associated assets, building the slideshow.
function paginateSavePhotosButton() {
    // Finally ready to save the photo gallery the user's been building.
    jQuery('#save').attr('disabled','disabled');
    jQuery('#processing').show(); // Show the processing indicator

    // Show the Entry Save Status field.
    jQuery('#entry-save-status-field').show();

    // Grab the entry sort order. Use it to submit the entries to save in the
    // correct order.
    var sort_order = jQuery('#tabs ul').sortable('toArray');

    // We want to do a *synchronous* AJAX request. (AJAX is normally
    // asyncrhonous -- Asynchronous Javascript and XML. So this is really
    // SJAX, I guess.) The SJAX request is so that we can be sure to save the
    // entries in the order requested. That is, with a normal Ajax request, we
    // would submit each entry to be saved, but we can't be sure they'll
    // complete saving in the order requested. An SJAX request will asure us
    // that it *is* saved as requesteed.
    // Anyway, doing the synchronous request effectively locks things up
    // during each request so the status display needs to be handled a little
    // differently: with one loop, display the items to save in the status bar
    // so the user knows the save has started. Then, in the next loop, do the
    // actual Ajax request.
    for(var i=0; i<sort_order.length; i++) {
        var id = sort_order[i];
        jQuery('<p/>')
            .fadeIn('slow')
            .addClass('entry saving')
            .attr('id', 'asset-'+id)
            .html( '<span class="name">'
                + jQuery('form[name="'+id+'"] h3').text() + ' | '
                + jQuery('form[name="'+id+'"] input[name="title"]').val()
                + '</span><span class="status"></span>'
                + '<a class="edit hidden" target="_blank" title="Edit in a new window"></a>'
                + '<a class="view" target="_blank" title="View in a new window"></a>')
            .appendTo('#entry-save-status');
    }

    // Do the actual Ajax request to save the entry.
    for(var i=0; i<sort_order.length; i++) {
        var id = sort_order[i];
        saveEntry(id);
    }

    // Update the save status overview message. It currently reads "Saving
    // entries..." and it should reflect that the saving step is done.
    jQuery('p#entry-save-overview').text('Entries saved.');

    republishEntries();

    // Done! Success! Suggest the user create another album!
    jQuery('.actions-bar button').addClass('hidden');
    jQuery('.actions-bar button#create-another-album').removeClass('hidden');
    jQuery('#processing').hide(); // Hide the processing indicator
}

// Save the individual entry.
function saveEntry(id) {
    jQuery.ajax({
        type: 'POST',
        async: false, // Need synchronous operation to save entries in preferred order.
        url: CMSScriptURI,
        data: jQuery('form[name="'+id+'"]').serialize(),
        dataType: 'json',
        success: function(data, textStatus, jqXHR) {
            // A valid response has been received from the server, but we
            // need to check that response (in data.result.status) to know
            // if the file was successfully written to the server.
            if ( data.status == -1 ) {
                // Fatal error! Misconfiguration?
                if ( jQuery('#entry-save-status p.error').length ) {
                    jQuery('#entry-save-status p.error')
                        .text( data.message )
                        .fadeIn('slow');
                }
                else {
                    jQuery('<p/>')
                        .addClass('error')
                        .text( data.message )
                        .fadeIn('slow')
                        .prependTo('#entry-save-status');
                }

                // If the process is failing there's no point in
                // showing the status of the entries being saved.
                jQuery('#entry-save-status p.entry').each(function(index) {
                    jQuery(this).remove();
                });
            }
            else if ( data.status == 0 ) {
                // Not used during the entry save. Any error is fatal.
            }
            else if ( data.status == 1 ) {
                // The entry was successfully saved! Update the status
                // box with the edit link and "completed" checkbox.
                jQuery('#entry-save-status p#asset-'+data.asset_id)
                    .removeClass('saving')
                    .addClass('saved entry_id-'+data.entry_id);

                // The Edit link
                jQuery('#entry-save-status p#asset-'+data.asset_id+' a.edit')
                    .attr('href', CMSScriptURI
                        + '?__mode=view&amp;_type=entry&amp;id='
                        + data.entry_id 
                        + '&amp;blog_id='
                        + jQuery('input[name="blog_id"]').val() )
                    .removeClass('hidden');

                // If this entry is supposed to be published, note it. All
                // entries will be published after they have been saved.
                if (data.entry_status == 2) {
                    to_republish.push(data.entry_id);
                }
            }
            else {
                alert("No status from response? Shouldn't happen.");
            }
        },
        error: function (jqXHR, textStatus, errorThrown) {
            alert(errorThrown);
        }
    });
}

// After all entries have been successfully saved, republish. This provides us
// a way to smartly republish many entries, avoiding extra republishing of
// index templates and archives.
function republishEntries() {
    // If there are no entries to republish, just give up.
    if (to_republish.length == 0) {
        return;
    }

    jQuery('<p/>')
        .addClass('publishing')
        .html('Publishing entries and archives...'
            + '<span class="status"></span>')
        .appendTo('#entry-save-status');

    jQuery.ajax({
        type: 'POST',
        url: CMSScriptURI,
        data: {
            '__mode': 'PhotoGallery.multi_repub',
            'magic_token': jQuery('input[name="magic_token"]').val(),
            'blog_id': jQuery('input[name="blog_id"]').val(),
            'entry_ids': to_republish.join(',')
        },
        dataType: 'json',
        success: function(data, textStatus, jqXHR) {
            // A valid response has been received from the server, but we
            // need to check that response (in data.result.status) to know
            // if the file was successfully written to the server.
            if ( data.status == -1 ) {
                // Fatal error! Misconfiguration?
                if ( jQuery('#entry-save-status p.error').length ) {
                    jQuery('#entry-save-status p.error')
                        .text( data.message )
                        .fadeIn('slow');
                }
                else {
                    jQuery('<p/>')
                        .addClass('error')
                        .text( data.message )
                        .fadeIn('slow')
                        .prependTo('#entry-save-status');
                }
            }
            else if ( data.status == 0 ) {
                // Not used during republishing. Any error is fatal.
            }
            else if ( data.status == 1 ) {
                // Success! Update the Publishing notice and add the View
                // link to the entries list.
                // The View link
                for(var i=0; i<data.published_entries.length; i++) {
                    var obj = data.published_entries[i];

                    jQuery('#entry-save-status p.entry_id-'+obj.entry_id+' a.view')
                        .attr('href', obj.entry_url)
                        .removeClass('hidden');
                }

                jQuery('#entry-save-status p.publishing')
                    .removeClass('publishing')
                    .addClass('published')
                    .html('Published. <a href="'
                        + data.category_archive_url
                        + '">View this album</a>.'
                        + '<span class="status"></span>'
                    );
            }
        },
        error: function (jqXHR, textStatus, errorThrown) {
            // If an error was thrown, it was likely that MT couldn't publish
            // a template for some reason. Tell the user!
            var mt_error = jQuery("<div>").html(jqXHR.responseText).find('#generic-error');
            if (mt_error) {
                jQuery('<div/>')
                    .html(mt_error)
                    .appendTo('#entry-save-status');
            }

            jQuery('#entry-save-status p.publishing')
                .removeClass('publishing')
                .addClass('error')
                .html('Publishing failed.');

            return false;
        }
    });
}
