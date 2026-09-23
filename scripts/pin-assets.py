#!/usr/bin/env python3
"""Maintainer-only pin creation. Downloads public fixed revisions; no runtime catalog lookup."""
import concurrent.futures, hashlib, json, pathlib, urllib.request, time, subprocess
ROOT=pathlib.Path(__file__).resolve().parent.parent
MODEL_REV='0f63a7800b00dd0226abd051b906c246e1907482'
TOKEN_REV='e37978b90ca9030d5170a5c07aadb050351a65bb'
repo=json.load(open(ROOT/'artifacts/model-repo.json'))
def get(job):
    url, path, local=job
    local.parent.mkdir(parents=True,exist_ok=True)
    if not local.exists():
        for attempt in range(3):
            try:
                subprocess.run(['curl','--fail','--location','--silent','--show-error','--retry','4','--retry-all-errors','--max-time','600',url,'-o',str(local)+'.partial'],check=True)
                pathlib.Path(str(local)+'.partial').replace(local); break
            except Exception:
                if attempt==2: raise
                time.sleep(2)
    h=hashlib.sha256()
    with local.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''): h.update(b)
    return {'path':path,'url':url,'bytes':local.stat().st_size,'sha256':h.hexdigest()}
catalog=[]
for name in ['base','small']:
    prefix='openai_whisper-'+name+'/'
    jobs=[]
    for item in repo['siblings']:
        source=item['rfilename']
        if source.startswith(prefix):
            relative=source[len(prefix):]
            jobs.append((f'https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/{MODEL_REV}/{source}',relative,ROOT/'artifacts/models'/name/relative))
    for source in ['tokenizer.json','tokenizer_config.json','special_tokens_map.json']:
        jobs.append((f'https://huggingface.co/openai/whisper-base/resolve/{TOKEN_REV}/{source}',source,ROOT/'artifacts/models'/name/source))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: files=list(pool.map(get,jobs))
    catalog.append({'id':name,'displayName':'Whisper '+name+' · multilingual','revision':MODEL_REV,'tokenizerRevision':TOKEN_REV,'license':'MIT (OpenAI Whisper / Argmax Core ML conversion); tokenizer Apache-2.0 repository metadata','files':files})
    print(name,sum(f['bytes'] for f in files),flush=True)
    (ROOT/'Resources/Models.json').write_text(json.dumps({'schema':1,'models':catalog},indent=2)+'\n')
