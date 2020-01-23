#! /bin/bash

# get total cpu time and average cpu efficiency across jobs (and across total cpu time in case jobs all have the same duration)
# checks for jobs completed/failed/timed from 16:00 the previous day to 16:00 on the day this script is executed
# sends an email containing the data

mailto=( "tehrhard@uni-mainz.de" ) # replace or add others if desired

# time range to analyse
start=`date --date="1 day ago" +"%Y-%m-%dT16:00"`
end=`date +"%Y-%m-%dT16:00"`
#start="2019-11-19T16:00"
#end="2019-11-20T16:00"
echo $start;
echo $end;

# job name that the database will be searched for
jobname=icecube-pyglidein;

# set the minimal job duration
# (e.g. to prevent taking into account glideins that are not assigned any computational tasks)
min_cputime_minutes=30
min_cputimeraw=$((min_cputime_minutes*60)) # in seconds

# file to hold cpu efficiency for each job: currently used to obtain average CPU eff. across jobs
outfile=cpu_effs_${start}_to_${end}_gt_${min_cputime_minutes}min.txt

# check if this combination of time range & min. glidein duration has already been processed
if [ -f "$outfile" ]
then
  echo "$outfile exists. Aborting!"
  exit 1
else
  :
fi

echo "Getting total cpu time and cpu efficiency for jobs with name '$jobname' from '$start' to '$end', with min. CPU time ${min_cputime_minutes}min"
cputimes=`sacct -S $start -E $end --name=$jobname --format=cputimeraw -n -X -s to,cd,f`; # in seconds
IFS=' ' read -r -a cputimearray <<< `echo $cputimes`
jobids=`sacct -S $start -E $end --name=$jobname --format=jobid -n -X -s to,cd,f`; # timeout,completed,failed
IFS=' ' read -r -a jobidarray <<< `echo $jobids`

# now calculate total cpu time and no. of jobs
cputimetot=0;
count=0
inds=()
for c in $cputimes
do
  if [ "$c" -gt "$min_cputimeraw" ] # only use if threshold exceeded
  then
    ((cputimetot+=$c))
    inds+=($count)
  else
    ((cputimetot+=0))
  fi
  ((count+=1))
done

cputimetothr=`python -c "print '%.1f' % (float(${cputimetot})/3600.)"` # in hours
echo "total CPU time: ${cputimetothr}h"

# this is the most time consuming part (only needed if one is interested in CPU efficiencies)
njobs="${#inds[@]}"
echo "Need to process $njobs jobs in total. Will now start querying 'seff' for each."
for ind in "${inds[@]}"
do
  j="${jobidarray[ind]}"
  var=`seff $j | grep "CPU Efficiency"`
  var=`echo "$var" | cut -d ' ' -f 3 | cut -d '%' -f 1`
  echo $var >> "${outfile}"
done

# use the following command to take the average of a column in a given file
ave_cpu_eff=`awk '{ total += $0; count++ } END { print total/count }' $outfile`

# delete outfile if desired
#rm ${outfile}

mailtxt="completed jobs: ${njobs}|total CPU time: ${cputimetothr}h|ave. CPU eff.: ${ave_cpu_eff}%"
echo ${mailtxt}
for addr in "${mailto[@]}"
do
  #echo $addr
  mail -s "[mogon-pyglidein] ${start} to ${end} with T > ${min_cputime_minutes}min" $addr <<< $mailtxt
done
#echo "Average CPU efficiency of all jobs: $ave_cpu_eff%"
