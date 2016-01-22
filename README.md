# Medusa downloader

## Introduction

This rails application will combine with an nginx server running mod_zip to allow streamable zip downloads of medusa
content.

The nginx server will have an internal location that can access medusa content via links produced by this application. 
It will have an external location that proxies through to this application, which will produce manifests that mod_zip 
can use to stream the content.

Client applications will send AMQP requests to this application to get it to produce manifests for desired content by
naming that content relative to some 'root' directory that both the client and downloader know about. The downloader
then processes the request to prepare the manifest and lets the client know how to check on the status and how to 
download the archive once complete.

After some timeout period the request is invalidated and removed.

## AMQP message protocol

These are the AMQP messages that will be used. All AMQP messages will be JSON objects with the specified forms and 
fields. Fields are mandatory unless noted.

1. export (client to server)
    * action - 'export'
    * client_id - string - an id that the client can initially use to collate the return_request, which will contain a
      permanent id for the request.
    * return_queue - string - an AMQP queue that the downloader should use to send messages back to the client. This and
      the incoming queue should exist ahead of time and both the downloader and client will need access to them. 
    * root - string - the name of the 'root' from which the content is located. This maps to a directory on each side where
      the content of interest to that client resides. All content in a request must live underneath that directory; it is an
      error to escape from it with '..', etc. The downloader maintains a list of these to service multiple clients.
    * zip_name - string (optional) - the name of the zip file to be produced. If not supplied a non-meaningful one will
      be generated. Do not append the '.zip' extension.
    * timeout - integer (optional) - the server will automatically delete requests after a number of days, but the client
      can specify a number of days after which to delete, which will be used if it is smaller than the global number.
    * targets - array - an array of target (described below) telling the downloader what to include in the archive
        * target
            * type - string - either 'file' or 'directory'
            * recursive - boolean (optional - default: false) - ignored for a file. For a directory specifies whether to include
              the entire directory tree or just the files immediately included in the directory
            * path - string - the path relative to the root where the target is. This must resolve to an actual file or
              directory.
            * zip_path - string (optional, default '') - the path where the target should be located in the zip file. Files will
              be located in that directory. Directories (recursive or not) will be a directory in that directory. By default
              everything just goes in the top level of the zip. The zip will uncompress to a directory based on the zip_name.
              E.g. something like 'data.zip' will unzip to a 'data' directory with content by default in that directory.
2. request_received (server to client)
    * action - 'request_received'
    * client_id - string - the client_id that the client sent in the export message
    * id - string - an id that the downloader generates and will recognize for future communication
    * status - string - 'ok' or 'error' - reports an error if there was a problem generating the request itself. Any
      errors processing the request will be reported later with an error message. Note that
      the id, download_url, status_url fields will not be present on an error, and 
      client_id may not be (if it was not initially supplied). In addition it is possible
      to send erroneous requests that the downloader is unable to respond to, e.g.
      if an invalid (or no) return queue is specified.
    * error - string - if the status is 'error' this is an explanation of the problem
    * download_url - url to get the zip when it is available
    * status_url - url to get the status of the request
3. error (server to client)
    * action - 'error'
    * id - string - the id of the request
    * error - string - a description of the error. Examples of errors that might be detected during request processing: 
      target missing, target outside of root, etc.
4. request_completed (server to client)
    * action 'request_completed'
    * id - string - id of the request
    * deletion_time (optional) - string - when the request will be deleted and the content will no longer be available - 
      in the process of rethinking this since we don't actually create the zips now
    * download_url - same as request_received
    * status_url - same as request_received
    
Other messages that may be implemented in the future: delete_request, status

## Web interface

This isn't completely defined yet, but users will be able to check on the status of a request. Requests should generally
result in something downloadable fairly quickly, but the downloader does need to run through all the targets, confirm
they are valid, and make a manifest. This may take a little time for large numbers of files, whether requested directly
or through directory targets. These requests will be proxied through nginx to the downloader.

Actual content download will again be proxied through nginx to the downloader. The downloader will return the manifest
and headers that direct nginx to deliver a zip archive. So the downloader's part in these requests is fairly minimal. 
Nginx will handle the bulk of the work based on the manifest. If the file system has changed after the generation of the
manifest there could be errors here, but there's not really a good way to deal with them. By and large there shouldn't be
changes to the permanently stored content.

## Extraction

This application in conjunction with nginx produces archives in the 
zip format. If the request exceeds what the normal zip format (4GB or
something like 65000 files) can handle then the nginx mod_zip module
automatically produces a zip64 archive instead (sufficient for anything
we might do). However, not all unzip tools handle these correctly.
Most notably, OS X, as of version 10.11, does not, either with the 
command line unzip program or the standard finder tool. The Windows 
Explorer and Linux unzip (and derivatives) seem to work fine. 
 
Alternatives that we have seen work on the Mac include 7zip (available via
homebrew as 7z or probably as a more normal Mac download from the 7zip
website) and The Unarchiver (available through the app store or in more
featureful form through its own website).

