#!/usr/bin/env python3
"""Original synthetic corpus. Speech audio stays in ignored artifacts; no microphone is used."""
import json, pathlib, subprocess, wave, random, math, struct, hashlib, sys
root=pathlib.Path(__file__).resolve().parent.parent
out=root/'artifacts/fixtures';out.mkdir(parents=True,exist_ok=True)
en=[
'Please open the window and close the door.',
'The little garden looks beautiful in the morning.',
'We can review the changes after lunch today.',
'Please save this draft before closing the window.',
'I would like another cup of coffee please.',
'Create a new branch in Git and add a unit test for the parser before you update the documentation for this change.',
'The API returns a JSON object with the user name and a status code. Please check the response before saving the result.',
'Our Swift application should keep the microphone closed while idle. Start recording only when the shortcut is held and stop on release.',
'Run the Python script from the terminal and check the output carefully. The configuration file should contain a valid local database address.',
'Please review the Docker configuration and the database migration together. We need a reliable backup before changing the production settings this afternoon.',
'Tomorrow morning we will walk along the river and visit the small bookshop near the bridge. If the weather stays warm, we can have lunch outside and spend the afternoon reading before taking the train home.',
'The team reviewed every page of the report and left a short comment beside each question. We will discuss the remaining issues at our next meeting, agree on the final wording, and send the revised draft to the editor.',
'Please keep the original document open while you compare the two versions. The introduction needs a clearer explanation, but the examples are already helpful. After the review, save a separate copy so we can find the earlier draft.',
'The new library is on the corner beside the station, opposite the bakery. It has a quiet room upstairs where students can work together. I will meet you by the main entrance after my appointment on Thursday afternoon.',
'We should test the complete workflow before making any promises about speed or accuracy. A single successful example does not show that every case works. Record the results carefully and describe any missing evidence in the final report.',
'The afternoon train was delayed because a tree had fallen across the line during the storm.',
'Keep the original clipboard contents if another application copies a new image while dictation is running.',
'A small green notebook was left on the table beside the empty glass and the reading lamp.',
'Cancel the current recording when the computer goes to sleep and ignore any result that arrives later.',
'The final review should distinguish completed implementation from validation that still needs a real device.'
]
fr=[
'Bonjour, pouvez vous ouvrir la fenêtre ce matin ?',
'Le petit jardin est très agréable au printemps.',
'Nous pouvons revoir les changements après le déjeuner.',
'Enregistrez ce brouillon avant de fermer la fenêtre.',
'Je voudrais une autre tasse de café, merci.',
'Créez une nouvelle branche dans Git et ajoutez un test pour le programme avant de modifier la documentation de cette application locale.',
'Cette API renvoie un objet JSON avec le nom du client et un code de réponse. Vérifiez les données avant de les enregistrer.',
'Notre application Swift doit garder le microphone fermé au repos. Elle commence à enregistrer uniquement pendant que vous maintenez le raccourci du clavier.',
'Lancez le script Python dans le terminal et vérifiez soigneusement le résultat. Le fichier de configuration doit contenir une adresse de base valide.',
'Vérifiez la configuration Docker et la migration de la base de données. Nous avons besoin de conserver une copie avant toute modification importante.',
'Demain matin, nous marcherons le long de la rivière avant de visiter la petite librairie près du pont. Si le temps reste agréable, nous pourrons déjeuner dehors et passer quelques heures à lire avant de rentrer en train.',
'Chaque membre de notre équipe a relu le rapport et ajouté une remarque à côté des questions importantes. Nous discuterons des derniers problèmes lors de la prochaine réunion pour préparer une version plus claire avant la fin de la semaine.',
'Gardez le document original ouvert pendant que vous comparez les deux versions. Le premier paragraphe demande une explication plus claire, mais les exemples sont déjà utiles. Après la lecture, enregistrez une nouvelle copie pour retrouver facilement le brouillon précédent.',
'La nouvelle bibliothèque se trouve près de la gare, en face de la boulangerie. Une salle calme est disponible au premier étage pour travailler ensemble. Je vous retrouverai devant la porte principale après mon rendez vous de jeudi après midi.',
'Nous devons tester le parcours complet avant de promettre une certaine vitesse ou une bonne précision. Un seul exemple réussi ne prouve pas que tous les cas fonctionnent. Notez les résultats et décrivez les éléments qui restent à vérifier.',
'Le train de cet après midi a été retardé par un arbre tombé sur la voie pendant la tempête.',
'Conservez le contenu du presse papiers si une autre application copie une nouvelle image pendant la transcription.',
'Un petit carnet vert était posé sur la table à côté du verre vide et de la lampe.',
'Annulez tout enregistrement lorsque cet ordinateur se met en veille et ignorez les résultats qui arrivent plus tard.',
'Le dernier bilan doit distinguer le travail terminé des vérifications qui nécessitent encore un appareil réel.'
]
manifest={'schema':1,'license':'Original reference texts and manifest: CC0-1.0. Synthetic speech generated locally with installed macOS voices; audio is not redistributed.','normalization':'Unicode NFC, lowercase, punctuation to spaces, retain accents; apostrophes split; word-level Levenshtein. No number expansion.','limitations':'Synthetic voices, not natural microphone speech. Two voices per language. Fixed original text, seeds, voices, rate and generated hashes; platform voice updates may change waveforms. Live microphone and natural-speaker robustness remain separate gates.','clips':[]}
def save(name, samples):
 path=out/(name+'.wav')
 with wave.open(str(path),'wb') as f:
  f.setparams((1,2,16000,0,'NONE','not compressed'));f.writeframes(struct.pack('<'+'h'*len(samples),*[max(-32768,min(32767,int(x))) for x in samples]))
 return path
def entry(id,lang,text,path,kind,split,warm=None,voice=None,terms=[]):
 with wave.open(str(path),'rb') as f: duration=f.getnframes()/f.getframerate()
 manifest['clips'].append({'id':id,'language':lang,'reference':text,'path':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'duration':duration,'kind':kind,'split':split,'warmGroup':warm,'voice':voice,'technicalTerms':terms})
for lang,texts,voices in [('en',en,['Samantha','Daniel']),('fr',fr,['Thomas','Amélie'])]:
 for i,text in enumerate(texts):
  name=f'{lang}-{i+1:02}';path=out/(name+'.wav');voice=voices[i%2]
  if not path.exists(): subprocess.run(['say','-v',voice,'-r','180','-o',str(path),'--file-format=WAVE','--data-format=LEI16@16000',text],check=True)
  with wave.open(str(path),'rb') as f: samples=list(struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes())))
  group=3 if i<5 else 8 if i<10 else 15 if i<15 else None
  if group and len(samples)<group*16000: samples += [0]*(group*16000-len(samples));save(name,samples)
  terms=([['Git'],['API','JSON'],['Swift'],['Python'],['Docker']][i-5] if 5<=i<10 else [])
  entry(name,lang,text,path,'speech','heldout' if i>=15 else 'calibration',group,voice,terms)
for i in range(5):
 lang='en' if i<3 else 'fr';index=15+i%5;source=out/f'{lang}-{index+1:02}.wav'
 with wave.open(str(source),'rb') as f: samples=struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))
 path=save(f'quiet-{i+1}',[x*0.035 for x in samples]);entry(f'quiet-{i+1}',lang,(en if lang=='en' else fr)[index],path,'quiet','heldout',voice='attenuated existing synthetic voice')
for i in range(10):
 rng=random.Random(20260923+i);n=16000*(3+i%3)
 # Half exact silence; half seeded low-level room-like noise below speech floor.
 samples=[0]*n if i<5 else [rng.gauss(0,12)+5*math.sin(2*math.pi*60*t/16000) for t in range(n)]
 path=save(f'noise-{i+1:02}',samples);entry(f'noise-{i+1:02}','none','',path,'noSpeech','heldout' if i%2 else 'calibration')
# Long boundary input: concatenate distinct synthetic sentences, then pad to exactly 59 s.
samples=[]
for i in range(10,14):
 with wave.open(str(out/f'en-{i+1:02}.wav'),'rb') as f:samples.extend(struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes())))
samples=(samples+[0]*944000)[:944000];save('boundary-59',samples)
manifest_path=root/'Tests/Fixtures/manifest.json'
if manifest_path.exists() and '--update-manifest' not in sys.argv:
 locked=json.loads(manifest_path.read_text())
 if locked != manifest:
  sys.exit('BLOCKED: generated corpus differs from the frozen manifest. Investigate voice/OS differences; use --update-manifest only for an explicitly documented corpus revision.')
else:
 manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(f'Generated {len(manifest["clips"])} fixed synthetic clips plus 59-second boundary, no microphone used.')
