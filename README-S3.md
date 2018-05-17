# S3 integration

This documentation is to be folded into the rest of the documention, but for now it will be helpful to collect 
together the changes necessary for S3. 

## Roots

We need to expand the concept of a root. There should be a type parameter at the top level, which is either 
'filesystem' (default) or 's3'. Otherwise the filesystem type is unchanged. An s3 root needs a name, amazon and secret keys,
bucket, and prefix (analogous to the path in the filesystem, default blank). I'm not sure if the region will be needed -
it depends on some internals in manifest generation (basically we need enough to get the size of objects and to
generate public urls, both using the s3 api).
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

## Manifest generation

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

## Nginx configuration

Given the above manifest format, there needs to be an entry in the nginx configuration that translates it back to the
real type of url. For example (don't forget the trailing slashes):

```
        location ^~ /bucket/ {
            proxy_pass https://bucket.region.amazonaws.com/;
            internal;
        }

```

I don't know if the second nginx trick will be necessary, but if so then you can set it up just as you'd expect. Have
the main nginx proxy_pass to the second and then set the second one up as above.