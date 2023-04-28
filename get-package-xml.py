#!/usr/bin/python3

from xml.dom.minidom import parse
import xml.dom.minidom
import sys

PackageXMLTree = xml.dom.minidom.parse(sys.argv[2])
collection = PackageXMLTree.documentElement

def get_depend(depend_name, org_depend_file_name):

    deps = collection.getElementsByTagName(depend_name)

    f = open(org_depend_file_name, 'a+', encoding='utf-8')

    for dep in deps:    
        if dep.hasAttribute("ROS_VERSION"):
            ros_version = dep.getAttribute("ROS_VERSION")
            if ros_version == "1":
                continue
        if dep.hasAttribute("condition"):
            ros_version = dep.getAttribute("condition")
            if ros_version == "$ROS_VERSION == 1":
                continue

        if dep.hasAttribute("type"):
            url_type = dep.getAttribute("type")
            if url_type != "website":
                continue

        if depend_name == "maintainer" and dep.hasAttribute("email"):
            email = dep.getAttribute("email")
            f.write(depend_name + ":" + dep.childNodes[0].data + " " + email + "\n")
            f.close()
            return

        if depend_name == "description":
            f.write(dep.childNodes[0].data + "\n")
        else:
            f.write(depend_name + ":" + dep.childNodes[0].data + "\n")


    f.close()

get_depend("depend", sys.argv[1])
get_depend("build_depend", sys.argv[1])
get_depend("build_export_depend", sys.argv[1])
get_depend("exec_depend", sys.argv[1])
get_depend("test_depend", sys.argv[1])
get_depend("buildtool_depend", sys.argv[1])
get_depend("buildtool_export_depend", sys.argv[1])
get_depend("license", sys.argv[1])
get_depend("url", sys.argv[1])
get_depend("maintainer", sys.argv[1])
get_depend("description", sys.argv[1] + "-description")
