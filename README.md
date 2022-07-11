# SuiteCRM 8 image
## General information

**This is an unnaffiliated project without links or input from *SalesAgility Inc*, which holds trademarked rights to the SuiteCRM brand.**

This repository contains source code of the SuiteCRM 8's unofficial container image. The image is built from the official [upstream source code](https://github.com/salesagility/SuiteCRM).

**There is no guaranteed support.**  If you don't know how to run this or break it while running, you get to keep the pieces. I'm only running this since an official SuiteCRM container doesn't exist.

**This is still very much experimental, and might break at any point.** Contributions are welcome, but might ultimately not get included. I'm trying to keep the application as close to upstream source as possible and only replace or add to the codebase at container level if necessary for configuring the container. If you want to make more changes, I suggest using this as parent image.

**This image is not meant to be stand-alone.** This image **only** builds the applicaton and provides php-fpm support. To actually use SuiteCRM, you'll need to provide a web server for delivery and database.

## Changes to vanilla source code
Nothing yet.

## Installation and usage
This image will provide php-fpm and the app filesystem. You need to configure a web server with pass-through of php to the fpm of this container. Also you need to configure a database.

Most likely however you want to use this as a base image.

## Helm chart?!
Not yet, at least.

## License
This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.  