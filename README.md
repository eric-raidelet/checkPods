# checkpods
A shell tool for Kubernetes Pods / Containers. 

It's mainly a wrapper around kubectl commands without the need of deeper knowledge of jsonpath structure.
One of the main goals was to provide more detailed information with a single command and only a few command line arguments.

Furthermore, checkpods is able to identify evicted Pods and let you delete evicted Pods with a single command.
One simple feature is to check for a running instance first before it deletes the evicted Pod. 
However this can be suppressed on demand.

The tool provides a compact view, where the output contains only the Pod names or Node names. This is very handy
to pass it over to another tool or process for further handling with xargs.

Please see also the tool that extend checkpods with more possibilities: podlogs and podexec
