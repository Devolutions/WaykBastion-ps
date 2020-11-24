# Wayk Bastion Changelog

This document provides a list of notable changes introduced in Wayk Bastion by release.

## 2020.3.2 (2020-11-26)
  * Improve the interface of Wayk web client
  * Fix an issue where the server could be unresponsive
  * Fix potential session connection failure when client and server clocks are not synchronized
 
## 2020.3.1 (2020-10-30)
  * Change den-lucid log level to warn and log format to json
  * Fix broken Backup/Restore for MongoDB Windows containers

## 2020.3.0 (2020-10-27)
  * Rebranding Wayk Den to Wayk Bastion
  * Upgrade the authentication component
  * Add a button to reset the white label in the web interface
  * Fix an issue where machine registration state could be lost after certificate renewal
  * Fix an issue where a session could not be opened with machine name if it was not lowercase
  * Fix Backup-WaykDenData/Restore-WaykDenData commands on Windows 
  * Fix handling of netstat wrapper when the command is not available

## 2020.2.5 (2020-10-08)
  * Fix an issue where machine registration state could be lost

## 2020.2.4 (2020-08-25)
  * Improve "All Servers" section to display machines by group
  * Fix access denied issue with role assignments on machine groups
  * Fix an issue preventing the listing of more than 100 users
  * Fix an issue preventing some clients from connecting to Wayk Den
  * Add simplified jet relay deployment launched with Wayk Den by default
  * Add check to ensure listener and external URLs include protocol scheme
  * Add check to warn about TCP ports being already used on the host

## 2020.2.3 (2020-08-03)
  * Add initial Wayk Den enrollment token for Wayk Now automation
  * Add automatic machine name alias usable as target id for all servers
  * Add automatic fully qualified DNS name alias for domain-joined machines
  * Allow SRD connections with matching Active Directory user on target machine

## 2020.2.2 (2020-07-06)
  * Fix User-Agent parsing
  * Fix an issue where an old client moving to 2020.2.0 had its Den ID reset
  * Fix exporting issue in white label with 2x images

## 2020.2.1 (2020-06-18)
  * Improve Active Directory user synchronization
  * Add `Domain Users` as default group for Active Directory
  * Add a server description that can be edited in Web UI interface
  * Add a background in Wayk Now web client
  * Fix machine route to return all servers on private Den
  
## 2020.2.0 (2020-06-10)
  * Add new revised and improved Den V3 protocol support
  * Change Wayk Now minimum client requirement to 2020.2.x
  * Change Wayk Now minimum server requirement to 2020.1.x
  * Add new Wayk Now web client in Web UI (preview feature)
  * Add new "Machine User Login" role mandatory for client connections
  * Add automatic publishing of white label branding file from server
  * Add LDAP account provider configuration in Web UI instead of cmdlet
  * Add LDAP configuration test button in Web UI to validation parameters
  * Add Devolutions Jet relay configuration in Web UI instead of cmdlet
  * Add detailed system information with component versions in Web UI
  * Add client user name and server machine name information in "Sessions"
  * Move list of all clients to "Clients" section to replace "Connections"
  * Move list of all servers (machines) to "All servers" section of Web UI
  * Fix Devolutions Jet relay potential WebSocket transport data corruption

## 2020.1.10 (2020-05-13)
  * Fix Devolutions Jet relay panic on aborted TLS/WSS handshakes
  * Fix Backup-WaykDenData/Restore-WaykDenData commands path handling

## 2020.1.9 (2020-04-22)
  * Add basic telemetry support that can be disabled in the configuration
  * Fix WebSocket disconnection when ping/pong takes more than 15 seconds
  * Fix adding users to groups when using an external account provider
  * Change active connection count to include server connections only

## 2020.1.8 (2020-04-14)
  * Add support for localhost access to Web UI in addition to external URL
  * Fix importation of certificate chains that contain a single certificate
  * Add docker restart policy (on-failure by default) parameter for containers

## 2020.1.7 (2020-04-09)
  * Add docker isolation (hyperv, process) parameter for Windows containers
  * Fix problem when loading Wayk Den Web UI with null well-known endpoint
  * Fix system service cmdlet wrapper to use PowerShell encoded commands

## 2020.1.6 (2020-04-08)
  * Add Wayk Den and Jet relay system service registration (Windows only)
  * Add check to warn about DNS server being set to 127.0.0.1 on the host
  * Add check to warn about Symantec Endpoint Protection issues with docker
  * Add better error handling when Web UI cannot be loaded completely
  * Add "Update-WaykDen" command to force pulling latest container images
  * Fix issue with machine names containing special UTF-8 characters
  * Fix https listener on Linux due to broken paths in traefik.toml file

## 2020.1.5 (2020-03-25)
  * Fix Active Directory integration (LDAPS + simple bind)
  * Fix Devolutions Jet relay possible ghost sessions

## 2020.1.4 (2020-03-18)
  * Add support for web-based Wayk Now white-label bundle editor
  * Add support for Active Directory LDAPS integration with custom CA
  * Add "unlimited mode" for COVID-19 relief until September 19th, 2020

## 2020.1.3 (2020-02-19)
  * Add option to disable usage of a docker network
  * Add Devolutions Jet relay management commands
  * Add getting started guide with relay servers
  * Add getting started guide with ACME/letsencrypt

## 2020.1.2 (2020-02-06)
  * Fix support for Windows containers on Windows Server 2019
  * Add workaround for MongoDB Windows container lock file issue
  * Add Backup-WaykDenData/Restore-WaykDenData helper commands
  * Add getting started guide with an Azure virtual machine

## 2020.1.1 (2020-01-30)
  * Rewrite cmdlet in PowerShell instead of C#
  * Use YAML configuration files instead of LiteDB

## 2020.1.0 (2020-01-20)
  * Initial public release
  * Add initial Wayk Den web user interface
  * Add getting started guide with an Argo tunnel
