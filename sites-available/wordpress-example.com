# www to non-www redirect -- duplicate content is BAD:
# https://github.com/h5bp/html5-boilerplate/blob/5370479476dceae7cc3ea105946536d6bc0ee468/.htaccess#L362
# Choose between www and non-www, listen on the *wrong* one and redirect to
# the right one -- http://wiki.nginx.org/Pitfalls#Server_Name
server {
  # Don't forget to tell on which port this server listens
  listen 80;

  # listen on the www host
  server_name www.wordpress-example.com;

  # and redirect to the non-www host (declared below)
  return 301 $scheme://wordpress-example.com$request_uri;
}

server {
  # listen 80 deferred; # for Linux
  # listen 80 accept_filter=httpready; # for FreeBSD
  listen 80;

  # The host name to respond to
  server_name wordpress-example.com;

  # Supporting or forcing SSL?
  #listen 443 ssl;
  #include h5bp/enable/ssl.conf;
  #ssl_certificate /etc/nginx/certs/server.crt;
  #ssl_certificate_key /etc/nginx/certs/server.key;

  #Parameterization using hostname of access and log filenames.
  access_log /var/log/nginx/wordpress-example.com_access.log;
  # Could also specifically only log humans request and bots requests
  # access_log /var/log/nginx/wordpress-example.com_access.log main if=!$bot_ua;
  # Log bots?
  # access_log /var/log/nginx/wordpress-example.com_access.bots.log main if=$bot_ua;
  # to boost IO on HDD we can disable access logs
  # access_log off;

  # Error logging (log levels: debug, info, notice, warn, error, crit, alert, emerg)
  error_log /var/log/nginx/wordpress-example.com_error.log warn;

  # Path for root files
  root /sites/wordpress-example.com/public;

  # Index files
  index index.php;

  # Allow uploads?
  client_max_body_size 10M;

  #Specify a charset utf-8 already a default define in nginx.conf
  # charset utf-8;

  # Restricted access?
  # include h5bp/limit/local.conf;

  # Include the h5bp basic config set
  include h5bp/base/basic.conf;

  # Enable gzip
  include h5bp/enable/gzip.conf;
  # Default compression level is 5. Can be overwritten
  # gzip_comp_level 2;

  location @php {
    # PHP enabled?
    include h5bp/enable/php.conf;

    # Use this instead if Php is off
    #return 405;

    # Php caching
    #include h5bp/enable/php_cache.conf;
    #fastcgi_cache_valid 200 301 302 304 1h;
    #fastcgi_cache_min_uses 3;

    # Php request limiting?
    limit_req zone=reqPerSec10 burst=50 nodelay;
    limit_conn conPerIp 10;
  }

  location ~ ^.+\.php(?:/.*)?$ {
    try_files !noop! @php;
  }

  # Allowed methods
  # if ($request_method !~ ^(OPTIONS|GET|HEAD|POST)$ ) {
  #     return 405;
  # }

  # Static requests limiting
  limit_req zone=reqPerSec20 burst=100 nodelay;
  limit_conn conPerIp 20;

  # Seconds to wait for backend to generate a page
  fastcgi_read_timeout 10;

  # Default location /
  include h5bp/location/default.conf;

  # Enable clickjacking protection in modern browsers
  # Available in IE8 also
  include h5bp/directive-only/x-frame-options.conf;

  # Enable the Cross-site scripting (XSS)
  include h5bp/directive-only/x-xss-protection.conf;

  # Prevent mobile network providers from modifying your site
  include h5bp/directive-only/no-transform.conf;

  # Disable content-type sniffing on some browsers
  include h5bp/directive-only/x-content-type-options.conf;

  # Enable Content Security Policy (CSP)
  include h5bp/directive-only/content-security-policy.conf;

  # Enable Built-in filename-based cache busting (Read inside conf file)
  include h5bp/location/cache-busting.conf;

  # Enable Cross domain AJAX requests (BE CAREFUL IF ENABLE)
  # include h5bp/directive-only/cross-domain-insecure.conf;

  # Including the php-fpm status and ping pages config.
  # Uncomment to enable if you're running php-fpm.
  #include h5bp/location/php_fpm_status_vhost.conf;

  # Use custom error pages?
  #fastcgi_intercept_errors   on;
  #include h5bp/location/errors.conf;
  #error_page 404 /404.html;
  #error_page 500 501 502 503 504 /50x.html;

  ########## Your custom locations & settings ##########

  # This is a sample for stopping hotlinking.
  # location ~ \.(jpe?g|png|gif)$ {
  #      valid_referers none blocked wordpress-example.com *.wordpress-example.com;
  #      if ($invalid_referer) {
  #         return   403;
  #     }
  # }
}
