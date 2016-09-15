#
# modules.py
#
# Copyright (C) 2016  Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Red Hat Author(s):  David Shea <dshea@redhat.com>

import re

import requests
import json

import xml.etree.ElementTree as ET
import gzip

import modulemd

def parse_json(baseurl):
    """Fetch and parse the JSON file describing a...stack? group? murder? of modules

    Usually raises ValueError if something goes wrong.

    :param baseurl: The URL to the murder of modules
    :returns: the parsed JSON object
    :rtype: dict
    """

    # Fetch the JSON
    response = requests.get(baseurl + "/modules.json")
    if response.status_code != requests.codes.ok:
        raise ValueError("Unable to fetch modules.json")
    
    # Parse the JSON
    json_obj = json.loads(response.text)

    # The return type of json.loads depends on the disaster at https://docs.python.org/3/library/json.html#json-to-py-table
    # This JSON is supposed to be a list, though, so make sure that happened.
    if not isinstance(json_obj, list):
        raise ValueError("Invalid data in modules.json")

    return json_obj

def parse_module_metadata(module_url):
    """Fetch and parse the YAML describing a module.

    Raises some kind of exception if something goes wrong.

    :param module_url: The URL to the repo.
    :returns: The parsed YAML object
    :rtype: modulemd.ModuleMetadata
    """

    # The module's yaml file is part of the repo data, so to find it we first
    # have to fetch and parse yet another metadata file in yet another format.

    # Important note: both YAML and XML specify the character encoding as part
    # of the bytestream (YAML via an optional BOM, XML via the <?xml encoding= part),
    # so the parsers for both should get response.content, which is bytes, and not
    # response.text, which is str.

    response = requests.get(module_url + "/repodata/repomd.xml")
    if response.status_code != requests.codes.ok:
        raise ValueError("Unable to fetch repomd for " + module_url)

    # Parse the repomd, and find the piece that describes the module file.
    # Python does xpath weird: absolute paths are not allowed, and, since the parse
    # functions return a top-level Element object and not a separate Document type,
    # "." from the top-level object is the outmost element. So "./data" is what the
    # rest of the world would call "/repomd/data".
    # Also important: use response.content, and not response.text, because the parser
    # does the character conversion stuff itself based on the <?xml encoding= value.
    tree = ET.fromstring(response.content)
    namespaces = {"md" : "http://linux.duke.edu/metadata/repo"}
    # If something goes wrong this will throw an AttributeError probably
    yaml_url = tree.find("./md:data[@type='module']/md:location", namespaces).get("href")

    # Fetch the YAML
    response = requests.get(module_url + "/" + yaml_url)
    if response.status_code != requests.codes.ok:
        raise ValueError("Unable to fetch YAML for " + module_url)

    # It's probably compressed. If so, uncompress
    if yaml_url.endswith('.gz'):
        yaml_data = gzip.decompress(response.content)
    else:
        yaml_data = response.content

    # Parse the YAML and return the ModuleMetadata object
    mmd = modulemd.ModuleMetadata()
    mmd.loads(yaml_data)
    return mmd

def parse_module(baseurl, module_name):
    """Parse a module and its requirments, and return the repos and packages involved.

    :param baseurl: The murder of modules to use
    :param module_name: The name of module to parse, e.g., fm-httpd
    :returns: a tuple of (url-list, package-set)
    :rtype: (list, set)
    """

    # rpmUtils.splitFilename could have been handy, but it no longers exists in a
    # dnf world, because ???.
    # Also splitFilename parsed envra, which would have been easier
    def _split_nevra(nevra):
        # NOTES FOR THE FUTURE?
        # rpm (at least on the build side) enforces a few restrictions to keep
        # this mess almost parseable:
        # - no ':' in any field
        # - no '-' in version or release
        # - epoch has to be an unsigned int
        # which leaves separating the arch from the release the last impossible
        # part, since you can totally have a release of, say, 1.x86_64, and the arch
        # optional, of course.

        # For right now, though, all we really care about is the name, so just
        # do something sloppy, which will fail on partiularly awful package
        # names, the most obvious case being ones where the name ends in '-<digit>',
        # which is totally a thing. e.g., polkit-qt5-1
        # On the plus side, the list in data.components.rpm.packages seems to always
        # have an epoch, so this bad solution will only fail in *some* contexts
        
        # name-<digits>:<digit>...
        yes_epoch = re.compile(r'(?P<name>.*)-\d+:\d.*')

        # name-<digit>...
        no_epoch = re.compile(r'(?P<name>.*)-\d.*')

        # fallback: just return the whole thing
        name_only = re.compile(r'(?P<name>.*)')

        match = re.match(yes_epoch, nevra)

        if match is None:
            match = re.match(no_epoch, nevra)

        if match is None:
            match = re.match(name_only, nevra)

        return match.group(1)

        return nevra_re.match(nevra).groups()

    # Recursive function to parse a module and its requirements
    def _enable_mod(baseurl, module_name, module_json):
        repos = []
        pkgs = set()

        # Find this module in the json in the sloppiest way possible
        # Throws an IndexError if it ain't exist
        mdj = [m for m in module_json if m['name'] == module_name][0]

        # Save the repo for this module
        repos.append(baseurl + "/" + mdj['url'])

        # Parse the YAML
        mmd = parse_module_metadata(baseurl + "/" + mdj['url'])

        # Find what modules, if any, this module requires.
        # requires is a dictionary, with module names as keys, and a version number as
        # the values. However, it's not real clear how to interpret this number (example
        # data has what looks like <version>-<release>, but spec.yaml has no -<release>,
        # and how badly is this going to change when someone realizes there's no >=),
        # so for now we're ignoring it.
        for req in mmd.requires.keys():
            req_repos, req_pkgs = _enable_mod(baseurl, req, module_json)
            repos += req_repos
            pkgs |= req_pkgs

        # Add the list of packages that the yaml says to install.
        # This will be either: whatever is listed in the data.profiles.default.rpms, or
        # everything listed in data.components.rpms.packages, which is a dict.
        # Only keep the package names and throw out the -evra part.
        if 'default' in mmd.profiles:
            pkgs.update(_split_nevra(p) for p in mmd.profiles['default'].rpms)
        else:
            pkgs.update(_split_nevra(p) for p in mmd.components.rpms.packages.keys())

        return (repos, pkgs)

    return _enable_mod(baseurl, module_name, parse_json(baseurl))
