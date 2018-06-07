# Medusa downloader

## Introduction

This rails application will combine with an nginx server running mod_zip 
and another nginx server (optionally any server capable of serving 
static content - this application can do it if properly configured, but
nginx is much faster) to allow streamable zip downloads of medusa
content.

This application produces packages on the file system and manifests for
the packages suitable for nginx mod_zip. The mod_zip nginx server 
proxies this application and gets these manifests. In turn, it calls
out to the second nginx server to actually get the files from the 
filesystem, which it packages and streams. (This is not done 
with a single nginx server because of difficulties with open file 
limits - it appears that internally serving the files directly from
the mod_zip server does not close them in time, whereas making the
requests go to an external server does.)

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
    * root - string - the name of the 'root' from which the content is located. This maps to medusa_storage root on each side where
      the content of interest to that client resides. All content in a request must live underneath that root; it is an
      error to escape from it with '..', etc. The downloader maintains a list of these to service multiple clients or 
      multiple storage areas.
    * zip_name - string (optional) - the name of the zip file to be produced. If not supplied a non-meaningful one will
      be generated. Do not append the '.zip' extension.
    * timeout - integer (optional) - the server will automatically delete requests after a number of days, but the client
      can specify a number of days after which to delete, which will be used if it is smaller than the global number.
    * targets - array - an array of target (described below) telling the downloader what to include in the archive
        * target
            * type - string - either 'file', 'directory', or 'literal'
            * recursive - boolean (optional - default: false) - ignored except for a directory. For a directory specifies whether to include
              the entire directory tree or just the files immediately included in the directory
            * path - string - the path relative to the root where the target is. This must resolve to an actual file or
              directory. Ignored for 'literal'.
            * zip_path - string (optional, default '') - the path where the target should be located in the zip file. Files will
              be located in that directory. Directories (recursive or not) will be a directory in that directory. By default
              everything just goes in the top level of the zip. The zip will uncompress to a directory based on the zip_name.
              E.g. something like 'data.zip' will unzip to a 'data' directory with content by default in that directory.
            * name - string (required for 'literal', optional for others with default File.basename(path)) - 
              applies only to files. May be used to rename a file in the zip. 
            * content - string - ignored except for a literal. The content of this string will be placed at the
              appropriate place in the zip.
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
    * approximate_size - approximate size of the download. Note that this is computed by adding up the
      size of the component files and ignores the overhead of placing them in a zip. Use caution
      if you display this, since it will _not_ be the size of the file the users winds up with.
    
Other messages that may be implemented in the future: delete_request, status

## Web interface

### Creation

Users can create a request via a web interface rather than the 
AMQP interface. Generally this should only be used when the request
is for a small number of files and hence can be completed quickly.

The path for creation is /downloads/create. 
It is recommended that you restrict this in some way to trusted users.
If you set 'active' to true in the auth section of the
config/medusa_downloader.yml file then the client must provide http
digest credentials. The realm and users/passwords are also configured
there in this case - see the template file

Alternately you can set 'active' to false and enforce authentication
somewhere else - since this application presupposes proxying by nginx
that is also a fine place to do it.

If you want this feature to be turned off you can simply activate
authentication on the rails side and have no users.

The request should be a post with the body a string parseable as JSON.
The format of the JSON is the same as for an AMQP request , with the 
following changes. The action is not necessary, as this
is implicit in the URL. The return_queue and client_id are not necessary,
as these exist only to facilitate the asynchronous action via AMQP.

The response will again be a JSON parseable string in the format of the AMQP
response. On success a 201 will be returned with this message. On a
failure a 400 or 500 will be returned with a JSON object giving a short
error message in the 'error' field.

### Status

Users will be able to check on the status of a request using the status url provided. Requests should generally
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

## Request flow

This is to make clear exactly what happens when a download is done
 in case other explanations are confusing.
 
1. User hits /downloads/<root>/<id>/get
2. Mod-zip nginx proxies to Rails
3. Rails returns manifest to mod-zip nginx along with header to 
   tell mod-zip nginx to create zip from manifest
4. For each line of the manifest mod-zip nginx makes an internal call
    to the location indicated in that line
5. This location is configured to proxy the file-serving nginx, which
   serves the content for that file back to the mod-zip nginx, which
   incorporates it into the zip
6. When all lines of the manifest have been done the mod-zip nginx
   finishes the zip
7. As 4-6 are happening the zip is being streamed back to the user.

We originally had only the mod-zip nginx. Instead of a call out to
the file-serving nginx we just served the file contents directly
from the mod-zip nginx to itself as the zip was created. However, doing
this internally to the mod-zip nginx gave us problem with open
file limits on the OS, which we speculate was because mod_zip/nginx
wasn't closing the files until the whole zip was sent. Going to an
external request for the file content seems to have solved this problem.

## S3 integration

In addition to content lying on an accessible filesystem we can also serve
content from S3. To do this configure a medusa_storage root of type s3. 

The root type will then be taken into account in generating the manifest. So examples are:

```yaml

production:
  roots:
    - name: medusa
      path: /path/to/storage/root
      type: filesystem
    - name: medusa-s3
      aws_access_key_id: key-id
      aws_secret_access_key: secret-key
      bucket: medusa-content
      prefix: collection/prefix

``` 

### Manifest generation

For our purposes we continue to think of S3 using the directory model. So it still makes sense to talk about files, 
directories, and recursive directories. If a trailing slash is left out we insert it to. Everything is taken relative
to the specified root prefix, as with the filesystem. (Note that if we're not thinking that way we can just do everything
as individual objects using the 'file' target and everything will still work.) 'literal' targets will still be handled
with a manifest entry pointing to a real file on the file system, which we do the same way we did for the file system
type root.

Instead of symlinking to content on the filesystem, we use the S3 capability to generate a time limited, pre-signed, 
public URL. These look roughly like:

https://bucket.s3-region.amazonaws.com/key?some_parameters.

The manifest in this case generates entries like:

- <size> /bucket/key?some_parameters /path/in/zip

As an example, if your bucket were 'content', the prefix 'my/collection', and the target 'path/to/file.txt' to go at 
the top level of the zip then the bucket 'content' would have to have an object with key 'my/collection/path/to/file.txt' 
and you'd get something like the following in the manifest:

- <size of file.txt> /content/my/collection/path/to/file.txt?params file.txt 

### Nginx configuration

Given the above manifest format, there needs to be an entry in the nginx configuration that translates it back to the
real type of url. For example (don't forget the trailing slashes, and make sure that the format is correct to match
the presigned urls):

```
        location ^~ /bucket/ {
            proxy_pass https://bucket.s3.region.amazonaws.com/;
            internal;
        }

```

I don't know if the second nginx trick will be necessary, but if so then you can set it up just as you'd expect. Have
the main nginx proxy_pass to the second and then set the second one up as above.