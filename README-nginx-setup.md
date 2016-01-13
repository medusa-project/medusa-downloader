# nginx setup

It is necessary to have nginx with the mod_zip module installed. This application works by creating the manifests
necessary for nginx+mod_zip to create zip files on the fly. 

The nginx configuration needed is fairly simple. First, we have to proxy through urls prefaced with /downloads to
this rails app with a section like:

    location /downloads/ {
      proxy_pass http://localhost:3000/downloads/;		 
    }	

In the manifests this app generates locations for nginx to find the actual files to zip and serve. These locations
look like '/internal/download_id/path'. This application stores these under the 'storage' path as configured in 
medusa_downloader.yml, and the 'download_id/path' are relative from that. So make sure that nginx is configured
to allow following symlinks, add a symlink in the nginx document root named 'internal' to the application storage
path, and add a configuration section like the following to nginx.conf:

    location ^~ / {
      root html;
      internal;
    }

The internal directive means that nginx alone is allowed to access these locations; an outside user cannot hit them.
(This is unrelated to our use of 'internal' in the location itself and the symlink.) When nginx examines the 
manifest and finds /internal/download_id/path it looks in its web root for /internal/download_id/path and because 
of how we set up the symlink it finds download_id/path under the storage for medusa-downloader. Note that this path
will again be a symlink to the actual content on the filesystem. So all this must be readable by nginx.
