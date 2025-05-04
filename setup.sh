#!/bin/bash

APP_DIR="/opt/app"

#################################################################################################
# Make the ubuntu user owner of all files and directories under $APP_DIR (recursively)
#
# Relevant link: https://www.geeksforgeeks.org/chown-command-in-linux-with-examples/
#################################################################################################
sudo chown -R ubuntu $APP_DIR

#################################################################################################
# Update Ubuntu's package list and install the following dependencies:
# - python3-pip
# - python3-venv
# - nginx 
# 
# Relevant link: https://ubuntu.com/server/docs/package-management
#################################################################################################
sudo apt update && sudo apt install -y nginx \
python3-pip \
python3.10-venv

#################################################################################################
# Create a Python virtual environment in the current directory and activate it
#
# Relevant link: https://www.liquidweb.com/blog/how-to-setup-a-python-virtual-environment-on-ubuntu-18-04/
#################################################################################################
python3 -m venv ~/app
source ~/app/bin/activate

#################################################################################################
# Install the Python dependencies listed in requirements.txt
#
# Relevant link: https://realpython.com/what-is-pip/
#################################################################################################
python3 -m pip install -r $APP_DIR/requirements.txt

# Set up Gunicorn to serve the Django application
cat > /tmp/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
Environment="AWS_DEFAULT_REGION=us-east-1"
User=$USER
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$PWD/app/bin/gunicorn \
          --workers 3 \
          --bind unix:/tmp/gunicorn.sock \
          cloudtalents.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
sudo mv /tmp/gunicorn.service /etc/systemd/system/gunicorn.service

#################################################################################################
# Start and enable the Gunicorn service
#
# Relevant link: https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units
#################################################################################################
sudo systemctl enable gunicorn.service --now

# Configure Nginx to proxy requests to Gunicorn
sudo rm /etc/nginx/sites-enabled/default
cat > /tmp/nginx_config <<EOF
server {
    listen 80;
    server_name your_domain_or_IP;

    location = /favicon.ico { access_log off; log_not_found off; }

    location /media/ {
        root $APP_DIR/;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://unix:/tmp/gunicorn.sock;
    }
}
EOF
sudo mv /tmp/nginx_config /etc/nginx/sites-available/cloudtalents

# Enable and test the Nginx configuration
sudo ln -s /etc/nginx/sites-available/cloudtalents /etc/nginx/sites-enabled
sudo nginx -t

#################################################################################################
# Restart the nginx service to reload the configuration
#
# Relevant link: https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units
#################################################################################################
sudo systemctl daemon-reload
sudo systemctl restart nginx

#################################################################################################
# Allow traffic to port 80 using ufw
#
# Relevant link: https://codingforentrepreneurs.com/blog/hello-linux-nginx-and-ufw-firewall
#################################################################################################
sudo ufw enable
sudo ufw allow http


# Print completion message
echo "Django application setup complete!"


#################################################################################################
# CloudWatch Agent Installation and Configuration
#
# Relevant links:
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/download-cloudwatch-agent-commandline.html
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html
#################################################################################################

# Download and install CloudWatch Agent
sudo wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
rm ./amazon-cloudwatch-agent.deb


# Create CloudWatch Agent configuration
sudo mkdir -p $APP_DIR
sudo cat > $APP_DIR/cloudwatch-config.json <<EOF
{
  "agent": {
     "metrics_collection_interval": 60,
     "region": "eu-west-1"
    },
  "metrics": {
      "append_dimensions": {
      "ImageId": "\${aws:ImageId}",
      "InstanceId": "\${aws:InstanceId}",
      "InstanceType": "\${aws:InstanceType}",
      "AutoScalingGroupName": "\${aws:AutoScalingGroupName}"
      },
        "metrics_collected": {
    "mem": {
        "measurement": [
            { "name": "used_percent", "rename": "MEM_USAGE_PERCENT", "unit": "Percent" }
          ]
        }
      }
  },
    "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/opt/app/**.log",
                "log_group_name": "/startup/app",
                "log_stream_name": "{instance_id}",
                "retention_in_days": 30
              }
            ]
          }
      }
    }
}
EOF


# Start and enable CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:$APP_DIR/cloudwatch-config.json

sudo systemctl enable amazon-cloudwatch-agent.service --now


# Print completion message
echo "CloudWatch Agent installation and configuration complete!"