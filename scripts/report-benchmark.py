#!/usr/bin/env python3
import json,sys,math,pathlib
rows=[json.loads(x) for x in open(sys.argv[1]) if x.startswith('{')]; quality=[x for x in rows if x['phase']=='quality']
failed=False
result={}
for lang,limit in [('en',.20),('fr',.25)]:
 group=[x for x in quality if x['language']==lang and x['kind'] in ['speech','quiet']]
 n=sum(x['referenceWords'] for x in group); rate=sum(x['wordErrors'] for x in group)/n if n else 1
 result[lang+'WER']=rate;failed|=rate>limit
 for split in ['calibration','heldout']:
  selected=[x for x in group if x['split']==split];count=sum(x['referenceWords'] for x in selected)
  result[lang+split+'WER']=sum(x['wordErrors'] for x in selected)/count if count else None
quiet=[x for x in quality if x['kind']=='quiet'];result['quietWER']=sum(x['wordErrors'] for x in quiet)/sum(x['referenceWords'] for x in quiet)
terms=sum(x['termCount'] for x in quality);result['technicalTermsPreserved']=sum(x['termsPreserved'] for x in quality)/terms if terms else 0
failed|=result['technicalTermsPreserved']<.8
noise=[x for x in quality if x['kind']=='noSpeech'];result['noSpeechRejections']=sum(x['noSpeech'] for x in noise);failed|=len(noise)!=10 or result['noSpeechRejections']!=10
for group in [3,8,15,'all']:
 vals=sorted(x['decodeSeconds'] for x in rows if x['phase']=='warm' and (group=='all' or x['group']==group))
 if vals:result['warmDecode'+str(group)]={'n':len(vals),'p50':vals[math.ceil(.5*len(vals))-1],'p95':vals[math.ceil(.95*len(vals))-1]}
memory=[x['residentBytes'] for x in rows if x['phase']=='memory'];result['memoryFirstLastBytes']=[memory[0],memory[-1]] if memory else []
result['memoryGrowth']=memory[-1]/memory[0]-1 if memory and memory[0] else None
result['summary']=next((x for x in rows if x['phase']=='summary'),{})
result['note']='Decode-only file measurements, not release-to-insertion; no permission-based gates are passed by this report.'
result['qualityGates']='FAIL' if failed else 'PASS'
out=pathlib.Path(sys.argv[1]).with_suffix('.summary.json');out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if failed:sys.exit(1)
