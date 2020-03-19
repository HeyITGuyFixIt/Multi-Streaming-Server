# Multi Streaming Server
A Nginx server with RTMP module to send video streaming to multiple services.

If you have an optical fiber connection, you might want to send your live streams to multiple services to reach a wider audience. 

If you use Open Broadcast Software, I know it's possible to launch multiple instances, but it has a large CPU cost.

With this project, you can have only one stream to send and the Nginx RTMP server will dispatch this stream to every streaming services that you want. The only brake is your upload speed.

Please note that you also can encode your stream on the fly. If you want to stream to Youtube Gaming in 1080p at 60 FPS and on Twitch in 720p at 30 FPS, it's possible changing the Nginx configuration file.

## Prerequisites

To work on Windows, this project needs to run a Unix virtual machine (*exec* command doesn't work on Windows) using [VirtualBox](https://www.virtualbox.org/wiki/Downloads). This VM is automatically setup using [Vagrant](https://www.vagrantup.com/).

You also need a software to stream to the Nginx server. I personally used [Open Broadcast Software](https://obsproject.com/).

## Usage

Rename the file **nginx.template.conf** (located into *nginx/conf/*) to **nginx.conf** and change its content with your specific data. For instance, you need to change **{{ youtube_key }}** by your Youtube stream key.

Then, launch this command at the root folder of this project (where there is the *Vagrant* file):

```shell
vagrant up
```

If you see the message "*Nginx is ready to use*", you can start to stream. With OBS, change the RTMP URL to **rtmp://192.168.42.42:1935/live**, you don't need to enter a stream key.

To check that the stream is properly received and sent to each services, you can browse to http://192.168.42.42:8080/stat.

## FAQ

- [How to install on a dedicated server](./#user-content-how-to-install-on-a-dedicated-server)
- [How to display all services' chat messages in the same place](./#user-content-how-to-display-all-services-chat-messages-in-the-same-place)
- [How to handle new services](./#user-content-how-to-handle-new-services)

# How to install on a dedicated server

If you own your own dedicated server, you could install the multi streaming server directly on this server to make use of its bandwidth.

Here are the steps to follow for a server with a fresh **Ubuntu 14.04 LTS** installation (it's should be similar for most distribs). We need to build a custom version of Nginx that includes a RTMP module, so **make sure that you don't already have an installation of Nginx running on your system before starting!**

## Install Git

If Git is not already installed (it's available by default since _Ubuntu 16.04_), launch these commands:

```
sudo apt-get update
sudo apt-get install git
```

## Clone the project

Clone the project's files wherever you want, I put mine in my home folder (`~`).

```
git clone https://github.com/Noxalus/Multi-Streaming-Server.git
cd Multi-Streaming-Server
```

## Create Nginx configuration file

Rename the `nginx.template.conf` file into `nginx.conf`:

`mv nginx/conf/nginx.template.conf nginx/conf/nginx.conf`

And change all variables between curly braces ``{{ }}`` like:

- **{{ my_ip_address }}**: the IP address of the device that will record and send video stream (IPv4, can be obtain [here](http://whatismyip.host/))
- **{{ youtube_key }}**: your Youtube stream key (mine looks like that: `XXXX-XXXX-XXXX-XXXX`)
- **{{ twitch_key }}**: your Twitch stream key (mine looks like that: `live_00000000_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`)
- **{{ dailymotion_key }}**: your Dailymotion stream key (mine looks like that: `XXXXXXX?auth=XXXX_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`)
- **{{ hitbox_key }}**: your Hitbox stream key (mine looks like that: `noxalus?key=XXXXXXXX`)

## Execute `bootstrap.sh` script

`chmod +x bootstrap.sh && ./bootstrap.sh`

Press `ENTER` when asked by the script until the installation is complete.

You should see this message at the end:

`Nginx is ready to use.`

If not, make sure your `nginx.conf` file doesn't contain syntax error and check logs into `/usr/local/nginx/logs` folders.

## Make sure the RTMP server is running

You just need to access to the http://yourdomain:8080/stat page to see if the RTMP server is running.

## Send video stream to your server

Open your favorite live stream software and use the following RTMP URL: `rtmp://yourdomain:1935/live` to broadcast your stream to all services specified in the `nginx.conf` file.

# How to display all services' chat messages in the same place

Some streamers display chat messages in the overlay on top of stream video. Unfortunatly, as you broadcast to multiple services, the chat messages scattered on these different services.

To solve this problem, I made another project called [Live Stream Chat Retriever](https://github.com/Noxalus/Live-Stream-Chat-Retriever) that will allow you to retrieve all services' messages to display them in a single HTML page in real time.

Please note that this project has a [`chat`](https://github.com/Noxalus/Multi-Streaming-Server/tree/chat) branch that update the `bootstrap.sh` script to integrate the chat during the installation.

# How to handle new services

By default, this project provide a template with examples for Youtube, Twitch, Dailymotion and Hitbox live services, but you might want to broadcast to another one like Facebook Live for instance.

Of course, it's possible, all you need to retrieve is the RTMP URL of the service in addition with your personal stream key generated by this service.

For Facebook Live, here is what it looks like:

![](https://raw.githubusercontent.com/Noxalus/Multi-Streaming-Server/master/doc/facebook-rtmp-stream-key.jpg)

(Please make sure to pick the checkbox to make the stream key persistent otherwise you will need to change the Nginx configuration each time you make a new live stream...)

Now, look at the file called `nginx/conf/nginx.template.conf`, specifically to the `rtmp` block:

![](https://raw.githubusercontent.com/Noxalus/Multi-Streaming-Server/master/doc/nginx-conf-file.jpg)

This file has a really simple structure easily understandable thanks to the image above. The red block corresponds to the `live` application, the one on which you will send your video stream with the following URL `rtmp://yourdomain:1935/live`. It's into this application that you will transmit the video stream to all services you want. These services are described by the blue blocks that simply push the stream to the RTMP URL corresponding to each service.

If we want to handle Facebook live, we need to add a new application block. Let's call this application `facebook`:

```
application facebook {
	live on;
	record off;

	allow publish 127.0.0.1;
	deny publish all;

	push rtmp://live-api-a.facebook.com:80/rtmp/151958038809828?s_ps=1&a=ATj_CJYL2PqKwBP4;
}
```

Note that we append the stream key to the RTMP URL, it's always like that.

Now, we just have to update the `live` application to push the video stream to our new `facebook` application

```
application live {
	[...]

	push rtmp://localhost/facebook/${name};
}
```

That's all, the Nginx configuration should be reloaded automatically with your changes.

Here is an entire Nginx configuration file that only broadcast your stream to Facebook live:

```
#user  nobody;
worker_processes  1;
 
error_log  logs/error.log  debug;
error_log  logs/error.log  notice;
error_log  logs/error.log  info;
pid        logs/nginx.pid;

 
events {
    worker_connections  1024;
}

http {
    include             mime.types;
    default_type        application/octet-stream;

    sendfile            on;
    keepalive_timeout   65;

    server {
        listen          8080;
        server_name     localhost;

        # rtmp stat
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        location /stat.xsl {
            # you can move stat.xsl to a different location
            root html;
        }

        # rtmp control
        location /control {
            rtmp_control all;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
 
rtmp {
    server {
        listen 1935;
        chunk_size 8192;

        application live {
            live on;
            record off;
            
            allow publish {{ my_ip_address }};
            deny publish all;
			
            push rtmp://localhost/facebook/${name};
        }

		application facebook {
			live on;
			record off;

			allow publish 127.0.0.1;
			deny publish all;

			push rtmp://live-api-a.facebook.com:80/rtmp/151958038809828?s_ps=1&a=ATj_CJYL2PqKwBP4;
		}
    }
}
```
