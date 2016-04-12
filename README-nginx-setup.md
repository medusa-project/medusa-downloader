# nginx setup

It is necessary to have nginx with the mod_zip module installed, which 
we'll assume is on port 8080. It also 
is required to have a second nginx (or any webserver that can serve 
static content) to serve the files to the mod_zip server (avoiding an
nginx problem with open files that we couldn't work around). We'll assume
this is on port 8081.

This application works by creating the manifests
necessary for nginx+mod_zip to create zip files on the fly.

The nginx configuration needed is fairly simple. 

For the mod_zip nginx, we have to proxy through urls prefaced with /downloads to
this rails app with a section like:

    location /downloads/ {
      proxy_pass http://localhost:3000/downloads/;		 
    }	

Note that you might also want to use nginx to restrict access to the
/downloads/create location - see nginx documentation for ways to do 
this using standard http authentication methods. To use this you'll
also need to install the nginx-http-auth-digest module 
(https://github.com/atomx/nginx-http-auth-digest) in nginx. A
sample config section:

    location /downloads/create {
        auth_digest 'request_creators';
        auth_digest_user_file /etc/nginx/conf/digest_users;
        proxy_pass http://localhost:3000/downloads/create;
    }

In the manifests this app generates locations for nginx to find the 
actual files to zip and serve. 

These locations look like '/internal/download_id/path'. This application
stores these under the 'storage' path as configured in 
medusa_downloader.yml, and the 'download_id/path' 
are relative from that. 

Make sure that the file-serving nginx is configured
to allow following symlinks, add a symlink in the nginx document 
root named 'internal' to the application storage
path, and add a configuration section like the following to nginx.conf:

    location ^~ / {
      root html;
    }

Finally, we need a way for the mod_zip nginx to get the file content 
from the file-serving nginx. In the mod_zip nginx put a section like:

	location ^~ /internal {
	    proxy_pass http://localhost:8081/internal;
	    internal;
	}
_

The internal directive means that nginx alone is allowed to access these locations; an outside user cannot hit them.
(This is unrelated to our use of 'internal' in the location itself and the symlink.) When nginx examines the 
manifest and finds /internal/download_id/path it looks in its web root for /internal/download_id/path.
This section proxies this through to the file-serving nginx which then returns
the file content.

If you wish it is possible to set things up so that this application or
another web server fills the role of the file-serving nginx. Just make sure
that when the above /internal location is hit that the proxied server
serves up the right content back to the mod_zip nginx.

    
