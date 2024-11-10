#!/usr/bin/env bash

# Environment variables for the application.
#
# Variables:
#   PORT (str): The port to bind the server to.
#
export SERVICE_PORT=":9000"

# Database settings
#
# Format:
#   <dialect>://<username>:<password>@<host>:<port>/<database>
#
# Variables used in the URL:
#   dialect (str): The name of the database management system.
#   username (str): The username used to connect to the database.
#   password (str): The password used to connect to the database.
#   host (str): The hostname or IP address of the database server.
#   port (int): The port number on which the database server is listening.
#   database (str): The name of the database.
#
#   sslmode=disable means that the connection with our database
#   will not be encrypted.
#
export DATABASE_URL=""

#
export AMI_USER="admin"
#
export AMI_PASS=""

#
export MEDIA_PATH=""

# Randomly generated base64 encoded 32 byte string
# used for various purposes such as signing tokens and
# encrypting sensitive data.
#
export SECRET_KEY="$(openssl rand -base64 32)"
