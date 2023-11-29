#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  - nginx

locale: "en_US.UTF-8"
timezone: "Europe/Stockholm"

write_files:
  # Write the NGINX configuration file to the sites-available directory
  - path: /etc/nginx/sites-available/nginx.conf
    content: |
        # ----------------------------------------------------
        # Define a group of backend servers for load balancing
        # ----------------------------------------------------
        upstream worker-nodes {
            # Add your backend servers here
            # server <ip>:<port>;
        }

        # ----------------------------------------------------
        # HTTP server configuration
        # Redirect all HTTP traffic to HTTPS
        # ----------------------------------------------------
        server {
            # Listen on port 80 as the default server
            listen 80 default_server;
            listen [::]:80 default_server;

            # Default server name
            server_name _;

            # Redirect all HTTP requests to HTTPS
            return 301 https://$host$request_uri;
        }

        # ----------------------------------------------------
        # HTTPS server configuration
        # ----------------------------------------------------
        server {
            # Listen on port 443 as the default server
            listen 443 ssl default_server;
            listen [::]:443 ssl default_server;

            # Default server name
            server_name _;

            # SSL configuration
            ssl_certificate /etc/nginx/ssl/nginx.crt; # Path to your SSL certificate
            ssl_certificate_key /etc/nginx/ssl/nginx.key; # Path to your SSL certificate key

            location / {
                # Forward requests to the backend servers
                proxy_pass http://worker-nodes;

                # Use HTTP 1.1
                proxy_http_version 1.1;

                # Set headers for proxy
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection 'upgrade';
                proxy_set_header Host $host;

                # Bypass the cache for upgraded connections
                proxy_cache_bypass $http_upgrade;
            }
        }

runcmd:
# ---------------------------------------------------------
# NGINX
#

# Create the directory for the SSL files if it doesn't exist
- ["mkdir", "-p", "/etc/nginx/ssl"]

# Generate a new RSA private key and save it to /etc/nginx/ssl/nginx.key
- ["openssl", "genrsa", "-out", "/etc/nginx/ssl/nginx.key", "2048"]

# TODO: Replace the self-signed certificate with a certificate issued by a trusted Certificate Authority (CA). 
#       Self-signed certificates can cause trust issues with clients and are not recommended for production environments.

# Generate a Certificate Signing Request (CSR) using the private key
# The -subj option sets the subject of the CSR, which includes information like the country (C), state (ST), locality (L), organization (O), and common name (CN)
- ["openssl", "req", "-new", "-key", "/etc/nginx/ssl/nginx.key", "-out", "/etc/nginx/ssl/nginx.csr", "-subj", "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"]

# Generate a self-signed certificate using the CSR and private key from the previous steps
# The certificate is valid for 365 days and is saved to /etc/nginx/ssl/nginx.crt
- ["openssl", "x509", "-req", "-days", "365", "-in", "/etc/nginx/ssl/nginx.csr", "-signkey", "/etc/nginx/ssl/nginx.key", "-out", "/etc/nginx/ssl/nginx.crt"]

# Remove the default configuration file if it exists
- ["rm", "-f", "/etc/nginx/sites-enabled/default"]

# Create a symbolic link to enable the site
- ["ln", "-s", "/etc/nginx/sites-available/nginx.conf", "/etc/nginx/sites-enabled/"]

# Restart the NGINX service to apply the changes
# - ["systemctl", "restart", "nginx"]

# ---------------------------------------------------------
# Clean up
#

- ["echo", "WARNING: CLEAN UP"]

# Clean up unneeded packages and files to free up disk space
- apt autoremove -y
- apt clean -y

final_message: "The system is finally up, after $UPTIME seconds"
