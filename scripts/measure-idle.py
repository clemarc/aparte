#!/usr/bin/env python3
"""Read-only process resource sampling. Caller records whether actual Ready was observed."""
import argparse,csv,json,subprocess,time,pathlib
p=argparse.ArgumentParser();p.add_argument('--pid',required=True,type=int);p.add_argument('--seconds',type=int,default=300);a=p.parse_args()
def read():
 fields=subprocess.check_output(['ps','-p',str(a.pid),'-o','time=,rss=,%cpu='],text=True).split()
 parts=fields[0].split(':');seconds=float(parts[-1])+60*int(parts[-2])+(3600*int(parts[-3]) if len(parts)>2 else 0)
 return seconds,int(fields[1])*1024,float(fields[2])
start=time.monotonic();initial=read();rows=[(0,*initial)]
while time.monotonic()-start<a.seconds:
 time.sleep(min(5,a.seconds-(time.monotonic()-start)));rows.append((time.monotonic()-start,*read()))
path=pathlib.Path('artifacts/idle-release.csv')
with path.open('w') as f:
 writer=csv.writer(f);writer.writerow(['elapsedSeconds','cumulativeCPUSeconds','residentBytes','reportedCPUPercent']);writer.writerows(rows)
elapsed=rows[-1][0];average=100*(rows[-1][1]-rows[0][1])/elapsed
result={'durationSeconds':elapsed,'averageCPUPercentOneCore':average,'initialResidentBytes':rows[0][2],'finalResidentBytes':rows[-1][2],'context':'Installed Release process; actual Ready not verified because permissions/desktop interaction are blocked. Not a PASS for the Ready resource gate.'}
path.with_suffix('.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
