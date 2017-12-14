# Windows Server 2016

Windows Server 2016 nodes can be initialised with the Shippable agent to run runSh builds. Some of the pre-requisites for installing it are listed below. After installing the pre-requisites, please read about [how to add the node using Shippable UI](http://docs.shippable.com/platform/tutorial/runtime/custom-nodes/). We do not support auto initialisation for macOS at this time. Only manual scripts are supported.

## Prerequisites
- [tar](http://gnuwin32.sourceforge.net/packages/gtar.htm)
- [gzip](http://gnuwin32.sourceforge.net/packages/gzip.htm)
- Add Inbound rule to allow port 2375 in Windows Firewall 
