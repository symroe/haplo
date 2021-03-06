/*global KApp,KSubsets,KControl,KCtrlDropdownMenu,KCtrlObjectInsertMenu,ActiveXObject,DOMParser */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var KCtrlDocumentTextEdit;

(function($) {

var j__parseXml = function(string) {
    var xmlDoc = null;
    try // Internet Explorer
    {
        var x = new ActiveXObject("Microsoft.XMLDOM");
        x.async = "false";
        x.loadXML(string);
        xmlDoc = x; // succeded
    }
    catch(e) {
        try // Firefox, Mozilla, Safari, Opera, etc.
        {
            var parser = new DOMParser();
            xmlDoc = parser.parseFromString(string,"text/xml");
        }
        catch(e2) {
            // Will return null to show error
        }
    }
    return xmlDoc;
};

// TODO: Make a proper XML escaping function and use it consistently everywhere
// NOTE: Also used for escaping HTML in this file
var j__xmlEscape = function(string) {
    return string.replace(/&/g,'&amp;').replace(/>/g,'&gt;').replace(/</g,'&lt;');
};
/*function j__xmlUnescape(string) {
    return string.gsub('&lt;','<').gsub('&gt;','>').gsub('&amp;','&');
}*/

// Tags etc for conversion to and from XML
var CONVERSION_TAGS_OUT = {
    p:1,
    li:1,
    h1:1, h2:1, h3:1, h4:1
};
var CONVERSION_CONTAINERS = {
    sidebar:1,
    box:1,
    quoteleft:1,
    quoteright:1
};

// How empty paragraphs are created to make sure there's something to click.
// IE has a different requirements to everything else.
var EMPTY_PARAGRAPH_FOR_EDIT_CONTENTS = KApp.p__runningMsie ? '' : '<br>';
var EMPTY_PARAGRAPH_FOR_EDIT = '<p>'+EMPTY_PARAGRAPH_FOR_EDIT_CONTENTS+'</p>';



// --------------------------------------------------------------------------------------
// Base class for widgets.
// Don't use KControls because their structure doesn't work very well when buried
// deep in iframes.

var makeWidgetContructor = function() {
    return function(docedit,spec,no_container) {
        // Use defaults?
        var defs = this.p__defaults;
        if(!spec) {spec = defs;}
        // Check spec
        var ok = true;
        _.each(this.p__required, function(p) {
            if(!spec[p]) {
                if(!defs) {
                    ok = false;
                } else {
                    spec[p] = defs[p];
                }
            }
        });
        this.p__ok = ok;
        // Store
        this.p__docedit = docedit;
        this.p__spec = spec;
        this.p__noContainer = no_container;
        return this;
    };
};

var KDocEditWidget = makeWidgetContructor();
_.extend(KDocEditWidget.prototype, KControl.prototype);
_.extend(KDocEditWidget, {
    q__allControls: [],
    j__widget: function(i) {
        return this.q__allControls[i];
    },
    // Logic for undoable widget deletion
    j__clearUndoable: function() {
        if(this.q__undoable) {
            this.q__undoable.parentNode.removeChild(this.q__undoable);
            $(this.q__undoButton).hide();
            this.q__undoable = null;
        }
    },
    j__undoDelete: function(event) {
        event.preventDefault();
        if(KApp.p__runningMsie) {$(this.q__undoable).removeClass('z__msie_hide_widget_in_contenteditable');} else {$(this.q__undoable).show();}
        $(this.q__undoButton).hide();
        this.q__undoable = null;
    }
});
_.extend(KDocEditWidget.prototype, {
    j__generateHtml2: function(i) {
        // Store ID
        KDocEditWidget.q__allControls[i] = this;
        // Make HTML
        var h = this.p__headingName;
        h = '<div class="z__widget_container_delete"><a id="'+i+'__x" href="#">&nbsp;</a></div><div class="z__widget_container_inner">'+((!h)?'':'<div class="z__widget_type_heading">'+h+'</div>')+this.j__generateHtml3(i)+'</div>';
        if(this.p__noContainer) {return h;}
        // This construction is mirrored in j__insertNewWidget()
        return '<div class="z__widget_container" contentEditable="false" id="'+i+'">'+h+'</div>';
    },
    j__attach2: function(i) {
        // Attach handler to delete button
        $('#'+i+'__x').click(_.bind(this.j__onDelete, this));
        // Call subclass
        this.j__attach3(i);
    },
    j__attach3: function(i) {
        // Empty so this doesn't have to be implemented
    },
    j__onDelete: function(event) {
        event.preventDefault();
        var t = this.q__domObj;
        // Set for undoable
        var w = KDocEditWidget;
        w.j__clearUndoable(); // remove any previously deleted widget
        if(!w.q__undoButton) {
            // Make the undoable button
            w.q__undoButton = document.createElement('div');
            w.q__undoButton.className = 'z__widget_undo_delete_button';
            w.q__undoButton.innerHTML = '<a href="#">undo delete</a>';
            t.parentNode.parentNode.appendChild(w.q__undoButton);
            // Attach the event handler
            $('a',w.q__undoButton).click(_.bind(w.j__undoDelete, w));
        } else {
            $(w.q__undoButton).show();
        }
        KApp.j__positionClone(w.q__undoButton, t, 2 + t.offsetWidth, 0 - w.q__undoButton.offsetHeight);
        // Hide this widget, for now
        if(KApp.p__runningMsie) {$(t).addClass('z__msie_hide_widget_in_contenteditable');} else {$(t).hide();}
        // Mark it as the element to delete
        w.q__undoable = t;
    },
    // -----------------------------------
    // Utility functions
    // -----------------------------------
    j__select: function(i,nm,p,opts) {
        var v = this.p__spec[nm];
        var h = '<select ';
        if(KApp.p__runningMsie) {
            // Nasty horrid hack for IE -- otherwise the dropdowns just disappear all on their own
            // IE6 and IE7 have different behaviours to work around. Lovely. Still, this magic seems to do the job.
            h+='onmousedown="this.parentNode.parentNode.focus();" onmouseup="this.parentNode.parentNode.blur();" ';
        }
        h+='id="'+i+'_'+nm+'">';
        _.each(opts, function(i) {
            h += '<option value="'+i[0]+'"'+((v==i[0])?' selected':'')+'>'+p+i[1]+'</option>';
        });
        return h+'</select>';
    }
});

// Object insertion
var KDocEditWidgetObject = makeWidgetContructor();
_.extend(KDocEditWidgetObject.prototype, KDocEditWidget.prototype);
_.extend(KDocEditWidgetObject.prototype, {
    p__widgetType: 'OBJ',
    p__required: ['ref','title','style'],
    // no defaults in p__defaults
    j__generateHtml3: function(i) {
        // TODO: Don't require title: attr in OBJ doc edit widget -- but would require code server side to make sure titles are always available
        return '<div class="z__widget_checkbox"><input id="'+i+'_l" type="checkbox"'+((this.p__spec.style=='linkedheading')?' checked':'')+'> Link only</div><span id="'+i+'_r" class="z__widget_reference">'+this.p__spec.ref+'</span><p id="'+i+'_t" class="z__widget_linked"></p>';
    },
    j__attach3: function(i) {
        $('#'+i+'_t').text(this.p__spec.title); // HTML escaping
    },
    j__output: function() {
        var i = this.q__domId;
        return [['ref',$('#'+i+'_r').text()],['title',$('#'+i+'_t').text()],
            ['style',($('#'+i+'_l')[0].checked)?'linkedheading':'generic']];
    }
});

// SEARCH
var KDocEditWidgetSearch = makeWidgetContructor();
_.extend(KDocEditWidgetSearch.prototype, KDocEditWidget.prototype);
_.extend(KDocEditWidgetSearch.prototype, {
    p__headingName: 'Search',
    p__widgetType: 'SEARCH',
    p__required: ['q','sort','style','paged','subset','limit','within'],
    p__defaults: {q:'',sort:'relevance',style:'',paged:'0',subset:'',limit:'',within:'link'},
    j__generateHtml3: function(i) {
        // extra div around query input is required for IE
        var h = '<div><input type="text" style="width:98%;" id="'+i+'_q" value=""></div>';
        h+=this.j__select(i,'subset','in ',[['','all permitted']].concat(KSubsets))+' ';
        h+=this.j__select(i,'sort','sort by ',[['relevance','Relevance'],['title','Title'],['date','Date']])+' ';
        h+=this.j__select(i,'style','',[['','Full listing'],['mini','Mini listing'],['cal','As calendar']])+' ';
        h+=this.j__select(i,'paged','',[['0','Show all'],['1','Paged results']])+' ';
        h+=this.j__select(i,'within','',[['','No search within'],['link','Search within link'],['field','Search within field']])+' ';
        h+='<span style="display:inline-block;">Limit results to <input type="text" size="4" id="'+i+'_limit" value="">';
        return h+'</span>';
    },
    j__attach3: function(i) {
        // Set value now so HTML escaping happens
        $('#'+i+'_q').val(this.p__spec.q);
        $('#'+i+'_limit').val(this.p__spec.limit);
    },
    j__output: function() {
        var i = this.q__domId;
        var r = [];
        _.each(this.p__required, function(k) {
            var v = $('#'+i+'_'+k).val();
            if(k === 'limit') { v = parseInt(v,10); v = ""+(isNaN(v) ? "" : v); }
            r.push([k,v]);
        });
        return r;
    }
});

// HTML
var KDocEditWidgetHTML = makeWidgetContructor();
_.extend(KDocEditWidgetHTML.prototype, KDocEditWidget.prototype);
_.extend(KDocEditWidgetHTML.prototype, {
    p__headingName: 'HTML',
    p__widgetType: 'HTML',
    p__required: ['html'],
    p__defaults: {html:''},
    j__generateHtml3: function(i) {
        // Need rows= at least 5 otherwise Safari doesn't put in scroll bars properly
        return '<textarea id="'+i+'_h" rows="5" cols="80"></textarea>';
    },
    j__attach3: function(i) {
        $('#'+i+'_h').val(this.p__spec.html);    // use val() to escape things nicely
    },
    j__output: function() {
        return [['html',$('#'+this.q__domId+'_h').val()]];
    }
});

// File (image, other file)
var KDocEditWidgetFile = makeWidgetContructor();
_.extend(KDocEditWidgetFile.prototype, KDocEditWidget.prototype);
_.extend(KDocEditWidgetFile.prototype, {
    p__headingName: 'File',
    p__widgetType: 'FILE',
    p__required: ['name','img','caption','size','pos','link'],
    p__defaults: {size:'m',img:0,pos:'m',caption:'',link:0},
    j__generateHtml3: function(i) {
        // Image or just a file link?
        this.q__isImg=(this.p__spec.img*1)==1;
        var h = '<b>'+this.p__spec.name+'</b>';
        if(this.q__isImg) {
            h += '<br>Size: '+
                this.j__select(i,'size','',[['s','Small'],['m','Medium'],['l','Large']])+' Position: '+
                this.j__select(i,'pos','',[['l','Left'],['m','Middle'],['r','Right'],['s','Sidebar']])+
                ' &nbsp; <input id="'+i+'_l" type="checkbox"'+((this.p__spec.link*1)?' checked':'')+'> Link to download'+
                '<div><input type="text" style="width:98%;" id="'+i+'_c" value=""></div>';

        }
        return h;
    },
    j__attach3: function(i) {
        $('#'+i+'_c').val(this.p__spec.caption); // for HTML escaping
    },
    j__output: function() {
        var i = this.q__domId;
        var r = [['name',this.p__spec.name],['img',this.q__isImg?1:0]];
        if(this.q__isImg) {
            r.push(['caption',$('#'+i+'_c').val()]);
            _.each(['size','pos'], function(k) {
                var v = $('#'+i+'_'+k).val();
                r.push([k,v]);
            });
            r.push(['link',$('#'+i+'_l')[0].checked?1:0]);
        }
        return r;
    }
});


// Class lookup for widget
KDocEditWidget.p__classes = {
    OBJ: KDocEditWidgetObject,
    SEARCH: KDocEditWidgetSearch,
    HTML: KDocEditWidgetHTML,
    FILE: KDocEditWidgetFile
};
KDocEditWidget.p__menuOrder = ['SEARCH','HTML'];

// --------------------------------------------------------------------------------------

// On server
//      control_document_text_edit(dom_id, initial_contents)
//
// Constructor argument is the initial contents of the document.
// Use the j__value method to extra the text.
//
/* global */ KCtrlDocumentTextEdit = function(initial_doc) {
    this.q__initialDoc = initial_doc;
    this.q__editable = true;    // when not supported, still marked as editable so greyed out deleting works as expected
    if(!document.body.contentEditable) {
        this.q__notSupported = true;
        return;
    }
    this.q__paraStyleButton = new KCtrlDropdownMenu(_.bind(this.j__paragraphStylesContents, this),
        _.bind(this.j__paragraphStylesHandleSelection, this), 'p', 'z__document_text_floating_buttons');
    this.q__insertButton = new KCtrlObjectInsertMenu(_.bind(this.j__insertMenuCallback, this), null, 'Add content');
    this.q__widgetsButton = new KCtrlDropdownMenu(_.bind(this.j__insertWidgetsContents, this),
        _.bind(this.j__insertWidgetsHandleSelection, this), 'Add widget');
    // Which key to use for shortcuts?
    //  IE uses Ctrl 1 .. 8
    //  FF uses Alt 1 .. 8 on Mac (and Ctrl on Windows)
    this.q__shortcutModifier = (navigator.appVersion.indexOf('Win') > 0)?'alt':'ctrl';
};
_.extend(KCtrlDocumentTextEdit.prototype, KControl.prototype);
_.extend(KCtrlDocumentTextEdit.prototype, {
    // Given DOM id is a container div, then with suffixes
    //      _s - paragraph style dropdown
    //      _i - insert button
    //      _w - widgets button
    //      _l - insert file button
    //      _f - floating controls
    //      _a - add content box
    //      _p - add content link
    //      _e - editable document, has contentEditable=true
    //      _x - initial content from controls_helper.rb (deleted after init)
    q__PARAGRAPH_STYLES: [
        ['p','Paragraph','0'],
        ['1','Heading 1','1',true],['2','Heading 2','2'],['3','Heading 3','3'],['4','Heading 4','4'],
        ['i','List item',undefined,true]
    ],

    q__floatingControlsY: -1,    // -1 means 'hidden'

    // q__selectedParagraph is updated when the selection moves. May be null.

    // NOTE: Implemented using styles on 'p' objects because Safari doesn't like execCommand and
    // will crash if nodes are swapped around within the editable area.
    // TODO: Clean up pasted text, handle <br>s etc.
    // TODO: See if it's possible to disable the editor control in IE somehow (for displaying in uneditable delete mode)

    // ---------------------------
    // API implementation

    j__generateHtml2: function(i) {
        // Have to do this later than initialize()
        if(this.p__keditorValueControl) {
            this.q__fileButton = new KCtrlDropdownMenu(_.bind(this.j__insertFileContents, this),
                _.bind(this.j__insertFileSelection, this), 'Insert file');
        }

        return '<div class="z__document_text_edit" id="'+i+'">' +
            this.j__generateHtmlInner(i) + '</div>';
    },
    j__attach2: function(i) {
        // Was this generated by the helper or the javascript?
        var c = $('#'+i+'_x');
        if(c.length !== 0) {
            // Need to swap in the real HTML, didn't get done by j__generateHtml2().
            this.q__initialDoc = c.val();
            $('#'+i).html(this.j__generateHtmlInner(i));
        }

        if(this.q__notSupported) {
            // Disable all controls
            _.each(['input','select','textarea'], function(tag) {
                $('#'+i+' '+tag).prop('disabled', true);
            });
            // Don't set things up for document editing, as it's not possible
            return;
        }

        // Attach handlers to the various bits of UI
        this.q__insertButton.j__attach();
        this.q__paraStyleButton.j__attach();
        this.q__widgetsButton.j__attach();
        if(this.q__fileButton) {this.q__fileButton.j__attach();}
        $('#'+i+'_p').click(_.bind(this.j__onAddContentClick, this));

        // Attach other handlers
        var e = $('#'+i+'_e');
        // Attach more handlers
        var updateHandler = _.bind(this.j__updateSelectionInfo, this);
        $('#'+i+'_e').bind('beforedeactivate', updateHandler).
            click(updateHandler).
            keyup(_.bind(this.j__handleKeyup, this)).
            bind('paste', _.bind(this.j__handlePaste, this));

        // Attach widgets
        var w = this.q__initialWidgets;
        if(w) {
            _.each(w, function(x) {
                x.j__attach();
            });
        }
    },

    j__value: function() {
        // Get rid of any pending deleted widget in the DOM
        KDocEditWidget.j__clearUndoable();
        // Make sure everything is properly clean before converting the dom elements
        this.j__cleanUpDom();
        // Convert the nodes in the DOM into document text
        return (this.q__notSupported)?(this.q__initialDoc):(this.j__domObjsToDoc(this.j__getEditContainer()));
    },

    // ---------------------------
    // HTML generation
    j__generateHtmlInner: function(i) {
        if(this.q__notSupported) {
            // TODO: Nicer message about unsupported document editing
            return '<div class="z__document_text_edit_not_supported">Document editing is not supported on this browser.</div><div id="'+i+'_e" class="z__document_text_edit_document">'+this.j__docTextToHtml(this.q__initialDoc)+'</div>';
        }

        this.q__initialWidgets = [];
        return '<div id="'+i+'_f" class="z__document_text_edit_floating_controls" style="display:none">'+
            '<a href="#" id="'+i+'_p" class="z__document_text_floating_buttons">+</a> '+
            this.q__paraStyleButton.j__generateHtml(i+'_s')+'</div>'+
            '<div class="z__document_text_edit_add_controls" style="display:none" id="'+i+'_a">' +
            this.q__insertButton.j__generateHtml(i+'_i') +
            this.q__widgetsButton.j__generateHtml(i+'_w') +
            ((this.q__fileButton)?(this.q__fileButton.j__generateHtml(i+'_l')):'') +
            '</div><div id="'+i+'_e" tabindex="1" class="z__document_text_edit_document" contentEditable="true">' +
            this.j__docTextToHtml(this.q__initialDoc,this.q__initialWidgets) +
            EMPTY_PARAGRAPH_FOR_EDIT+'</div>';

        // The paragraph with an img at the end of the document text editor stops Mozilla from using lots of <br>s and
        // getting the formatting all wrong, and IE from giving an error message on page open when there's
        // an empty document. And all of them need something to get the formatting right.
    },

    // ---------------------------
    // Extra functionality for other scripts to call

    j__setEditable: function(editable,uneditable_style) {
        // Check something needs doing
        if(editable == this.q__editable) {return;}

        // Change the editable status
        var x = this.j__getEditContainer();
        x.contentEditable = editable;

        // Show/hide toolbar, apply/remove uneditable style
        var s = uneditable_style || 'z__uneditable';
        var t = $('#'+this.q__domId+'_t'); // toolbar
        if(editable) {
            t.show();
            $(x).removeClass(s);
        } else {
            t.hide();
            $(x).addClass(s);
        }

        // Set editable flag for later
        this.q__editable = editable;
    },

    // ---------------------------
    // Access to items
    j__getEditContainer: function() {
        return $('#'+this.q__domId+'_e')[0];
    },


/*
        // IE code for focusing within the editable area.
        // This is quite a bit of fun and games to get the selection in the right place to avoid
        // nasty text movement.
        var s = this.q__document.selection;
        if(s == null || s.type == 'None') {
            var r = this.q__document.selection.createRange();
            r.moveToElementText(this.q__document.body.lastChild);
            r.setEndPoint('StartToEnd',r);
            r.select();
            this.q__document.body.focus();
        }
*/

    j__updateSelectionInfo: function() {
        this.j__hideAddContentBox();     // don't let the add content box stay open
        // Save the selection, if there is one
        var u = this.j__getFirstParentOfSelection();
        if(u) {
            // Store the selected paragraph for use later
            this.q__selectedParagraph = u;

            // Check to see if the action thing needs moving
            var y = u.offsetTop;
            var c = this.q__floatingControlsY;
            var f = $('#'+this.q__domId+'_f');
            if(c == -1) {
                // hidden; show floating controls
                f.show();
            }
            if(c != y) {
                f[0].style.top=y+'px';
            }
            // Store current position
            this.q__floatingControlsY=y;

            // Update paragraph style button
            this.j__setParagraphStyleButtonCaption();
        }
    },
    j__handleMouseup: function(evt) {
        this.j__updateSelectionInfo();
        // Hide any drop down menus
        KApp.j__closeAnyDroppedMenu();
    },
    j__handleKeyup: function(event) {
        KDocEditWidget.j__clearUndoable();

        this.j__updateSelectionInfo();

        // Make sure the element isn't in an input or textarea
        var e = event.target;
        if(e.nodeType==NODE__TEXT_NODE) {e=e.parentNode;}
        var et = e.tagName.toLowerCase();
        if(et=='input' || et=='textarea') {return;}

        // Handle the keycode
        var kc = event.which;
        if(kc == 13 /* return */) {
            // Make sure the style on the new paragraph is normal paragraph text
            this.j__setCurrentParagraphStyle(null);
        } else if(((this.q__shortcutModifier == 'ctrl') ? event.ctrlKey : event.altKey) && kc >= 48 && kc <= 52)    // ctrl-0 ... 4
        {
            this.j__setCurrentParagraphStyle((kc==48)?null:String.fromCharCode(kc));
        }
    },

    j__handlePaste: function(evt) {
        // Need a slight delay before cleaning the new DOM nodes to give time for them to be added
        var t = this;
        window.setTimeout(function() {
            t.j__cleanUpDom();
            if(KCtrlDocumentTextEdit.iePasteBugFound && !(KCtrlDocumentTextEdit.iePasteBugReported)) {
                KCtrlDocumentTextEdit.iePasteBugReported = true;
                alert("Some of the pasted text could not be decoded correctly.\n\nClick PREVIEW to check that the text is correct.\n\nUse unstyled text to avoid this issue.");
            }
        }, 100); // needs to be at least 100 for IE7
    },

    // ---------------------------
    // Insert file drop down menu -- only enabled when part of a KEditor
    j__insertFileContents: function() {
        var f = this.j__getCurrentUploadedFiles();
        if(f.length === 0) {
            return '<div class="z__dropdown_menu_entry_title">(no files, click Upload file...)</div>';
        }
        return _.map(f, function(c) {
            return '<a>'+j__xmlEscape(c.p__fileInfo.filename)+'</a>';
        }).join('');
    },
    j__insertFileSelection: function(a,index) {
        KDocEditWidget.j__clearUndoable();
        this.j__hideAddContentBox();     // don't let the add content box stay open
        var f = this.j__getCurrentUploadedFiles()[index];
        var is_img = (f.p__fileInfo.mimeType.match(/^image\//))?1:0;
        this.j__insertNewWidget(KDocEditWidgetFile,{name:f.p__fileInfo.filename,img:is_img});
    },

    j__getCurrentUploadedFiles: function() {
        var r = [];
        _.each(this.p__keditorValueControl.p__parentContainer.p__keditor.q__attrContainers, function(container) {
            _.each(container.j__getAllValueControls(), function(v) {
                if(v.p__dataType == T_IDENTIFIER_FILE && v.j__hasValue()) {
                    r.push(v.j__getControl());
                }
            });
        });
        return r;
    },

    // ---------------------------
    // Paragraph styles drop down menu
    j__paragraphStylesContents: function() {
        this.j__hideAddContentBox();     // don't let the add content box stay open
        var c = [];
        var m = this.q__shortcutModifier; // because of scoping in iterator
        _.each(this.q__PARAGRAPH_STYLES, function(n) {
            if(n[3]) { c.push('<div class="z__dropdown_menu_entry_divider"></div>'); }
            c.push('<a href="#" style="white-space:nowrap">', n[1]);
            if(n[2]) { c.push('&nbsp; (', m, '-', n[2], ')'); }
            c.push('</a>');
        });
        return c.join('');
    },
    j__paragraphStylesHandleSelection: function(a,index) {
        KDocEditWidget.j__clearUndoable();

        var s = this.q__PARAGRAPH_STYLES[index];
        if(s) {
            this.j__setCurrentParagraphStyle(s[0]);
            this.j__setParagraphStyleButtonCaption();
        }
    },

    // ---------------------------
    // Set paragraph style
    j__setCurrentParagraphStyle: function(s) {
        // Set style
        if(this.q__selectedParagraph) {
            this.q__selectedParagraph.className =  s ? ('p_'+s) : '';
            this.j__setParagraphStyleButtonCaption();
        }
    },

    // and the display for it
    j__setParagraphStyleButtonCaption: function() {
        // so tempting to use substr(-1) but IE implements it wrong
        var v = 'p';
        if(this.q__selectedParagraph) {
            var c=this.q__selectedParagraph.className;
            if(c.length > 1) {
                v = c.substr(c.length-1,1);
            }
        }
        this.q__paraStyleButton.j__setCaption(v);
    },

    // ---------------------------
    // Handling the add content bit
    j__onAddContentClick: function(event) {
        event.preventDefault();
        KApp.j__closeAnyDroppedMenu();
        if(this.q__addContentBoxShown) {
            this.j__hideAddContentBox();
        } else {
            var e = $('#'+this.q__domId+'_a')[0];
            e.style.top=(this.q__floatingControlsY+($('#'+this.q__domId+'_f')[0].offsetHeight))+'px';
            $(e).show();
            this.q__addContentBoxShown = true;
        }
    },

    j__hideAddContentBox: function() {
        if(this.q__addContentBoxShown) {
            $('#'+this.q__domId+'_a').hide();
            this.q__addContentBoxShown = false;
        }
    },

    // ---------------------------
    // Widgets drop down menu
    j__insertWidgetsContents: function() {
        // Output all names of the widgets
        var h = '';
        _.each(KDocEditWidget.p__menuOrder, function(t) {
            h += '<a href="#">'+KDocEditWidget.p__classes[t].prototype.p__headingName+'</a>';
        });
        return h;
    },
    j__insertWidgetsHandleSelection: function(a,index) {
        this.j__hideAddContentBox();     // don't let the add content box stay open
        // Get rid of any undoable widget which is hanging around
        KDocEditWidget.j__clearUndoable();
        // Add the widget
        this.j__insertNewWidget(KDocEditWidget.p__classes[KDocEditWidget.p__menuOrder[index]]);
        // Clean the DOM
        this.j__cleanUpDom();
    },

    // ---------------------------
    // Browser specific code

    j__getFirstParentOfSelection: function() {
        if(!(this.q__editable)) {return null;}
        var e, scan;
        var u = null;       // output
        var b = document.body;
        if(b.createTextRange) {
            // Internet Explorer
            try {
                var r = document.selection.createRange();
                e = this.j__getEditContainer();
                scan = e.firstChild;
                var bt = b.createTextRange();
                if(bt && r && bt.inRange(r)) {
                    // Check it's not before the document
                    var t = r.duplicate();
                    t.moveToElementText(e);
                    if(r.compareEndPoints("StartToStart",t) >= 0) {
                        // Point is after the start, scan through
                        while(scan && !u) {
                            t = r.duplicate();
                            t.moveToElementText(scan);
                            if(r.compareEndPoints("StartToEnd",t) <= 0) // <= is important, < won't work if cursor at end
                            {
                                u = scan;
                            }
                            scan = scan.nextSibling;
                        }
                    }
                }
            }
            catch(e2) {} // do nothing -- exception handler protects against weird errors in IE6 popping up and causing problems.
        } else {
            var s = window.getSelection();
            if(s) {
                if(s.focusNode) {
                    u = s.focusNode;
                }
/*                // Safari 3 implements this, but differently to Mozilla, perhaps only having a range when
                // there's a real selection.
                if(s.getRangeAt && s.rangeCount > 0) {
                    // Mozilla
                    u = s.getRangeAt(0).startContainer.parentNode;
                }
                // Try again for Safari / WebKit
                if(u == null && s.baseNode) {
                    var u = s.baseNode.parentNode;
                }*/
            }
        }

        if(u) {
            while(u && u.nodeName.toLowerCase() != 'p') {
                if(u.className=='z__widget_container') {
                    // It's in a widget, abort!
                    return null;
                }
                u = u.parentNode;
            }
            // Check that it's in the right document
            e = this.j__getEditContainer();
            scan = u;
            while(scan && scan != e) {
                scan = scan.parentNode;
            }
            if(scan != e) {
                // Under the wrong document
                return null;
            }
            // Check it's not in a widget -- two checks do seem to be necessary
            var w = u;
            while(w) {
                if(w.className=='z__widget_container'){return null;}
                w = w.parentNode;
            }
        }

        return u;
    },

    // ---------------------------
    // Insert from menu

    j__insertObjrefs: function(i) {
        for(var n = i.length - 1; n >= 0; --n)  // insert backwards so they appear in the right order
        {
            this.j__insertNewWidget(KDocEditWidgetObject,{
                ref: i[n],
                title: KApp.j__objectTitle(i[n]).replace(/^\s+/, '').replace(/\s+$/, ''),
                style: 'linkedheading'
            });
        }
    },

/*    j__insertResponseText: function(t) {
        // TODO: Proper implementation
        var u = this.j__getFirstParentOfSelection();
        // Safari loses the selection when the box is clicked, so use the last seen one
        if(u == null) {u = this.q__lastSeenSelection;}
        // If no selection at all, find the end of it
        if(u == null) {
            u = this.q__document.body.lastChild;
        }
        if(u != null) {
            var b = u.nextSibling;
            var lines = t.split("\n");
            for(var i = 0; i < lines.length; i++) {
                var p = this.q__document.createElement('p');
                p.innerHTML = lines[i];
                u.parentNode.insertBefore(p,b);
            }
        }
    },*/

    j__insertMenuCallback: function(data_type,data) {
        this.j__hideAddContentBox();     // don't let the add content box stay open
        if(data_type == 'o') {
            this.j__insertObjrefs(data);
        } else if(data_type == 's') {
            this.j__insertNewWidget(KDocEditWidgetSearch,data);
        }
    },

    // ---------------------------
    // Widget HTML
    j__htmlForWidget: function(w) {
        return w.j__generateHtml();
    },
    // Widget reading
    j__widgetContainerToDoc: function(div) {
        // Find widget object
        var w = KDocEditWidget.j__widget(div.id);
        if(!w) {
            return '';
        } else {
            var o = w.j__output();
            if(!o) {return '';}
            var d = '<widget type="'+w.p__widgetType+'">';
            _.each(o, function(e) {
                d += '<v name="'+e[0]+'">'+j__xmlEscape(e[1].toString().split(/[\r\n]+/).join('\n'))+'</v>';     // \r\n for IE
            });
            return d+"</widget>";
        }
    },

    j__insertNewWidget: function(wclass, spec) {
        // Work out where to put it
        var after = this.q__selectedParagraph;
        if(!after) {return;}
        var x = after.parentNode;
        var i = after.nextSibling;  // insert point

        // Create widget
        var w = new wclass(this, spec, true);   // if spec == null, suitable defaults are used (true means 'no container')
        if(!w || !(w.p__ok)) {return;}   // check everything is fine

        // Make widget HTML (first, so the ID gets allocated)
        var h = w.j__generateHtml();

        // Need a blank paragraph?
        if(after.className == 'z__widget_container') {
            var p = document.createElement('p');
            x.insertBefore(p,i);
            p.innerHTML = EMPTY_PARAGRAPH_FOR_EDIT_CONTENTS;
        }

        // Add to document
        var n = document.createElement('div');
        n.id = w.q__domId;
        n.className = 'z__widget_container';
        n.contentEditable = false;
        x.insertBefore(n,i);
        n.innerHTML = h;
        // Attach
        w.j__attach();

        // Paragraph after
        var para = document.createElement('p');
        x.insertBefore(para,i);
        para.innerHTML = EMPTY_PARAGRAPH_FOR_EDIT_CONTENTS;
    },

    // ---------------------------
    // Tidy up the mess that the browser made of the DOM

    j__cleanUpDom: function() {
        // Function to detect nodes with element children, ie not normal text nodes
        var nodeHasElementChildren = function(node) {
            var scan = node.firstChild;
            while(scan !== undefined && scan !== null) {
                if(scan.nodeType == NODE__ELEMENT_NODE) {
                    return true;
                }
                scan = scan.nextSibling;
            }
            return false;
        };

        var container = this.j__getEditContainer();
        var scan = container.firstChild;
        var toDelete = [];
        while(scan !== undefined && scan !== null) {
            // Check the node!
            // Allow:
            //   Must be an element
            //   <p> with just text children, no <br>
            //   <p> with just a <br> as contents
            //   <div class="z__widget_container">
            var ok = false;
            if(scan.nodeType == NODE__ELEMENT_NODE) {
                var nodename = scan.nodeName.toLowerCase();
                if(nodename == 'p') {
                    if(nodeHasElementChildren(scan)) {
                        // Might be an ending paragraph or a blank paragraph, though
                        var contents = scan.innerHTML.toLowerCase();
                        if(contents == '<br>' || contents == '<br/>') {
                            // Empty paragraph with just a <br> is fine.
                            ok = true;
                        }
                    } else {
                        ok = true;
                    }
                }
                if(nodename == 'div' && scan.className == 'z__widget_container') {
                    ok = true; // It's a widget
                }
            }

            if(!ok) {
                // Need to rebuild the DOM elements from the contents of this node.
                // Scan through the nodes. Gather the text contents together.
                // Start a new node when encountering a <p>, <div> or <br>
                var paragraphs = [];
                var cleanedText = '';
                var collectParagraph = function() {
                    if(cleanedText !== '') {
                        var p = document.createElement('p');
                        p.appendChild(document.createTextNode(cleanedText));
                        paragraphs.push(p);
                        cleanedText = '';
                    }
                };
                var cleanRecursive = function(node, limit) {
                    if(limit < 0) { return; } // don't trust the DOM
                    var s = node.firstChild;
                    while(s !== null && s !== undefined) {
                        if(s.nodeType == NODE__TEXT_NODE) {
                            cleanedText += s.nodeValue;
                        } else if(s.nodeType == NODE__ELEMENT_NODE) {
                            var nodename = s.nodeName.toLowerCase();
                            if(nodename == 'p' || nodename == 'div' || nodename == 'br') {
                                // New paragraph
                                collectParagraph();
                            }
                            // Recurse into the child nodes
                            cleanRecursive(s, limit - 1);
                        }
                        s = s.nextSibling;
                    }
                };
                cleanRecursive(scan, 32);

                // Collect anything left over
                collectParagraph();

                // Try to remove this node.
                var nextNode = scan.nextSibling;

                // Add the paragraphs
                var x;
                for(x = 0; x < paragraphs.length; ++x) {
                    try {
                        container.insertBefore(paragraphs[x], nextNode);
                    } catch(e) {
                        // IE can get terribly confused. If there's an error, give up now.
                        KCtrlDocumentTextEdit.iePasteBugFound = true;
                        return;
                    }
                }

                // Try to remove the node
                try {
                    container.removeChild(scan);
                } catch(e2) {
                    // IE can get terribly confused. If there's an error, remove the paragraphs we added, then give up.
                    KCtrlDocumentTextEdit.iePasteBugFound = true;
                    for(var y = 0; y < paragraphs.length; ++y) {
                        container.removeChild(paragraphs[y]);
                    }
                    return;
                }

                // Next!
                scan = nextNode;
            } else {
                scan = scan.nextSibling;
            }
        }
    },

    // ---------------------------
    // Conversion functions

    j__docTextToHtml: function(doc,widgets_out) {
        if(!doc || doc === '') {return '';}

        // Parse the xml from the server
        var xml = j__parseXml(doc);
        if(!xml) {
            // Shouldn't happen if there's valid XML given and used on a supported browser
            return '<h1>ERROR SETTING UP EDITOR</h1>';
        }

        // Setup for conversion
        var htmlComponents = [];
        var text_before = false;    // whether there's text preceeding the current line -- widgets need space before and after

        // Scan to produce output
        var scan = xml.documentElement;
        while(scan) {
            // Text?
            var nname = scan.nodeName;
            if(nname == '#text') {
                // Text
                htmlComponents.push(j__xmlEscape(scan.nodeValue));
            } else {
                // Container tag

                // Start tag?
                if(CONVERSION_TAGS_OUT[nname]) {
                    htmlComponents.push('<p class="p_',nname.charAt(nname.length-1),'">');
                } else if(CONVERSION_CONTAINERS[nname]) {
                    htmlComponents.push('<p>:',nname,'</p>');
                } else if(nname == 'widget') {
                    // Widget node... gather values
                    var spec = {};
                    var values = scan.getElementsByTagName('v');
                    for(var x = 0; x < values.length; x++) {
                        var v = values[x];
                        spec[v.getAttribute('name')] = v.firstChild ? v.firstChild.nodeValue : ''; // is already unescaped
                    }
                    // Instantiate?
                    var widget = null;
                    var wc = KDocEditWidget.p__classes[scan.getAttribute('type')];
                    if(wc) {
                        try {
                            widget = new wc(this,spec);
                        } catch(e) {} // ignoring errors
                    }
                    if(!widget || !(widget.p__ok)) {
                        htmlComponents.push('<p>CANNOT EDIT WIDGET</p>');
                    } else {
                        // Make sure there's text or space before
                        if(!text_before) {
                            htmlComponents.push(EMPTY_PARAGRAPH_FOR_EDIT);
                        }
                        htmlComponents.push(this.j__htmlForWidget(widget));
                        if(widgets_out) {
                            // Make widgets used accessible to caller for calling j__attach()
                            widgets_out.push(widget);
                        }
                        text_before = false;
                    }
                }
            }

            if(scan.firstChild && nname != 'widget') {
                // Down
                scan = scan.firstChild;
            } else {
                // Up and across
                while(scan && !scan.nextSibling) {
                    // Up

                    // Terminate the parent node
                    var p = scan.parentNode;
                    if(p) {
                        // Close tag?
                        if(CONVERSION_TAGS_OUT[p.nodeName]) {
                            htmlComponents.push('</p>');
                        } else if(CONVERSION_CONTAINERS[p.nodeName]) {
                            htmlComponents.push('<p>:main</p>');
                        }
                    }

                    // Up
                    scan = p; // p == null terminates scan
                }

                if(scan) {
                    // And across
                    scan = scan.nextSibling;
                }
            }
        }

        return htmlComponents.join('');
    },
    j__domObjsToDoc: function(r) {
        var documentComponents = ['<doc>'];
        var appendParagraphToDocument = function(tag, text) {
            if(text && text.length > 0 && /\S/.test(text)) {
                documentComponents.push('<',tag,'>',j__xmlEscape(text),'</',tag,'>');
            }
        };
        var s = r.firstChild;
        var container = null;
        while(s) {
            if(s.nodeType == NODE__TEXT_NODE) {
                appendParagraphToDocument('p', s.nodeValue);
            } else if(s.nodeType == NODE__ELEMENT_NODE) {
                var n = s.nodeName.toLowerCase();
                if(n == 'div' && s.className == 'z__widget_container') {
                    documentComponents.push(this.j__widgetContainerToDoc(s));
                } else {
                    // Try and capture the text inside the tag - being very careful to avoid IE problem
                    var textContent = '';
                    var limit = 256;    // a safety limit for IE's circular post-pasting DOMs
                    var capture = function(node) {
                        var scan = node.firstChild;
                        while(scan !== null && scan !== undefined) {
                            if(limit < 0) { return; }
                            limit--;
                            if(scan.nodeType == NODE__TEXT_NODE) {
                                if(textContent !== '') {
                                    textContent += ' '; // make sure there's spaces between everything
                                }
                                // XML spec says valid chars are:
                                //   Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
                                // Allow all the 16 bit characters, but omit the last range which is not represented in 16 bits.
                                // Have had problems with \u001d being in the string, pasted in by Safari or Firefox, which
                                // then means the text can't be edited as the XML won't parse.
                                textContent += scan.nodeValue.replace(/[^\u0009\u000a\u000d\u0020-\ud7ff\ue000-\ufffd]+/g,' ');
                            } else if(scan.nodeType == NODE__ELEMENT_NODE) {
                                capture(scan);
                            }
                            scan = scan.nextSibling;
                        }
                    };
                    capture(s);
                    // Work out how the node should be represented
                    if(n == 'p') {
                        // Is it styled?
                        var tag = 'p';
                        if(s.className.substr(0,2) == 'p_') {
                            var t = s.className.substr(2);
                            if(t === 'i') { tag = 'li'; } else if(t !== 'p') { tag = 'h'+t; }
                        }
                        // Is it a container tag?
                        var cmatch = /^:([a-zA-Z]+)\s*$/.exec(textContent);
                        if(cmatch) {
                            var q = cmatch[1].toLowerCase();
                            if(q == 'main' || container) {
                                // close current container tag
                                documentComponents.push('</',container,'>');
                                container = null;
                            }
                            if(CONVERSION_CONTAINERS[q]) {
                                // Open container tag
                                documentComponents.push('<',q,'>');
                                container = q;
                            }
                        } else {
                            appendParagraphToDocument(tag, textContent);
                        }
                    } else {
                        // Just assume this odd node is a paragraph
                        appendParagraphToDocument('p', textContent);
                    }
                }
            }
            s = s.nextSibling;
        }
        // Close container tag?
        if(container) {
            documentComponents.push('</',container,'>');
        }
        documentComponents.push('</doc>');
        return documentComponents.join('');
    }
});

// For reporting bugs to the user
KCtrlDocumentTextEdit.iePasteBugFound = false;
KCtrlDocumentTextEdit.iePasteBugReported = false;

})(jQuery);

