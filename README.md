# memory_diagnostic_script
This script is supposed to monitor the impact of introducing new features on the existing processes of an RTOS device

***************************************RDK-B DIAGNOSTIC SCRIT************************************
Usage:

   -h --help    		= To display help menu
   -u --upload  		= TFTP IP			(upload or skip) 
   -p --polling-time    	= Polling time in seconds 	(300 seconds by default)
   -t --total-time  	        = Total time in seconds 	(1800 seconds by default)


			[NOTE]:To run the script use 'nice -n -20 ./diag.sh'
Application:

The script aims to generate report for the memory utilizaion of processes running on RDKB devices.
Capabilites can be enhaced to cater many Linux based systems as well. This can be handy for QA/Dev 
teams in case they wish to check for memory impacts generated by introducing new functionality on
the RDKB processes. This can be achieved by comparing the report generated before enabling the 
functionality with the report generated after enabling it. In case there is no corelation between 
these values, the developer needs to check the memory management for that particular functionailty.



The Diagnostic script is used to monitor the following memory parameters associated with the build.
   1. CPU utilization
   2. Load Average
   3. RAM Flash size
   4. Process Memory Utilization
   5. Dev Memory Utilization
   6. VmRSS for processes
   7. Stack memory for processes

The script has 2 modes of operation:

   1. Default mode

In the default mode, the script will test for all the 7 parameters for all the processes.

   2. Processes specific mode (takes process names as arguments)

We can manually specify the processes that need to be monitored by passing them as seperate arguments.

The report will contain the stastistics related to all the 7 parameters and will be uploaded to the TFTP
server that is specified as an optional arguments.
