#!/bin/bash
#
#
Version="1.0"
# v1.0 - June 4th 2020 - Eric Raidelet
# Initial Release
#
Version="1.1"
# v1.1 - June 5th 2020 - Eric Raidelet
# Including Namespace selector
# Added check to search running Pod instance before Pod deletion
#
Version="1.2"
# v1.2 - June 6th 2020 - Eric Raidelet
# Change: Option -d all: Changed to -d evicted for future options
# Bugfix: Option -l:  didnt show line numbers properly
# Bugfix: Option -d evicted : Find running instances with chart name and container name 
# Enhancement: Option -c node: sorts out duplicates
Version="1.3"
# v1.3 - June 17th 2020 - Eric Raidelet
# Enhancement: Added the option -o to get Pods on a specific node
# Enhancement: Added the option -k to get Containers by Pod
# Enhancement: Added the option -w to include kubectl watch feature
# Change: The default list now contains Node IP and Pod IP
# Change: When deleting all evicted Pods with -d evicted, tell if
#         there were 0 pods evicted instead of returning nothing
# 
Version="1.4"
# v1.4 - June 18th 2020 - Eric Raidelet
# Enhancement: Add the option -f to suppress Pod deletion confirmations
# Enhancement: Add the option -H to suppress headers regardless of -l
# Enhancement: Add the option -D to get a dashboard like topology view
# Bugfix: Option -c for compact view included headers
Version="1.5"
# v1.5 - June 24th 2020 - Eric Raidelet
# Enhancement: Changed the overall output handling and enabled the possibility
#              to check for specific Pod names only, as an example:
#              checkpods.sh -D "pod1 pod2 pod3" ---> Show overview for 3 Pods in the same default namespace


# defining some variables, no fancy stuff

NoHeaders="false"
ShowLines="false"
PodStatus="!=shownothing"
SortOrder=".metadata.name"
NameSpace="--all-namespaces"
Node=""
SelectedNode=""
CompactView="false"
ShowColumns="all"
DeletePod=""
DeleteSilently="false"
ForceDeletion="false"
DeleteAllEvicted="false"
ContainerDetails="false"
PodTopology="false"
UseWatch="false"
PodList=""
LogsSinceHours="2"
ShowOnlyIssuePods="true"

# console colors to impress you

color_white="\033[1;37m"
color_orange="\033[0;33m"
color_red="\033[0;31m"
color_green="\033[0;32m"
color_nc="\033[0m"

# No root, no cookies
if [ "$(id -u)" != "0" ]; then echo -e "\nThis script must run ${color_white}as uid=0 (root)${color_nc}\n"; exit 1; fi



# usage shows the help 

usage()
{
	echo ""
	echo -e "${color_orange}checkpods v$Version - Eric Raidelet${color_nc}"
	echo "--------------------------------------------------------------"
	echo "This tool is mainly a wrapper around K8s onboard utilities"
	echo "with the advantage to make Pod checks easier for non"
	echo "console junkies. It also provides an easy way to delete"
	echo "evicted Pods with a single command while checking"
	echo "for a running instance first for your safety."
	echo "--------------------------------------------------------------"
	echo ""
	echo "checkpods.sh \"Pod1 Pod2\" ---> Show details about these 2 Pods"
	echo "                              in the same default namespace."
	echo ""
	echo -e "${color_white}General usage${color_nc}"
	echo "-H = suppress headers"
	echo "-l = Show line numbers for counting, suppress headers"
	echo "-p = Show only Pods with specific Phase/Status"
	echo "     -p <a | all> = show all Pods" 
	echo "     -p <r|running> = show only running Pods"
	echo "     -p <f|failed|evicted> = show all but running Pods"
	echo "-s = Sort by (Default: Pod name)"
	echo "     -s <n|node> = Sort by Node the Pod is located"
	echo "     -s <t|time> = Sort by time the Pod was created"
	echo "     -s <r|restart> = Sorty by Restart Count" 
	echo "-n = Show only specific namespace (Default: all)"
	echo "     -n <kube-system|default|...>"
	echo "-o = Show only Pods on a specific Node"
	echo "     -o <...> Specified by Node name"
	echo "-c = Compact view"
	echo "     -c <p | pod> Pod name only"
	echo "     -c <n | node> Node name only"
	echo "     Note: Using -l with -c hides headers AND also numbers."
	echo "           The usecase is mostly to pass the output to other scripts for further usage or checkpods.sh itself."
	echo "-w = Watch the list dynamically for changes. Does not work with all options and relies on kubectl -w ."
	echo ""
	echo -e "${color_white}Pod deletion${color_nc}"
	echo "-d = Delete Pods"
	echo "     -d <e | evicted> Delete all evicted Pods"
	echo "     -d <...> Specified by Pod name, can be multiple delimited by space"
	echo "-q = Quiet mode, add this option to -d to suppress all -d delete confirmations and questions"
	echo "-f = Force mode, add this option to -d to force Pod deletion. Use with caution! Read K8s manual!"
	echo ""
	echo -e "${color_white}More infos${color_nc}"
	echo "-C = List Containers by Pod with details"
	echo "     Note: The option -c has priority and hides details."
	echo "-D = Dashboard-like topology overview."
	echo "     This view does not provide the -w option."
	echo "     Objects marked with (X) have events in the queue, check them with \"kubectl get events\"."
	echo "     Note: The option -c has no effect with -D"
	echo ""
	echo -e "${color_orange}Example:${color_nc}"
	echo "--------------------------------------------------------------"
	echo "checkpods -n myspace -p failed -s node --> Show only failed Pods in namespace myspace, order by Node"
	echo "checkpods -d my-pod-35hhd773-487dh73   --> Delete Pod with name my-pod-35hhd773-487dh73"
	echo "checkpods -d evicted -f                --> Delete all evicted Pods, suppress safety questions"
	echo "checkpods -D -o my-node-01           --> Show Dashboard-like overview from node prod-node-01"
	echo "checkpods -D | grep \"(X)\"              --> Show Dashboard-like overview and grep for objects with events"
	echo ""
	echo "More advanced:"
	echo "checkpods.sh -o my-node-01 -c pod | xargs checkpods.sh -D"
	echo "First run checkpods.sh to get a -c compact view from all Pods on node -o my-node-01"
	echo "Pass the list of Pod names to xarg and show checkpods.sh -D dashboard overview with these Pods"
	echo ""

	exit 0
}



# retrieving the command line arguments

while getopts "hHlp:s:n:o:d:fqc:CDw" OPTION
do
	case $OPTION in
		H)
		NoHeaders="true"
		;;
		l)
		NoHeaders="true"
		ShowLines="true"
		;;
		p)
		Phase=$OPTARG
		;;
		s)
		Sort=$OPTARG
		;;
		n)
		NameSpace="--namespace=$OPTARG"
		;;
		o)
		Node=$OPTARG
		;;
		d)
		DeletePod=$OPTARG
		;;
		f)
		ForceDeletion="true"
		;;
		q)
		DeleteSilently="true"
		;;
		c)
		CompactView=$OPTARG
		;;
		C)
		ContainerDetails="true"
		;;
		D)
		PodTopology="true"
		;;
		w)
		UseWatch="true"
		;;
		*)
		usage
		exit n | 1
		;;
	esac
done

# Get the remaining arguments, we await 1 or multiple space delimited pod names here

shift $(($OPTIND - 1))
if [ $# -gt 0 ]; then PodList=$*; fi

if [ "$PodList" != "" ]
then
	origIFS=$IFS
	IFS=" "
	read -a PodListArray <<< $PodList
	IFS=$origIFS
fi

case $Phase in
	"" | "all")
	PodStatus="!=blablablabla"
	;;
	"e" | "evicted" | "f" | "failed")
	PodStatus="!=Running"
	;;
	"r" | "running")
	PodStatus="=Running"
	;;
	*)
	PodStatus="!=blablablabla"
	;;
esac

case $Sort in
	"c" | "created" | "t" | "time" | "start")
	SortOrder=".metadata.creationTimestamp"
	;;
	"r" | "restart")
	SortOrder=".status.containerStatuses[0].restartCount"
	;;
	"n" | "node")
	SortOrder=".spec.nodeName"
	;;
	*)
	SortOrder=".metadata.name"
	;;	
esac

case $Node in
	"")
	SelectedNode="!=dummynodename"
	;;
	*)
	SelectedNode="=$Node"
	;;
esac
	

case $DeletePod in
	"e" | "evicted")
	DeletePod="evicted"
	;;
	"l" | "list")
	DeletePod="list"
	;;
	*)
	DeletePod=""
	;;
esac

case $CompactView in
	"node" | "nodes" | "n")
	ShowColumns="node"
	;;
	"pod" | "pods" | "p")
	ShowColumns="pod"
	;;
	"" | "false")
	ShowColumns="all"
	;;
	*)
	ShowColumns="pod"
	;;
esac



# The user wants a Pod Topology list

if [ "$PodTopology" = "true" ]
then

	if [ "$PodList" = "" ]
	then
		PodListArray=$(kubectl get pods $NameSpace --no-headers=true --field-selector=status.phase$PodStatus,spec.nodeName$SelectedNode --sort-by=$SortOrder -o=custom-columns=NAME:.metadata.name)
	fi
	
	if [ "$NoHeaders" != "true" ]
	then 
		echo -e "\n${color_orange}Collecting infos, this might take some time...${color_nc}\n"
	fi

	# Lets iterate through the pods
	
	Output=""
	if [ "$NoHeaders" != "true" ]
	then
		Output+="POD||NS||STATUS||NODE||OWNERTTYPE||OWNERNAME||RDY/AVL/REQ||DEPLOYMENT\n"
	fi	
	
	declare -A PodNodeArray
	declare -A PodParentArray
	IssueCounter=0
	
	
	for ThisPod in ${PodListArray[*]}
	#for ThisPod in $(kubectl get pods $NameSpace --no-headers=true --field-selector=status.phase$PodStatus,spec.nodeName$SelectedNode --sort-by=$SortOrder -o=custom-columns=NAME:.metadata.name)
	do


		Values=$(kubectl get pods $NameSpace --no-headers=true --field-selector=metadata.name=$ThisPod -o=custom-columns=NAME:.metadata.name,NS:.metadata.namespace,NODE:.spec.nodeName,CONTAINES:.spec.containers[*].name,STATUS:.status.phase,TYPE:.metadata.ownerReferences[*].kind,PARENT:.metadata.ownerReferences[*].name)
		PodName=$(echo $Values | awk '{print $1}')
		PodNameSpace=$(echo $Values | awk '{print $2}')
		PodNode=$(echo $Values | awk '{print $3}')
		Containers=$(echo $Values | awk '{print $4}')
		PodStatus=$(echo $Values | awk '{print $5}')
		OwnerType=$(echo $Values | awk '{print $6}')
		PodOwner=$(echo $Values | awk '{print $7}')
		
		# Reset Pod status before enumerating
		PodNameLabel="$PodName"
		PodContainerIssue="false"
		PodHasIssue="false" 
		OutputNewPod=""
		
		read -d, -a ContainerArray <<< $Containers
		
		Label="\e[1A\e[KGetting infos for ${color_white}$PodName${color_nc}: "

		echo -e $Label
		
		
		
		for ThisContainer in "${ContainerArray[@]}"
		do
			echo -e "\e[1A\e[K${Label}Checking logs for container ${color_white}$ThisContainer${color_nc}\n"		
			cmd="kubectl logs $ThisPod -c $ThisContainer -n $PodNameSpace --timestamps=true --since=${LogsSinceHours}h | grep 'ERR'"
			Values=$(eval $cmd)
			if [ "$Values" != "" ]
			then
				PodNameLabel=" (X) $PodName"
				PodContainerIssue="true"
			fi
		done
		
		if [ "$PodContainerIssue" = "true" ]; then IssueCounter=$(( $IssueCounter+1 )); PodHasIssue="true"; fi

		
		
		# Check for Pod events
		
		echo -e "\e[1A\e[K${Label}Checking Pod events\n"
		
		Values=""
		Values=$(kubectl get events --no-headers=true --all-namespaces --field-selector=involvedObject.kind=Pod,involvedObject.name=$PodName -o=custom-columns=MSG:.message)
		if [ "$Values" != "" ]
		then
			if [ "PodHasIssue" != "true" ]
			then
				PodNameLabel=" (X) $PodName"
				IssueCounter=$(( $IssueCounter+1 ))
				PodHasIssue="true"
			fi
		fi

		# Check for Node events
		
		echo -e "\e[1A\e[K${Label}Checking events Node ${color_white}$PodNode${color_nc}\n"
		
		PodNodeLabel="$PodNode"
		Values=""
		
		if [[ -v ${PodNodeArray["$PodNode"]} || -z ${PodNodeArray["$PodNode"]} ]]
		then
			PodNodeArray["$PodNode"]="$PodNodeLabel"
			Values=$(kubectl get events --no-headers=true --all-namespaces --field-selector=involvedObject.kind=Node,involvedObject.name=$PodNode -o=custom-columns=MSG:.message)
			if [ "$Values" != "" ]
			then
				PodNodeLabel=" (X) $PodNode"
				PodNodeArray["$PodNode"]="$PodNodeLabel"
				IssueCounter=$(( $IssueCounter+1 ))
				PodHasIssue="true"
			fi
		else	
			PodNodeLabel=${PodNodeArray["$PodNode"]}
		fi
		
		# Check for rs/sts events
		
		echo -e "\e[1A\e[K${Label}Checking events for RS/STS ${color_white}$PodOwnerLabel${color_nc}\n"
		
		PodOwnerLabel="$PodOwner"
		Values=""
		if [[ -v ${PodParentArray["$PodOwner"]} || -z ${PodParentArray["$PodOwner"]} ]]
		then
			PodParentArray["$PodOwner"]="$PodOwnerLabel"
			if [ "$OwnerType" = "ReplicaSet" ]
			then
				Values=$(kubectl get events --no-headers=true --all-namespaces --field-selector=involvedObject.kind=ReplicaSet,involvedObject.name=$PodOwner -o=custom-columns=MSG:.message)
			elif [ "$OwnerType" = "StatefulSet" ]
			then
				Values=$(kubectl get events --no-headers=true --all-namespaces --field-selector=involvedObject.kind=StatefulSet,involvedObject.name=$PodOwner -o=custom-columns=MSG:.message)
			elif [ "$OwnerType" = "DaemonSet" ]
			then
				Values=$(kubectl get events --no-headers=true --all-namespaces --field-selector=involvedObject.kind=DaemonSet,involvedObject.name=$PodOwner -o=custom-columns=MSG:.message) 
			fi
			
			if [ "$Values" != "" ]
			then
				PodOwnerLabel=" (X) $PodOwner"
				PodParentArray["$PodOwner"]="$PodOwnerLabel"
				IssueCounter=$(( $IssueCounter+1 ))
				PodHasIssue="true"
			fi
		else
			PodOwnerLabel=${PodParentArray["$PodOwner"]}
		fi
		
		OutputNewPod+="$PodNameLabel||$PodNameSpace||$PodStatus||$PodNodeLabel||"	

		
		echo -e "\e[1A\e[K${Label}Retrieving available replicas\n"
		
		MarkerRdy=""
		MarkerAvl=""
		
		if [ "$OwnerType" = "ReplicaSet" ]
		then
			
			Values=$(kubectl get rs --no-headers=true -n $PodNameSpace --field-selector=metadata.name=$PodOwner -o=custom-columns=TYPE:.metadata.ownerReferences[*].kind,PARENT:.metadata.ownerReferences[*].name,REQREPL:.status.replicas,AVREPL:.status.availableReplicas,READYREPL:.status.readyReplicas)
			ParentType=$(echo $Values | awk '{print $1}')
			Parent=$(echo $Values | awk '{print $2}')
			Replicas=$(echo $Values | awk '{print $3}')
			AvailableReplicas=$(echo $Values | awk '{print $4}')
			ReadyReplicas=$(echo $Values | awk '{print $5}')
			MarkerRdy=""
			MarkerAvl=""
			if [ "$ReadyReplicas" -lt "$Replicas" ]; then MarkerRdy="(X) "; IssueCounter=$(( $IssueCounter+1 )); PodHasIssue="true"; fi
			if [ "$AvailableReplicas" -lt "$Replicas" ]; then MarkerAvl="(X)"; IssueCounter=$(( $IssueCounter+1 )); PodHasIssue="true"; fi
			if [ "$ParentType" != "Deployment" ]
			then
				Parent="$ParentType: $Parent"
			fi
			
			ParentLabel="$Parent"
			Values=""
			if [[ ! "${PodParentArray[@]}" =~ "${PodOwner}" ]]
			then
				PodArray+=("$PodNode")
				Values=$(kubectl get events --no-headers=true --all-namespaces --field-selector=involvedObject.kind=deployment,involvedObject.name=$PodOwner -o=custom-columns=MSG:.message)
				if [ "$Values" != "" ]
				then
					ParentLabel=" (X) $Parent"
					IssueCounter=$(( $IssueCounter+1 ))
					PodHasIssue="true"
				fi
			fi
			
			OutputNewPod+="$OwnerType||$PodOwnerLabel||$MarkerReady$ReadyReplicas/$MarkerAvl$AvailableReplicas/$Replicas||$ParentLabel\n"
		
			
		elif [ "$OwnerType" = "StatefulSet" ]
		then
			Values=$(kubectl get statefulsets -n $PodNameSpace --no-headers=true --field-selector=metadata.name=$PodOwner -o=custom-columns=REQREPL:.status.replicas,AVREPL:.status.currentReplicas,READYREPL:.status.readyReplicas)
			Replicas=$(echo $Values | awk '{print $1}')
			AvailableReplicas=$(echo $Values | awk '{print $2}')
			ReadyReplicas=$(echo $Values | awk '{print $3}')
			MarkerRdy=""
			MarkerAvl=""
			if [ "$ReadyReplicas" -lt "$Replicas" ]; then MarkerRdy="(X) "; IssueCounter=$(( $IssueCounter+1 )); PodHasIssue="true"; fi
			if [ "$AvailableReplicas" -lt "$Replicas" ]; then MarkerAvl="(X) "; IssueCounter=$(( $IssueCounter+1 )); PodHasIssue="true"; fi
			OutputNewPod+="$OwnerType||$PodOwnerLabel||$MarkerRdy$ReadyReplicas/$MarkerAvl$AvailableReplicas/$Replicas||-\n"
		elif [ "$OwnerType" = "DaemonSet" ]
		then
			Values=$(kubectl get daemonsets -n $PodNameSpace --no-headers=true --field-selector=metadata.name=$PodOwner -o=custom-columns=REQREPL:.status.desiredNumberScheduled,AVREPL:.status.numberAvailable,READYREPL:.status.numberReady)
			Replicas=$(echo $Values | awk '{print $1}')
			AvailableReplicas=$(echo $Values | awk '{print $2}')
			ReadyReplicas=$(echo $Values | awk '{print $3}')
			MarkerRdy=""
			MarkerAvl=""
			if [ "$ReadyReplicas" -lt "$Replicas" ]; then MarkerRdy="X:"; IssueCounter=$(( $IssueCounter+1 )); PodHasIssue="true"; fi
			if [ "$AvailableReplicas" -lt "$Replicas" ]; then MarkerAvl="X:"; IssueCounter=$(( $IssueCounter+1 )); PodHasIssue="true"; fi
			OutputNewPod+="$OwnerType||$PodOwnerLabel||$MarkerRdy$ReadyReplicas/$MarkerAvl$AvailableReplicas/$Replicas||-\n"
		else
			OutputNewPod+="$OwnerType||$PodOwnerLabel||-/-/-||-\n"
		fi
		
		if [ "$NoHeaders" != "" ]
		then
			echo -e "\e[1A\e[K"; 
			echo -e "\e[1A\e[K";
			echo -e "\e[1A\e[K";			
		fi
		
		if [ "$ShowOnlyIssuePods" != "true" ] || [ "$PodHasIssue" = "true" ]
		then
			Output+=$OutputNewPod
		fi
		
	done
	
	
	
	if [ "$Output" != "" ]
	then
		printf "%b" $Output | column -t -s "||"
		if [ "$NoHeaders" != "" ] && [ $IssueCounter -gt 0 ]
		then
			echo ""
			echo -e "Found ${color_white}$IssueCounter objects marked with (X) ${color_nc}with events or issues."
			echo ""
		fi
	fi 
	
	# This view will end here and terminate the tool gracefully
	
	exit 0

fi




# the user wants to delete pods

if [ "$DeletePod" != "" ]
then
	if [ "$ForceDeletion" = "true" ]; then echo -e "${color_red}Force deletion was used, this is not recommended!${color_nc}"; fi
	if [ "$DeletePod" = "evicted" ]
	then
		echo -e "${color_orange}Deleting all evicted Pods${color_nc}"
		if [ "$ForceDeletion" = "true" ]; then echo -e "${color_red}Force deletion was used, this is not recommended!{color_nc}"; fi
		LastChartFound=""
		LastChartPod=""
		ThisPodContainerName=""
		LastPodContainerName=""		
		Counter=0
 
		# we will now iterate through the pods in the given namespace

		for ThisPod in $(kubectl get pods $NameSpace --no-headers=true --field-selector status.phase!=Running -o=custom-columns=NAME:.metadata.name,.STATUS:.status.reason | grep Evicted | awk '{print $1}')
		do
			ThisPodChartName=""
			CheckChart=""
			CheckContainerName=""
			StartSearch="true"
			Counter=$(Counter+1)
			echo "------------------------------------------------------"
			echo -e "Working on evicted Pod ${color_white}$ThisPod${color_nc}"
			
			# lets grab the chart name used by th pod for a comparison later
	
			ThisPodChartName=$(kubectl get pods $NameSpace --field-selector metadata.name=$ThisPod -o jsonpath="{.items[*].metadata.labels."chart/name"}")
			ThisPodContainerName=$(kubectl get pods $NameSpace --field-selector metadata.name=$ThisPod -o jsonpath="{.items[*].spec.containers[*].name}")			

			# an empty chart name variable prevents checks or run in issues, we dont want that
	
			if [ "$ThisPodChartName" = "" ]
			then
				echo -e "${color_orange}Pod $ThisPod has no chart, skipping${color_nc}"
				continue
			fi

			# lets go on

			echo -e "Pod is using chart ${color_white}$ThisPodChartName${color_nc}"
			echo -e "Pod has container name ${color_white}$ThisPodContainerName${color_nc}"

			# a previous search might have already found an instance using the given chart.
			# depending on your infrastructure the search can take a while. 
			# lets ask the user if he really wants to search again
	
			if [ "$LastChartFound" != "" ] && [ "$LastChartFound" == "$ThisPodChartName" ] && [ "$LastContainerName" == "$ThisPodContainerName" ]
			then
				echo -e "${color_green}Hint:${color_nc}"
				echo -e "This Pod uses chart ${color_white}$ThisPodChartName${color_nc} with container name ${color_white}$ThisPodContainerName${color_nc}"
				echo -e "This is used at least by running Pod ${color_white}$LastChartPod${color_nc} with chart ${color_white}$LastChartFound${color_nc} and container ${color_white}$LastContainerName${color_nc}"
				if [ "$DeleteSilently" = "true" ]
				then
					echo "Suppress delete confirmation used, skipping option to search again"
					Confirm="y"
				else
					echo "I will skip searching again, type any key to continue or (n)o if you want to start a new search"
					read Confirm
				fi
				
				if [ "$Confirm" == "n" ]
				then
					LastChartFound=""
					LastChartPod=""
					StartSearch="true"
				else
					StartSearch="false"
				fi
			fi

			# we want to search a running pod with the given chart
			# this is only for some safety so you can be sure the evicted pod
			# has already been restarted and is in a running condition.
			# this is not necessary but hey, good to know to be safe

			if [ "$StartSearch" = "true" ]
			then
				echo "Lets check if we find a running instance"
				# why not count the found instances
				Count=0
				for SearchPod in $(kubectl get pods $NameSpace --no-headers=true --field-selector status.phase=Running -o=custom-columns=NAME:.metadata.name)
				do
					#echo "Checking against $SearchPod"
					CheckChart=$(kubectl get pods $NameSpace --no-headers=true --field-selector metadata.name=$SearchPod -o jsonpath="{.items[*].metadata.labels."chart/name"}")
					CheckContainerName=$(kubectl get pods $NameSpace --no-headers=true --field-selector metadata.name=$SearchPod -o jsonpath="{.items[*].spec.containers[*].name}")
					if [ "$CheckChart" = "$ThisPodChartName" ] && [ "$CheckContainerName" = "$ThisPodContainerName" ]
					then	
						echo -e "Pod ${color_white}$SearchPod${color_nc} uses chart ${color_white}$CheckChart${color_nc} and container name ${color_white}$CheckContainerName${color_nc}"
						Count=$((Count+1))
						LastChartFound=$ThisPodChartName
						LastContainerName=$ThisPodContainerName
						LastChartPod=$SearchPod
					fi
				done
				echo -e "${color_green}Found $Count instances${color_nc}"
			fi

			# ask the user if he wants to delete the pod
			# last chance to grab some info before deletion

			if [ "$DeleteSilently" != "true" ]
			then
				echo "Please confirm (type yes) deleting Pod $ThisPod"
				read Confirm
			else
				echo "Suppress delete confirmation used, deleting Pod $ThisPod"
				Confirm="yes"
			fi

			if [ "$Confirm" = "yes" ]
			then
				if [ "$ForceDeletion" != "true" ]
				then
					kubectl delete pods $ThisPod
				else
					kubectl delete pods $ThisPod --grace-period=0 --force
				fi
			else
				echo "skipped"
			fi
		done
		
		if [ "$Counter" = "0" ]; then echo "No Pods were evicted"; fi
		
		exit 0
		
	elif [ "$DeletePod" = "list" ]
	then
		echo -e "${color_orange}Deleting Pods${color_nc}"
		
		if [ "$PodList" = "" ]
		then
			echo -e "No Pod name given by argument."
			exit 1
		fi
		
		for ThisPod in ${PodListArray[*]}
		do
			echo -e "Deleting Pod ${color_white}$ThisPod${color_nc}"
			if [ "$DeleteSilently" != "true" ]
			then
				echo "Press enter to delete Pod..."
				read Confirm
			fi
			if [ "$ForceDeletion" != "true" ]
			then
				kubectl delete pods $ThisPod
			else
				kubectl delete pods $ThisPod --grace-period=0 --force
			fi
		done
		
		exit 0
		
	fi

	
fi




# Here comes the default view
# lets reset the CustomColumns variable first

CustomColumns=""

# If the user wants a -k list of containers in each Pod we will
# adjust the columns accordingly

if [ "$ContainerDetails" = "true" ]
then
	CustomColumns="NAME:.metadata.name,NS:.metadata.namespace,STATUS:.status.phase,NODE:.spec.nodeName,CONTAINERS:.spec.containers[*].name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,IMAGE:.spec.containers[*].image"
fi


# in case the user want a -c compact view we choose which columns to show in the output
# Note that this will also overwrite custom columns specified e.g. by -k and make these obsolete

if [ "$ShowColumns" = "pod" ]
then
	CustomColumns="NAME:.metadata.name"
	NoHeaders="true"
elif [ "$ShowColumns" = "node" ]
then
	CustomColumns="NODE:.spec.nodeName"
	NoHeaders="true"
fi

# if no CustomColumns were set use the default list view

if [ "$CustomColumns" = "" ]
then
	CustomColumns="NAME:.metadata.name,POD-IP:.status.podIP,NODE:.spec.nodeName,NODE-IP:.status.hostIP,NS:.metadata.namespace,CREATED:.metadata.creationTimestamp,PHASE:.status.phase,RESTART:.status.containerStatuses[0].restartCount,STATUS:.status.reason,REASON:.status.message"
fi


# We have our base cmd now, lets get the string

if [ "$PodList" != "" ]
then
	IncludePods="metadata.name=${PodListArray[0]}"
	if [ "$NoHeaders"] != "true" ] && [ ${#PodListArray[*]} -gt 1 ]; then echo -e "${color_orange}Multiple arguments given, but this output only supports field-selector with 1 argument, shrinked to 1${color_nc}."; fi
else
	IncludePods="metadata.name!=dduummyyname"
fi

cmd="kubectl get pods --no-headers=${NoHeaders} ${NameSpace} --field-selector=${IncludePods},status.phase${PodStatus},spec.nodeName${SelectedNode} -o=custom-columns=${CustomColumns} --sort-by=${SortOrder}"


# If option -w was used append it to the cmd line

if [[ "$UseWatch" = "true" && "$DeletePod" = "" ]]
then
	cmd+=" -w"
fi



# simple dummy grep stuff to get the line numnbers as counter

if [ "$ShowLines" = "true" ]
then
	if [ "$ShowColumns" = "all" ]
	then
		cmd+=" | grep -n -v blablablabla"
	fi
fi








# Ok, the cmd was created, here comes the output




# Assume that the user wanted a compact list with all the node names that
# have evicted pods. We dont want to show duplicates in that case (because
# we are still running kubectl to get pods with their nodes, we will have
# duplicates).
# Lets catch that case here

if [ "$ShowColumns" = "node" ]
then

	# This is simple but does the job. Passing everything in an Array
	# automatically sorts out the duplicates.

	unset NodeArray
	declare -A NodeArray
	for Node in $(eval $cmd)
	do
		NodeArray[$Node]=$Node
	done

	# However, that Array keys might now be sorted weird depending on the output
	# If the user wanted a list sorted by node names, lets do that

	if [ "$SortOrder" = ".spec.nodeName" ]
	then
		printf "%s\n" "${NodeArray[@]}" | sort	
	else
		printf "%s\n" "${NodeArray[@]}"	
	fi
	
	# We are done here, so lets exit properly

	exit 0

fi


# Everything else shows the normal output of the command

eval $cmd

exit 0


