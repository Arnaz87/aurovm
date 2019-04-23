# Auro VM

A reference implementation of the [Auro abstract machine](https://gitlab.com/aurovm/spec).

**Note**: The main documentation is in english, but files in notes and a few source comments here and there are in spanish. I'm working on translating the important stuff to english.

**License**: This project is open source software, distributed under the MIT license.

# How to use

To install auro, you need the Nim language. Run `make install` as the superuser, then you can run any auro module with `auro <module_name>`, the module has to be in the working directory or installed in the system. To install an auro module run `auro --install <file>`, the file has to have the module name.

To execute a Auro module, use `auro <modulefile>`. To create module files, you can use [Aulang](https://gitlab.com/aurovm/aulang) or [AuLua](https://gitlab.com/aurovm/aulua). To see the contents of a compiled module, you can use [aurodump](https://gitlab.com/aurovm/aurodump). You can also compile a Auro module to Javascript with [auroweb](https://gitlab.com/aurovm/auroweb). You can see lua running in the web implementation [here](http://arnaud.com.ve/auro/).

