# PALNI ArchivesSpace Docker Image

## Installation

- Install MySQL and create database with user permissions per [ArchivesSpace instructions](https://archivesspace.github.io/tech-docs/provisioning/mysql.html)
    - Insure global variable log_bin_trust_function_creators=1 
- Change DB URL in [docker-compose.yml](/docker-compose.yml) to reflect correct credentials for DB
- Change Frontend and Backend proxy urls to reflect "http://archivesspace.palni.org/<institution>"
- Change mapped ports in [docker-compose.yml](/docker-compose.yml)
- Run `$ docker-compose up`

## Tech Involved

- Ubuntu 18.04
- MySQL v8.0.25
- Archivesspace v2.8.1

## Notes

On [Docker Hub](https://hub.docker.com/r/pshowell23/aspace-docker)
Used [this repo](https://gitlab.msu.edu/msu-libraries/public/archivesspace-docker/-/tree/master) for inspiration.
