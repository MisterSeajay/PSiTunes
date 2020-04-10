Plist.Net - plistdotnet v0.4
Copyright (c) 2008, TWSS
All rights reserved.

Installation
------------

Add a reference to Plist.dll to your project and you are sorted.

Usage
-----

To create a plist from from an object, use the following:

string plist = Plist.PlistDocument.CreateDocument(value);

Sorry it's so simple.

Notes
-----

1. Any custom classes you wish to convert into a Property List MUST be marked
   as 'Serializable', otherwise they will be ignored.

2. When making a plist from custom classes any values you want included in the
   plist MUST be exposed through a Property (at least a GETter) rather than
   public variables.
   
To-Do
-----

- Add some exception handling.
- Re-create an object from a (specially crafted) plist.