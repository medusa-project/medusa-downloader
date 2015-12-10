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



