# SuiteCRM 7 image by tlii
## General information

**This is an unnaffiliated project without links or input from *SalesAgility Inc*, which holds trademarked rights to the SuiteCRM brand.**

This repository contains source code of the SuiteCRM 7's unofficial container image. The image is built from the official [upstream source code](https://github.com/salesagility/SuiteCRM). There are minor replacements to the official source code to make it more container-friendly (see below).

**There is no guaranteed support.**  If you don't know how to run this or break it while running, you get to keep the pieces. I'm developing this primarily for my own use, but if anyone finds it useful, go for it. If you notice issues, feel free to file an issue.

**This is still very much experimental, and might break at any point.** Contributions are welcome, but might ultimately not get included. I'm trying to keep the application as close to upstream source as possible and only replace or add to the codebase at container level if necessary for configuring the container. If you want to make more changes, I suggest using this as parent image.

**This image does nothing alone.** You'll need to provide a database and possibly reverse proxy or web server. If you want a more complete solution, use the Helm chart (see below) or the included docker composer file (work-in-progress).

## Changes to vanilla source code
- `config_si.php` reads values from environment variables instead of hard-coding.

## Installation and usage
This image only builds the SuiteCRM application and serves it, depending on your target stage, either with php-fpm or apache2.

For apache2 images, you must provide a database and port forwarding. The image only exposes port 80, so it is highly recommended to run a reverse proxy with TLS termination in front of it. 

For php-fpm images, this image will provide php-fpm and the app filesystem. In addition to external database, you need to configure a web server with pass-through of php to the fpm of this container.

You **must** provide the image with the following environment variables:

	DATABASE_NAME: The name of database in the external db server.
	DATABASE_USER: The username on the external db server.
	DATABASE_PASSWORD: The password for the external db server.
	DATABASE_SERVER: The hostname for the external db server.
	SUITECRM_SITEURL: The URL to access the application.

In addition to the mandatory environment variables there are some optional ones:
    SUITECRM_INSTALL_DIR: You can change install location, but you probably shouldn't.
    SUITECRM_UPGRADE_WITH_IMAGE: If set to any non-null value, the codebase is updated each time the image starts. This is useful for automatic updates. *Warning*: At this point Quick Repair & Rebuild is not run automatically, so this setting is usually not recommended.

## Helm chart?!
Not yet, at least.

## Development
By building with target stage `base-final` you can create a base image that finalizes the source tree, but *does not install* any flavor of PHP. You can use it as a base image, but have to install, enable etc. all php-related stuff yourself.

## License
This image is licensed under AGPL3.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.  

	SugarCRM Community Edition is a customer relationship management program developed by SugarCRM, Inc. Copyright (C) 2004-2013 SugarCRM Inc.

	SuiteCRM 7 is an extension to SugarCRM Community Edition developed by SalesAgility Ltd. Copyright (C) 2011 - 2022 SalesAgility Ltd.