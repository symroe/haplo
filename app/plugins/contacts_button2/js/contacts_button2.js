/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Called when an object's page is requested
P.hook("hObjectDisplay", function(response, object) {
    // Build a list of menu items, which depend on the type of the object being displayed.
    // Menu items link to an object editor for a new object which links to the current object.
    // Only add a menu item if the user has permission to create the proposed object.
    var menuItems = [];
    if((object.isKindOf(TYPE["std:type:organisation"]) || object.isKindOf(TYPE["std:type:person"])) &&
            O.currentUser.canCreateObjectOfType(TYPE["std:type:contact-note"])) {
        menuItems.push(['/do/contacts/add-note/'+object.ref, 'Add Contact note']);
    }
    if(object.isKindOf(TYPE["std:type:organisation"]) && O.currentUser.canCreateObjectOfType(TYPE["std:type:person"])) {
        menuItems.push(['/do/contacts/add-person/'+object.ref, 'Add Person']);
    }
    if(menuItems.length > 0) {
        // Create a button at the top of the page with label 'Contacts', which displays the menu items when clicked.
        response.buttons["Contacts"] = menuItems;
    }
});

// Declare that the plugin responds to a URL (which must be below a root URL set in plugin.json)
P.respond("GET", "/do/contacts/add-note", [
    // Define the sources of the values of the arguments to the handler function
    {pathElement:0, as:"object"}        // if the user doesn't have permission to read this object, the handler won't be called
], function(E, object) {
    // Make a blank object to act as a template
    var templateObject = O.object();
    // Set the type of the object, so the editor knows what fields to display
    // The append* functions are automatically generated from the schema created in the system management web interface.
    templateObject.appendType(TYPE["std:type:contact-note"]);
    // Add a link to the original object in the participant field
    templateObject.append(object, ATTR["std:attribute:participant"]);
    // Add today's date to the note
    templateObject.append(new Date(), ATTR["dc:attribute:date"]);
    // If the user has a representative object, add them as a participant as well
    if(O.currentUser.ref !== null) {
        templateObject.append(O.currentUser.ref, ATTR["std:attribute:participant"]);
    }
    // Copy the "works for" fields from the original object, so the organisation is linked from the contact note
    object.every(ATTR["std:attribute:works-for"], function(value,desc,qualifier) {
        templateObject.append(value, ATTR["std:attribute:participant"]);
    });
    // Render a standard template to show the editor for the new object
    E.render({
        // Pass the templateObject to the std:new_object_editor template
        templateObject:templateObject,
        // Properties for the standard page chrome
        pageTitle:'Add note to '+object.title,          // HTML <title> and <h1>
        backLink:object.url(), backLinkText:'Cancel'    // Add a link in the top left back to the original object
    }, "std:new_object_editor");
});

P.respond("GET", "/do/contacts/add-person", [
    {pathElement:0, as:"object"}
], function(E, object) {
    var templateObject = O.object();
    templateObject.appendType(TYPE["std:type:person"]);
    templateObject.append(object, ATTR["std:attribute:works-for"]);
    E.render({
        templateObject:templateObject,
        pageTitle:'Add person to '+object.title,
        backLink:object.url(), backLinkText:'Cancel'
    }, "std:new_object_editor");
});
